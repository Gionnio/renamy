//
//  SidebarView.swift
//  Renamy
//
//  Filters by status and kind, with counts; folder and format at the bottom.
//

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var vm: RenamyViewModel

    var body: some View {
        List(selection: $vm.sidebarFilter) {
            Section(vm.t("side_status")) {
                row(.all, "side_all", "tray.full")
                row(.ambiguous, "side_ambiguous", "questionmark.circle", tint: .orange)
                row(.ready, "side_ready", "checkmark.circle", tint: .green)
                row(.notFound, "side_not_found", "exclamationmark.circle", tint: .red)
                row(.moved, "side_moved", "checkmark.seal")
            }
            Section(vm.t("side_kind")) {
                row(.movies, "kind_movies", "film")
                row(.series, "kind_series", "tv")
                if vm.animeEnabled { row(.anime, "kind_anime", "sparkles.tv") }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) { footer }
    }

    private func row(_ filter: SidebarFilter, _ key: String, _ icon: String, tint: Color? = nil) -> some View {
        Label {
            Text(vm.t(key))
        } icon: {
            Image(systemName: icon)
        }
        .listItemTint(tint ?? .accentColor)
        .badge(vm.count(filter))
        .tag(Optional(filter))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().padding(.bottom, 4)
            if let url = vm.selectedFolderURL {
                Label(url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"), systemImage: "folder")
                    .lineLimit(1).truncationMode(.middle)
            }
            Text(String(format: vm.t(vm.createSubfolders ? "side_format_move" : "side_format_rename"), vm.renameFormat.shortLabel))
        }
        .font(.caption).foregroundStyle(.secondary)
        .padding([.horizontal, .bottom], 12)
    }
}

extension RenameFormat {
    /// Short name for the sidebar: "Plex", "Jellyfin"…
    var shortLabel: String { Strings.get("fmt_short_\(rawValue)") }
}
