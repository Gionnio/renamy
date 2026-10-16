//
//  NamingTests.swift
//  Expected names follow the behaviour of Renamy 2.1.1.
//

import Foundation

func runNamingTests() {
    let movie = ResolvedMedia(title: "Big Buck Bunny", year: "2008", tmdbID: "10378", isTV: false, season: nil, episode: nil)
    check(Naming.fileName(movie, format: .standard) == "Big Buck Bunny (2008)", "movie standard")
    check(Naming.fileName(movie, format: .compact) == "Big.Buck.Bunny.2008", "movie compact")
    check(Naming.fileName(movie, format: .plex) == "Big Buck Bunny (2008) {tmdb-10378}", "movie plex")
    check(Naming.fileName(movie, format: .jellyfin) == "Big Buck Bunny (2008) [tmdbid-10378]", "movie jellyfin")
    check(Naming.fileName(movie, format: .emby) == "Big Buck Bunny (2008) [tmdbid=10378]", "movie emby")

    let noYear = ResolvedMedia(title: "Title", year: "N/A", tmdbID: "", isTV: false, season: nil, episode: nil)
    check(Naming.fileName(noYear, format: .plex) == "Title", "movie without year and id")

    let episode = ResolvedMedia(title: "Show: Name", year: "2015", tmdbID: "63639", isTV: true, season: "01", episode: "02")
    check(Naming.fileName(episode, format: .plex) == "Show Name (2015) S01E02", "episode plex: no tag on the episode")
    check(Naming.fileName(episode, format: .compact) == "Show.Name.2015.S01E02", "episode compact")
    check(Naming.seriesFolderName(episode, format: .plex) == "Show Name (2015) {tmdb-63639}", "series folder plex")
    check(Naming.seriesFolderName(episode, format: .compact) == "Show Name", "series folder compact")
    check(Naming.seriesFolderName(episode, format: .standard) == "Show Name (2015)", "series folder standard")

    let noSeason = ResolvedMedia(title: "Show", year: "2020", tmdbID: "1", isTV: true, season: nil, episode: "07")
    check(Naming.fileName(noSeason, format: .standard) == "Show (2020) S01E07", "episode without season defaults to 01")

    let base = URL(fileURLWithPath: "/Library", isDirectory: true)
    let generated = Naming.destinationFolder(media: episode, isTV: true, usesGeneratedName: true,
                                             newName: "Show Name (2015) S01E02", format: .plex, base: base)
    check(generated.path == "/Library/Show Name (2015) {tmdb-63639}/Season 01", "destination series from metadata")
    let edited = Naming.destinationFolder(media: episode, isTV: true, usesGeneratedName: false,
                                          newName: "Other Show S03E01", format: .plex, base: base)
    check(edited.path == "/Library/Other Show/Season 03", "destination series from a name edited by hand")
    let film = Naming.destinationFolder(media: movie, isTV: false, usesGeneratedName: true,
                                        newName: "Big Buck Bunny (2008) {tmdb-10378}", format: .plex, base: base)
    check(film.path == "/Library/Big Buck Bunny (2008) {tmdb-10378}", "destination movie")
}
