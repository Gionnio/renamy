//
//  FileNameParserTests.swift
//  Cases from testkit/MATRIX.md §1.
//

import Foundation

private struct Expected {
    let name: String
    var folders: [String] = []
    let title: String
    let year: String?
    let isTV: Bool
    let season: String?
    let episode: String?
    var anime = false
}

/// Cases from testkit/MATRIX.md §1, plus guards against false episodes.
private let cases: [Expected] = [
    // 1–3: standard episode patterns
    Expected(name: "Show.Name.S01E01.1080p.mkv", title: "Show Name", year: nil, isTV: true, season: "01", episode: "01"),
    Expected(name: "Show Name - S01E02 - The Return.mkv", title: "Show Name", year: nil, isTV: true, season: "01", episode: "02"),
    Expected(name: "Show Name 1x02 Titolo.mkv", title: "Show Name", year: nil, isTV: true, season: "01", episode: "02"),
    // 5–7, 9: absolute numbering and season in the title
    Expected(name: "[Tag] Show Name - 01 [1080p].mkv", title: "Show Name", year: nil, isTV: true, season: nil, episode: "01", anime: true),
    Expected(name: "Show Name S2 - 03.mkv", title: "Show Name", year: nil, isTV: true, season: "02", episode: "03", anime: true),
    Expected(name: "Show Name 2nd Season - 04.mkv", title: "Show Name", year: nil, isTV: true, season: "02", episode: "04", anime: true),
    Expected(name: "Show Name Season 3 - 01.mkv", title: "Show Name", year: nil, isTV: true, season: "03", episode: "01", anime: true),
    Expected(name: "Show Name - 12 [ABCD1234].mkv", title: "Show Name", year: nil, isTV: true, season: nil, episode: "12", anime: true),
    Expected(name: "Show_Name_-_05v2.mkv", title: "Show Name", year: nil, isTV: true, season: nil, episode: "05", anime: true),
    // 8: episode number only, series and season from the folders
    Expected(name: "01 - Pilot.mkv", folders: ["Season 1", "Show Name"], title: "Show Name", year: nil, isTV: true, season: "01", episode: "01"),
    Expected(name: "S01E03.mkv", folders: ["Stagione 1", "Show Name (2015)"], title: "Show Name", year: "2015", isTV: true, season: "01", episode: "03"),
    Expected(name: "Show Name - 07.mkv", folders: ["Season 2", "Show Name"], title: "Show Name", year: nil, isTV: true, season: "02", episode: "07", anime: true),
    // 10–13: movies
    Expected(name: "Big Buck Bunny (2008).mp4", title: "Big Buck Bunny", year: "2008", isTV: false, season: nil, episode: nil),
    Expected(name: "1917.2019.mkv", title: "1917", year: "2019", isTV: false, season: nil, episode: nil),
    Expected(name: "Blade.Runner.2049.2017.mkv", title: "Blade Runner 2049", year: "2017", isTV: false, season: nil, episode: nil),
    Expected(name: "Film.2020.1920x1080.mkv", title: "Film", year: "2020", isTV: false, season: nil, episode: nil),
    // Guards: a year after a dash is a year; a leading number outside a season folder is part of the title
    Expected(name: "Title - 2001.mkv", title: "Title", year: "2001", isTV: false, season: nil, episode: nil),
    Expected(name: "300 - Rise of an Empire (2014).mkv", title: "300 - Rise of an Empire", year: "2014", isTV: false, season: nil, episode: nil),
    Expected(name: "300 - Rise of an Empire (2014).mkv", folders: ["Movies"], title: "300 - Rise of an Empire", year: "2014", isTV: false, season: nil, episode: nil),
    Expected(name: "Big Buck Bunny (2008) {tmdb-10378}.mp4", title: "Big Buck Bunny", year: "2008", isTV: false, season: nil, episode: nil),
]

func runFileNameParserTests() {
    for c in cases {
        let r = recognize(fileName: c.name, folders: c.folders)
        let ok = r.title == c.title && r.year == c.year && r.isTV == c.isTV
            && r.season == c.season && r.episode == c.episode && r.looksLikeAnime == c.anime
        let got = "title=\(r.title) year=\(r.year ?? "-") tv=\(r.isTV) S=\(r.season ?? "-") E=\(r.episode ?? "-") anime=\(r.looksLikeAnime)"
        let place = c.folders.isEmpty ? "" : " in \(c.folders.reversed().joined(separator: "/"))"
        check(ok, "recognize \(c.name)\(place) [\(got)]")
    }

    // 4: the year on some episodes only applies to the whole series in that folder, never to movies
    let withYear = recognize(fileName: "Show.Name.2019.S01E01.mkv"), without = recognize(fileName: "Show.Name.S01E02.mkv")
    let other = recognize(fileName: "Show.Name.S01E03.mkv")
    let years = harmonizeYears([("/a", withYear), ("/a", without), ("/b", other)])
    check(years == ["2019", "2019", nil], "harmonizeYears same folder only [\(years)]")
    let twoYears = harmonizeYears([("/a", recognize(fileName: "Show.2005.S01E01.mkv")), ("/a", recognize(fileName: "Show.2023.S01E01.mkv")),
                                   ("/a", recognize(fileName: "Show.S01E02.mkv"))])
    check(twoYears == ["2005", "2023", nil], "harmonizeYears ambiguous year stays unknown")
    let movies = harmonizeYears([("/a", recognize(fileName: "Dune.2021.mkv")), ("/a", recognize(fileName: "Dune.mkv"))])
    check(movies == ["2021", nil], "harmonizeYears never touches movies")

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
