//
//  TMDBRequest.swift
//  Renamy
//
//  Builds TMDB API requests. Pure Foundation: compiled by scripts/test.sh.
//

import Foundation

enum TMDBRequest {
    /// - Parameters:
    ///   - key: v3 API key (sent as `api_key`) or v4 Read Access Token (sent as Bearer, it is much longer)
    ///   - language: e.g. "it-IT"
    static func make(path: String, params: [String: String], key rawKey: String, language: String) throws -> URLRequest {
        guard var comps = URLComponents(string: "https://api.themoviedb.org/3/\(path)") else { throw URLError(.badURL) }
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // NEW: supporto anche al Read Access Token v4 (JWT, molto più lungo della key v3)
        let isBearer = key.count > 40
        var items = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        items.append(URLQueryItem(name: "language", value: language))
        if !isBearer { items.append(URLQueryItem(name: "api_key", value: key)) }
        comps.queryItems = items.sorted { $0.name < $1.name }
        // FIX: prima la query era codificata con .urlQueryAllowed, che NON codifica "&", "=" e "+":
        // "Fast & Furious" troncava la query. URLComponents gestisce & e =, il + va fatto a mano.
        comps.percentEncodedQuery = comps.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if isBearer { req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        return req
    }
}
