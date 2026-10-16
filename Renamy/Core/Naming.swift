//
//  Naming.swift
//  Renamy
//
//  Builds file names and destination folders from resolved metadata.
//  Pure Foundation: compiled by scripts/test.sh.
//

import Foundation

/// Metadata of a matched file, as needed to build its name.
struct ResolvedMedia {
    /// Title as returned by the metadata source (not sanitized yet).
    let title: String
    /// Release or first air year, empty when unknown.
    let year: String
    let tmdbID: String
    let isTV: Bool
    let season: String?
    let episode: String?
}

enum Naming {

    static func hasValidYear(_ year: String?) -> Bool {
        guard let y = year else { return false }
        return y.count == 4 && y.allSatisfy(\.isNumber)
    }

    /// File name without extension, e.g. "Title (2008) {tmdb-10378}" or "Show (2015) S01E02".
    static func fileName(_ media: ResolvedMedia, format: RenameFormat) -> String {
        let title = sanitizeFileName(media.title)
        let year = media.year
        // FIX: senza data di uscita prima usciva "Titolo (N/A)"
        let hasYear = hasValidYear(year)
        var name: String
        if format == .compact {
            name = title.replacingOccurrences(of: " ", with: ".") + (hasYear ? ".\(year)" : "")
        } else {
            name = hasYear ? "\(title) (\(year))" : title
            // Per le serie il tag TMDB va sulla cartella della serie, non sul singolo episodio
            if !media.isTV, let tag = format.tmdbTag(media.tmdbID) { name += " \(tag)" }
        }
        if media.isTV, let e = media.episode {
            let s = media.season ?? "01"
            name += (format == .compact ? "." : " ") + "S\(s)E\(e)"
        }
        return sanitizeFileName(name)
    }

    /// Folder of a series, e.g. "Show (2015) {tmdb-63639}".
    static func seriesFolderName(_ media: ResolvedMedia, format: RenameFormat) -> String {
        let title = sanitizeFileName(media.title)
        let year = media.year
        let base = hasValidYear(year) ? "\(title) (\(year))" : title
        switch format {
        case .compact:  return title
        case .standard: return base
        case .plex, .jellyfin, .emby:
            if let tag = format.tmdbTag(media.tmdbID) { return sanitizeFileName("\(base) \(tag)") }
            return base
        }
    }

    /// Destination folder when files are moved into folders.
    /// Series use the metadata (works for every format); the regex is only for names edited by hand.
    /// - Parameters:
    ///   - media: resolved metadata, nil when the file was never matched
    ///   - usesGeneratedName: whether `newName` is still the automatically generated name
    static func destinationFolder(media: ResolvedMedia?, isTV: Bool, usesGeneratedName: Bool,
                                  newName: String, format: RenameFormat, base: URL) -> URL {
        if isTV {
            if usesGeneratedName, let media, media.episode != nil {
                let series = seriesFolderName(media, format: format)
                let season = media.season ?? "01"
                return base.appendingPathComponent(series, isDirectory: true)
                    .appendingPathComponent("Season \(season)", isDirectory: true)
            }
            let ns = NSRange(newName.startIndex..., in: newName)
            if let m = Patterns.tvFolderFallback.firstMatch(in: newName, range: ns),
               let tR = Range(m.range(at: 1), in: newName), let sR = Range(m.range(at: 2), in: newName) {
                var root = String(newName[tR])
                if format == .compact { root = root.replacingOccurrences(of: ".", with: " ") }
                let season = String(format: "%02d", Int(newName[sR]) ?? 1)
                return base.appendingPathComponent(sanitizeFileName(root), isDirectory: true)
                    .appendingPathComponent("Season \(season)", isDirectory: true)
            }
        }
        return base.appendingPathComponent(newName, isDirectory: true)
    }
}
