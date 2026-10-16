//
//  Theme.swift
//  Renamy
//
//  Theme setting and its picker.
//

import SwiftUI

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { self.rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String { Strings.get("theme_\(rawValue)") }
}

// MARK: - Theme Selection

struct ThemeSelectionView: View {
    @Binding var selectedTheme: AppTheme

    var body: some View {
        HStack(spacing: 20) {
            ThemeOptionView(title: AppTheme.system.label, isSelected: selectedTheme == .system) {
                HStack(spacing: 0) {
                    ThemePreviewIcon(mode: .light).frame(width: 30).environment(\.colorScheme, .light)
                    ThemePreviewIcon(mode: .dark).frame(width: 30).environment(\.colorScheme, .dark)
                }
            }.onTapGesture { selectedTheme = .system }

            ThemeOptionView(title: AppTheme.light.label, isSelected: selectedTheme == .light) {
                ThemePreviewIcon(mode: .light).frame(width: 60).environment(\.colorScheme, .light)
            }.onTapGesture { selectedTheme = .light }

            ThemeOptionView(title: AppTheme.dark.label, isSelected: selectedTheme == .dark) {
                ThemePreviewIcon(mode: .dark).frame(width: 60).environment(\.colorScheme, .dark)
            }.onTapGesture { selectedTheme = .dark }
        }
    }
}

struct ThemeOptionView<Content: View>: View {
    let title: String; let isSelected: Bool; let content: () -> Content
    var body: some View {
        VStack(spacing: 8) {
            content()
                .frame(height: 45).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1))
                .shadow(radius: 1)
            Text(title).font(.caption).foregroundColor(isSelected ? .primary : .secondary)
        }.contentShape(Rectangle())
    }
}

struct ThemePreviewIcon: View {
    enum Mode { case light, dark }
    let mode: Mode
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(mode == .light ? Color(nsColor: .windowBackgroundColor) : Color.black.opacity(0.8))
            Rectangle().fill(mode == .light ? Color.gray.opacity(0.2) : Color.white.opacity(0.1)).frame(height: 10)
            Rectangle().fill(mode == .light ? Color.white : Color.white.opacity(0.05)).frame(width: 15).padding(.top, 10)
            VStack(alignment: .leading, spacing: 3) {
                RoundedRectangle(cornerRadius: 1).fill(Color.gray.opacity(0.4)).frame(width: 25, height: 2)
                RoundedRectangle(cornerRadius: 1).fill(Color.gray.opacity(0.2)).frame(width: 20, height: 2)
            }.padding(.top, 16).padding(.leading, 20)
        }
    }
}
