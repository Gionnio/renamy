//
//  FileSystem.swift
//  Renamy
//
//  Collecting video files, safe moves and the remaining-time estimate.
//

import Foundation

// MARK: - Logic Utils

func calcolaETA(processed: Int, total: Int, startTime: Date) -> String {
    guard processed > 0 else { return "..." }
    let remaining = (Date().timeIntervalSince(startTime) / Double(processed)) * Double(total - processed)
    return remaining < 60 ? "\(Int(remaining)) sec" : "\(Int(remaining / 60)) min"
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
