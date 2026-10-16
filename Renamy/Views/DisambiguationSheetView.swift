//
//  DisambiguationSheetView.swift
//  Renamy
//
//  Choice between several matching titles.
//

import SwiftUI

// MARK: - Disambiguation Sheet

struct DisambiguationSheetView: View {
    let ambiguity: AmbiguousMatch
    let onSelect: (DisambiguationCandidate) -> Void
    let onCancel: () -> Void
    @EnvironmentObject var vm: RenamyViewModel

    var body: some View {
        VStack {
            Text(vm.t("sheet_title")).font(.title2).padding(.top)
            if let firstID = ambiguity.fileIDs.first, let file = vm.fileList.first(where: { $0.id == firstID }) {
                VStack(spacing: 4) {
                    Text(vm.t("sheet_original")).font(.caption).foregroundStyle(.secondary)
                    Text(file.originalName).font(.headline).lineLimit(2).multilineTextAlignment(.center)
                    if ambiguity.fileIDs.count > 1 {
                        Text(String(format: vm.t("sheet_applies_to"), ambiguity.fileIDs.count))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal).padding(.bottom, 4)
            }
            Divider().padding(.vertical)
            List(ambiguity.candidates) { cand in
                Button(action: { onSelect(cand) }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(cand.title).bold()
                            if cand.originalTitle != cand.title {
                                Text(cand.originalTitle).font(.caption).foregroundColor(.secondary)
                            }
                            // NEW: fonte e formato per i risultati AniList (TV, MOVIE, OVA…)
                            if cand.source == .anilist {
                                Text("AniList" + (cand.format.map { " · \($0)" } ?? "")).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(cand.year).font(.body)
                            if !cand.date.isEmpty { Text(cand.date).font(.caption).foregroundColor(.secondary) }
                        }
                    }
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
            // FIX: Annulla passa dal ViewModel (resetta il flag di elaborazione in sospeso) e risponde a Esc
            Button(vm.t("sheet_cancel"), action: onCancel).keyboardShortcut(.cancelAction).padding()
        }.frame(minWidth: 420, minHeight: 500)
    }
}
