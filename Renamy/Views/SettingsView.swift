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

/// Settings window with tabs, like the other apps (mockup C).
struct SettingsView: View {
    @EnvironmentObject var vm: RenamyViewModel

    var body: some View {
        TabView {
            Form {
                Section {
                    SecureField(vm.t("lbl_api_key"), text: $vm.apiKey)
                } header: { Text("TMDB") } footer: {
                    Text(vm.t("lbl_api_hint")).font(.caption).foregroundStyle(.secondary)
                }
                AnimeSettingsSection(vm: vm, mapping: vm.animeMapping)
            }
            .formStyle(.grouped)
            .tabItem { Label(vm.t("tab_sources"), systemImage: "cloud") }

            Form {
                Section {
                    Picker(vm.t("lbl_format"), selection: $vm.renameFormat) {
                        ForEach(RenameFormat.allCases) { Text($0.label).tag($0) }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.t("lbl_format_example")).font(.caption).foregroundStyle(.secondary)
                        Text(example(isTV: false)).font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(example(isTV: true)).font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label(vm.t("tab_names"), systemImage: "textformat") }

            Form {
                Section {
                    Toggle(vm.t("lbl_subfolders"), isOn: $vm.includeSubfolders)
                    Toggle(isOn: $vm.createSubfolders) {
                        Text(vm.t("lbl_move"))
                        Text(vm.t("lbl_move_hint")).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem { Label(vm.t("tab_folders"), systemImage: "folder") }

            Form {
                Section(vm.t("sec_appearance")) {
                    ThemeSelectionView(selectedTheme: $vm.appTheme).padding(.vertical, 5)
                }
                Section(vm.t("sec_language")) {
                    LanguagePicker()
                }
            }
            .formStyle(.grouped)
            .tabItem { Label(vm.t("tab_appearance"), systemImage: "circle.lefthalf.filled") }
        }
        .frame(width: 520, height: 470)
        .preferredColorScheme(vm.appTheme.colorScheme)
    }

    /// Example names in the chosen format (open movie and a made-up series).
    private func example(isTV: Bool) -> String {
        let media = isTV
            ? ResolvedMedia(title: "Show Name", year: "2015", tmdbID: "12345", isTV: true, season: "01", episode: "02")
            : ResolvedMedia(title: "Big Buck Bunny", year: "2008", tmdbID: "10378", isTV: false, season: nil, episode: nil)
        let name = Naming.fileName(media, format: vm.renameFormat)
        guard isTV, vm.createSubfolders else { return name }
        return Naming.seriesFolderName(media, format: vm.renameFormat) + "/Season 01/" + name
    }
}

/// NEW: anime con AniList e numerazione TMDB.
private struct AnimeSettingsSection: View {
    @ObservedObject var vm: RenamyViewModel
    @ObservedObject var mapping: AnimeMappingStore

    var body: some View {
        Section {
            Toggle(isOn: $vm.animeEnabled) {
                Text(vm.t("lbl_anime_enabled"))
                Text(vm.t("lbl_anime_enabled_hint")).font(.caption).foregroundStyle(.secondary)
            }
            Toggle(isOn: $vm.animeUseTMDB) {
                Text(vm.t("lbl_anime_tmdb"))
                Text(vm.t("lbl_anime_tmdb_hint")).font(.caption).foregroundStyle(.secondary)
            }.disabled(!vm.animeEnabled)
            Toggle(vm.t("lbl_anime_english"), isOn: $vm.animeTitlesEnglish).disabled(!vm.animeEnabled)
            HStack {
                Text(status).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if mapping.isUpdating { ProgressView().controlSize(.small) }
                Button(vm.t("btn_update_now")) { Task { await mapping.refresh() } }
                    .controlSize(.small).disabled(mapping.isUpdating || !vm.animeEnabled || !vm.animeUseTMDB)
            }
        } header: { Text(vm.t("sec_anime")) }
    }

    private var status: String {
        guard let date = mapping.lastUpdated else { return vm.t("anime_map_never") }
        let when = date.formatted(date: .numeric, time: .omitted)
        guard mapping.entryCount > 0 else { return String(format: vm.t("anime_map_date"), when) }
        return String(format: vm.t("anime_map_status"), when, mapping.entryCount)
    }
}
