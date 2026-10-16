//
//  SettingsView.swift
//  Renamy
//
//  Language picker and settings.
//

import SwiftUI
import AppKit

// MARK: - Language

/// Come nelle altre app (Upgrady): Sistema / Italiano / English. macOS legge la lingua
/// all'avvio, quindi al cambio si chiede di riavviare.
private struct LanguagePicker: View {
    @State private var choice = LanguagePicker.current
    @State private var askRelaunch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(Strings.get("lbl_lang"), selection: Binding(get: { choice }, set: { v in
                choice = v
                if v.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                } else {
                    UserDefaults.standard.set([v], forKey: "AppleLanguages")
                }
                askRelaunch = true
            })) {
                Text(Strings.get("lang_system")).tag("")
                Text(verbatim: "Italiano").tag("it")
                Text(verbatim: "English").tag("en")
            }
            Text(Strings.get("lang_restart_hint")).font(.caption).foregroundStyle(.secondary)
        }
        .alert(Strings.get("alert_restart_title"), isPresented: $askRelaunch) {
            Button(Strings.get("btn_restart")) { Self.relaunch() }
            Button(Strings.get("btn_later"), role: .cancel) {}
        }
    }

    static var current: String {
        let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
        return (domain["AppleLanguages"] as? [String])?.first.map { String($0.prefix(2)) } ?? ""
    }

    /// Chiude Renamy e lo riapre quando è davvero chiuso, così non ne restano due aperti.
    /// La riapertura parte solo se la chiusura va a buon fine.
    static func relaunch() {
        relaunchRequested = Date()
        if relaunchObserver == nil {
            relaunchObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                guard let asked = relaunchRequested, Date().timeIntervalSince(asked) < 120 else { return }
                let pid = ProcessInfo.processInfo.processIdentifier
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/sh")
                task.arguments = ["-c", "while /bin/kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
                try? task.run()
            }
        }
        // Le Impostazioni sono un foglio: chiudiamolo prima di uscire
        for window in NSApp.windows { window.attachedSheet.map { window.endSheet($0) } }
        NSApp.terminate(nil)
    }
    private static var relaunchRequested: Date?
    private static var relaunchObserver: NSObjectProtocol?
}

// MARK: - Settings Sheet

struct SettingsSheetView: View {
    @ObservedObject var vm: RenamyViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text(vm.t("settings_title")).font(.title2).padding()
            Form {
                Section {
                    SecureField("API Key TMDB", text: $vm.apiKey)
                } header: { Text(vm.t("sec_api")) } footer: {
                    Text(vm.t("lbl_api_hint")).font(.caption).foregroundStyle(.secondary)
                }
                Section(vm.t("sec_language")) {
                    LanguagePicker()
                }
                Section(vm.t("sec_appearance")) {
                    ThemeSelectionView(selectedTheme: $vm.appTheme).padding(.vertical, 5)
                }
                Section(vm.t("sec_format")) {
                    Picker(vm.t("lbl_format"), selection: $vm.renameFormat) {
                        ForEach(RenameFormat.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section(vm.t("sec_folders")) {
                    Toggle(vm.t("lbl_subfolders"), isOn: $vm.includeSubfolders)
                    Toggle(vm.t("lbl_move"), isOn: $vm.createSubfolders)
                }
            }.padding()
            Button(vm.t("btn_done")) { dismiss() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).padding()
        }.frame(width: 440, height: 580)
    }
}
