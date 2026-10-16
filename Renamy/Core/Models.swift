//
//  Models.swift
//  Renamy
//
//  Plain data types shared by the app and the tests.
//

import Foundation

enum MediaKind { case movie, tv }

/// Lingua dell'interfaccia: quella scelta nelle Impostazioni (AppleLanguages) o del sistema.
/// macOS la legge all'avvio, come nelle altre app: dopo il cambio serve un riavvio.
enum AppLanguage {
    static var isItalian: Bool { Bundle.main.preferredLocalizations.first?.hasPrefix("it") ?? false }
    /// Lingua dei titoli TMDB: segue quella dell'app
    static var apiCode: String { isItalian ? "it-IT" : "en-US" }
}

struct Strings {
    /// Testi in it.lproj / en.lproj (Localizable.strings)
    static func get(_ key: String) -> String { NSLocalizedString(key, comment: "") }
}

/// Where a candidate comes from.
enum MetadataSource: String, Hashable { case tmdb, anilist }

struct DisambiguationCandidate: Identifiable, Hashable {
    let id: String; let title: String; let originalTitle: String; let year: String; let date: String
    var source: MetadataSource = .tmdb
    /// AniList format (TV, MOVIE, OVA…), nil for TMDB.
    var format: String? = nil
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

    var label: String { Strings.get("fmt_\(rawValue)") }

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
    var label: String {
        switch self {
        case .pronto:            return Strings.get("status_ready")
        case .nonTrovato:        return Strings.get("status_not_found")
        case .ambiguo:           return Strings.get("status_ambiguous")
        case .manuale:           return Strings.get("status_manual")
        case .spostato:          return Strings.get("status_moved")
        case .ripristinato:      return Strings.get("status_restored")
        case .erroreSpostamento: return Strings.get("status_error_move")
        case .erroreRete:        return Strings.get("status_error_net")
        case .erroreRegex:       return Strings.get("status_error")
        }
    }
}
