//
//  InspectorView.swift
//  Renamy
//
//  Right column: details of the selected series, movie or file, and the choice between titles.
//

import SwiftUI
import AppKit

struct InspectorView: View {
    @EnvironmentObject var vm: RenamyViewModel

    var body: some View {
        Group {
            if let group = vm.selectedGroup {
                if let amb = group.ambiguity {
                    ChoicePanel(ambiguity: amb, files: group.files).id(group.id)
                } else if group.first.resolvedTitle == nil && group.first.status != .manuale {
                    NotFoundPanel(files: group.files)
                } else {
                    DetailPanel(group: group, file: vm.selectedFile)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.dashed").font(.system(size: 40)).foregroundStyle(.tertiary)
                    Text(vm.t("insp_none_title")).font(.headline).foregroundStyle(.secondary)
                    Text(vm.t("insp_none_sub")).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

// MARK: - Choice

/// The candidates for files still to choose, plus "Apply also to".
struct ChoicePanel: View {
    @EnvironmentObject var vm: RenamyViewModel
    let ambiguity: AmbiguousMatch
    let files: [MediaFile]
    @State private var highlighted: String?
    @State private var applyAlso = true
    @State private var checked: Set<UUID> = []

    var body: some View {
        let suggestions = vm.applyAlsoSuggestions(for: ambiguity)
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.t(ambiguity.isTV ? "choice_which_series" : "choice_which_movie")).font(.title3.weight(.semibold))
                Text(fileSummary).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(ambiguity.candidates) { cand in
                        CandidateCard(candidate: cand, isTV: ambiguity.isTV, isHighlighted: cand.id == currentID)
                            .onTapGesture(count: 2) { choose(cand) }
                            .onTapGesture { highlighted = cand.id }
                    }
                }
            }
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(vm.t("choice_apply_also"), isOn: $applyAlso).font(.callout.weight(.semibold))
                    ForEach(suggestions, id: \.file.id) { s in
                        Toggle(isOn: Binding(get: { checked.contains(s.file.id) },
                                             set: { on in if on { checked.insert(s.file.id) } else { checked.remove(s.file.id) } })) {
                            HStack(spacing: 4) {
                                Text(s.file.originalName).lineLimit(1)
                                if !s.preselected {
                                    Text(String(format: vm.t("choice_other_folder"), s.file.currentURL.deletingLastPathComponent().lastPathComponent))
                                        .foregroundStyle(.tertiary).lineLimit(1)
                                }
                            }.font(.caption)
                        }
                        .padding(.leading, 18).disabled(!applyAlso)
                    }
                    Text(vm.t("choice_apply_also_hint")).font(.caption2).foregroundStyle(.tertiary).padding(.leading, 18)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.25)))
            }
            HStack {
                Button(vm.t("ctx_manual")) { vm.prepareManualSearch(for: files) }
                Spacer()
                Button(vm.t("sheet_cancel")) { vm.cancelDisambiguation(); vm.selection = nil }
                    .keyboardShortcut(.cancelAction)
                Button(vm.t("btn_choose")) { if let c = current { choose(c) } }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(current == nil)
            }
        }
        .padding(16)
        .onAppear { checked = Set(suggestions.filter(\.preselected).map(\.file.id)) }
    }

    private var currentID: String? { highlighted ?? ambiguity.candidates.first?.id }
    private var current: DisambiguationCandidate? { ambiguity.candidates.first { $0.id == currentID } }

    private var fileSummary: String {
        guard let first = files.first else { return "" }
        if files.count == 1 { return first.originalName }
        return String(format: vm.t("choice_files_summary"), first.originalName, files.count - 1)
    }

    private func choose(_ cand: DisambiguationCandidate) {
        vm.resolve(ambiguity, with: cand, alsoFor: applyAlso ? checked : [])
    }
}

struct CandidateCard: View {
    @EnvironmentObject var vm: RenamyViewModel
    let candidate: DisambiguationCandidate
    let isTV: Bool
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            PosterView(url: candidate.posterURL.flatMap(URL.init(string:)), title: candidate.title, width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.title).font(.callout.weight(.semibold)).lineLimit(2)
                if candidate.originalTitle != candidate.title {
                    Text(candidate.originalTitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Text(source).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                Text(candidate.year).font(.callout)
                if !candidate.date.isEmpty { Text(candidate.date).font(.caption2).foregroundStyle(.tertiary) }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(isHighlighted ? Color.accentColor.opacity(0.10) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isHighlighted ? Color.accentColor : Color.secondary.opacity(0.25),
                                                           lineWidth: isHighlighted ? 2 : 1))
        .contentShape(Rectangle())
    }

    private var source: String {
        if candidate.source == .anilist { return "AniList" + (candidate.format.map { " · \($0)" } ?? "") }
        return vm.t(isTV ? "kind_tv" : "kind_movie") + " · TMDB"
    }
}

// MARK: - Details

struct DetailPanel: View {
    @EnvironmentObject var vm: RenamyViewModel
    let group: FileGroup
    /// Set when a single file is selected: its name can be edited here.
    let file: MediaFile?

