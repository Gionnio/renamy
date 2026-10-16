//
//  FileNameParserTests.swift
//  Cases from testkit/MATRIX.md §1.
//

import Foundation

private struct Expected {
    let name: String
    let title: String
    let year: String?
    let isTV: Bool
    let season: String?
    let episode: String?
    var knownIssue: String? = nil
}

private let cases: [Expected] = [
    // 1–3: standard episode patterns
    Expected(name: "Show.Name.S01E01.1080p.mkv", title: "Show Name", year: nil, isTV: true, season: "01", episode: "01"),
    Expected(name: "Show Name - S01E02 - The Return.mkv", title: "Show Name", year: nil, isTV: true, season: "01", episode: "02"),
    Expected(name: "Show Name 1x02 Titolo.mkv", title: "Show Name", year: nil, isTV: true, season: "01", episode: "02"),
    // 5–7, 9: absolute numbering and season in the title (fixed in phase 2)
    Expected(name: "[Tag] Show Name - 01 [1080p].mkv", title: "Show Name", year: nil, isTV: true, season: nil, episode: "01",
             knownIssue: "absolute numbering not recognized"),
    Expected(name: "Show Name S2 - 03.mkv", title: "Show Name", year: nil, isTV: true, season: "02", episode: "03",
             knownIssue: "season in the title not recognized"),
    Expected(name: "Show Name 2nd Season - 04.mkv", title: "Show Name 2nd Season", year: nil, isTV: true, season: "02", episode: "04",
             knownIssue: "season in the title not recognized"),
    Expected(name: "Show Name - 12 [ABCD1234].mkv", title: "Show Name", year: nil, isTV: true, season: nil, episode: "12",
             knownIssue: "absolute numbering and checksum tag not recognized"),
    // 10–13: movies
    Expected(name: "Big Buck Bunny (2008).mp4", title: "Big Buck Bunny", year: "2008", isTV: false, season: nil, episode: nil),
    Expected(name: "1917.2019.mkv", title: "1917", year: "2019", isTV: false, season: nil, episode: nil),
    Expected(name: "Blade.Runner.2049.2017.mkv", title: "Blade Runner 2049", year: "2017", isTV: false, season: nil, episode: nil),
    Expected(name: "Film.2020.1920x1080.mkv", title: "Film", year: "2020", isTV: false, season: nil, episode: nil),
]

func runFileNameParserTests() {
    for c in cases {
        let parsed = parseEpisodeInfo(from: c.name)
        let cleaned = cleanFileNameRegex(c.name)
        let isTV = parsed.isTV || cleaned.isTV
        let ok = cleaned.title == c.title && cleaned.year == c.year && isTV == c.isTV
            && parsed.season == c.season && parsed.episode == c.episode
        let got = "title=\(cleaned.title) year=\(cleaned.year ?? "-") tv=\(isTV) S=\(parsed.season ?? "-") E=\(parsed.episode ?? "-")"
        check(ok, "parse \(c.name) [\(got)]", knownIssue: c.knownIssue)
    }

    // TMDB IDs typed in the manual search
    check(extractTMDBID(from: "#12345")?.id == "12345", "extractTMDBID #id")
    check(extractTMDBID(from: "tv:1396")?.kind == .tv, "extractTMDBID tv:")
    check(extractTMDBID(from: "[tmdbid=10378]")?.id == "10378", "extractTMDBID [tmdbid=]")
    check(extractTMDBID(from: "https://www.themoviedb.org/movie/10378-big-buck-bunny")?.kind == .movie, "extractTMDBID link")
    check(extractTMDBID(from: "1917") == nil, "extractTMDBID bare number is a title")

    // File names
    check(sanitizeFileName("Title: Part 1/2") == "Title Part 1 2", "sanitizeFileName invalid characters")
    check(sanitizeFileName("...Hidden") == "Hidden", "sanitizeFileName leading dots")
    check(normalizeTitle("Amélie!") == normalizeTitle("amelie"), "normalizeTitle accents and punctuation")
}
