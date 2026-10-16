//
//  TMDBClient.swift
//  Renamy
//
//  Searches and details from TMDB, with a cache of the responses.
//

import Foundation

@MainActor
final class TMDBClient {
    /// Read at every request, so a key changed in Settings is used right away.
    private let apiKey: () -> String
    /// OK responses: episodes of the same series make the same query and must not repeat N identical calls.
    private var cache: [URL: Data] = [:]

    init(apiKey: @escaping () -> String) { self.apiKey = apiKey }

    func clearCache() { cache.removeAll() }

    /// Returns nil for 404.
    private func data(path: String, params: [String: String]) async throws -> Data? {
        let req = try TMDBRequest.make(path: path, params: params, key: apiKey(), language: AppLanguage.apiCode)
        if let url = req.url, let cached = cache[url] { return cached }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200:
            if let url = req.url { cache[url] = data }
            return data
        case 404: return nil
        case 401: throw TMDBError.unauthorized
        default:  throw TMDBError.http(http.statusCode)
        }
    }

    private func decodeSearch(endpoint: String, params: [String: String], isTV: Bool) async throws -> [DisambiguationCandidate] {
        guard let data = try await data(path: endpoint, params: params) else { return [] }
        if isTV { return try JSONDecoder().decode(TMDBResponse<TVResult>.self, from: data).results.map(\.candidate) }
        return try JSONDecoder().decode(TMDBResponse<MovieResult>.self, from: data).results.map(\.candidate)
    }

    func search(query: String, year: String?, isTV: Bool) async throws -> [DisambiguationCandidate] {
        let endpoint = isTV ? "search/tv" : "search/movie"
        let yearKey = isTV ? "first_air_date_year" : "year"
        var params = ["query": query]
        if let y = year, !y.isEmpty { params[yearKey] = y }
        var cands = try await decodeSearch(endpoint: endpoint, params: params, isTV: isTV)
        // FIX: se l'anno nel nome file è sbagliato (o è l'anno della stagione) riprova senza anno
        if cands.isEmpty, params[yearKey] != nil {
            params.removeValue(forKey: yearKey)
            cands = try await decodeSearch(endpoint: endpoint, params: params, isTV: isTV)
        }
        return cands
    }

    /// Movie or series by TMDB ID; nil when that ID does not exist for that kind.
    func details(id: String, kind: MediaKind) async throws -> DisambiguationCandidate? {
        guard let data = try await data(path: kind == .tv ? "tv/\(id)" : "movie/\(id)", params: [:]) else { return nil }
        if kind == .tv { return try JSONDecoder().decode(TVResult.self, from: data).candidate }
        return try JSONDecoder().decode(MovieResult.self, from: data).candidate
    }
}