    var body: some View {
        let first = group.first
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    PosterView(url: first.posterURL, title: first.resolvedTitle ?? first.originalName, width: 78)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(heading).font(.title3.weight(.semibold)).lineLimit(3)
                        if let orig = first.resolvedOriginalTitle, orig != first.resolvedTitle {
                            Text(orig).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                        }
                        HStack(spacing: 4) {
                            KindBadges(file: first)
                        }
                        HStack(spacing: 4) {
                            if let id = first.anilistID { CapsuleBadge(text: "AniList \(id)", color: .secondary) }
                            if !first.tmdbID.isEmpty { CapsuleBadge(text: "TMDB \(first.tmdbID)", color: .secondary) }
                        }
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
                    if first.isTVShow {
                        GridRow {
                            Text(vm.t("insp_episodes")).foregroundStyle(.secondary)
                            Text(episodesText)
                        }
                    }
                    GridRow {
                        Text(vm.t("insp_format")).foregroundStyle(.secondary)
                        Text(formatText)
                    }
                    GridRow {
                        Text(vm.t("insp_status")).foregroundStyle(.secondary)
                        HStack(spacing: 5) { StatusDot(status: first.status); Text(first.status.label) }
                    }
                }
                .font(.callout)

                if let note = numberingNote {
                    Label(note, systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(9).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                }

                if let file {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.t("insp_new_name")).font(.caption).foregroundStyle(.secondary)
                        NameField(file: file)
                        Text(file.originalName).font(.caption).foregroundStyle(.tertiary).textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.t(vm.createSubfolders ? "insp_destination" : "insp_rename_in_place")).font(.caption).foregroundStyle(.secondary)
                    Text(treeText).font(.caption.monospaced()).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(9).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack {
                    Button(vm.t("insp_change_match")) { vm.prepareManualSearch(for: group.files) }
                        .disabled(group.files.allSatisfy { $0.status == .spostato })
                    Button(vm.t("ctx_reveal")) { NSWorkspace.shared.activateFileViewerSelecting(group.files.map(\.currentURL)) }
                }
            }
            .padding(16)
        }
    }

    private var heading: String {
        let f = group.first
        let t = f.resolvedTitle ?? f.proposedName
        return Naming.hasValidYear(f.resolvedYear) ? "\(t) (\(f.resolvedYear!))" : t
    }

    private var episodesText: String {
        let codes = group.files.compactMap(episodeCode).sorted()
        guard let first = codes.first else { return String(format: vm.t("n_files"), group.files.count) }
        if codes.count == 1 { return first }
        return String(format: vm.t("insp_episode_range"), group.files.count, first, codes.last!)
    }

    private var formatText: String {
        let f = group.first
        if let tag = vm.renameFormat.tmdbTag(f.tmdbID) { return vm.renameFormat.shortLabel + " · " + tag }
        return vm.renameFormat.label
    }

    /// Explains when the TMDB numbering differs from the one in the file name (anime).
    private var numberingNote: String? {
        // Senza stagione nel nome vale la 1: cambia davvero solo se il numero è diverso
        func number(_ s: String?, default d: Int?) -> Int? { s.flatMap { Int($0) } ?? d }
        guard let f = group.files.first(where: {
                  $0.isTVShow && (number($0.parsedSeason, default: 1) != number($0.recognizedSeason, default: 1)
                                  || number($0.parsedEpisode, default: nil) != number($0.recognizedEpisode, default: nil)) }),
              let code = episodeCode(f) else { return nil }
        let season = f.recognizedSeason ?? "—", episode = f.recognizedEpisode ?? "—"
        return String(format: vm.t("insp_numbering_note"), season, episode, code)
    }

    private var treeText: String {
        let files = group.files
        guard let first = files.first else { return "" }
        let preview = vm.destinationPreview(for: first)
        var lines: [String] = []
        for (i, folder) in preview.folders.enumerated() {
            lines.append(String(repeating: "   ", count: i) + (i == 0 ? "" : "└ ") + folder)
        }
        let indent = String(repeating: "   ", count: preview.folders.count)
        let branch = preview.folders.isEmpty ? "" : "└ "
        lines.append(indent + branch + preview.fileName)
        if files.count > 1 { lines.append(indent + "   " + String(format: vm.t("insp_and_more"), files.count - 1)) }
        return lines.joined(separator: "\n")
    }
}

/// Editable new name of a file (changes become "Ready (Manual)").
struct NameField: View {
    @EnvironmentObject var vm: RenamyViewModel
    @ObservedObject var file: MediaFile

    var body: some View {
        TextField("…", text: $file.proposedName)
            .textFieldStyle(.roundedBorder)
            .disabled(file.status == .spostato)
            .onChange(of: file.proposedName) { _, _ in vm.proposedNameEdited(file) }
    }
}

// MARK: - Not found

struct NotFoundPanel: View {
    @EnvironmentObject var vm: RenamyViewModel
    let files: [MediaFile]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(files.first?.status.label ?? "", systemImage: "exclamationmark.circle").font(.title3.weight(.semibold))
                .foregroundStyle(.red)
            Text(files.first?.originalName ?? "").font(.callout).textSelection(.enabled)
            Text(vm.t("insp_not_found_hint")).font(.callout).foregroundStyle(.secondary)
            if files.count == 1, let file = files.first {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.t("insp_new_name")).font(.caption).foregroundStyle(.secondary)
                    NameField(file: file)
                }
            }
            HStack {
                Button(vm.t("ctx_manual")) { vm.prepareManualSearch(for: files) }.buttonStyle(.borderedProminent)
                Button(vm.t("ctx_reveal")) { NSWorkspace.shared.activateFileViewerSelecting(files.map(\.currentURL)) }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
