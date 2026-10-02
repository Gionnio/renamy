//
//  ContentView.swift
//  Renamy
//
//  Version: 2.0.1
//  Target: macOS 14.0+
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import AppKit

// MARK: - Enums & Localization

enum AppLanguage: String, CaseIterable, Identifiable {
    case italian = "Italiano"; case english = "English"
    var id: String { self.rawValue }
    var apiCode: String { self == .italian ? "it-IT" : "en-US" }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { self.rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    func label(for lang: AppLanguage) -> String {
        switch self {
        case .system: return lang == .italian ? "Automatico" : "Automatic"
        case .light:  return lang == .italian ? "Chiaro" : "Light"
        case .dark:   return lang == .italian ? "Scuro" : "Dark"
        }
    }
}

struct Strings {
    // FIX: dizionario statico, prima veniva ricostruito a ogni chiamata
    private static let table: [String: [AppLanguage: String]] = [
        "app_title":          [.italian: "Renamy",                   .english: "Renamy"],
        "settings_title":     [.italian: "Impostazioni",            .english: "Settings"],
        "status_ready":       [.italian: "Pronto",                  .english: "Ready"],
        "status_not_found":   [.italian: "Non Trovato",             .english: "Not Found"],
        "status_ambiguous":   [.italian: "Scegli...",               .english: "Select..."],
        "status_manual":      [.italian: "Pronto (Manuale)",        .english: "Ready (Manual)"],
        "status_moved":       [.italian: "Spostato!",               .english: "Moved!"],
        "status_restored":    [.italian: "Ripristinato",            .english: "Restored"],
        "status_error_move":  [.italian: "Errore File",             .english: "File Error"],
        "status_error_net":   [.italian: "Errore Rete",             .english: "Network Error"],
        "status_error":       [.italian: "Errore",                  .english: "Error"],
        "msg_ready":          [.italian: "Trascina qui file o cartelle.", .english: "Drag files or folders here."],
        "msg_adding":         [.italian: "Analisi nuovi file...",   .english: "Analyzing new files..."],
        "msg_added":          [.italian: "File aggiunti.",          .english: "Files added."],
        "msg_scanning":       [.italian: "Scansione...",            .english: "Scanning..."],
        "msg_no_files":       [.italian: "Nessun nuovo file.",      .english: "No new files."],
        "msg_scan_done":      [.italian: "Fatto.",                  .english: "Done."],
        "msg_cleaned":        [.italian: "Lista svuotata.",         .english: "List cleared."],
        "msg_searching":      [.italian: "Ricerca TMDB...",         .english: "Searching TMDB..."],
        "msg_search_done":    [.italian: "Ricerca completata.",     .english: "Search completed."],
        "msg_processing":     [.italian: "Elaborazione...",         .english: "Processing..."],
        "msg_done":           [.italian: "Tutto fatto!",            .english: "All done!"],
        "msg_undoing":        [.italian: "Ripristino...",           .english: "Restoring..."],
        "msg_undo_done":      [.italian: "Ripristinati:",           .english: "Restored:"],
        "msg_manual_search":  [.italian: "Cerca:",                  .english: "Search:"],
        "msg_fetching_id":    [.italian: "Recupero TMDB ID...",     .english: "Fetching TMDB ID..."],
        "err_no_folder":      [.italian: "Nessuna cartella.",       .english: "No folder."],
        "err_no_api":         [.italian: "Manca API Key.",          .english: "Missing API Key."],
        "err_api_invalid":    [.italian: "API Key TMDB non valida.", .english: "Invalid TMDB API Key."],
        "err_no_ready":       [.italian: "Nessun file pronto.",     .english: "No files ready."],
        "err_no_targets":     [.italian: "Nessun file da cercare.", .english: "No files to search."],
        "err_ambiguous":      [.italian: "Risolvi ambiguità.",      .english: "Resolve ambiguities."],
        "err_id_not_found":   [.italian: "ID non trovato.",         .english: "ID not found."],
        "err_write_denied":   [.italian: "Permesso di scrittura negato.", .english: "Write permission denied."],
        "col_original":       [.italian: "File Originale",          .english: "Original File"],
        "col_proposed":       [.italian: "Nuovo Nome",              .english: "New Name"],
        "col_status":         [.italian: "Stato",                   .english: "Status"],
        "sheet_title":        [.italian: "Seleziona Titolo",        .english: "Select Title"],
        "sheet_original":     [.italian: "File in esame:",          .english: "Analyzing file:"],
        "sheet_applies_to":   [.italian: "La scelta si applica a %d file", .english: "This choice applies to %d files"],
        "sheet_cancel":       [.italian: "Annulla",                 .english: "Cancel"],
        "sec_api":            [.italian: "API",                     .english: "API"],
        "sec_format":         [.italian: "Stile",                   .english: "Style"],
        "sec_appearance":     [.italian: "Aspetto",                 .english: "Appearance"],
        "sec_folders":        [.italian: "Cartelle",                .english: "Folders"],
        "sec_language":       [.italian: "Lingua",                  .english: "Language"],
        "lbl_format":         [.italian: "Formato",                 .english: "Format"],
        "lbl_subfolders":     [.italian: "Includi sottocartelle",   .english: "Include subfolders"],
        "lbl_move":           [.italian: "Sposta in cartelle",      .english: "Move to folders"],
        "lbl_lang":           [.italian: "Lingua App",              .english: "App Language"],
        "lbl_api_hint":       [.italian: "API Key v3 oppure Read Access Token v4", .english: "v3 API Key or v4 Read Access Token"],
        "btn_search":         [.italian: "Cerca",                   .english: "Search"],
        "btn_done":           [.italian: "Fatto",                   .english: "Done"],
        "btn_open":           [.italian: "Apri",                    .english: "Open"],
        "btn_tmdb":           [.italian: "Cerca TMDB",              .english: "Search TMDB"],
        "btn_process":        [.italian: "Elabora",                 .english: "Process"],
        "alert_confirm_title":[.italian: "Conferma",                .english: "Confirm"],
        "alert_confirm_msg":  [.italian: "Procedere?",              .english: "Proceed?"],
        "alert_manual_title": [.italian: "Manuale",                 .english: "Manual"],
        "alert_manual_hint":  [.italian: "Titolo oppure #ID TMDB",  .english: "Title or #TMDB ID"],
        "alert_manual_sub":   [.italian: "Titolo, oppure ID: #12345, tmdb:12345, tv:12345, movie:12345 o link themoviedb.org",
                               .english: "Title, or ID: #12345, tmdb:12345, tv:12345, movie:12345 or a themoviedb.org link"],
        "panel_access_msg":   [.italian: "Renamy necessita del permesso di scrittura per questa cartella. Seleziona '%@'.",
                               .english: "Renamy needs write permission for this folder. Select '%@'."],
        "panel_access_btn":   [.italian: "Concedi Accesso",         .english: "Grant Access"],
        "ctx_manual":         [.italian: "Cerca manualmente…",      .english: "Search manually…"],
        "ctx_reveal":         [.italian: "Mostra nel Finder",       .english: "Show in Finder"],
        "tip_open":           [.italian: "Apri cartella",           .english: "Open folder"],
        "tip_scan":           [.italian: "Scansiona (Solo Nuovi)",  .english: "Scan (New Only)"],
        "tip_reset":          [.italian: "Reset",                   .english: "Reset"],
        "tip_undo":           [.italian: "Annulla",                 .english: "Undo"],
        "tip_tmdb":           [.italian: "Cerca manuale",           .english: "Manual Search"],
        "tip_process":        [.italian: "Applica",                 .english: "Apply"],
        "tip_settings":       [.italian: "Impostazioni",            .english: "Settings"],
        "tip_sel_all":        [.italian: "Tutti",                   .english: "All"],
        "tip_desel_all":      [.italian: "Nessuno",                 .english: "None"],
        "tip_filter":         [.italian: "Filtra",                  .english: "Filter"]
    ]

