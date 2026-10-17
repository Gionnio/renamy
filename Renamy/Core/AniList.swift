//
//  AniList.swift
//  Renamy
//
//  AniList GraphQL search: request body, response decoding and title matching.
//  Pure Foundation: compiled by scripts/test.sh.
//

import Foundation

struct AniListMedia: Decodable, Equatable {
    struct Title: Decodable, Equatable { let romaji: String?; let english: String?; let native: String? }
    struct DateParts: Decodable, Equatable { let year: Int?; let month: Int?; let day: Int? }
    struct Cover: Decodable, Equatable { let medium: String? }

    let id: Int
    let format: String?
    let episodes: Int?
    let seasonYear: Int?
    let startDate: DateParts?
    let title: Title
    let synonyms: [String]?
    let coverImage: Cover?

    var year: String {
        if let y = startDate?.year ?? seasonYear { return String(y) }
        return "N/A"
    }

    var isMovie: Bool { format == "MOVIE" }

    /// Title used for names when the series is not on TMDB.
    func displayTitle(preferEnglish: Bool) -> String {
        let romaji = title.romaji ?? title.english ?? title.native ?? ""
        return preferEnglish ? (title.english ?? romaji) : romaji
    }

    /// All titles, for matching the name in the file.
    var allTitles: [String] { [title.romaji, title.english, title.native].compactMap { $0 } + (synonyms ?? []) }

    func candidate(preferEnglish: Bool) -> DisambiguationCandidate {
        let shown = displayTitle(preferEnglish: preferEnglish)
        let other = preferEnglish ? (title.romaji ?? shown) : (title.english ?? title.native ?? shown)
        var date = ""
        if let y = startDate?.year {
            date = String(format: "%04d-%02d-%02d", y, startDate?.month ?? 1, startDate?.day ?? 1)
        }
        return DisambiguationCandidate(id: String(id), title: shown, originalTitle: other, year: year, date: date,
                                       source: .anilist, format: format, posterURL: coverImage?.medium)
    }
}

enum AniListAPI {
    static let endpoint = URL(string: "https://graphql.anilist.co")!

    static let searchQuery = """
    query ($search: String) {
      Page(perPage: 10) {
        media(search: $search, type: ANIME) {
          id format episodes seasonYear
          startDate { year month day }
          title { romaji english native }
          synonyms
          coverImage { medium }
        }
      }
    }
    """

    static func searchBody(_ search: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["query": searchQuery, "variables": ["search": search]])
    }

    private struct Response: Decodable {
        struct DataPart: Decodable { struct Page: Decodable { let media: [AniListMedia] }; let Page: Page }
        let data: DataPart
    }

    static func decodeSearch(_ data: Data) throws -> [AniListMedia] {
        try JSONDecoder().decode(Response.self, from: data).data.Page.media
    }

    /// Picks the result without asking: one result, or one result whose title matches the query
    /// exactly (any of its titles), preferring series or movies as the file suggests.
    static func automaticChoice(_ results: [AniListMedia], query: String, isTV: Bool) -> AniListMedia? {
        if results.count == 1 { return results[0] }
        let norm = normalizeTitle(query)
        let exact = results.filter { $0.allTitles.contains { normalizeTitle($0) == norm } }
        if exact.count == 1 { return exact[0] }
        let preferred = exact.filter { $0.isMovie != isTV }
        return preferred.count == 1 ? preferred[0] : nil
    }
}
