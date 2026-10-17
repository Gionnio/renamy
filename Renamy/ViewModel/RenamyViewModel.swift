//
//  RenamyViewModel.swift
//  Renamy
//
//  App state: ingest, search, choices, renaming and undo.
//

import SwiftUI
import Combine
import AppKit

// MARK: - ViewModel

@MainActor
final class RenamyViewModel: ObservableObject {
    @Published var fileList: [MediaFile] = []
    @Published var selectedFolderURL: URL?
    @Published var statusText = "..."
    @Published var isScanning = false; @Published var isProcessing = false
    @Published var progress: Double = 0.0; @Published var etaText: String = ""
    @Published var isShowingRetryAlert = false; @Published var retrySearchName = ""
    /// File su cui agisce la ricerca manuale (un file o un gruppo intero); vuoto = i file da sistemare.
    @Published var manualSearchFileIDs: [UUID] = []
    @Published var showConfirmationAlert = false
    // NEW: finestra a tre colonne
    @Published var sidebarFilter: SidebarFilter? = .all
    @Published var searchText = ""
    /// Riga selezionata: id di un gruppo (`FileGroup.id`) o di un file (`"file:" + uuid`).
    @Published var selection: String?
    @Published var expandedGroups: Set<String> = []

    // FIX: @AppStorage dentro un ObservableObject non notifica la UI da solo:
    // senza willSet il cambio tema/lingua/formato non ridisegnava la finestra.
    @AppStorage("tmdbApiKey")        var apiKey: String = ""            { willSet { objectWillChange.send() } }
    @AppStorage("includeSubfolders") var includeSubfolders = true       { willSet { objectWillChange.send() } }
    @AppStorage("createSubfolders")  var createSubfolders = true        { willSet { objectWillChange.send() } }
    @AppStorage("renameFormat")      var renameFormat: RenameFormat = .plex {
        willSet { objectWillChange.send() }
        didSet { regenerateProposedNames() }   // NEW: i nomi si aggiornano al cambio formato
    }
    @AppStorage("appTheme")          var appTheme: AppTheme = .system  { willSet { objectWillChange.send() } }
    // NEW: anime con AniList e numerazione TMDB dalla mappa delle corrispondenze
    @AppStorage("animeEnabled")       var animeEnabled = true           { willSet { objectWillChange.send() } }
    @AppStorage("animeUseTMDB")       var animeUseTMDB = true           { willSet { objectWillChange.send() } }
    @AppStorage("animeTitlesEnglish") var animeTitlesEnglish = true     { willSet { objectWillChange.send() } }

    @Published var undoHistory: [RenameHistoryItem] = []
    @Published var ambiguousMatches: [AmbiguousMatch] = []
    /// Scelta da fare adesso: si apre nel pannello di destra.
    @Published var currentAmbiguity: AmbiguousMatch? = nil {
        didSet { if let amb = currentAmbiguity { selection = FileGroup.ambiguityID(amb); sidebarFilter = .all } }
    }
    @Published var pendingProcessAfterDisambiguation = false

    private var fileObservers: [UUID: AnyCancellable] = [:]
    private lazy var tmdb = TMDBClient(apiKey: { [weak self] in self?.apiKey ?? "" })
    private let anilist = AniListClient()
    let animeMapping = AnimeMappingStore()
    /// Risultati AniList già visti, per applicare la scelta fatta nel foglio.
    private var anilistMedia: [Int: AniListMedia] = [:]
    private var createdFolders: Set<URL> = []
    private var authFailed = false

    // FIX: prima lo stato iniziale era sempre in italiano
    init() { self.statusText = Strings.get("msg_ready") }
    func t(_ key: String) -> String { Strings.get(key) }
    func updateStatusReady() { statusText = t("msg_ready") }

    /// FIX: i MediaFile sono ObservableObject annidati: senza inoltro, filtro e toolbar
    /// non si aggiornavano quando cambiava lo stato di un singolo file.
    private func observe(_ files: [MediaFile]) {
        let parent = objectWillChange
        for f in files { fileObservers[f.id] = f.objectWillChange.sink { _ in parent.send() } }
    }

    // MARK: Ingest (drop + scan)

