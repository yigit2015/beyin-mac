import Foundation

enum GraphBuilder {
    /// Notlardan grafiği kurar: wikilink'leri çözer, dereceleri, kümeleri ve özeti hesaplar.
    static func build(notes: [Note]) -> VaultGraph {
        var byKey: [String: [Note.ID]] = [:]
        for note in notes {
            byKey[Wikilinks.key(for: note.id), default: []].append(note.id)
        }
        // Aynı adlı birden çok not: Obsidian gibi en kısa yol kazanır.
        for key in byKey.keys {
            byKey[key]?.sort { $0.count != $1.count ? $0.count < $1.count : $0 < $1 }
        }

        var edgeSet = Set<Edge>()
        var undirected = Set<UndirectedPair>()
        var unresolved = 0
        for note in notes {
            let folder = (note.id as NSString).deletingLastPathComponent
            for link in note.outgoingLinks {
                guard let candidates = byKey[Wikilinks.key(for: link)] else {
                    unresolved += 1
                    continue
                }
                let target = candidates.first { ($0 as NSString).deletingLastPathComponent == folder } ?? candidates[0]
                guard target != note.id else { continue }
                edgeSet.insert(Edge(source: note.id, target: target))
                undirected.insert(UndirectedPair(note.id, target))
            }
        }

        // Not başına bağlantı = gelen + giden çözülmüş wikilink (tasarım: Veri kuralları).
        var degree: [Note.ID: Int] = [:]
        for edge in edgeSet {
            degree[edge.source, default: 0] += 1
            degree[edge.target, default: 0] += 1
        }

        var byCategory: [NoteCategory: Int] = [:]
        var groups: [String: (title: String, category: NoteCategory, ids: [Note.ID])] = [:]
        for note in notes {
            byCategory[note.category, default: 0] += 1
            let (id, title) = clusterID(for: note)
            groups[id, default: (title, note.category, [])].ids.append(note.id)
        }
        let clusters = groups
            .map { Cluster(id: $0.key, title: $0.value.title, category: $0.value.category, noteIDs: $0.value.ids.sorted()) }
            .sorted { $0.noteIDs.count != $1.noteIDs.count ? $0.noteIDs.count > $1.noteIDs.count : $0.id < $1.id }
        let bySubcluster = Dictionary(uniqueKeysWithValues: clusters
            .filter { $0.category == .project }
            .map { ($0.id, $0.noteIDs.count) })

        let top = degree
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(30)
            .map { RankedNote(id: $0.key, degree: $0.value) }

        let stats = VaultStats(
            noteCount: notes.count,
            linkCount: undirected.count,
            unresolvedLinkCount: unresolved,
            isolatedCount: notes.filter { degree[$0.id] == nil }.count,
            privateCount: notes.filter(\.isPrivate).count,
            byCategory: byCategory,
            bySubcluster: bySubcluster,
            topConnected: top)

        return VaultGraph(
            notes: Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) }),
            edges: edgeSet.sorted { ($0.source, $0.target) < ($1.source, $1.target) },
            degree: degree,
            clusters: clusters,
            stats: stats)
    }

    /// Küme kimliği ve başlığı: proje notları alt klasöre göre, diğerleri kategoriye göre.
    static func clusterID(for note: Note) -> (String, String) {
        if note.category == .project, let project = note.project {
            return (note.clusterID, note.subcluster.map(Note.subclusterTitle) ?? project)
        }
        return (note.clusterID, note.category.pluralTitle)
    }
}

private struct UndirectedPair: Hashable {
    let a: Note.ID
    let b: Note.ID

    init(_ x: Note.ID, _ y: Note.ID) {
        (a, b) = x < y ? (x, y) : (y, x)
    }
}
