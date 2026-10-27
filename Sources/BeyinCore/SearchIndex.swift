import Foundation

/// "Beyne sor" için yerel tam metin arama. Ağ ya da model çağrısı yok.
public struct SearchIndex: Sendable {
    private struct Entry: Sendable {
        let id: Note.ID
        let title: String
        let body: String
        let isPrivate: Bool
    }

    private let entries: [Entry]

    public static let empty = SearchIndex(entries: [])

    private init(entries: [Entry]) {
        self.entries = entries
    }

    init(graph: VaultGraph, bodies: [Note.ID: String]) {
        entries = graph.notes.values.map { note in
            Entry(id: note.id,
                  title: Self.fold(note.title),
                  body: Self.fold(bodies[note.id] ?? note.excerpt),
                  isPrivate: note.isPrivate)
        }
    }

    /// Önizleme: gövde yerine özetlerle.
    init(graph: VaultGraph) {
        self.init(graph: graph, bodies: [:])
    }

    /// Her sorgu kelimesi için: başlıkta geçerse 5, gövdede her geçiş 1 (en çok 5). Tüm kelimeler bulunmalı.
    public func search(_ query: String, in graph: VaultGraph, includePrivate: Bool, limit: Int) -> [SearchHit] {
        let terms = Self.fold(query)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count >= 2 }
        guard !terms.isEmpty else { return [] }
        var hits: [SearchHit] = []
        for entry in entries where includePrivate || !entry.isPrivate {
            var score = 0.0
            var matchedAll = true
            for term in terms {
                let inTitle = entry.title.contains(term)
                let inBody = min(entry.body.occurrences(of: term), 5)
                if !inTitle && inBody == 0 {
                    matchedAll = false
                    break
                }
                score += (inTitle ? 5 : 0) + Double(inBody)
            }
            guard matchedAll else { continue }
            score += Double(graph.degree(of: entry.id)) * 0.1
            hits.append(SearchHit(id: entry.id, score: score, snippet: snippet(entry, term: terms[0], graph: graph)))
        }
        return Array(hits.sorted { $0.score != $1.score ? $0.score > $1.score : $0.id < $1.id }.prefix(limit))
    }

    /// Eşleşmenin çevresinden ~140 karakter, orijinal harflerle (özet üzerinden).
    private func snippet(_ entry: Entry, term: String, graph: VaultGraph) -> String {
        guard let note = graph.note(entry.id), !note.isPrivate else { return "" }
        let source = VaultLoader.plain(note.excerpt)
        let folded = Self.fold(source)
        guard let range = folded.range(of: term) else { return String(source.prefix(140)) }
        let offset = folded.distance(from: folded.startIndex, to: range.lowerBound)
        let start = max(0, offset - 50)
        let chars = Array(source)
        let end = min(chars.count, start + 140)
        guard start < end else { return String(source.prefix(140)) }
        return (start > 0 ? "…" : "") + String(chars[start..<end]) + (end < chars.count ? "…" : "")
    }

    /// Küçük harf, Türkçe uyumlu, aksansız karşılaştırma.
    static func fold(_ text: String) -> String {
        text.lowercased(with: Locale(identifier: "tr_TR"))
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
    }
}

private extension String {
    func occurrences(of needle: String) -> Int {
        var count = 0
        var searchRange = startIndex..<endIndex
        while let found = range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<endIndex
        }
        return count
    }
}
