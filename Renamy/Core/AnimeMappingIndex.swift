//
//  AnimeMappingIndex.swift
//  Renamy
//
//  Reads the community anime ID mapping (Fribb/anime-lists, anime-list-mini.json) and converts an
//  AniList entry and episode to the TMDB numbering. Pure Foundation: compiled by scripts/test.sh.
//
//  The file is downloaded at runtime and never bundled: it does not declare a license.
//

import Foundation

struct AnimeMappingEntry: Equatable {
    let anilistID: Int
    /// TV, MOVIE, OVA, ONA, SPECIAL…
    let type: String
    let tmdbTV: Int?
    let tmdbMovies: [Int]
    let tmdbSeason: Int?
    let tvdbSeason: Int?
    let tmdbOffset: Int?
    let tvdbOffset: Int?
}

/// An episode in the TMDB numbering.
struct TMDBEpisodeRef: Equatable {
    let tvID: Int
    let season: Int
    let episode: Int
}

struct AnimeMappingIndex {
    private(set) var byAniList: [Int: AnimeMappingEntry] = [:]
    private(set) var byTMDBTV: [Int: [AnimeMappingEntry]] = [:]

    var count: Int { byAniList.count }

    init(entries: [AnimeMappingEntry]) {
        for e in entries {
            byAniList[e.anilistID] = e
            if let tv = e.tmdbTV { byTMDBTV[tv, default: []].append(e) }
        }
    }

    /// Missing values are empty strings in the file, IDs can be numbers or strings.
    private static func int(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        if let s = value as? String { return Int(s) }
        return nil
    }

    static func parse(_ data: Data) throws -> AnimeMappingIndex {
        guard let list = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let entries = list.compactMap { item -> AnimeMappingEntry? in
            guard let anilist = int(item["anilist_id"]) else { return nil }
            let tmdb = item["themoviedb_id"] as? [String: Any]
            let season = item["season"] as? [String: Any]
            let offset = item["episode_offset"] as? [String: Any]
            return AnimeMappingEntry(
                anilistID: anilist, type: item["type"] as? String ?? "",
                tmdbTV: int(tmdb?["tv"]), tmdbMovies: (tmdb?["movie"] as? [Any])?.compactMap { int($0) } ?? [],
                tmdbSeason: int(season?["tmdb"]), tvdbSeason: int(season?["tvdb"]),
                tmdbOffset: int(offset?["tmdb"]), tvdbOffset: int(offset?["tvdb"]))
        }
        return AnimeMappingIndex(entries: entries)
    }

    func entry(anilistID: Int) -> AnimeMappingEntry? { byAniList[anilistID] }

    /// TMDB movie of an AniList movie, if mapped.
    func tmdbMovie(anilistID: Int) -> Int? { byAniList[anilistID]?.tmdbMovies.first }

    /// TMDB numbering of an episode.
    /// - Parameters:
    ///   - anilistID: the chosen AniList entry (often the first season, found by title)
    ///   - fileSeason: season written in the file name ("S2", "2nd Season"), nil for absolute numbering
    ///   - fileEpisode: episode number in the file name
    /// AniList has one entry per season; when the file names a season, the entry of the same series
    /// with that TVDB season is used, so "2nd Season - 01" gets the offset of the second season.
    func tmdbEpisode(anilistID: Int, fileSeason: Int?, fileEpisode: Int) -> TMDBEpisodeRef? {
        guard let chosen = byAniList[anilistID], let tv = chosen.tmdbTV else { return nil }
        var entry = chosen
        if let wanted = fileSeason, chosen.tvdbSeason != wanted {
            let sameSeries = byTMDBTV[tv] ?? []
            let regular = sameSeries.filter { $0.tvdbSeason == wanted && $0.type != "SPECIAL" }
            if let match = regular.first(where: { $0.type == "TV" }) ?? regular.first { entry = match }
        }
        let season: Int; let offset: Int
        if let s = entry.tmdbSeason {
            season = s; offset = entry.tmdbOffset ?? 0
        } else {
            season = entry.tvdbSeason ?? fileSeason ?? 1; offset = entry.tvdbOffset ?? 0
        }
        // The file names a season the mapping does not know: keep the file numbering
        if let wanted = fileSeason, entry.tvdbSeason != wanted, entry.anilistID == chosen.anilistID {
            return TMDBEpisodeRef(tvID: tv, season: wanted, episode: fileEpisode)
        }
        return TMDBEpisodeRef(tvID: tv, season: season, episode: fileEpisode + offset)
    }
}
