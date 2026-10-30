//
//  MainView.swift
//  Renamy
//
//  Main window: sidebar, grouped list, inspector, toolbar and status bar.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MainView: View {
    @EnvironmentObject var vm: RenamyViewModel
    @State private var isDropTargeted = false
    @State private var columns = NavigationSplitViewVisibility.all

    var body: some View {
        // La barra di stato sta sotto le tre colonne, così non copre i pulsanti in fondo ai pannelli
        VStack(spacing: 0) {
            splitView
            StatusBar()
        }
        .frame(minWidth: 980, minHeight: 560)
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columns) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } content: {
            // Azioni nella barra della colonna centrale: "Rinomina N file" resta sopra l'elenco su cui agisce
            LibraryColumn(isDropTargeted: isDropTargeted)
                .navigationSplitViewColumnWidth(min: 420, ideal: 560)
                .toolbar { toolbar }
        } detail: {
            // La ricerca da sola sopra il pannello di destra: con il pulsante accanto non ci stava
            // e il pulsante sbordava oltre la linea tra le colonne
            InspectorView()
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
                .searchable(text: $vm.searchText, placement: .toolbar, prompt: Text(vm.t("search_prompt")))
        }
        .navigationTitle(vm.t("app_title"))
        .navigationSubtitle(subtitle)
        .onDrop(of: [UTType.fileURL, UTType.folder], isTargeted: $isDropTargeted) { providers in
            vm.handleDrop(providers: providers)
            return true
        }
        .alert(vm.t("alert_manual_title"), isPresented: $vm.isShowingRetryAlert) {
            TextField(vm.t("alert_manual_hint"), text: $vm.retrySearchName)
            Button(vm.t("btn_search")) { vm.retrySearchManual(name: vm.retrySearchName); vm.retrySearchName = "" }
            Button(vm.t("sheet_cancel"), role: .cancel) { vm.retrySearchName = ""; vm.manualSearchFileIDs = [] }
        } message: {
            Text(vm.t("alert_manual_sub"))
        }
        .alert(vm.t("alert_confirm_title"), isPresented: $vm.showConfirmationAlert) {
            Button(vm.t("sheet_cancel"), role: .cancel) { }
            Button(vm.t("btn_process")) { vm.executeProcessing() }
        } message: { Text(String(format: vm.t("alert_confirm_count"), vm.filesToProcess().count)) }
    }

    private var subtitle: String {
        guard let url = vm.selectedFolderURL else { return vm.fileList.isEmpty ? "" : String(format: vm.t("n_files"), vm.fileList.count) }
        return url.lastPathComponent + " · " + String(format: vm.t("n_files"), vm.fileList.count)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { openFolder() } label: { Label(vm.t("btn_open"), systemImage: "folder") }
                .disabled(vm.isScanning || vm.isProcessing).help(vm.t("tip_open"))
            Button { vm.scanFolder() } label: { Label(vm.t("tip_scan"), systemImage: "arrow.clockwise") }
                .disabled(vm.selectedFolderURL == nil || vm.isScanning || vm.isProcessing).help(vm.t("tip_scan"))
            Button { vm.undoLastOperation() } label: { Label(vm.t("tip_undo"), systemImage: "arrow.uturn.backward") }
                .disabled(vm.undoHistory.isEmpty || vm.isProcessing).help(vm.t("tip_undo"))
            // Tutte le azioni nello stesso gruppo e con simboli semplici: a destra restano solo
            // il pulsante principale e la ricerca, così niente sta a cavallo della linea tra le colonne
            Button { vm.manualSearchFileIDs = []; vm.retrySearchName = ""; vm.isShowingRetryAlert = true } label: {
                Label(vm.t("btn_tmdb"), systemImage: "text.magnifyingglass")
            }.disabled(vm.isScanning || vm.isProcessing || vm.fileList.isEmpty).help(vm.t("tip_tmdb"))
            Button { vm.resetAll() } label: { Label(vm.t("tip_reset"), systemImage: "trash") }
                .disabled(vm.isScanning || vm.isProcessing || vm.fileList.isEmpty).help(vm.t("tip_reset"))
        }
    }

    private func openFolder() {
        // FIX: prima la cartella corrente veniva azzerata anche se si annullava il pannello
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.begin { response in
            if response == .OK, let url = panel.url { vm.selectedFolderURL = url; vm.scanFolder() }
        }
    }
}

// MARK: - Status bar

struct StatusBar: View {
    @EnvironmentObject var vm: RenamyViewModel

    var body: some View {
        HStack(spacing: 14) {
            if vm.isScanning || vm.isProcessing {
                ProgressView(value: vm.progress).progressViewStyle(.linear).frame(width: 140)
                Text(vm.statusText).lineLimit(1)
                if !vm.etaText.isEmpty { Text(vm.etaText).foregroundStyle(.tertiary) }
            } else if vm.fileList.isEmpty {
                Text(vm.statusText).lineLimit(1)
            } else {
                counter(.ready, color: .green, key: "status_n_ready")
                counter(.ambiguous, color: .orange, key: "status_n_ambiguous")
                counter(.notFound, color: .red, key: "status_n_not_found")
                if vm.count(.moved) > 0 { counter(.moved, color: .secondary, key: "status_n_moved") }
                Text(vm.statusText).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer()
            Text(sources).foregroundStyle(.secondary)
            // Pulsante principale in fondo a destra: in alto, accanto alla ricerca, sbordava oltre
            // la linea tra le colonne quando il pannello di destra era stretto
            Button { vm.requestProcessing() } label: {
                Text(String(format: vm.t("btn_rename_n"), vm.filesToProcess().count)).padding(.horizontal, 4)
            }
            .font(.body)
            .buttonStyle(.borderedProminent)
            .disabled(vm.filesToProcess().isEmpty || vm.isScanning || vm.isProcessing)
            .help(vm.t("tip_process"))
        }
        .font(.caption)
        .padding(.horizontal, 12).frame(height: 44)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
    }

    private func counter(_ filter: SidebarFilter, color: Color, key: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(String(format: vm.t(key), vm.count(filter)))
        }
    }

    private var sources: String {
        let tmdb = vm.apiKey.isEmpty ? "TMDB ✕" : "TMDB ✓"
        return vm.animeEnabled ? tmdb + " · AniList ✓" : tmdb
    }
}

// MARK: - Empty states

struct DropPlaceholderView: View {
    let isTargeted: Bool
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 48))
                .foregroundColor(isTargeted ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.15), value: isTargeted)
            Text(message)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScanningView: View {
    @EnvironmentObject var vm: RenamyViewModel
    var body: some View {
        VStack(spacing: 8) {
            Text(vm.statusText).font(.title3)
            ProgressView(value: vm.progress).progressViewStyle(.linear).frame(maxWidth: 260)
            Text(vm.etaText).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
