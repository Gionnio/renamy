//
//  FileListView.swift
//  Renamy
//
//  The middle column: files grouped by series or movie, with selection boxes and episodes.
//

import SwiftUI
import AppKit
import Combine

struct LibraryColumn: View {
    @EnvironmentObject var vm: RenamyViewModel
    let isDropTargeted: Bool

    var body: some View {
        ZStack {
            if vm.isScanning {
                ScanningView()
            } else if vm.fileList.isEmpty {
                DropPlaceholderView(isTargeted: isDropTargeted, message: vm.t("msg_ready"))
            } else {
                GroupedFileList()
            }
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08).cornerRadius(12))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
    }
}

struct GroupedFileList: View {
    @EnvironmentObject var vm: RenamyViewModel

    var body: some View {
        let groups = vm.visibleGroups
        VStack(spacing: 0) {
            HStack {
                Text(header(groups)).foregroundStyle(.secondary)
                Spacer()
                Button(vm.t("tip_sel_all")) { vm.selectAll() }.buttonStyle(.link)
                Text("·").foregroundStyle(.tertiary)
                Button(vm.t("tip_desel_all")) { vm.deselectAll() }.buttonStyle(.link)
            }
            .font(.caption)
            .padding(.horizontal, 12).padding(.vertical, 6)
            Divider()
            if groups.isEmpty {
                Text(vm.t("list_empty_filter")).foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $vm.selection) {
                    ForEach(groups) { group in
                        GroupRow(group: group).tag(group.id)
                        if group.files.count > 1, vm.expandedGroups.contains(group.id) {
                            ForEach(group.files) { file in
                                EpisodeRow(file: file).tag("file:" + file.id.uuidString)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func header(_ groups: [FileGroup]) -> String {
        String(format: vm.t("list_header"), groups.count, groups.reduce(0) { $0 + $1.files.count })
    }
}

/// Selection box for one or more files: checked, unchecked or mixed.
struct SelectionBox: View {
    @EnvironmentObject var vm: RenamyViewModel
    let files: [MediaFile]

    var body: some View {
        let selected = files.filter(\.isSelected).count
        Toggle("", isOn: Binding(
            get: { selected == files.count && selected > 0 },
            set: { on in files.forEach { $0.isSelected = on }; vm.objectWillChange.send() }))
            .toggleStyle(.checkbox).labelsHidden()
            .opacity(selected > 0 && selected < files.count ? 0.5 : 1)
            .disabled(files.allSatisfy { $0.status == .spostato || $0.status == .ambiguo })
    }
}

struct GroupRow: View {
    @EnvironmentObject var vm: RenamyViewModel
    let group: FileGroup

    var body: some View {
        let file = group.first
        HStack(spacing: 10) {
            if group.files.count > 1 {
                Button { toggle() } label: {
                    Image(systemName: vm.expandedGroups.contains(group.id) ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 12)
                }.buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 12)
            }
            SelectionBox(files: group.files)
            PosterView(url: file.posterURL, title: title)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.semibold)).lineLimit(1)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            badges
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu { FileContextMenu(files: group.files) }
    }

    private func toggle() {
        if vm.expandedGroups.contains(group.id) { vm.expandedGroups.remove(group.id) } else { vm.expandedGroups.insert(group.id) }
    }

    private var title: String {
        let file = group.first
        // Titolo e anno del film o della serie; il nome nuovo completo è nel pannello di destra
        if group.ambiguity == nil, let t = file.resolvedTitle {
            return Naming.hasValidYear(file.resolvedYear) ? "\(t) (\(file.resolvedYear!))" : t
        }
        if file.status == .manuale { return file.proposedName }
        return file.recognizedTitle.isEmpty ? file.originalName : file.recognizedTitle
    }

    private var subtitle: String {
        let files = group.files, file = group.first
        if let amb = group.ambiguity {
            let n = String(format: vm.t(amb.isTV ? "sub_possible_series" : "sub_possible_titles"), amb.candidates.count)
            return files.count > 1 ? String(format: vm.t("n_episodes"), files.count) + " · " + n : file.originalName + " · " + n
        }
        if file.resolvedTitle == nil && file.status != .manuale { return file.originalName + " · " + vm.t("sub_search_manually") }
        if file.isTVShow {
            let seasons = Set(files.compactMap(\.parsedSeason)).sorted()
            var parts = [String(format: vm.t(files.count == 1 ? "n_episode" : "n_episodes"), files.count)]
            if !seasons.isEmpty { parts.append(String(format: vm.t(seasons.count == 1 ? "sub_season" : "sub_seasons"), seasons.joined(separator: ", "))) }
            if files.count == 1, let code = episodeCode(file) { parts = [code] }
            return parts.joined(separator: " · ") + (files.count == 1 ? " · " + file.originalName : "")
        }
        return file.originalName
    }

    @ViewBuilder private var badges: some View {
        let file = group.first
        HStack(spacing: 6) {
            if group.ambiguity != nil {
                KindBadges(file: file)
                CapsuleBadge(text: vm.t("badge_choose"), color: .orange)
            } else if file.resolvedTitle == nil && file.status != .manuale {
                CapsuleBadge(text: file.status.label, color: file.status.color)
            } else {
                KindBadges(file: file)
                if file.status == .spostato { CapsuleBadge(text: file.status.label, color: .secondary) }
                else { StatusDot(status: worst) }
            }
        }
    }

    /// The most urgent status in the group (error > to choose > ready).
    private var worst: FileStatus {
        let s = group.files.map(\.status)
        if let e = s.first(where: { $0.color == .red }) { return e }
        return s.contains(.ambiguo) ? .ambiguo : group.first.status
    }
}

struct EpisodeRow: View {
    @EnvironmentObject var vm: RenamyViewModel
    @ObservedObject var file: MediaFile

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 12)
            SelectionBox(files: [file])
            Text(episodeCode(file) ?? "—").font(.caption.monospaced().weight(.semibold)).foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.proposedName.isEmpty ? "—" : file.proposedName).lineLimit(1)
                Text(file.originalName).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 8)
            StatusDot(status: file.status)
        }
        .padding(.leading, 18).padding(.vertical, 1)
        .contentShape(Rectangle())
        .contextMenu { FileContextMenu(files: [file]) }
    }
}

struct FileContextMenu: View {
    @EnvironmentObject var vm: RenamyViewModel
    let files: [MediaFile]

    var body: some View {
        Button(vm.t("ctx_manual")) { vm.prepareManualSearch(for: files) }
            .disabled(files.allSatisfy { $0.status == .spostato } || vm.isScanning || vm.isProcessing)
        Button(vm.t("ctx_reveal")) { NSWorkspace.shared.activateFileViewerSelecting(files.map(\.currentURL)) }
    }
}
