//
//  MediaFile.swift
//  Renamy
//
//  A video file in the list and its matching state.
//

import Foundation
import Combine

// MARK: - Models

final class MediaFile: ObservableObject, Identifiable {
    let id = UUID(); let originalURL: URL; let originalName: String
    /// Posizione attuale del file su disco (cambia dopo lo spostamento / undo).
    var currentURL: URL
    @Published var proposedName: String; @Published var isSelected: Bool
    @Published var status: FileStatus; @Published var isTVShow: Bool; @Published var tmdbID: String = ""
    var parsedSeason: String?; var parsedEpisode: String?
    /// Titolo e anno riconosciuti dal nome del file e dalle cartelle (usati per la ricerca automatica).
    var recognizedTitle = ""; var recognizedYear: String?
    /// Nome in stile anime (etichette tra parentesi quadre, numerazione assoluta, stagione nel titolo).
    var looksLikeAnime = false
    @Published var ambiguousCandidates: [DisambiguationCandidate]? = nil
    /// Metadati TMDB risolti: servono per rigenerare il nome al cambio formato e per le cartelle serie.
    var resolvedTitle: String?; var resolvedYear: String?
    /// Ultimo nome generato automaticamente (per distinguere le modifiche manuali).
    var generatedName: String = ""

    init(url: URL, status: FileStatus, proposedName: String = "", isSelected: Bool = false, isTVShow: Bool = false,
         tmdbID: String = "", parsedSeason: String? = nil, parsedEpisode: String? = nil) {
        self.originalURL = url; self.currentURL = url; self.originalName = url.lastPathComponent; self.status = status
        self.proposedName = proposedName; self.isSelected = isSelected; self.isTVShow = isTVShow
        self.tmdbID = tmdbID; self.parsedSeason = parsedSeason; self.parsedEpisode = parsedEpisode
    }
}
