//
//  GroupingTests.swift
//

import Foundation

func runGroupingTests() {
    let a1 = UUID(), a2 = UUID(), sameFolder = UUID(), otherFolder = UUID(), otherTitle = UUID(), movie = UUID()
    let items = [
        GroupingItem(id: a1, folder: "/Series", title: "Doctor Who", isTV: true),
        GroupingItem(id: a2, folder: "/Series", title: "Doctor Who", isTV: true),
        GroupingItem(id: sameFolder, folder: "/Series", title: "doctor who", isTV: true),
        GroupingItem(id: otherFolder, folder: "/Classics", title: "Doctor Who", isTV: true),
        GroupingItem(id: otherTitle, folder: "/Series", title: "The Expanse", isTV: true),
        GroupingItem(id: movie, folder: "/Series", title: "Doctor Who", isTV: false),
    ]
    let s = Grouping.applyAlsoSuggestions(group: [a1, a2], items: items)
    let byID = Dictionary(uniqueKeysWithValues: s.map { ($0.id, $0.preselected) })
    check(byID.count == 2, "apply also: only same title and kind [\(byID.count)]")
    check(byID[sameFolder] == true, "apply also: same folder starts checked")
    check(byID[otherFolder] == false, "apply also: other folder never checked automatically")
    check(byID[otherTitle] == nil && byID[movie] == nil, "apply also: other titles and movies excluded")
    check(Grouping.applyAlsoSuggestions(group: [], items: items).isEmpty, "apply also: empty group")
}
