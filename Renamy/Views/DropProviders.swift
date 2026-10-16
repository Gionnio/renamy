//
//  DropProviders.swift
//  Renamy
//
//  Resolves dropped items to file URLs.
//

import AppKit
import UniformTypeIdentifiers

// MARK: - Drag & Drop Helper

@MainActor
func resolveProviders(_ providers: [NSItemProvider]) async -> [URL] {
    await withCheckedContinuation { continuation in
        let group = DispatchGroup()
        var collected: [URL] = []
        let lock = NSLock()

        let acceptedTypes: [String] = [
            UTType.fileURL.identifier,
            "public.file-url",
            UTType.folder.identifier,
            "public.folder"
        ]

        for provider in providers {
            guard let typeIdentifier = acceptedTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else { continue }

            group.enter()
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                defer { group.leave() }
                var resolved: URL? = nil

                if let url = item as? URL {
                    resolved = url
                } else if let data = item as? Data {
                    if let url = URL(dataRepresentation: data, relativeTo: nil, isAbsolute: true) {
                        resolved = url
                    } else if let str = String(data: data, encoding: .utf8), let url = URL(string: str) {
                        resolved = url
                    }
                } else if let str = item as? String, let url = URL(string: str) {
                    resolved = url
                }

                if let url = resolved, url.isFileURL {
                    let clean = url.standardizedFileURL
                    lock.lock(); collected.append(clean); lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
            continuation.resume(returning: collected)
        }
    }
}
