//
//  AnimeTests.swift
//  Mapping entries and AniList results shaped like the real data (checked on 15/10/2026).
//

import Foundation

private let mappingJSON = """
[
 {"type":"TV","anilist_id":154587,"mal_id":52991,"themoviedb_id":{"tv":209867},"season":{"tvdb":1,"tmdb":1},"episode_offset":""},
 {"type":"TV","anilist_id":182255,"mal_id":59978,"themoviedb_id":{"tv":209867},"season":{"tvdb":2,"tmdb":1},"episode_offset":{"tmdb":28}},
 {"type":"TV","anilist_id":209939,"mal_id":63816,"themoviedb_id":{"tv":209867},"season":{"tvdb":3,"tmdb":1},"episode_offset":{"tmdb":38}},
 {"type":"SPECIAL","anilist_id":"170068","themoviedb_id":{"tv":209867},"season":{"tvdb":0,"tmdb":0},"episode_offset":""},
 {"type":"MOVIE","anilist_id":"1000","themoviedb_id":{"movie":[4567]},"season":"","episode_offset":""},
 {"type":"TV","anilist_id":2000,"themoviedb_id":"","season":"","episode_offset":""},
 {"type":"TV","anilist_id":3000,"themoviedb_id":{"tv":555},"season":{"tvdb":2},"episode_offset":{"tvdb":12}},
 {"type":"OVA","anilist_id":"","themoviedb_id":{"tv":1}}
]
"""

private let aniListJSON = """
{"data":{"Page":{"media":[
 {"id":154587,"format":"TV","episodes":28,"seasonYear":2023,"startDate":{"year":2023,"month":9,"day":29},
  "title":{"romaji":"Sousou no Frieren","english":"Frieren: Beyond Journey’s End","native":"葬送のフリーレン"},
  "synonyms":["Frieren at the Funeral"],"coverImage":{"medium":"https://example.invalid/a.jpg"}},
 {"id":182255,"format":"TV","episodes":10,"seasonYear":2026,"startDate":{"year":2026,"month":1,"day":16},
  "title":{"romaji":"Sousou no Frieren 2nd Season","english":null,"native":null},"synonyms":[],"coverImage":null},
 {"id":170068,"format":"ONA","episodes":12,"seasonYear":null,"startDate":{"year":2023,"month":null,"day":null},
  "title":{"romaji":"Sousou no Frieren: Marumaru no Mahou","english":null,"native":null},"synonyms":null,"coverImage":null}
]}}}
"""

func runAnimeTests() {
    guard let index = try? AnimeMappingIndex.parse(Data(mappingJSON.utf8)) else { check(false, "mapping parses"); return }
    check(index.count == 7, "mapping: entries with an AniList ID (string IDs too, empty ID skipped) [\(index.count)]")
    check(index.entry(anilistID: 2000)?.tmdbTV == nil, "mapping: empty TMDB field")
    check(index.tmdbMovie(anilistID: 1000) == 4567, "mapping: movie")

    // Frieren: TMDB numbers the second and third seasons as a continuation of season 1
    check(index.tmdbEpisode(anilistID: 154587, fileSeason: nil, fileEpisode: 5) == TMDBEpisodeRef(tvID: 209867, season: 1, episode: 5),
          "first season, absolute numbering")
    check(index.tmdbEpisode(anilistID: 154587, fileSeason: 2, fileEpisode: 1) == TMDBEpisodeRef(tvID: 209867, season: 1, episode: 29),
          "\"2nd Season - 01\" found from the first season entry → S01E29")
    check(index.tmdbEpisode(anilistID: 154587, fileSeason: 3, fileEpisode: 2) == TMDBEpisodeRef(tvID: 209867, season: 1, episode: 40),
          "third season → S01E40")
    check(index.tmdbEpisode(anilistID: 182255, fileSeason: nil, fileEpisode: 1) == TMDBEpisodeRef(tvID: 209867, season: 1, episode: 29),
          "second season entry chosen directly")
    check(index.tmdbEpisode(anilistID: 154587, fileSeason: 4, fileEpisode: 3) == TMDBEpisodeRef(tvID: 209867, season: 4, episode: 3),
          "season unknown to the mapping keeps the file numbering")
    check(index.tmdbEpisode(anilistID: 3000, fileSeason: nil, fileEpisode: 1) == TMDBEpisodeRef(tvID: 555, season: 2, episode: 13),
          "only TVDB numbering available")
    check(index.tmdbEpisode(anilistID: 2000, fileSeason: nil, fileEpisode: 1) == nil, "no TMDB series")

    // AniList
    guard let results = try? AniListAPI.decodeSearch(Data(aniListJSON.utf8)) else { check(false, "AniList response decodes"); return }
    check(results.count == 3, "AniList: three results")
    check(results[0].displayTitle(preferEnglish: true) == "Frieren: Beyond Journey’s End", "AniList: English title")
    check(results[1].displayTitle(preferEnglish: true) == "Sousou no Frieren 2nd Season", "AniList: romaji when there is no English title")
    check(results[0].candidate(preferEnglish: false).source == .anilist && results[0].year == "2023", "AniList: candidate and year")
    check(AniListAPI.automaticChoice(results, query: "Sousou no Frieren", isTV: true)?.id == 154587, "AniList: exact romaji title chosen")
    check(AniListAPI.automaticChoice(results, query: "Frieren at the Funeral", isTV: true)?.id == 154587, "AniList: synonym chosen")
    check(AniListAPI.automaticChoice(results, query: "Frieren", isTV: true) == nil, "AniList: partial title asks")
    let body = (try? AniListAPI.searchBody("Sousou & Frieren")).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    check((body?["variables"] as? [String: String])?["search"] == "Sousou & Frieren", "AniList: search sent as a variable")
}