    func handleDrop(providers: [NSItemProvider]) {
        guard !isScanning, !isProcessing else { return }
        guard !apiKey.isEmpty else { statusText = t("err_no_api"); return }
        statusText = t("msg_adding"); isScanning = true; progress = 0; etaText = ""

        Task {
            let urls = await resolveProviders(providers)
            let include = includeSubfolders
            // FIX: enumerazione fuori dal main thread (prima bloccava la UI su cartelle grandi)
            let videos = await Task.detached(priority: .userInitiated) {
                await collectVideoURLs(from: urls, includeSubfolders: include)
            }.value

            if selectedFolderURL == nil, !videos.isEmpty {
                let firstDir = urls.first { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true }
                selectedFolderURL = firstDir ?? videos.first?.deletingLastPathComponent()
            }
            await ingest(videos, doneKey: "msg_added")
        }
    }

    func scanFolder() {
        guard let baseURL = selectedFolderURL else { statusText = t("err_no_folder"); return }
        guard !apiKey.isEmpty else { statusText = t("err_no_api"); return }
        guard !isScanning, !isProcessing else { return }
        statusText = t("msg_scanning"); isScanning = true; progress = 0; etaText = ""
        let include = includeSubfolders
        Task {
            let videos = await Task.detached(priority: .userInitiated) {
                await collectVideoURLs(from: [baseURL], includeSubfolders: include)
            }.value
            await ingest(videos, doneKey: "msg_scan_done")
        }
    }

    private func ingest(_ candidates: [URL], doneKey: String) async {
        // FIX: considera anche la posizione attuale, altrimenti dopo "Elabora" una nuova
        // scansione ri-aggiungeva come "nuovi" i file appena spostati.
        let existing = Set(fileList.flatMap { [$0.originalURL.standardizedFileURL, $0.currentURL.standardizedFileURL] })
        let newURLs = candidates.filter { !existing.contains($0) }
        guard !newURLs.isEmpty else {
            statusText = t("msg_no_files"); isScanning = false; progress = 0; etaText = ""
            return
        }

        // NEW: riconoscimento da nome e cartelle ("Season 1", cartella della serie); l'anno presente solo
        // su alcuni episodi della stessa serie e cartella vale per tutti, così fanno la stessa ricerca
        let recognized = newURLs.map { url -> (folder: String, recognition: Recognition) in
            let parent = url.deletingLastPathComponent()
            let folders = [parent.lastPathComponent, parent.deletingLastPathComponent().lastPathComponent]
            return (parent.path, recognize(fileName: url.lastPathComponent, folders: folders))
        }
        let years = harmonizeYears(recognized)
        let newFiles = zip(newURLs, zip(recognized, years)).map { url, item -> MediaFile in
            let r = item.0.recognition
            let file = MediaFile(url: url, status: .pronto, isTVShow: r.isTV, parsedSeason: r.season, parsedEpisode: r.episode)
            file.recognizedTitle = r.title; file.recognizedYear = item.1; file.looksLikeAnime = r.looksLikeAnime
            file.recognizedSeason = r.season; file.recognizedEpisode = r.episode
            return file
        }

        await searchNamesForFiles(newFiles)

        observe(newFiles)
        fileList.append(contentsOf: newFiles)
        if !authFailed { statusText = t(doneKey) }
        isScanning = false; progress = 0; etaText = ""
        rebuildAmbiguities()
        currentAmbiguity = ambiguousMatches.first
    }

    func resetAll() {
        isScanning = false; isProcessing = false; progress = 0; etaText = ""
        fileList.removeAll(); fileObservers.removeAll(); tmdb.clearCache(); anilist.clearCache(); anilistMedia.removeAll(); createdFolders.removeAll()
        ambiguousMatches.removeAll(); undoHistory.removeAll()
        currentAmbiguity = nil; pendingProcessAfterDisambiguation = false; manualSearchFileIDs = []
        selection = nil; expandedGroups.removeAll(); searchText = ""
        statusText = t("msg_cleaned")
    }

    // MARK: Search

    func searchNamesForFiles(_ files: [MediaFile]) async {
        statusText = t("msg_searching"); authFailed = false
        progress = 0; etaText = ""
        let total = max(files.count, 1); let start = Date(); var processed = 0
        for file in files {
            if authFailed { file.status = .erroreRete } else { await searchName(for: file) }
            processed += 1
            progress = Double(processed) / Double(total)
            if processed > 3 { etaText = calcolaETA(processed: processed, total: total, startTime: start) }
        }
        if !authFailed { statusText = t("msg_search_done") }
    }

