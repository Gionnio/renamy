//
//  FileNameParser.swift
//  Renamy
//
//  Recognizes title, year, season and episode from a file name.
//  Pure Foundation: compiled by scripts/test.sh.
//

import Foundation

let videoExtensions: Set<String> = ["mkv", "mp4", "avi", "mov", "m4v"]

enum Patterns {
    // FIX: aggiunti lookbehind/lookahead: prima "Film.2020.1920x1080.mkv" veniva preso per una serie (20x108)
    static let episode = try! NSRegularExpression(
        pattern: #"(?i)(?<![a-z0-9])(?:s|stagione)[.\s_-]*(\d{1,2})[.\s_-]*(?:e|ep|episodio|x)[.\s_-]*(\d{1,4})(?!\d)|(?<![a-z0-9])(\d{1,2})x(\d{1,3})(?!\d)"#)
    // FIX: aggiunto il punto tra i separatori ("Show.E05.mkv" prima non veniva riconosciuto)
    static let absoluteEpisode = try! NSRegularExpression(
        pattern: #"(?i)(?:^|[\s._\-\[])(?:ep|episodio)[.\s_]*(\d{1,4})(?=[\s._\-\]]|$)|(?:^|[\s._\-\[])e(\d{2,4})(?=[\s._\-\]]|$)"#)
    // Marcatore TV sul nome già "pulito" (punti/underscore → spazi); allineato ai due pattern sopra
    // NEW: anche stagione nel titolo ("S2 - 03", "2nd Season", "Season 2") e numerazione assoluta ("Title - 05");
    // nella numerazione assoluta un anno (19xx/20xx) non è mai un episodio
    static let tvMarker = try! NSRegularExpression(
        pattern: #"(?i)\b(?:s\d{1,2}\s*e\d{1,4}|\d{1,2}x\d{1,3}|stagione\s*\d{1,2}|(?:ep|episodio)\s*\d{1,4}|e\d{2,4}|s\d{1,2}\s*-\s*\d{1,4}|\d{1,2}(?:st|nd|rd|th)\s+season|season\s+\d{1,2})\b|(?:^|\s)-\s*(?!(?:19|20)\d{2}(?!\d))\d{1,4}(?:v\d)?(?=\s|$)"#)
    /// "Title S2 - 03", "Title 2nd Season - 04", "Title Season 2 - 04"
    static let seasonDash = try! NSRegularExpression(
        pattern: #"(?i)(?:(?<![a-z0-9])s(\d{1,2})|(\d{1,2})(?:st|nd|rd|th)[.\s_]+season|season[.\s_]+(\d{1,2}))[.\s_]*-[.\s_]*(\d{1,4})(?:v\d)?(?!\d)"#)
    /// "Title - 05" (numerazione assoluta); un anno non è un episodio
    static let dashAbsolute = try! NSRegularExpression(
        pattern: #"(?i)(?:^|[\s._])-[\s._]*(?!(?:19|20)\d{2}(?!\d))(\d{1,4})(?:v\d)?(?=[\s._]|$)"#)
    /// "01 - Episode title.mkv": usato solo dentro una cartella di stagione
    static let leadingNumber = try! NSRegularExpression(pattern: #"^\s*(\d{1,3})\s*-\s"#)
    /// Cartella di stagione: "Season 1", "Stagione 01", "S1"
    static let seasonFolder = try! NSRegularExpression(pattern: #"(?i)^\s*(?:season|stagione|s)[\s._-]*(\d{1,2})\s*$"#)
    /// Etichette tra parentesi quadre: "[Tag]", "[1080p]", "[ABCD1234]"
    static let bracketTag = try! NSRegularExpression(pattern: #"\[[^\]]*\]"#)
    static let checksumTag = try! NSRegularExpression(pattern: #"\[[0-9A-Fa-f]{8}\]"#)
    static let year = try! NSRegularExpression(pattern: #"\b(19\d{2}|20\d{2})\b"#)
    static let junk = try! NSRegularExpression(
        pattern: #"(?i)\b(1080p|720p|480p|4k|2160p|uhd|bluray|brrip|bdrip|web-dl|webdl|webrip|web|hdtv|dvdrip|h264|h265|hevc|x264|x265|ita|eng|multi|sub|subs|repack|proper|remux|ac3|aac|ddp|dts|hdr|10bit)\b"#)
    static let multiSpace = try! NSRegularExpression(pattern: #" {2,}"#)
    // Usato solo per nomi TV modificati a mano (altrimenti si usano i metadati)
    static let tvFolderFallback = try! NSRegularExpression(pattern: #"(?i)^(.+?)[\s.]+S(\d{1,2})E\d{1,4}"#)
    static let tmdbLink = try! NSRegularExpression(pattern: #"(?i)themoviedb\.org/(movie|tv)/(\d+)"#)
}

func parseEpisodeInfo(from name: String) -> (isTV: Bool, season: String?, episode: String?) {
    let ns = NSRange(name.startIndex..., in: name)
    if let m = Patterns.episode.firstMatch(in: name, range: ns) {
        let sR = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 3)
        let eR = m.range(at: 2).location != NSNotFound ? m.range(at: 2) : m.range(at: 4)
        if let rS = Range(sR, in: name), let rE = Range(eR, in: name) {
            return (true, String(format: "%02d", Int(name[rS]) ?? 0), String(format: "%02d", Int(name[rE]) ?? 0))
        }
    }
    if let m = Patterns.seasonDash.firstMatch(in: name, range: ns),
       let sR = [1, 2, 3].map({ m.range(at: $0) }).first(where: { $0.location != NSNotFound }),
       let rS = Range(sR, in: name), let rE = Range(m.range(at: 4), in: name) {
        return (true, String(format: "%02d", Int(name[rS]) ?? 0), String(format: "%02d", Int(name[rE]) ?? 0))
    }
    if let m = Patterns.absoluteEpisode.firstMatch(in: name, range: ns) {
        let r = m.range(at: 1).location != NSNotFound ? m.range(at: 1) : m.range(at: 2)
        if let rr = Range(r, in: name) { return (true, nil, String(format: "%02d", Int(name[rr]) ?? 0)) }
    }
    if let m = Patterns.dashAbsolute.firstMatch(in: name, range: ns), let rr = Range(m.range(at: 1), in: name) {
        return (true, nil, String(format: "%02d", Int(name[rr]) ?? 0))
    }
    return (false, nil, nil)
}

/// Taglia il testo al primo tag tecnico (risoluzione, codec, lingua…) purché resti un titolo.
private func stripJunk(_ text: String) -> String {
    let ns = NSRange(text.startIndex..., in: text)
    for m in Patterns.junk.matches(in: text, range: ns) {
        guard let r = Range(m.range, in: text) else { continue }
        let before = String(text[..<r.lowerBound])
        if !cleanupTitleString(before).isEmpty { return before }
    }
    return text
}

/// FIX: usa l'ULTIMO anno preceduto da un titolo non vuoto.
/// Prima "1917.2019.mkv", "2001.A.Space.Odyssey.1968" o "Blade.Runner.2049.2017" producevano titolo vuoto o anno errato.
private func splitAtYear(_ text: String) -> (title: String, year: String)? {
    let ns = NSRange(text.startIndex..., in: text)
    for m in Patterns.year.matches(in: text, range: ns).reversed() {
        guard let r = Range(m.range, in: text) else { continue }
        let before = cleanupTitleString(String(text[..<r.lowerBound]))
        if !before.isEmpty { return (before, String(text[r])) }
    }
    return nil
}

func cleanFileNameRegex(_ raw: String) -> (title: String, year: String?, isTV: Bool) {
    cleanBaseName((raw as NSString).deletingPathExtension)
}

/// Title, year and TV marker of a name without extension (file or folder).
func cleanBaseName(_ nameWithoutExt: String) -> (title: String, year: String?, isTV: Bool) {
    let clean = nameWithoutExt.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ")
    let range = NSRange(clean.startIndex..., in: clean)

    // 1. Serie TV
    if let match = Patterns.tvMarker.firstMatch(in: clean, range: range),
       let tRange = Range(match.range, in: clean) {
        let prefix = stripJunk(String(clean[..<tRange.lowerBound]))
        if let split = splitAtYear(prefix) { return (split.title, split.year, true) }
        return (cleanupTitleString(prefix), nil, true)
    }

    // 2. Film con anno
    let withoutJunk = stripJunk(clean)
    if let split = splitAtYear(withoutJunk) { return (split.title, split.year, false) }

    // 3. Solo "junk wall" / fallback
    return (cleanupTitleString(withoutJunk), nil, false)
}

func cleanupTitleString(_ text: String) -> String {
    var t = text
    t = t.replacingOccurrences(of: "(", with: " ").replacingOccurrences(of: ")", with: " ")
         .replacingOccurrences(of: "[", with: " ").replacingOccurrences(of: "]", with: " ")
         .replacingOccurrences(of: "{", with: " ").replacingOccurrences(of: "}", with: " ")
    t = Patterns.multiSpace.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: " ")
    return t.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-")))
}

func sanitizeFileName(_ name: String) -> String {
    let invalidChars: Set<Character> = [":", "/", "\\", "?", "*", "\"", "<", ">", "|"]
    var s = String(name.map { invalidChars.contains($0) ? " " : $0 })
    while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    // FIX: un nome che inizia con "." diventerebbe un file nascosto
    while s.hasPrefix(".") { s.removeFirst() }
    return s
}

func normalizeTitle(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

/// Estrae un TMDB ID dall'input utente.
/// Accetta: "#12345", "tmdb:12345", "id:12345", "tv:12345", "movie:12345", "{tmdb-12345}", "[tmdbid=12345]",
/// oppure un link themoviedb.org/movie/12345-…
/// FIX: un numero "nudo" NON è più trattato come ID: "1917", "2012", "300" sono titoli di film.
func extractTMDBID(from input: String) -> (id: String, kind: MediaKind?)? {
    var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    let ns = NSRange(s.startIndex..., in: s)
    if let m = Patterns.tmdbLink.firstMatch(in: s, range: ns),
       let kR = Range(m.range(at: 1), in: s), let iR = Range(m.range(at: 2), in: s) {
        return (String(s[iR]), s[kR] == "tv" ? .tv : .movie)
    }

    if let f = s.first, let l = s.last, (f == "{" && l == "}") || (f == "[" && l == "]") {
        s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
    }
    let prefixes: [(String, MediaKind?)] = [
        ("tv:", .tv), ("serie:", .tv), ("movie:", .movie), ("film:", .movie),
        ("tmdbid=", nil), ("tmdbid-", nil), ("tmdbid:", nil), ("tmdb-", nil), ("tmdb:", nil), ("id:", nil), ("#", nil)
    ]
    for (prefix, kind) in prefixes where s.hasPrefix(prefix) {
        let rest = s.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty, rest.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return (rest, kind)
    }
    return nil
}

// MARK: - Recognition

/// What Renamy understands from a file name and its folders.
struct Recognition: Equatable {
    var title: String
    var year: String?
    var isTV: Bool
    var season: String?
    var episode: String?
    /// Name in the style of anime releases: bracket tags, checksum, absolute numbering or season in the title.
    var looksLikeAnime: Bool
}

private func firstMatch(_ re: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
    re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
}

/// Removes "[...]" tags and tidies the spaces they leave.
private func removeBracketTags(_ text: String) -> String {
    let ns = NSRange(text.startIndex..., in: text)
    let s = Patterns.bracketTag.stringByReplacingMatches(in: text, range: ns, withTemplate: " ")
    return Patterns.multiSpace.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " ")
        .trimmingCharacters(in: .whitespaces)
}

/// - Parameters:
///   - fileName: file name with extension
///   - folders: names of the containing folders, closest first (parent, grandparent)
func recognize(fileName: String, folders: [String] = []) -> Recognition {
    let base = (fileName as NSString).deletingPathExtension
    let hasLeadingTag = base.trimmingCharacters(in: .whitespaces).hasPrefix("[")
    let hasChecksum = firstMatch(Patterns.checksumTag, in: base) != nil
    let name = removeBracketTags(base)

    let parsed = parseEpisodeInfo(from: name)
    let cleaned = cleanBaseName(name)
    var result = Recognition(title: cleaned.title, year: cleaned.year, isTV: parsed.isTV || cleaned.isTV,
                             season: parsed.season, episode: parsed.episode, looksLikeAnime: false)
    let spaced = name.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ")
    let absolute = parsed.season == nil && firstMatch(Patterns.dashAbsolute, in: name) != nil
    result.looksLikeAnime = hasLeadingTag || hasChecksum || absolute || firstMatch(Patterns.seasonDash, in: spaced) != nil

    // Folders: "Season N" gives the season, the folder above gives the series
    guard let parent = folders.first else { return result }
    var seasonFromFolder: String? = nil
    if let m = firstMatch(Patterns.seasonFolder, in: parent), let r = Range(m.range(at: 1), in: parent) {
        seasonFromFolder = String(format: "%02d", Int(parent[r]) ?? 0)
    }
    let seriesFolder = seasonFromFolder != nil ? folders.dropFirst().first : parent

    if let season = seasonFromFolder {
        // "01 - Episode title.mkv" counts as an episode only inside a season folder
        if !result.isTV, let m = firstMatch(Patterns.leadingNumber, in: name), let r = Range(m.range(at: 1), in: name) {
            result.isTV = true; result.episode = String(format: "%02d", Int(name[r]) ?? 0); result.title = ""
        }
        if result.isTV, result.season == nil { result.season = season }
    }
    if result.isTV, result.title.isEmpty, let folder = seriesFolder {
        let fromFolder = cleanBaseName(removeBracketTags(folder))
        result.title = fromFolder.title
        if result.year == nil { result.year = fromFolder.year }
    }
    return result
}

/// Episodes of the same series in the same folder share the year when only some file names have it.
/// Movies are never touched: two films with the same title can be different films.
/// - Returns: the year for each item, in the same order
func harmonizeYears(_ items: [(folder: String, recognition: Recognition)]) -> [String?] {
    var yearsByKey: [String: Set<String>] = [:]
    let keys = items.map { item -> String? in
        guard item.recognition.isTV, !item.recognition.title.isEmpty else { return nil }
        return item.folder + "\u{1}" + normalizeTitle(item.recognition.title)
    }
    for (key, item) in zip(keys, items) {
        guard let key, let year = item.recognition.year else { continue }
        yearsByKey[key, default: []].insert(year)
    }
    return zip(keys, items).map { key, item in
        if let year = item.recognition.year { return year }
        guard let key, let years = yearsByKey[key], years.count == 1 else { return nil }
        return years.first
    }
}

/// "DragonBallZ" → "Dragon Ball Z". Used only as a second attempt when a search finds nothing:
/// applied always it would break titles like "MacGyver" or "iCarly".
func splitJoinedWords(_ text: String) -> String {
    var out = ""
    let chars = Array(text)
    for (i, c) in chars.enumerated() {
        if i > 0, c.isUppercase, chars[i - 1].isLowercase { out.append(" ") }
        out.append(c)
    }
    return out
}
