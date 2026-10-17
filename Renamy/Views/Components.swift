//
//  Components.swift
//  Renamy
//
//  Small shared views: poster, capsule badge, status dot.
//

import SwiftUI

/// Poster from TMDB or AniList, with a tinted placeholder while it loads or when there is none.
struct PosterView: View {
    let url: URL?
    let title: String
    var width: CGFloat = 34

    private var height: CGFloat { (width * 1.47).rounded() }

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: width > 50 ? 8 : 5))
        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
    }

    private var placeholder: some View {
        // Colore stabile per titolo (hashValue cambia a ogni avvio)
        let hue = Double(title.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 360 }) / 360
        return LinearGradient(colors: [Color(hue: hue, saturation: 0.55, brightness: 0.55), Color(hue: hue, saturation: 0.35, brightness: 0.8)],
                              startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottomLeading) {
                Text(String(title.prefix(1)).uppercased())
                    .font(.system(size: width * 0.32, weight: .bold)).foregroundStyle(.white).padding(width * 0.1)
            }
    }
}

struct CapsuleBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 1.5)
            .background(color.opacity(0.18), in: Capsule())
            .fixedSize()
    }
}

extension FileStatus {
    /// Green ready, orange to choose, red not found or error, secondary when renamed.
    var color: Color {
        switch self {
        case .pronto, .manuale, .ripristinato: return .green
        case .ambiguo: return .orange
        case .nonTrovato, .erroreRete, .erroreRegex, .erroreSpostamento: return .red
        case .spostato: return .secondary
        }
    }
}

struct StatusDot: View {
    let status: FileStatus
    var body: some View {
        Circle().fill(status.color).frame(width: 8, height: 8).help(status.label)
    }
}

/// Kind and source badges of a file.
struct KindBadges: View {
    @EnvironmentObject var vm: RenamyViewModel
    let file: MediaFile

    var body: some View {
        HStack(spacing: 4) {
            if vm.isAnime(file) {
                CapsuleBadge(text: vm.t("kind_anime"), color: .pink)
            } else if file.isTVShow {
                CapsuleBadge(text: vm.t("kind_tv"), color: .blue)
            } else {
                CapsuleBadge(text: vm.t("kind_movie"), color: .purple)
            }
            if let source {
                CapsuleBadge(text: source, color: .secondary)
            }
        }
    }

    private var source: String? {
        guard file.resolvedTitle != nil, file.status != .ambiguo else { return nil }
        if file.anilistID != nil { return file.tmdbID.isEmpty ? "AniList" : "AniList → TMDB" }
        return file.tmdbID.isEmpty ? nil : "TMDB"
    }
}

/// Short episode code, e.g. "S01E29".
func episodeCode(_ file: MediaFile) -> String? {
    guard file.isTVShow, let e = file.parsedEpisode else { return nil }
    return "S\(file.parsedSeason ?? "01")E\(e)"
}
