//
//  AniListClient.swift
//  Renamy
//
//  Anime search on AniList (no key). One request per title, cached; waits when the rate limit is hit.
//

import Foundation

enum AniListError: Error { case http(Int) }

@MainActor
final class AniListClient {
    private var cache: [String: [AniListMedia]] = [:]

    func clearCache() { cache.removeAll() }

    func search(_ query: String) async throws -> [AniListMedia] {
        let key = normalizeTitle(query)
        if let cached = cache[key] { return cached }
        var req = URLRequest(url: AniListAPI.endpoint, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try AniListAPI.searchBody(query)

        // AniList allows few requests per minute (30 on 15/10/2026): on 429 wait as told and retry
        for attempt in 0..<3 {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            if http.statusCode == 429, attempt < 2 {
                let wait = min(Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 30, 65)
                try await Task.sleep(for: .seconds(wait))
                continue
            }
            guard http.statusCode == 200 else { throw AniListError.http(http.statusCode) }
            let results = try AniListAPI.decodeSearch(data)
            cache[key] = results
            return results
        }
        throw AniListError.http(429)
    }
}
