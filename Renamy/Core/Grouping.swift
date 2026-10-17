//
//  Grouping.swift
//  Renamy
//
//  Which other files a choice can also apply to. Pure Foundation: compiled by scripts/test.sh.
//

import Foundation

/// A file still to choose, as seen by the grouping rules.
struct GroupingItem {
    let id: UUID
    /// Folder that contains the file.
    let folder: String
    /// Recognized title (before matching).
    let title: String
    let isTV: Bool
}

enum Grouping {
    /// Files proposed under "Apply also to": still to choose, same title and kind, not in the group.
    /// Only those in one of the group's folders start checked: two different series with the same
    /// name in different folders are never merged without the user ticking them.
    static func applyAlsoSuggestions(group: Set<UUID>, items: [GroupingItem]) -> [(id: UUID, preselected: Bool)] {
        let members = items.filter { group.contains($0.id) }
        guard let first = members.first else { return [] }
        let title = normalizeTitle(first.title)
        guard !title.isEmpty else { return [] }
        let folders = Set(members.map(\.folder))
        return items
            .filter { !group.contains($0.id) && $0.isTV == first.isTV && normalizeTitle($0.title) == title }
            .map { ($0.id, folders.contains($0.folder)) }
    }
}