    func searchName(for file: MediaFile, overrideQuery: String? = nil) async {
        var query = ""; var yearToUse: String? = nil; let isTV = file.isTVShow
        if let q = overrideQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty { query = q } else {
            query = file.recognizedTitle; yearToUse = file.recognizedYear
        }
        guard !query.isEmpty else { file.status = .nonTrovato; return }
        file.anilistID = nil
        // NEW: i nomi in stile anime si cercano prima su AniList; se AniList non trova nulla si prova TMDB
        if overrideQuery == nil, animeEnabled, file.looksLikeAnime, await searchAnime(for: file, query: query) { return }
        do {
            let cands = try await tmdb.search(query: query, year: yearToUse, isTV: isTV)
            handleCandidates(cands, file: file, query: query, year: yearToUse)
        } catch TMDBError.unauthorized {
            authFailed = true; file.status = .erroreRete; statusText = t("err_api_invalid")
        } catch {
            file.status = .erroreRete
        }
    }

    private func handleCandidates(_ cands: [DisambiguationCandidate], file: MediaFile, query: String, year: String?) {
        guard !cands.isEmpty else { file.status = .nonTrovato; file.ambiguousCandidates = nil; return }
        if cands.count == 1 { applyCandidate(cands[0], to: file); return }
        // NEW: se un solo risultato ha titolo identico (e anno coincidente, se noto) lo sceglie da solo
        let norm = normalizeTitle(query)
        let exact = cands.filter {
            (normalizeTitle($0.title) == norm || normalizeTitle($0.originalTitle) == norm) && (year == nil || $0.year == year)
        }
        if exact.count == 1 { applyCandidate(exact[0], to: file); return }
        file.status = .ambiguo; file.ambiguousCandidates = cands
    }

    // MARK: Anime

    /// true se il file è stato gestito (pronto o da scegliere); false per passare a TMDB.
    private func searchAnime(for file: MediaFile, query: String) async -> Bool {
        guard let results = try? await anilist.search(query), !results.isEmpty else { return false }
        for m in results { anilistMedia[m.id] = m }
        if let pick = AniListAPI.automaticChoice(results, query: query, isTV: file.isTVShow) {
            await applyAniList(pick, to: file)
        } else {
            file.status = .ambiguo
            file.ambiguousCandidates = results.map { $0.candidate(preferEnglish: animeTitlesEnglish) }
        }
        return true
    }

    /// Nome dalla voce AniList: con la mappa diventa titolo, ID e numerazione TMDB (quelli letti da
    /// Plex e Jellyfin); senza corrispondenza resta il titolo AniList, senza tag.
    func applyAniList(_ media: AniListMedia, to file: MediaFile) async {
        file.anilistID = media.id
        if animeUseTMDB, let index = await animeMapping.currentIndex() {
            do {
                if media.isMovie || !file.isTVShow, let movieID = index.tmdbMovie(anilistID: media.id),
                   let cand = try await tmdb.details(id: String(movieID), kind: .movie) {
                    file.isTVShow = false; applyCandidate(cand, to: file); return
                }
                if file.isTVShow, let episode = file.recognizedEpisode.flatMap({ Int($0) }),
                   let ref = index.tmdbEpisode(anilistID: media.id, fileSeason: file.recognizedSeason.flatMap { Int($0) }, fileEpisode: episode),
                   let cand = try await tmdb.details(id: String(ref.tvID), kind: .tv) {
                    applyCandidate(cand, to: file, season: String(format: "%02d", ref.season), episode: String(format: "%02d", ref.episode))
                    return
                }
                if let tv = index.entry(anilistID: media.id)?.tmdbTV, let cand = try await tmdb.details(id: String(tv), kind: .tv) {
                    applyCandidate(cand, to: file); return
                }
            } catch TMDBError.unauthorized {
                authFailed = true; file.status = .erroreRete; statusText = t("err_api_invalid"); return
            } catch {
                // Nome dal titolo AniList
            }
        }
        if media.isMovie { file.isTVShow = false }
        applyCandidate(media.candidate(preferEnglish: animeTitlesEnglish), to: file)
    }