    static func get(_ key: String, lang: AppLanguage) -> String {
        table[key]?[lang] ?? key
    }
}

// MARK: - Models

enum MediaKind { case movie, tv }

struct DisambiguationCandidate: Identifiable, Hashable {
    let id: String; let title: String; let originalTitle: String; let year: String; let date: String
}

// FIX: i match referenziano i file per UUID (non per indice, che diventava stantio)
// e hanno un id deterministico, così `sheet(item:)` non si confonde dopo un rebuild.
struct AmbiguousMatch: Identifiable {
    let id: String
    let fileIDs: [UUID]
    let candidates: [DisambiguationCandidate]
    let isTV: Bool
}

struct RenameHistoryItem { let originalURL: URL; let newURL: URL; let fileID: UUID; let baseURL: URL? }

enum RenameFormat: String, CaseIterable, Identifiable {
    case standard = "standard"; case compact = "compact"; case plex = "plex"; case jellyfin = "jellyfin"; case emby = "emby"
    var id: String { self.rawValue }

    func label(for lang: AppLanguage) -> String {
        switch self {
        case .standard: return lang == .italian ? "Titolo (Anno)"                        : "Title (Year)"
        case .compact:  return lang == .italian ? "Titolo.Anno"                          : "Title.Year"
        case .plex:     return lang == .italian ? "Plex: Titolo (Anno) {tmdb-id}"        : "Plex: Title (Year) {tmdb-id}"
        case .jellyfin: return lang == .italian ? "Jellyfin: Titolo (Anno) [tmdbid-id]"  : "Jellyfin: Title (Year) [tmdbid-id]"
        case .emby:     return lang == .italian ? "Emby: Titolo (Anno) [tmdbid=id]"      : "Emby: Title (Year) [tmdbid=id]"
        }
    }

    /// Tag TMDB riconosciuto dal media server (nil per i formati "semplici").
    func tmdbTag(_ id: String) -> String? {
        guard !id.isEmpty else { return nil }
        switch self {
        case .plex:              return "{tmdb-\(id)}"
        case .jellyfin:          return "[tmdbid-\(id)]"
        case .emby:              return "[tmdbid=\(id)]"
        case .standard, .compact: return nil
        }
    }
}

struct TMDBResponse<T: Codable>: Codable { let results: [T] }

struct MovieResult: Codable, Identifiable {
    let id: Int; let title: String; let originalTitle: String?; let releaseDate: String?
    enum CodingKeys: String, CodingKey { case id, title; case originalTitle = "original_title"; case releaseDate = "release_date" }
    var year: String { guard let d = releaseDate, d.count >= 4 else { return "N/A" }; return String(d.prefix(4)) }
    var candidate: DisambiguationCandidate {
        DisambiguationCandidate(id: "\(id)", title: title, originalTitle: originalTitle ?? title, year: year, date: releaseDate ?? "")
    }
}

struct TVResult: Codable, Identifiable {
    let id: Int; let name: String; let originalName: String?; let firstAirDate: String?
    enum CodingKeys: String, CodingKey { case id, name; case originalName = "original_name"; case firstAirDate = "first_air_date" }
    var year: String { guard let d = firstAirDate, d.count >= 4 else { return "N/A" }; return String(d.prefix(4)) }
    var candidate: DisambiguationCandidate {
        DisambiguationCandidate(id: "\(id)", title: name, originalTitle: originalName ?? name, year: year, date: firstAirDate ?? "")
    }
}

enum TMDBError: Error { case unauthorized, http(Int) }

enum FileStatus {
    case pronto, nonTrovato, ambiguo, manuale, spostato, ripristinato, erroreSpostamento, erroreRete, erroreRegex
    func label(for lang: AppLanguage) -> String {
        switch self {
        case .pronto:            return Strings.get("status_ready",      lang: lang)
        case .nonTrovato:        return Strings.get("status_not_found",  lang: lang)
        case .ambiguo:           return Strings.get("status_ambiguous",  lang: lang)
        case .manuale:           return Strings.get("status_manual",     lang: lang)
        case .spostato:          return Strings.get("status_moved",      lang: lang)
        case .ripristinato:      return Strings.get("status_restored",   lang: lang)
        case .erroreSpostamento: return Strings.get("status_error_move", lang: lang)
        case .erroreRete:        return Strings.get("status_error_net",  lang: lang)
        case .erroreRegex:       return Strings.get("status_error",      lang: lang)
        }
    }
}

final class MediaFile: ObservableObject, Identifiable {
    let id = UUID(); let originalURL: URL; let originalName: String
    /// Posizione attuale del file su disco (cambia dopo lo spostamento / undo).
    var currentURL: URL
    @Published var proposedName: String; @Published var isSelected: Bool
    @Published var status: FileStatus; @Published var isTVShow: Bool; @Published var tmdbID: String = ""
    var parsedSeason: String?; var parsedEpisode: String?
    @Published var ambiguousCandidates: [DisambiguationCandidate]? = nil
    /// Metadati TMDB risolti: servono per rigenerare il nome al cambio formato e per le cartelle serie.
    var resolvedTitle: String?; var resolvedYear: String?
    /// Ultimo nome generato automaticamente (per distinguere le modifiche manuali).
    var generatedName: String = ""

