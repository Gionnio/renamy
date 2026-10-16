//
//  ContentView.swift
//  Renamy
//
//  Main window.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - UI Views

struct ContentView: View {
    @StateObject private var vm = RenamyViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if vm.isScanning {
                        ScanningView(vm: vm)
                    } else if vm.fileList.isEmpty {
                        DropPlaceholderView(isTargeted: isDropTargeted, message: vm.t("msg_ready"))
                    } else {
                        FileListView(vm: vm)
                    }
                    Divider()
                    HStack {
                        Text(vm.statusText).font(.caption).lineLimit(1)
                        Spacer()
                        // NEW: durante l'elaborazione il progresso prima non era visibile
                        if vm.isProcessing {
                            ProgressView(value: vm.progress).progressViewStyle(.linear).frame(width: 140)
                        }
                    }.padding(8).background(.thinMaterial)
                }

                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.08).cornerRadius(12))
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .navigationTitle(vm.t("app_title"))
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    HStack {
                        Button {
                            // FIX: prima la cartella corrente veniva azzerata anche se si annullava il pannello
                            let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                            panel.begin { response in
                                if response == .OK, let url = panel.url { vm.selectedFolderURL = url; vm.scanFolder() }
                            }
                        } label: { Label(vm.t("btn_open"), systemImage: "folder") }
                        .disabled(vm.isScanning || vm.isProcessing).help(vm.t("tip_open"))

                        if let url = vm.selectedFolderURL {
                            Text(url.lastPathComponent).font(.caption).foregroundColor(.secondary).padding(.leading, 4)
                        }
                    }
                    Button { vm.scanFolder() } label: { Image(systemName: "magnifyingglass") }
                        .disabled(vm.selectedFolderURL == nil || vm.isScanning || vm.isProcessing).help(vm.t("tip_scan"))
                    Button { vm.undoLastOperation() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(vm.undoHistory.isEmpty || vm.isProcessing).help(vm.t("tip_undo"))
                    Button { vm.resetAll() } label: { Image(systemName: "arrow.clockwise") }
                        .disabled(vm.isScanning || vm.isProcessing).help(vm.t("tip_reset"))
                    Button { vm.selectAll() } label: { Image(systemName: "checklist") }
                        .disabled(vm.fileList.isEmpty).help(vm.t("tip_sel_all"))
                    Button { vm.deselectAll() } label: { Image(systemName: "checklist.unchecked") }
                        .disabled(vm.fileList.isEmpty).help(vm.t("tip_desel_all"))
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { vm.targetFileForManualSearch = nil; vm.retrySearchName = ""; vm.isShowingRetryAlert = true } label: {
                        Label(vm.t("btn_tmdb"), systemImage: "magnifyingglass.circle")
                    }.disabled(vm.isScanning || vm.isProcessing || vm.fileList.isEmpty).help(vm.t("tip_tmdb"))

                    Toggle(isOn: $vm.filterNonTrovati) { Image(systemName: "line.3.horizontal.decrease.circle") }
                        .toggleStyle(.button).disabled(vm.fileList.isEmpty).help(vm.t("tip_filter"))

                    Button { vm.requestProcessing() } label: { Label(vm.t("btn_process"), systemImage: "play.fill") }
                        .disabled(vm.fileList.isEmpty || vm.isScanning || vm.isProcessing).help(vm.t("tip_process"))

                    Button { vm.showSettingsSheet = true } label: { Label(vm.t("settings_title"), systemImage: "gearshape") }
                        .help(vm.t("tip_settings")).keyboardShortcut(",", modifiers: .command)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSettings"))) { _ in
                vm.showSettingsSheet = true
            }
            .onDrop(
                of: [UTType.fileURL, UTType.folder],
                isTargeted: $isDropTargeted
            ) { providers in
                vm.handleDrop(providers: providers)
                return true
            }
            .sheet(isPresented: $vm.showSettingsSheet) { SettingsSheetView(vm: vm) }
            .alert(vm.t("alert_manual_title"), isPresented: $vm.isShowingRetryAlert) {
                TextField(vm.t("alert_manual_hint"), text: $vm.retrySearchName)
                Button(vm.t("btn_search")) { vm.retrySearchManual(name: vm.retrySearchName); vm.retrySearchName = "" }
                Button(vm.t("sheet_cancel"), role: .cancel) { vm.retrySearchName = ""; vm.targetFileForManualSearch = nil }
            } message: {
                Text(vm.t("alert_manual_sub"))
            }
            .alert(vm.t("alert_confirm_title"), isPresented: $vm.showConfirmationAlert) {
                Button(vm.t("sheet_cancel"), role: .cancel) { }
                Button(vm.t("btn_process")) { vm.executeProcessing() }
            } message: { Text(vm.t("alert_confirm_msg")) }
            .sheet(item: $vm.currentAmbiguity) { amb in
                DisambiguationSheetView(ambiguity: amb,
                                        onSelect: { vm.resolveAmbiguity(selected: $0) },
                                        onCancel: { vm.cancelDisambiguation() })
                    .environmentObject(vm)
            }
        }
        .preferredColorScheme(vm.appTheme.colorScheme)
    }
}

// MARK: - Drop Placeholder

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
                .font(.title2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
