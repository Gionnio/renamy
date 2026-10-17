//
//  RenamyViewModel+Library.swift
//  Renamy
//
//  Groups, sidebar filters and counts for the three-column window.
//

import Foundation

/// Filters of the sidebar.
enum SidebarFilter: Hashable, CaseIterable {
    case all, ambiguous, ready, notFound, moved, movies, series, anime
}

/// A row of the list: a series (all its episodes), a movie, or a file still to match.
struct FileGroup: Identifiable {
    let id: String
    let files: [MediaFile]
    /// Set when the files are still to choose.
    let ambiguity: AmbiguousMatch?

    var first: MediaFile { files[0] }
    var isTV: Bool { first.isTVShow }

    static func ambiguityID(_ amb: AmbiguousMatch) -> String { "amb:" + amb.id }
}

extension RenamyViewModel {

    func isAnime(_ file: MediaFile) -> Bool { file.anilistID != nil || (animeEnabled && file.looksLikeAnime) }

    func matches(_ file: MediaFile, _ filter: SidebarFilter) -> Bool {
        switch filter {
        case .all:       return true
        case .ambiguous: return file.status == .ambiguo
        case .ready:     return [.pronto, .manuale, .ripristinato].contains(file.status)
        case .notFound:  return [.nonTrovato, .erroreRete, .erroreRegex, .erroreSpostamento].contains(file.status)
        case .moved:     return file.status == .spostato
        case .movies:    return !file.isTVShow && !isAnime(file)
        case .series:    return file.isTVShow && !isAnime(file)
        case .anime:     return isAnime(file)
        }
    }

    func count(_ filter: SidebarFilter) -> Int { fileList.filter { matches($0, filter) }.count }

    /// Group of a file: the choice still to make, the matched series, or the file itself.
    func groupID(containing file: MediaFile) -> String {
        if file.status == .ambiguo, let amb = ambiguousMatches.first(where: { $0.fileIDs.contains(file.id) }) {
            return FileGroup.ambiguityID(amb)
        }
        if file.isTVShow, file.status != .ambiguo, let title = file.resolvedTitle {
            // Stessa serie = stesso ID TMDB, o stesso titolo e anno per i nomi presi da AniList
            if !file.tmdbID.isEmpty { return "tv:tmdb:" + file.tmdbID }
            return "tv:title:" + normalizeTitle(title) + "|" + (file.resolvedYear ?? "")
        }
        return "file:" + file.id.uuidString
    }

    /// Groups shown in the list, in the order of the files, with the sidebar filter and the search applied.
    var visibleGroups: [FileGroup] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filter = sidebarFilter ?? .all
        var order: [String] = []
        var members: [String: [MediaFile]] = [:]
        for f in fileList where matches(f, filter) {
            if !query.isEmpty,
               !f.originalName.localizedCaseInsensitiveContains(query),
               !f.proposedName.localizedCaseInsensitiveContains(query) { continue }
            let id = groupID(containing: f)
            if members[id] == nil { order.append(id) }
            members[id, default: []].append(f)
        }
        return order.map { id in
            let amb = id.hasPrefix("amb:") ? ambiguousMatches.first { FileGroup.ambiguityID($0) == id } : nil
            return FileGroup(id: id, files: members[id] ?? [], ambiguity: amb)
        }
    }

    /// The group or file selected in the list.
    var selectedGroup: FileGroup? {
        guard let sel = selection else { return nil }
        if sel.hasPrefix("file:"), let file = fileList.first(where: { "file:" + $0.id.uuidString == sel }) {
            let id = groupID(containing: file)
            if id == sel { return FileGroup(id: id, files: [file], ambiguity: nil) }
            return visibleGroups.first { $0.id == id } ?? FileGroup(id: id, files: [file], ambiguity: nil)
        }
        if let group = visibleGroups.first(where: { $0.id == sel }) { return group }
        // Gruppo non visibile per il filtro: lo ricostruisce con tutti i suoi file
        let files = fileList.filter { groupID(containing: $0) == sel }
        guard !files.isEmpty else { return nil }
        let amb = sel.hasPrefix("amb:") ? ambiguousMatches.first { FileGroup.ambiguityID($0) == sel } : nil
        return FileGroup(id: sel, files: files, ambiguity: amb)
    }

    /// The single file selected (an episode row or a group of one file).
    var selectedFile: MediaFile? {
        guard let sel = selection else { return nil }
        if sel.hasPrefix("file:") { return fileList.first { "file:" + $0.id.uuidString == sel } }
        if let g = selectedGroup, g.files.count == 1 { return g.first }
        return nil
    }

    /// Other files still to choose that the choice can also apply to (see `Grouping`).
    func applyAlsoSuggestions(for amb: AmbiguousMatch) -> [(file: MediaFile, preselected: Bool)] {
        let pending = fileList.filter { $0.status == .ambiguo }
        let items = pending.map {
            GroupingItem(id: $0.id, folder: $0.currentURL.deletingLastPathComponent().path, title: $0.recognizedTitle, isTV: $0.isTVShow)
        }
        let byID = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0) })
        return Grouping.applyAlsoSuggestions(group: Set(amb.fileIDs), items: items).compactMap { s in
            byID[s.id].map { ($0, s.preselected) }
        }
    }

    /// Destination of a file as it will be after renaming: folder relative to the chosen folder, and file name.
    func destinationPreview(for file: MediaFile) -> (folders: [String], fileName: String) {
        let newName = sanitizeFileName(file.proposedName)
        let ext = file.currentURL.pathExtension
        let fileName = ext.isEmpty ? newName : "\(newName).\(ext)"
        guard createSubfolders, let base = selectedFolderURL else { return ([], fileName) }
        let folder = destinationFolder(for: file, newName: newName, base: base)
        let baseComponents = base.standardizedFileURL.pathComponents
        let parts = Array(folder.standardizedFileURL.pathComponents.dropFirst(baseComponents.count))
        return (parts, fileName)
    }
}