    // MARK: Naming

    /// - Parameters: season, episode: numerazione da usare al posto di quella del nome (anime → TMDB)
    func applyCandidate(_ cand: DisambiguationCandidate, to file: MediaFile, season: String? = nil, episode: String? = nil) {
        file.tmdbID = cand.source == .tmdb ? cand.id : ""
        file.resolvedTitle = cand.title; file.resolvedYear = cand.year; file.resolvedOriginalTitle = cand.originalTitle
        file.posterURL = cand.posterURL.flatMap(URL.init(string:))
        file.parsedSeason = season ?? file.recognizedSeason; file.parsedEpisode = episode ?? file.recognizedEpisode
        let name = buildFileName(for: file)
        file.generatedName = name          // prima di proposedName: vedi proposedNameEdited
        file.proposedName = name
        file.status = .pronto; file.isSelected = true; file.ambiguousCandidates = nil
    }

    /// Metadati risolti del file, nil se non è mai stato abbinato.
    private func resolvedMedia(for file: MediaFile) -> ResolvedMedia? {
        guard let title = file.resolvedTitle else { return nil }
        return ResolvedMedia(title: title, year: file.resolvedYear ?? "", tmdbID: file.tmdbID, isTV: file.isTVShow,
                             season: file.parsedSeason, episode: file.parsedEpisode)
    }

    func buildFileName(for file: MediaFile) -> String {
        guard let media = resolvedMedia(for: file) else { return file.proposedName }
        return Naming.fileName(media, format: renameFormat)
    }

    func seriesFolderName(for file: MediaFile) -> String? {
        resolvedMedia(for: file).map { Naming.seriesFolderName($0, format: renameFormat) }
    }

    func regenerateProposedNames() {
        for f in fileList where f.resolvedTitle != nil
            && [.pronto, .ripristinato].contains(f.status)
            && f.proposedName == f.generatedName {
            let n = buildFileName(for: f)
            f.generatedName = n; f.proposedName = n
        }
    }