    init(url: URL, status: FileStatus, proposedName: String = "", isSelected: Bool = false, isTVShow: Bool = false,
         tmdbID: String = "", parsedSeason: String? = nil, parsedEpisode: String? = nil) {
        self.originalURL = url; self.currentURL = url; self.originalName = url.lastPathComponent; self.status = status
        self.proposedName = proposedName; self.isSelected = isSelected; self.isTVShow = isTVShow
        self.tmdbID = tmdbID; self.parsedSeason = parsedSeason; self.parsedEpisode = parsedEpisode
    }
}

// MARK: - Logic Utils

let videoExtensions: Set<String> = ["mkv", "mp4", "avi", "mov", "m4v"]

enum Patterns {
    // FIX: aggiunti lookbehind/lookahead: prima "Film.2020.1920x1080.mkv" veniva preso per una serie (20x108)
    static let episode = try! NSRegularExpression(
        pattern: #"(?i)(?<![a-z0-9])(?:s|stagione)[.\s_-]*(\d{1,2})[.\s_-]*(?:e|ep|episodio|x)[.\s_-]*(\d{1,4})(?!\d)|(?<![a-z0-9])(\d{1,2})x(\d{1,3})(?!\d)"#)
    // FIX: aggiunto il punto tra i separatori ("Show.E05.mkv" prima non veniva riconosciuto)
    static let absoluteEpisode = try! NSRegularExpression(
        pattern: #"(?i)(?:^|[\s._\-\[])(?:ep|episodio)[.\s_]*(\d{1,4})(?=[\s._\-\]]|$)|(?:^|[\s._\-\[])e(\d{2,4})(?=[\s._\-\]]|$)"#)
    // Marcatore TV sul nome già "pulito" (punti/underscore → spazi); allineato ai due pattern sopra
    static let tvMarker = try! NSRegularExpression(
        pattern: #"(?i)\b(?:s\d{1,2}\s*e\d{1,4}|\d{1,2}x\d{1,3}|stagione\s*\d{1,2}|(?:ep|episodio)\s*\d{1,4}|e\d{2,4})\b"#)
    static let year = try! NSRegularExpression(pattern: #"\b(19\d{2}|20\d{2})\b"#)
    static let junk = try! NSRegularExpression(
        pattern: #"(?i)\b(1080p|720p|480p|4k|2160p|uhd|bluray|brrip|bdrip|web-dl|webdl|webrip|web|hdtv|dvdrip|h264|h265|hevc|x264|x265|ita|eng|multi|sub|subs|repack|proper|remux|ac3|aac|ddp|dts|hdr|10bit)\b"#)
    static let multiSpace = try! NSRegularExpression(pattern: #" {2,}"#)
    // Usato solo per nomi TV modificati a mano (altrimenti si usano i metadati)
    static let tvFolderFallback = try! NSRegularExpression(pattern: #"(?i)^(.+?)[\s.]+S(\d{1,2})E\d{1,4}"#)
    static let tmdbLink = try! NSRegularExpression(pattern: #"(?i)themoviedb\.org/(movie|tv)/(\d+)"#)
}

func parseEpisodeInfo(from name: String) -> (isTV: Bool, season: String?, episode: String?) {
    let ns = NSRange(name.startIndex..., in: name)
    if let m = Patterns.episode.firstMatch(in: name, range: ns) {
        let sR = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 3)
        let eR = m.range(at: 2).location != NSNotFound ? m.range(at: 2) : m.range(at: 4)
        if let rS = Range(sR, in: name), let rE = Range(eR, in: name) {
            return (true, String(format: "%02d", Int(name[rS]) ?? 0), String(format: "%02d", Int(name[rE]) ?? 0))
        }
    }
    if let m = Patterns.absoluteEpisode.firstMatch(in: name, range: ns) {
        let r = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
        if let rr = Range(r, in: name) { return (true, nil, String(format: "%02d", Int(name[rr]) ?? 0)) }
    }
    return (false, nil, nil)
}

/// Taglia il testo al primo tag tecnico (risoluzione, codec, lingua…) purché resti un titolo.
private func stripJunk(_ text: String) -> String {
    let ns = NSRange(text.startIndex..., in: text)
    for m in Patterns.junk.matches(in: text, range: ns) {
        guard let r = Range(m.range, in: text) else { continue }
        let before = String(text[..<r.lowerBound])
        if !cleanupTitleString(before).isEmpty { return before }
    }
    return text
}

/// FIX: usa l'ULTIMO anno preceduto da un titolo non vuoto.
/// Prima "1917.2019.mkv", "2001.A.Space.Odyssey.1968" o "Blade.Runner.2049.2017" producevano titolo vuoto o anno errato.
private func splitAtYear(_ text: String) -> (title: String, year: String)? {
    let ns = NSRange(text.startIndex..., in: text)
    for m in Patterns.year.matches(in: text, range: ns).reversed() {
        guard let r = Range(m.range, in: text) else { continue }
        let before = cleanupTitleString(String(text[..<r.lowerBound]))
        if !before.isEmpty { return (before, String(text[r])) }
    }
    return nil
}

func cleanFileNameRegex(_ raw: String) -> (title: String, year: String?, isTV: Bool) {
    let nameWithoutExt = (raw as NSString).deletingPathExtension
    let clean = nameWithoutExt.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ")
    let range = NSRange(clean.startIndex..., in: clean)

    // 1. Serie TV
    if let match = Patterns.tvMarker.firstMatch(in: clean, range: range),
       let tRange = Range(match.range, in: clean) {
        let prefix = stripJunk(String(clean[..<tRange.lowerBound]))
        if let split = splitAtYear(prefix) { return (split.title, split.year, true) }
        return (cleanupTitleString(prefix), nil, true)
    }

    // 2. Film con anno
    let withoutJunk = stripJunk(clean)
    if let split = splitAtYear(withoutJunk) { return (split.title, split.year, false) }

    // 3. Solo "junk wall" / fallback
    return (cleanupTitleString(withoutJunk), nil, false)
}

func cleanupTitleString(_ text: String) -> String {
    var t = text
    t = t.replacingOccurrences(of: "(", with: " ").replacingOccurrences(of: ")", with: " ")
         .replacingOccurrences(of: "[", with: " ").replacingOccurrences(of: "]", with: " ")
         .replacingOccurrences(of: "{", with: " ").replacingOccurrences(of: "}", with: " ")
    t = Patterns.multiSpace.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: " ")
    return t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-")))
}

func sanitizeFileName(_ name: String) -> String {
    let invalidChars: Set<Character> = [":", "/", "\\", "?", "*", "\"", "<", ">", "|"]
    var s = String(name.map { invalidChars.contains($0) ? " " : $0 })
    while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    // FIX: un nome che inizia con "." diventerebbe un file nascosto
    while s.hasPrefix(".") { s.removeFirst() }
    return s
}

func normalizeTitle(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

func calcolaETA(processed: Int, total: Int, startTime: Date) -> String {
    guard processed > 0 else { return "..." }
    let remaining = (Date().timeIntervalSince(startTime) / Double(processed)) * Double(total - processed)
    return remaining < 60 ? "\(Int(remaining)) sec" : "\(Int(remaining / 60)) min"
}

/// Estrae un TMDB ID dall'input utente.
/// Accetta: "#12345", "tmdb:12345", "id:12345", "tv:12345", "movie:12345", "{tmdb-12345}", "[tmdbid=12345]",
/// oppure un link themoviedb.org/movie/12345-…
/// FIX: un numero "nudo" NON è più trattato come ID: "1917", "2012", "300" sono titoli di film.
func extractTMDBID(from input: String) -> (id: String, kind: MediaKind?)? {
    var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    let ns = NSRange(s.startIndex..., in: s)
    if let m = Patterns.tmdbLink.firstMatch(in: s, range: ns),
       let kR = Range(m.range(at: 1), in: s), let iR = Range(m.range(at: 2), in: s) {
        return (String(s[iR]), s[kR] == "tv" ? .tv : .movie)
    }

    if let f = s.first, let l = s.last, (f == "{" && l == "}") || (f == "[" && l == "]") {
        s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
    }
    let prefixes: [(String, MediaKind?)] = [
        ("tv:", .tv), ("serie:", .tv), ("movie:", .movie), ("film:", .movie),
        ("tmdbid=", nil), ("tmdbid-", nil), ("tmdbid:", nil), ("tmdb-", nil), ("tmdb:", nil), ("id:", nil), ("#", nil)
    ]
    for (prefix, kind) in prefixes where s.hasPrefix(prefix) {
        let rest = s.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty, rest.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return (rest, kind)
    }
    return nil
}

/// Sposta un file senza mai sovrascrivere; gestisce i rename che cambiano solo maiuscole/minuscole
/// (su APFS case-insensitive il file di destinazione "esiste già").
func moveFileSafely(from source: URL, to dest: URL) throws {
    let fm = FileManager.default
    if source.path == dest.path { return }
    if source.path.lowercased() == dest.path.lowercased() {
        let tmp = dest.deletingLastPathComponent().appendingPathComponent(".renamy-\(UUID().uuidString)")
        try fm.moveItem(at: source, to: tmp)
        try fm.moveItem(at: tmp, to: dest)
        return
    }
    guard !fm.fileExists(atPath: dest.path) else { throw CocoaError(.fileWriteFileExists) }
    try fm.moveItem(at: source, to: dest)
}

/// Raccoglie i file video da una lista di file/cartelle. Gira fuori dal main thread.
func collectVideoURLs(from roots: [URL], includeSubfolders: Bool) -> [URL] {
    let fm = FileManager.default
    var result: [URL] = []; var seen = Set<URL>()

    func add(_ url: URL) {
        let u = url.standardizedFileURL
        guard videoExtensions.contains(u.pathExtension.lowercased()), !seen.contains(u) else { return }
        seen.insert(u); result.append(u)
    }

    for root in roots {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { continue }
        guard isDir.boolValue else { add(root); continue }

        let access = root.startAccessingSecurityScopedResource()
        defer { if access { root.stopAccessingSecurityScopedResource() } }
        var opts: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        if !includeSubfolders { opts.insert(.skipsSubdirectoryDescendants) }
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: opts) else { continue }
        for case let item as URL in en {
            if (try? item.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true { add(item) }
        }
    }
    return result.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

// MARK: - Drag & Drop Helper

@MainActor
func resolveProviders(_ providers: [NSItemProvider]) async -> [URL] {
    await withCheckedContinuation { continuation in
        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        let acceptedTypes: [String] = [
            UTType.fileURL.identifier,
            "public.file-url",
            UTType.folder.identifier,
            "public.folder"
        ]

        for provider in providers {
            guard let typeIdentifier = acceptedTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else { continue }

            group.enter()
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                defer { group.leave() }
                var resolved: URL? = nil

                if let url = item as? URL {
                    resolved = url
                } else if let data = item as? Data {
                    if let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) {
                        resolved = url
                    } else if let str = String(data: data, encoding: .utf8), let url = URL(string: str) {
                        resolved = url
                    }
                } else if let str = item as? String, let url = URL(string: str) {
                    resolved = url
                }

                if let url = resolved, url.isFileURL {
                    let clean = url.standardizedFileURL
                    lock.lock(); collected.append(clean); lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            continuation.resume(returning: collected)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class RenamyViewModel: ObservableObject {
    @Published var fileList: [MediaFile] = []
    @Published var selectedFolderURL: URL?
    @Published var statusText = "..."
    @Published var isScanning = false; @Published var isProcessing = false
    @Published var progress: Double = 0.0; @Published var etaText: String = ""
    @Published var isShowingRetryAlert = false; @Published var retrySearchName = ""
    @Published var targetFileForManualSearch: MediaFile? = nil
    @Published var showConfirmationAlert = false
    @Published var showSettingsSheet = false

    // FIX: @AppStorage dentro un ObservableObject non notifica la UI da solo:
    // senza willSet il cambio tema/lingua/formato non ridisegnava la finestra.
    @AppStorage("tmdbApiKey")        var apiKey: String = ""            { willSet { objectWillChange.send() } }
    @AppStorage("includeSubfolders") var includeSubfolders = true       { willSet { objectWillChange.send() } }
    @AppStorage("createSubfolders")  var createSubfolders = true        { willSet { objectWillChange.send() } }
    @AppStorage("renameFormat")      var renameFormat: RenameFormat = .plex {
        willSet { objectWillChange.send() }
        didSet { regenerateProposedNames() }   // NEW: i nomi si aggiornano al cambio formato
    }
    @AppStorage("appLanguage")       var appLanguage: AppLanguage = .italian { willSet { objectWillChange.send() } }
    @AppStorage("appTheme")          var appTheme: AppTheme = .system  { willSet { objectWillChange.send() } }

    @Published var filterNonTrovati = false
    @Published var undoHistory: [RenameHistoryItem] = []
    @Published var ambiguousMatches: [AmbiguousMatch] = []
    @Published var currentAmbiguity: AmbiguousMatch? = nil
    @Published var pendingProcessAfterDisambiguation = false

    private var fileObservers: [UUID: AnyCancellable] = [:]
    private var responseCache: [URL: Data] = [:]
    private var createdFolders: Set<URL> = []
    private var authFailed = false

    // FIX: prima lo stato iniziale era sempre in italiano
    init() { self.statusText = Strings.get("msg_ready", lang: appLanguage) }
    func t(_ key: String) -> String { Strings.get(key, lang: appLanguage) }
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

        let newFiles = newURLs.map { url -> MediaFile in
            let parsed = parseEpisodeInfo(from: url.lastPathComponent)
            return MediaFile(url: url, status: .pronto, isTVShow: parsed.isTV,
                             parsedSeason: parsed.season, parsedEpisode: parsed.episode)
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
        fileList.removeAll(); fileObservers.removeAll(); responseCache.removeAll(); createdFolders.removeAll()
        ambiguousMatches.removeAll(); undoHistory.removeAll()
        currentAmbiguity = nil; pendingProcessAfterDisambiguation = false; targetFileForManualSearch = nil
        statusText = t("msg_cleaned")
    }

    // MARK: TMDB networking

    private func tmdbRequest(path: String, params: [String: String]) throws -> URLRequest {
        guard var comps = URLComponents(string: "https://api.themoviedb.org/3/\(path)") else { throw URLError(.badURL) }
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // NEW: supporto anche al Read Access Token v4 (JWT, molto più lungo della key v3)
        let isBearer = key.count > 40
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "language", value: appLanguage.apiCode))
        if !isBearer { items.append(URLQueryItem(name: "api_key", value: key)) }
        comps.queryItems = items.sorted { $0.name < $1.name }
        // FIX: prima la query era codificata con .urlQueryAllowed, che NON codifica "&", "=" e "+":
        // "Fast & Furious" troncava la query. URLComponents gestisce & e =, il + va fatto a mano.
        comps.percentEncodedQuery = comps.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if isBearer { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        return req
    }

    /// Ritorna nil per 404. Le risposte OK vengono messe in cache: episodi della stessa serie
    /// generano la stessa query e non devono rifare N chiamate identiche.
    private func tmdbData(path: String, params: [String: String]) async throws -> Data? {
        let req = try tmdbRequest(path: path, params: params)
        if let url = req.url, let cached = responseCache[url] { return cached }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200:
            if let url = req.url { responseCache[url] = data }
            return data
        case 404: return nil
        case 401: throw TMDBError.unauthorized
        default:  throw TMDBError.http(http.statusCode)
        }
    }

    private func decodeSearch(endpoint: String, params: [String: String], isTV: Bool) async throws -> [DisambiguationCandidate] {
        guard let data = try await tmdbData(path: endpoint, params: params) else { return [] }
        if isTV { return try JSONDecoder().decode(TMDBResponse<TVResult>.self, from: data).results.map(\.candidate) }
        return try JSONDecoder().decode(TMDBResponse<MovieResult>.self, from: data).results.map(\.candidate)
    }

    private func searchCandidates(query: String, year: String?, isTV: Bool) async throws -> [DisambiguationCandidate] {
        let endpoint = isTV ? "search/tv" : "search/movie"
        let yearKey = isTV ? "first_air_date_year" : "year"
        var params = ["query": query]
        if let y = year, !y.isEmpty { params[yearKey] = y }
        var cands = try await decodeSearch(endpoint: endpoint, params: params, isTV: isTV)
        // FIX: se l'anno nel nome file è sbagliato (o è l'anno della stagione) riprova senza anno
        if cands.isEmpty, params[yearKey] != nil {
            params.removeValue(forKey: yearKey)
            cands = try await decodeSearch(endpoint: endpoint, params: params, isTV: isTV)
        }
        return cands
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
        var query = ""; var yearToUse: String? = nil; var isTV = file.isTVShow
        if let q = overrideQuery?.trimmingCharacters(in: .whitespacesAndNewlines), !q.isEmpty { query = q } else {
            let cleaned = cleanFileNameRegex(file.originalName)
            query = cleaned.title; yearToUse = cleaned.year
            if cleaned.isTV { isTV = true; file.isTVShow = true }
        }
        guard !query.isEmpty else { file.status = .nonTrovato; return }
        do {
            let cands = try await searchCandidates(query: query, year: yearToUse, isTV: isTV)
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

    // MARK: Naming

    func applyCandidate(_ cand: DisambiguationCandidate, to file: MediaFile) {
        file.tmdbID = cand.id; file.resolvedTitle = cand.title; file.resolvedYear = cand.year
        let name = buildFileName(for: file)
        file.generatedName = name          // prima di proposedName: vedi proposedNameEdited
        file.proposedName = name
        file.status = .pronto; file.isSelected = true; file.ambiguousCandidates = nil
    }

    private func hasValidYear(_ year: String?) -> Bool {
        guard let y = year else { return false }
        return y.count == 4 && y.allSatisfy(\.isNumber)
    }

    func buildFileName(for file: MediaFile) -> String {
        guard let rawTitle = file.resolvedTitle else { return file.proposedName }
        let title = sanitizeFileName(rawTitle)
        let year = file.resolvedYear ?? ""
        // FIX: senza data di uscita prima usciva "Titolo (N/A)"
        let hasYear = hasValidYear(year)
        var name: String
        if renameFormat == .compact {
            name = title.replacingOccurrences(of: " ", with: ".") + (hasYear ? ".\(year)" : "")
        } else {
            name = hasYear ? "\(title) (\(year))" : title
            // Per le serie il tag TMDB va sulla cartella della serie, non sul singolo episodio
            if !file.isTVShow, let tag = renameFormat.tmdbTag(file.tmdbID) { name += " \(tag)" }
        }
        if file.isTVShow, let e = file.parsedEpisode {
            let s = file.parsedSeason ?? "01"
            name += (renameFormat == .compact ? "." : " ") + "S\(s)E\(e)"
        }
        return sanitizeFileName(name)
    }

    func seriesFolderName(for file: MediaFile) -> String? {
        guard let rawTitle = file.resolvedTitle else { return nil }
        let title = sanitizeFileName(rawTitle)
        let year = file.resolvedYear ?? ""
        let base = hasValidYear(year) ? "\(title) (\(year))" : title
        switch renameFormat {
        case .compact:  return title
        case .standard: return base
        case .plex, .jellyfin, .emby:
            if let tag = renameFormat.tmdbTag(file.tmdbID) { return sanitizeFileName("\(base) \(tag)") }
            return base
        }
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
        statusText = t("msg_fetching_id")
        // Gli ID film e serie sono spazi separati (movie/123 ≠ tv/123): se l'utente specifica
        // "tv:" o "movie:" si usa solo quello, altrimenti si prova prima il tipo più probabile.
        let order: [MediaKind] = kind.map { [$0] } ?? (file.isTVShow ? [.tv, .movie] : [.movie, .tv])

        for k in order {
            do {
                guard let data = try await tmdbData(path: k == .tv ? "tv/\(tmdbID)" : "movie/\(tmdbID)", params: [:]) else { continue }
                let cand: DisambiguationCandidate
                if k == .tv { cand = try JSONDecoder().decode(TVResult.self, from: data).candidate }
                else { cand = try JSONDecoder().decode(MovieResult.self, from: data).candidate }
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

    func prepareManualSearch(for file: MediaFile) {
        targetFileForManualSearch = file
        retrySearchName = file.resolvedTitle ?? cleanFileNameRegex(file.originalName).title
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
        if let single = targetFileForManualSearch { return [single] }
        let problems: [FileStatus] = [.nonTrovato, .erroreRete, .erroreRegex, .ambiguo]
        let problematic = fileList.filter { problems.contains($0.status) }
        let selected = problematic.filter(\.isSelected)
        return selected.isEmpty ? problematic : selected
    }

    func retrySearchManual(name: String) {
        let q = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let single = targetFileForManualSearch
        let targets = manualSearchTargets()
        targetFileForManualSearch = nil
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
            if let tgt = single { currentAmbiguity = ambiguousMatches.first { $0.fileIDs.contains(tgt.id) } }
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

    private func filesToProcess() -> [MediaFile] {
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

    /// Cartella di destinazione. Per le serie usa i metadati TMDB (robusto per tutti i formati);
    /// la regex serve solo se l'utente ha modificato il nome a mano.
    private func destinationFolder(for file: MediaFile, newName: String, base: URL) -> URL {
        if file.isTVShow {
            if newName == file.generatedName, file.parsedEpisode != nil, let series = seriesFolderName(for: file) {
                let season = file.parsedSeason ?? "01"
                return base.appendingPathComponent(series, isDirectory: true)
                    .appendingPathComponent("Season \(season)", isDirectory: true)
            }
            let ns = NSRange(newName.startIndex..., in: newName)
            if let m = Patterns.tvFolderFallback.firstMatch(in: newName, range: ns),
               let tR = Range(m.range(at: 1), in: newName), let sR = Range(m.range(at: 2), in: newName) {
                var root = String(newName[tR])
                if renameFormat == .compact { root = root.replacingOccurrences(of: ".", with: " ") }
                let season = String(format: "%02d", Int(newName[sR]) ?? 1)
                return base.appendingPathComponent(sanitizeFileName(root), isDirectory: true)
                    .appendingPathComponent("Season \(season)", isDirectory: true)
            }
        }
        return base.appendingPathComponent(newName, isDirectory: true)
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
        for f in fileList where current.fileIDs.contains(f.id) { applyCandidate(selected, to: f) }
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
            let key = f.isTVShow ? "tv:" + cands.map(\.id).joined(separator: ",") : "movie:\(f.id.uuidString)"
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

// MARK: - UI Views

struct ContentView: View {
    @StateObject private var vm = RenamyViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if vm.isScanning {
                        ScanningView(vm: vm)
                    } else if vm.fileList.isEmpty {
                        DropPlaceholderView(isTargeted: isDropTargeted, message: vm.t("msg_ready"))
                    } else {
                        FileListView(vm: vm)
                    }
                    Divider()
                    HStack {
                        Text(vm.statusText).font(.caption).lineLimit(1)
                        Spacer()
                        // NEW: durante l'elaborazione il progresso prima non era visibile
                        if vm.isProcessing {
                            ProgressView(value: vm.progress).progressViewStyle(.linear).frame(width: 140)
                        }
                    }.padding(8).background(.thinMaterial)
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.08).cornerRadius(12))
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(vm.t("app_title"))
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    HStack {
                        Button {
                            // FIX: prima la cartella corrente veniva azzerata anche se si annullava il pannello
                            let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                            panel.begin { response in
                                if response == .OK, let url = panel.url { vm.selectedFolderURL = url; vm.scanFolder() }
                            }
                        } label: { Label(vm.t("btn_open"), systemImage: "folder") }
                        .disabled(vm.isScanning || vm.isProcessing).help(vm.t("tip_open"))

                        if let url = vm.selectedFolderURL {
                            Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary).padding(.leading, 4)
                        }
                    }
                    Button { vm.scanFolder() } label: { Image(systemName: "magnifyingglass") }
                        .disabled(vm.selectedFolderURL == nil || vm.isScanning || vm.isProcessing).help(vm.t("tip_scan"))
                    Button { vm.undoLastOperation() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(vm.undoHistory.isEmpty || vm.isProcessing).help(vm.t("tip_undo"))
                    Button { vm.resetAll() } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(vm.isScanning || vm.isProcessing).help(vm.t("tip_reset"))
                    Button { vm.selectAll() } label: { Image(systemName: "checklist") }
                        .disabled(vm.fileList.isEmpty).help(vm.t("tip_sel_all"))
                    Button { vm.deselectAll() } label: { Image(systemName: "checklist.unchecked") }
                        .disabled(vm.fileList.isEmpty).help(vm.t("tip_desel_all"))
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { vm.targetFileForManualSearch = nil; vm.retrySearchName = ""; vm.isShowingRetryAlert = true } label: {
                        Label(vm.t("btn_tmdb"), systemImage: "magnifyingglass.circle")
                    }.disabled(vm.isScanning || vm.isProcessing || vm.fileList.isEmpty).help(vm.t("tip_tmdb"))

                    Toggle(isOn: $vm.filterNonTrovati) { Image(systemName: "line.3.horizontal.decrease.circle") }
                        .toggleStyle(.button).disabled(vm.fileList.isEmpty).help(vm.t("tip_filter"))

                    Button { vm.requestProcessing() } label: { Label(vm.t("btn_process"), systemImage: "play.fill") }
                        .disabled(vm.fileList.isEmpty || vm.isScanning || vm.isProcessing).help(vm.t("tip_process"))

                    Button { vm.showSettingsSheet = true } label: { Label(vm.t("settings_title"), systemImage: "gearshape") }
                        .help(vm.t("tip_settings")).keyboardShortcut(",", modifiers: .command)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSettings"))) { _ in
                vm.showSettingsSheet = true
            }
            .onDrop(
                of: [UTType.fileURL, UTType.folder],
                isTargeted: $isDropTargeted
            ) { providers in
                vm.handleDrop(providers: providers)
                return true
            }
            .sheet(isPresented: $vm.showSettingsSheet) { SettingsSheetView(vm: vm) }
            .alert(vm.t("alert_manual_title"), isPresented: $vm.isShowingRetryAlert) {
                TextField(vm.t("alert_manual_hint"), text: $vm.retrySearchName)
                Button(vm.t("btn_search")) { vm.retrySearchManual(name: vm.retrySearchName); vm.retrySearchName = "" }
                Button(vm.t("sheet_cancel"), role: .cancel) { vm.retrySearchName = ""; vm.targetFileForManualSearch = nil }
            } message: {
                Text(vm.t("alert_manual_sub"))
            }
            .alert(vm.t("alert_confirm_title"), isPresented: $vm.showConfirmationAlert) {
                Button(vm.t("sheet_cancel"), role: .cancel) { }
                Button(vm.t("btn_process")) { vm.executeProcessing() }
            } message: { Text(vm.t("alert_confirm_msg")) }
            .sheet(item: $vm.currentAmbiguity) { amb in
                DisambiguationSheetView(ambiguity: amb,
                                        onSelect: { vm.resolveAmbiguity(selected: $0) },
                                        onCancel: { vm.cancelDisambiguation() })
                    .environmentObject(vm)
            }
        }
        .preferredColorScheme(vm.appTheme.colorScheme)
    }
}

// MARK: - Drop Placeholder

struct DropPlaceholderView: View {
    let isTargeted: Bool
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 48))
                .foregroundColor(isTargeted ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isTargeted)
            Text(message)
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Scanning / FileList / FileRow

struct ScanningView: View {
    @ObservedObject var vm: RenamyViewModel
    var body: some View {
        VStack {
            Text(vm.statusText).font(.title2).padding(.bottom, 8)
            ProgressView(value: vm.progress).progressViewStyle(.linear).padding(.horizontal, 50)
            Text(vm.etaText).font(.caption).foregroundColor(.secondary).padding(.top, 4)
        }.frame(maxHeight: .infinity)
    }
}

struct FileListView: View {
    @ObservedObject var vm: RenamyViewModel

    private var visibleFiles: [MediaFile] {
        guard vm.filterNonTrovati else { return vm.fileList }
        return vm.fileList.filter { [.nonTrovato, .ambiguo, .erroreRete, .erroreRegex, .erroreSpostamento].contains($0.status) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stesse colonne e margini delle righe, così le intestazioni restano allineate al contenuto
            HStack {
                Color.clear.frame(width: FileRowView.checkboxWidth, height: 1)
                Text(vm.t("col_original")).frame(maxWidth: .infinity, alignment: .leading)
                // Allineato al testo dentro il campo, non al suo bordo
                Text(vm.t("col_proposed")).padding(.leading, 6).frame(maxWidth: .infinity, alignment: .leading)
                Text(vm.t("col_status")).frame(width: FileRowView.statusWidth, alignment: .leading)
            }.font(.headline).padding(.horizontal, FileRowView.horizontalInset).padding(.vertical, 6)
            Divider()
            List(visibleFiles) { file in
                FileRowView(file: file, onManualSearch: {
                    if file.status == .ambiguo { vm.promptDisambiguation(for: file) }
                    else { vm.prepareManualSearch(for: file) }
                }).environmentObject(vm)
                .listRowInsets(EdgeInsets(top: 0, leading: FileRowView.horizontalInset, bottom: 0, trailing: FileRowView.horizontalInset))
            }.listStyle(.plain)
        }
    }
}

struct FileRowView: View {
    @ObservedObject var file: MediaFile
    @EnvironmentObject var vm: RenamyViewModel
    var onManualSearch: () -> Void

    static let checkboxWidth: CGFloat = 30
    static let statusWidth: CGFloat = 140
    static let horizontalInset: CGFloat = 12

    var body: some View {
        HStack {
            Toggle("", isOn: $file.isSelected).toggleStyle(.checkbox).labelsHidden().frame(width: Self.checkboxWidth, alignment: .leading)
            Text(file.originalName).font(.caption).lineLimit(2).foregroundColor(color(for: file.status)).frame(maxWidth: .infinity, alignment: .leading)
            TextField("...", text: $file.proposedName).textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
                .disabled(file.status == .spostato)
                .onChange(of: file.proposedName) { _, _ in vm.proposedNameEdited(file) }
            HStack {
                Text(file.status.label(for: vm.appLanguage)).font(.callout).foregroundColor(color(for: file.status))
                if [.nonTrovato, .erroreRete, .erroreRegex].contains(file.status) {
                    Button(action: onManualSearch) { Image(systemName: "magnifyingglass").foregroundColor(.blue) }.buttonStyle(.plain)
                } else if file.status == .ambiguo {
                    Button(action: onManualSearch) { Image(systemName: "list.bullet.circle.fill").foregroundColor(.orange) }.buttonStyle(.plain)
                }
            }.frame(width: Self.statusWidth, alignment: .leading)
        }
        .padding(.vertical, 4)
        // NEW: permette di correggere anche un file già abbinato (match sbagliato)
        .contextMenu {
            Button(vm.t("ctx_manual")) { vm.prepareManualSearch(for: file) }
                .disabled(file.status == .spostato || vm.isScanning || vm.isProcessing)
            Button(vm.t("ctx_reveal")) { NSWorkspace.shared.activateFileViewerSelecting([file.currentURL]) }
        }
    }

    private func color(for s: FileStatus) -> Color {
        switch s {
        case .ambiguo: return .orange
        case .nonTrovato, .erroreRete, .erroreRegex, .erroreSpostamento: return .red
        default: return .primary
        }
    }
}

// MARK: - Theme Selection

struct ThemeSelectionView: View {
    @Binding var selectedTheme: AppTheme
    var language: AppLanguage

    var body: some View {
        HStack(spacing: 20) {
            ThemeOptionView(title: AppTheme.system.label(for: language), isSelected: selectedTheme == .system) {
                HStack(spacing: 0) {
                    ThemePreviewIcon(mode: .light).frame(width: 30).environment(\.colorScheme, .light)
                    ThemePreviewIcon(mode: .dark).frame(width: 30).environment(\.colorScheme, .dark)
                }
            }.onTapGesture { selectedTheme = .system }

            ThemeOptionView(title: AppTheme.light.label(for: language), isSelected: selectedTheme == .light) {
                ThemePreviewIcon(mode: .light).frame(width: 60).environment(\.colorScheme, .light)
            }.onTapGesture { selectedTheme = .light }

            ThemeOptionView(title: AppTheme.dark.label(for: language), isSelected: selectedTheme == .dark) {
                ThemePreviewIcon(mode: .dark).frame(width: 60).environment(\.colorScheme, .dark)
            }.onTapGesture { selectedTheme = .dark }
        }
    }
}

struct ThemeOptionView<Content: View>: View {
    let title: String; let isSelected: Bool; let content: () -> Content
    var body: some View {
        VStack(spacing: 8) {
            content()
                .frame(height: 45).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1))
                .shadow(radius: 1)
            Text(title).font(.caption).foregroundColor(isSelected ? .primary : .secondary)
        }.contentShape(Rectangle())
    }
}

struct ThemePreviewIcon: View {
    enum Mode { case light, dark }
    let mode: Mode
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(mode == .light ? Color(nsColor: .windowBackgroundColor) : Color.black.opacity(0.8))
            Rectangle().fill(mode == .light ? Color.gray.opacity(0.2) : Color.white.opacity(0.1)).frame(height: 10)
            Rectangle().fill(mode == .light ? Color.white : Color.white.opacity(0.05)).frame(width: 15).padding(.top, 10)
            VStack(alignment: .leading, spacing: 3) {
                RoundedRectangle(cornerRadius: 1).fill(Color.gray.opacity(0.4)).frame(width: 25, height: 2)
                RoundedRectangle(cornerRadius: 1).fill(Color.gray.opacity(0.2)).frame(width: 20, height: 2)
            }.padding(.top, 16).padding(.leading, 20)
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheetView: View {
    @ObservedObject var vm: RenamyViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text(vm.t("settings_title")).font(.title2).padding()
            Form {
                Section {
                    SecureField("API Key TMDB", text: $vm.apiKey)
                } header: { Text(vm.t("sec_api")) } footer: {
                    Text(vm.t("lbl_api_hint")).font(.caption).foregroundStyle(.secondary)
                }
                Section(vm.t("sec_language")) {
                    Picker(vm.t("lbl_lang"), selection: $vm.appLanguage) {
                        ForEach(AppLanguage.allCases) { Text($0.rawValue).tag($0) }
                    }.onChange(of: vm.appLanguage) { _, _ in vm.updateStatusReady() }
                }
                Section(vm.t("sec_appearance")) {
                    ThemeSelectionView(selectedTheme: $vm.appTheme, language: vm.appLanguage).padding(.vertical, 5)
                }
                Section(vm.t("sec_format")) {
                    Picker(vm.t("lbl_format"), selection: $vm.renameFormat) {
                        ForEach(RenameFormat.allCases) { Text($0.label(for: vm.appLanguage)).tag($0) }
                    }
                }
                Section(vm.t("sec_folders")) {
                    Toggle(vm.t("lbl_subfolders"), isOn: $vm.includeSubfolders)
                    Toggle(vm.t("lbl_move"), isOn: $vm.createSubfolders)
                }
            }.padding()
            Button(vm.t("btn_done")) { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).padding()
        }.frame(width: 440, height: 580)
    }
}

// MARK: - Disambiguation Sheet

struct DisambiguationSheetView: View {
    let ambiguity: AmbiguousMatch
    let onSelect: (DisambiguationCandidate) -> Void
    let onCancel: () -> Void
    @EnvironmentObject var vm: RenamyViewModel

    var body: some View {
        VStack {
            Text(vm.t("sheet_title")).font(.title2).padding(.top)
            if let firstID = ambiguity.fileIDs.first, let file = vm.fileList.first(where: { $0.id == firstID }) {
                VStack(spacing: 4) {
                    Text(vm.t("sheet_original")).font(.caption).foregroundStyle(.secondary)
                    Text(file.originalName).font(.headline).lineLimit(2).multilineTextAlignment(.center)
                    if ambiguity.fileIDs.count > 1 {
                        Text(String(format: vm.t("sheet_applies_to"), ambiguity.fileIDs.count))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal).padding(.bottom, 4)
            }
            Divider().padding(.vertical)
            List(ambiguity.candidates) { cand in
                Button(action: { onSelect(cand) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(cand.title).bold()
                            if cand.originalTitle != cand.title {
                                Text(cand.originalTitle).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(cand.year).font(.body)
                            if !cand.date.isEmpty { Text(cand.date).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            // FIX: Annulla passa dal ViewModel (resetta il flag di elaborazione in sospeso) e risponde a Esc
            Button(vm.t("sheet_cancel"), action: onCancel).keyboardShortcut(.cancelAction).padding()
        }.frame(minWidth: 420, minHeight: 500)
    }
}
