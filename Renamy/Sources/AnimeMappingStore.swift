//
//  AnimeMappingStore.swift
//  Renamy
//
//  Downloads the community anime ID mapping into the Caches folder, refreshes it every week and
//  keeps the previous copy when the network is not available. It is never bundled with the app.
//

import Foundation
import Combine

@MainActor
final class AnimeMappingStore: ObservableObject {
    static let sourceURL = URL(string: "https://raw.githubusercontent.com/Fribb/anime-lists/master/anime-list-mini.json")!
    static let maxAge: TimeInterval = 7 * 24 * 3600

    @Published private(set) var lastUpdated: Date?
    @Published private(set) var entryCount = 0
    @Published private(set) var isUpdating = false

    private var index: AnimeMappingIndex?

    private var fileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Renamy", isDirectory: true)
            .appendingPathComponent("anime-list-mini.json")
    }

    init() {
        lastUpdated = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// The mapping, downloaded or refreshed when needed. Nil when it was never downloaded and the network fails.
    func currentIndex() async -> AnimeMappingIndex? {
        let isStale = lastUpdated.map { Date().timeIntervalSince($0) > Self.maxAge } ?? true
        if isStale { await refresh() }
        if index == nil { await load() }
        return index
    }

    /// Downloads a fresh copy; on failure the cached copy stays.
    func refresh() async {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }
        do {
            let (data, resp) = try await URLSession.shared.data(for: URLRequest(url: Self.sourceURL, timeoutInterval: 60))
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            let parsed = try await Task.detached(priority: .userInitiated) { try AnimeMappingIndex.parse(data) }.value
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            index = parsed; entryCount = parsed.count; lastUpdated = Date()
        } catch {
            // Keep the cached copy
        }
    }

    private func load() async {
        let url = fileURL
        guard let parsed = try? await Task.detached(priority: .userInitiated, operation: {
            try AnimeMappingIndex.parse(Data(contentsOf: url))
        }).value else { return }
        index = parsed; entryCount = parsed.count
    }
}