    /// Chiamato quando l'utente modifica il nome a mano nella tabella.
    /// NEW: lo stato "Pronto (Manuale)" esisteva ma non veniva mai assegnato; ora un file
    /// "Non Trovato" può essere rinominato scrivendo il nome a mano.
    func proposedNameEdited(_ file: MediaFile) {
        guard file.status != .spostato else { return }
        let name = file.proposedName.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return }
        if name != file.generatedName {
            if file.status != .manuale {
                file.status = .manuale; file.isSelected = true; file.ambiguousCandidates = nil
            }
        } else if file.status == .manuale {
            file.status = .pronto
        }
    }

    // MARK: Fetch diretto per TMDB ID

    func fetchByTMDBID(_ tmdbID: String, kind: MediaKind?, for file: MediaFile) async {
        statusText = t("msg_fetching_id"); file.anilistID = nil
        // Gli ID film e serie sono spazi separati (movie/123 ≠ tv/123): se l'utente specifica
        // "tv:" o "movie:" si usa solo quello, altrimenti si prova prima il tipo più probabile.
        let order: [MediaKind] = kind.map { [$0] } ?? (file.isTVShow ? [.tv, .movie] : [.movie, .tv])

        for k in order {
            do {
                guard let cand = try await tmdb.details(id: tmdbID, kind: k) else { continue }
                file.isTVShow = (k == .tv)
                applyCandidate(cand, to: file)
                return
            } catch TMDBError.unauthorized {
                authFailed = true; file.status = .erroreRete; statusText = t("err_api_invalid")
                return
            } catch { continue }
        }

        file.status = .nonTrovato
        statusText = t("err_id_not_found")
    }

    // MARK: Manual search

    func prepareManualSearch(for file: MediaFile) { prepareManualSearch(for: [file]) }

    /// Ricerca manuale per un gruppo intero (es. tutti gli episodi di una serie).
    func prepareManualSearch(for files: [MediaFile]) {
        guard let file = files.first else { return }
        manualSearchFileIDs = files.map(\.id)
        retrySearchName = file.resolvedTitle ?? file.recognizedTitle
        isShowingRetryAlert = true
    }

    func promptDisambiguation(for file: MediaFile) {
        rebuildAmbiguities()
        currentAmbiguity = ambiguousMatches.first { $0.fileIDs.contains(file.id) }
    }

    /// FIX: prima la ricerca globale includeva TUTTI i file selezionati; dato che i file trovati
    /// vengono auto-selezionati, una ricerca manuale sovrascriveva anche quelli già corretti.
    /// Ora agisce solo sui file problematici (quelli selezionati, o tutti se nessuno è selezionato).
    /// Per correggere un file già "Pronto" si usa il menu contestuale sulla riga.
    private func manualSearchTargets() -> [MediaFile] {
        if !manualSearchFileIDs.isEmpty {
            let ids = Set(manualSearchFileIDs)
            return fileList.filter { ids.contains($0.id) }
        }
        let problems: [FileStatus] = [.nonTrovato, .erroreRete, .erroreRegex, .ambiguo]
        let problematic = fileList.filter { problems.contains($0.status) }
        let selected = problematic.filter(\.isSelected)
        return selected.isEmpty ? problematic : selected
    }

    func retrySearchManual(name: String) {
        let q = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let single = manualSearchFileIDs.first
        let targets = manualSearchTargets()
        manualSearchFileIDs = []
        guard !q.isEmpty else { return }
        guard !apiKey.isEmpty else { statusText = t("err_no_api"); return }
        guard !targets.isEmpty else { statusText = t("err_no_targets"); return }

        let idInfo = extractTMDBID(from: q)
        statusText = idInfo == nil ? "\(t("msg_manual_search")) '\(q)'..." : t("msg_fetching_id")
        isScanning = true; progress = 0; etaText = ""; authFailed = false

        Task {
            var idNotFound = false
            for (i, f) in targets.enumerated() {
                if let info = idInfo {
                    await fetchByTMDBID(info.id, kind: info.kind, for: f)
                    if f.status == .nonTrovato { idNotFound = true }
                } else {
                    await searchName(for: f, overrideQuery: q)
                }
                progress = Double(i + 1) / Double(targets.count)
                if authFailed { break }
            }
            isScanning = false; progress = 0; retrySearchName = ""
            if authFailed { statusText = t("err_api_invalid") }
            else { statusText = idNotFound ? t("err_id_not_found") : t("msg_done") }
            rebuildAmbiguities()
            if let tgt = single { currentAmbiguity = ambiguousMatches.first { $0.fileIDs.contains(tgt) } }
            else { currentAmbiguity = ambiguousMatches.first }
        }
    }

    // MARK: Processing

    func requestProcessing() {
        if createSubfolders && selectedFolderURL == nil { statusText = t("err_no_folder"); return }
        rebuildAmbiguities()
        let selectedIDs = Set(fileList.filter(\.isSelected).map(\.id))
        if let blocking = ambiguousMatches.first(where: { $0.fileIDs.contains(where: selectedIDs.contains) }) {
            pendingProcessAfterDisambiguation = true; currentAmbiguity = blocking; statusText = t("err_ambiguous"); return
        }
        guard !filesToProcess().isEmpty else { statusText = t("err_no_ready"); return }
        showConfirmationAlert = true
    }

    func filesToProcess() -> [MediaFile] {
        fileList.filter {
            $0.isSelected && $0.status != .spostato && $0.status != .ambiguo
            && !sanitizeFileName($0.proposedName).isEmpty
        }
    }

    /// FIX: prima il pannello permessi veniva aperto in modo asincrono e l'elaborazione partiva
    /// comunque, senza aspettare la risposta dell'utente. Ora è bloccante e si può annullare.
    private func ensureWriteAccess(to url: URL) -> URL? {
        if FileManager.default.isWritableFile(atPath: url.path) { return url }
        let panel = NSOpenPanel()
        panel.message = t("panel_access_msg").replacingOccurrences(of: "%@", with: url.lastPathComponent)
        panel.prompt = t("panel_access_btn")
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
        panel.directoryURL = url
        guard panel.runModal() == .OK, let granted = panel.url else { return nil }
        selectedFolderURL = granted
        return granted
    }

    /// Cartella di destinazione (vedi Naming.destinationFolder).
    func destinationFolder(for file: MediaFile, newName: String, base: URL) -> URL {
        Naming.destinationFolder(media: resolvedMedia(for: file), isTV: file.isTVShow,
                                 usesGeneratedName: newName == file.generatedName,
                                 newName: newName, format: renameFormat, base: base)
    }

    func executeProcessing() {
        let toProcess = filesToProcess()
        guard !toProcess.isEmpty else { statusText = t("err_no_ready"); return }

        let useSubfolders = createSubfolders
        var baseURL: URL? = nil
        if useSubfolders {
            guard let base = selectedFolderURL else { statusText = t("err_no_folder"); return }
            guard let writable = ensureWriteAccess(to: base) else { statusText = t("err_write_denied"); return }
            baseURL = writable
        }

        isProcessing = true; statusText = t("msg_processing"); progress = 0
        undoHistory.removeAll(); createdFolders.removeAll()

        Task(priority: .userInitiated) {
            let fm = FileManager.default
            let access = baseURL?.startAccessingSecurityScopedResource() ?? false
            defer { if access { baseURL?.stopAccessingSecurityScopedResource() } }

            for (i, file) in toProcess.enumerated() {
                defer { progress = Double(i + 1) / Double(toProcess.count) }
                let source = file.currentURL
                // FIX: il nome modificato a mano non veniva sanificato ("/" o ":" rompevano il percorso)
                let newName = sanitizeFileName(file.proposedName)
                let ext = source.pathExtension
                let fileName = ext.isEmpty ? newName : "\(newName).\(ext)"

                let folder: URL
                if useSubfolders, let base = baseURL {
                    folder = destinationFolder(for: file, newName: newName, base: base)
                } else {
                    folder = source.deletingLastPathComponent()
                }
                let dest = folder.appendingPathComponent(fileName, isDirectory: false)

                // Già con il nome giusto nel posto giusto: niente da fare
                if dest.standardizedFileURL.path == source.standardizedFileURL.path {
                    file.status = .spostato; continue
                }

                do {
                    // Tiene traccia delle cartelle create per poterle rimuovere con l'undo
                    var missing: [URL] = []; var probe = folder.standardizedFileURL
                    while !fm.fileExists(atPath: probe.path) && probe.pathComponents.count > 1 {
                        missing.append(probe); probe = probe.deletingLastPathComponent()
                    }
                    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
                    createdFolders.formUnion(missing)

                    try moveFileSafely(from: source, to: dest)
                    undoHistory.append(RenameHistoryItem(originalURL: source, newURL: dest, fileID: file.id, baseURL: baseURL))
                    file.currentURL = dest
                    file.status = .spostato
                } catch {
                    file.status = .erroreSpostamento
                }
            }

            isProcessing = false; statusText = t("msg_done"); progress = 0
            for f in toProcess where f.status == .spostato { f.isSelected = false }
        }
    }

    func undoLastOperation() {
        guard !undoHistory.isEmpty, !isProcessing else { return }
        statusText = t("msg_undoing")
        var restoredCount = 0; var failed: [RenameHistoryItem] = []

        // FIX: ordine inverso + cartelle vuote create da Renamy rimosse + la history
        // conserva gli elementi falliti (prima venivano persi).
        for item in undoHistory.reversed() {
            let access = item.baseURL?.startAccessingSecurityScopedResource() ?? false
            defer { if access { item.baseURL?.stopAccessingSecurityScopedResource() } }
            do {
                try FileManager.default.createDirectory(at: item.originalURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try moveFileSafely(from: item.newURL, to: item.originalURL)
                removeEmptyCreatedFolders(startingAt: item.newURL.deletingLastPathComponent())
                if let file = fileList.first(where: { $0.id == item.fileID }) {
                    file.currentURL = item.originalURL; file.status = .ripristinato; file.isSelected = true
                }
                restoredCount += 1
            } catch {
                failed.append(item)
                print("Errore Undo: \(error)")
            }
        }
        undoHistory = Array(failed.reversed())
        statusText = "\(t("msg_undo_done")) \(restoredCount)."
    }

    private func removeEmptyCreatedFolders(startingAt dir: URL) {
        let fm = FileManager.default
        var current = dir.standardizedFileURL
        while createdFolders.contains(current) {
            guard let contents = try? fm.contentsOfDirectory(atPath: current.path),
                  contents.allSatisfy({ $0 == ".DS_Store" }),
                  (try? fm.removeItem(at: current)) != nil else { break }
            createdFolders.remove(current)
            current = current.deletingLastPathComponent()
        }
    }

    // FIX: include anche i file ripristinati / in errore che hanno un nome valido
    func selectAll()   { fileList.filter { [.pronto, .manuale, .ripristinato, .erroreSpostamento].contains($0.status) && !$0.proposedName.isEmpty }.forEach { $0.isSelected = true } }
    func deselectAll() { fileList.forEach { $0.isSelected = false } }

    // MARK: Ambiguities

    func resolveAmbiguity(selected: DisambiguationCandidate) {
        guard let current = currentAmbiguity else { return }
        resolve(current, with: selected)
    }

    /// Applica la scelta al gruppo e agli altri file spuntati in "Applica anche a".
    func resolve(_ ambiguity: AmbiguousMatch, with selected: DisambiguationCandidate, alsoFor extra: Set<UUID> = []) {
        let ids = Set(ambiguity.fileIDs).union(extra)
        let files = fileList.filter { ids.contains($0.id) }
        // NEW: una scelta AniList passa dalla mappa (rete): si prosegue a lavoro finito
        if selected.source == .anilist, let id = Int(selected.id), let media = anilistMedia[id] {
            currentAmbiguity = nil; statusText = t("msg_searching")
            Task {
                for f in files { await applyAniList(media, to: f) }
                statusText = authFailed ? t("err_api_invalid") : t("msg_search_done")
                selection = files.first.map { groupID(containing: $0) }
                continueAfterResolution()
            }
            return
        }
        for f in files { applyCandidate(selected, to: f) }
        // Il gruppo ora è quello della serie o del film scelto
        selection = files.first.map { groupID(containing: $0) }
        continueAfterResolution()
    }

    private func continueAfterResolution() {
        // FIX: prima rimuoveva il match per UUID da una lista che nel frattempo poteva essere stata
        // ricostruita (UUID diversi) → lo stesso sheet si ripresentava. Ora si ricostruisce sempre.
        rebuildAmbiguities()
        if pendingProcessAfterDisambiguation {
            let selectedIDs = Set(fileList.filter(\.isSelected).map(\.id))
            currentAmbiguity = ambiguousMatches.first { $0.fileIDs.contains(where: selectedIDs.contains) }
            if currentAmbiguity == nil {
                pendingProcessAfterDisambiguation = false
                // Lascia chiudere lo sheet prima di presentare l'alert di conferma
                Task { try? await Task.sleep(for: .milliseconds(350)); requestProcessing() }
            }
        } else {
            currentAmbiguity = ambiguousMatches.first
        }
    }

    /// FIX: annullare lo sheet lasciava `pendingProcessAfterDisambiguation` a true e
    /// l'elaborazione ripartiva a sorpresa alla successiva scelta.
    func cancelDisambiguation() {
        pendingProcessAfterDisambiguation = false
        currentAmbiguity = nil
    }

    /// Ricostruisce sempre da zero. NEW: gli episodi della stessa serie con gli stessi candidati
    /// vengono raggruppati → una sola scelta per tutta la stagione invece di una per episodio.
    func rebuildAmbiguities() {
        var order: [String] = []
        var groups: [String: (ids: [UUID], cands: [DisambiguationCandidate], isTV: Bool)] = [:]
        for f in fileList where f.status == .ambiguo {
            guard let cands = f.ambiguousCandidates, !cands.isEmpty else { continue }
            // I film non vengono raggruppati: due film diversi possono avere lo stesso titolo
            let key = f.isTVShow ? "tv:" + cands.map { "\($0.source.rawValue):\($0.id)" }.joined(separator: ",") : "movie:\(f.id.uuidString)"
            if groups[key] == nil { order.append(key); groups[key] = ([], cands, f.isTVShow) }
            groups[key]?.ids.append(f.id)
        }
        ambiguousMatches = order.compactMap { key in
            groups[key].map { AmbiguousMatch(id: key, fileIDs: $0.ids, candidates: $0.cands, isTV: $0.isTV) }
        }
    }

    // Mantiene compatibilità con eventuali chiamate a checkForAmbiguities
    func checkForAmbiguities() { rebuildAmbiguities() }
}
