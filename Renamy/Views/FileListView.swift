//
//  FileListView.swift
//  Renamy
//
//  Scanning progress, file list and rows.
//

import SwiftUI
import AppKit

// MARK: - Scanning / FileList / FileRow

struct ScanningView: View {
    @ObservedObject var vm: RenamyViewModel
    var body: some View {
        VStack {
            Text(vm.statusText).font(.title2).padding(.bottom, 8)
            ProgressView(value: vm.progress).progressViewStyle(.linear).padding(.horizontal, 50)
            Text(vm.etaText).font(.caption).foregroundColor(.secondary).padding(.top, 4)
        }.frame(maxHeight: .infinity)
    }
}

struct FileListView: View {
    @ObservedObject var vm: RenamyViewModel

    private var visibleFiles: [MediaFile] {
        guard vm.filterNonTrovati else { return vm.fileList }
        return vm.fileList.filter { [.nonTrovato, .ambiguo, .erroreRete, .erroreRegex, .erroreSpostamento].contains($0.status) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Stesse colonne e margini delle righe, così le intestazioni restano allineate al contenuto
            HStack {
                Color.clear.frame(width: FileRowView.checkboxWidth, height: 1)
                Text(vm.t("col_original")).frame(maxWidth: .infinity, alignment: .leading)
                // Allineato al testo dentro il campo, non al suo bordo
                Text(vm.t("col_proposed")).padding(.leading, 6).frame(maxWidth: .infinity, alignment: .leading)
                Text(vm.t("col_status")).frame(width: FileRowView.statusWidth, alignment: .leading)
            }.font(.headline).padding(.horizontal, FileRowView.horizontalInset).padding(.vertical, 6)
            Divider()
            List(visibleFiles) { file in
                FileRowView(file: file, onManualSearch: {
                    if file.status == .ambiguo { vm.promptDisambiguation(for: file) }
                    else { vm.prepareManualSearch(for: file) }
                }).environmentObject(vm)
                .listRowInsets(EdgeInsets(top: 0, leading: FileRowView.horizontalInset, bottom: 0, trailing: FileRowView.horizontalInset))
            }.listStyle(.plain)
        }
    }
}

struct FileRowView: View {
    @ObservedObject var file: MediaFile
    @EnvironmentObject var vm: RenamyViewModel
    var onManualSearch: () -> Void

    static let checkboxWidth: CGFloat = 30
    static let statusWidth: CGFloat = 140
    static let horizontalInset: CGFloat = 12

    var body: some View {
        HStack {
            Toggle("", isOn: $file.isSelected).toggleStyle(.checkbox).labelsHidden().frame(width: Self.checkboxWidth, alignment: .leading)
            Text(file.originalName).font(.caption).lineLimit(2).foregroundColor(color(for: file.status)).frame(maxWidth: .infinity, alignment: .leading)
            TextField("...", text: $file.proposedName).textFieldStyle(.roundedBorder).frame(maxWidth: .infinity)
                .disabled(file.status == .spostato)
                .onChange(of: file.proposedName) { _, _ in vm.proposedNameEdited(file) }
            HStack {
                Text(file.status.label).font(.callout).foregroundColor(color(for: file.status))
                if [.nonTrovato, .erroreRete, .erroreRegex].contains(file.status) {
                    Button(action: onManualSearch) { Image(systemName: "magnifyingglass").foregroundColor(.blue) }.buttonStyle(.plain)
                } else if file.status == .ambiguo {
                    Button(action: onManualSearch) { Image(systemName: "list.bullet.circle.fill").foregroundColor(.orange) }.buttonStyle(.plain)
                }
            }.frame(width: Self.statusWidth, alignment: .leading)
        }
        .padding(.vertical, 4)
        // NEW: permette di correggere anche un file già abbinato (match sbagliato)
        .contextMenu {
            Button(vm.t("ctx_manual")) { vm.prepareManualSearch(for: file) }
                .disabled(file.status == .spostato || vm.isScanning || vm.isProcessing)
            Button(vm.t("ctx_reveal")) { NSWorkspace.shared.activateFileViewerSelecting([file.currentURL]) }
        }
    }

    private func color(for s: FileStatus) -> Color {
        switch s {
        case .ambiguo: return .orange
        case .nonTrovato, .erroreRete, .erroreRegex, .erroreSpostamento: return .red
        default: return .primary
        }
    }
}
