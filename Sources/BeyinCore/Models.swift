import Foundation

// Ortak sözleşme: BeyinCore ile arayüz katmanı arasındaki tipler.
// Bu dosyayı claude1 yönetir; değişiklik gerekirse önce haber verilir.

/// Bir notun grafikteki türü. Yol ve frontmatter'daki `kind` alanından çıkarılır.
public enum NoteCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case core       // 🔮 850-Companion: Core, Kurallar, Journal, Last-Session, Threads
    case fact       // knowledge/ ya da kind: fact
    case person     // notes/kisiler/ ya da kind: person
    case task       // tasks/ ya da kind: task
    case daily      // daily/
    case chat       // projects/sohbet-arsivi/
    case project    // projects/<ad>/ altındaki diğer her şey

    public var id: String { rawValue }

    /// Tekil ad: rozet ve etiketlerde.
    public var title: String {
        switch self {
        case .core: "Çekirdek"
        case .fact: "Bilgi"
        case .person: "Kişi"
        case .task: "Görev"
        case .daily: "Günlük"
        case .chat: "Sohbet"
        case .project: "Proje"
        }
    }

    /// Çoğul ad: kategori kartlarında.
    public var pluralTitle: String {
        switch self {
        case .core: "Çekirdek"
        case .fact: "Bilgi"
        case .person: "Kişiler"
        case .task: "Görevler"
        case .daily: "Günlük"
        case .chat: "Sohbetler"
        case .project: "Projeler"
        }
    }
}

public enum Visibility: String, Codable, Sendable {
    case `internal`
    case `private`
}

/// Kasadaki tek bir Markdown notu. Uygulama notları yalnızca okur.
public struct Note: Identifiable, Hashable, Sendable {
    /// Kasa köküne göre yol, ör. "knowledge/haftalik-ozet.md".
    public let id: String
    public var title: String
    public var category: NoteCategory
    /// Frontmatter'daki `kind` (fact, person, task, note…), yoksa nil.
    public var kind: String?
    /// "eski-notlar", "sohbet-arsivi" gibi; projects/ dışındaysa nil (genel kasada üst klasör).
    public var project: String?
    /// Projenin ilk alt klasörü: "sohbetler", "masaustu", "vaultlar"…
    public var subcluster: String?
    public var visibility: Visibility
    /// Frontmatter tarihi (tarih/date/created), yoksa dosya oluşturma tarihi.
    public var created: Date?
    public var modified: Date
    public var wordCount: Int
    /// Ham wikilink hedefleri (`[[hedef|takma ad]]` → "hedef").
    public var outgoingLinks: [String]
    /// Gövdenin başı, Markdown satır yapısı korunarak (en çok ~12 satır / 600 karakter).
    /// Başlıklar "# " önekini korur, alıntı işaretleri (">") atılır; private notlarda boş.
    public var excerpt: String
    public var tags: [String]

    public init(id: String, title: String, category: NoteCategory, kind: String? = nil,
                project: String? = nil, subcluster: String? = nil, visibility: Visibility = .internal,
                created: Date? = nil, modified: Date, wordCount: Int = 0, outgoingLinks: [String] = [],
                excerpt: String = "", tags: [String] = []) {
        self.id = id
        self.title = title
        self.category = category
        self.kind = kind
        self.project = project
        self.subcluster = subcluster
        self.visibility = visibility
        self.created = created
        self.modified = modified
        self.wordCount = wordCount
        self.outgoingLinks = outgoingLinks
        self.excerpt = excerpt
        self.tags = tags
    }

    public var isPrivate: Bool { visibility == .private }

    /// Ait olduğu kümenin kimliği: proje notları alt klasöre göre, diğerleri kategoriye göre.
    public var clusterID: String {
        if category == .project, let project {
            return subcluster.map { "project:\(project)/\($0)" } ?? "project:\(project)"
        }
        return category.rawValue
    }

    /// "eski-notlar › Obsidian kasaları" gibi okunur yer.
    public var placeTitle: String {
        if category == .project, let project {
            return subcluster.map { "\(project) › \(Note.subclusterTitle($0))" } ?? project
        }
        return category.title
    }

    /// Klasör adlarının okunur karşılıkları.
    public static func subclusterTitle(_ folder: String) -> String {
        switch folder {
        case "sohbetler": "Sohbetler"
        case "masaustu": "Masaüstü"
        case "vaultlar": "Obsidian kasaları"
        case "indirilenler": "İndirilenler"
        case "claude": "Claude hafızası"
        case "icloud": "iCloud"
        default: folder
        }
    }
}

/// Çözülmüş bir wikilink: `source` notu `target` notuna bağlanır (yönlü).
public struct Edge: Hashable, Sendable {
    public let source: Note.ID
    public let target: Note.ID

    public init(source: Note.ID, target: Note.ID) {
        self.source = source
        self.target = target
    }
}

/// Grafikte birlikte çekilen not grubu: bir kategori ya da proje alt kümesi.
public struct Cluster: Identifiable, Hashable, Sendable {
    /// "core", "fact", "project:eski-notlar/sohbetler", "chat" gibi.
    public let id: String
    public var title: String
    public var category: NoteCategory
    public var noteIDs: [Note.ID]

    public init(id: String, title: String, category: NoteCategory, noteIDs: [Note.ID]) {
        self.id = id
        self.title = title
        self.category = category
        self.noteIDs = noteIDs
    }
}

public struct RankedNote: Hashable, Sendable {
    public let id: Note.ID
    public let degree: Int

    public init(id: Note.ID, degree: Int) {
        self.id = id
        self.degree = degree
    }
}

public struct VaultStats: Equatable, Sendable {
    public var noteCount: Int
    /// Benzersiz, yönsüz bağlantı sayısı (A→B ve B→A tek sayılır).
    public var linkCount: Int
    /// Hiçbir nota çözülemeyen wikilink sayısı.
    public var unresolvedLinkCount: Int
    /// Hiç bağlantısı olmayan not sayısı.
    public var isolatedCount: Int
    public var privateCount: Int
    public var byCategory: [NoteCategory: Int]
    /// Cluster.id → not sayısı (yalnız proje alt kümeleri).
    public var bySubcluster: [String: Int]
    /// Bağlantı sayısına göre azalan, en fazla 30 not.
    public var topConnected: [RankedNote]

    public init(noteCount: Int = 0, linkCount: Int = 0, unresolvedLinkCount: Int = 0, isolatedCount: Int = 0,
                privateCount: Int = 0, byCategory: [NoteCategory: Int] = [:], bySubcluster: [String: Int] = [:],
                topConnected: [RankedNote] = []) {
        self.noteCount = noteCount
        self.linkCount = linkCount
        self.unresolvedLinkCount = unresolvedLinkCount
        self.isolatedCount = isolatedCount
        self.privateCount = privateCount
        self.byCategory = byCategory
        self.bySubcluster = bySubcluster
        self.topConnected = topConnected
    }

    public func count(_ category: NoteCategory) -> Int { byCategory[category] ?? 0 }
}

/// Kasanın tamamı: notlar, bağlantılar, kümeler ve özet.
public struct VaultGraph: Sendable {
    public var notes: [Note.ID: Note]
    public var edges: [Edge]
    /// Not başına bağlantı: gelen + giden çözülmüş wikilink.
    public var degree: [Note.ID: Int]
    public var clusters: [Cluster]
    public var stats: VaultStats

    public init(notes: [Note.ID: Note] = [:], edges: [Edge] = [], degree: [Note.ID: Int] = [:],
                clusters: [Cluster] = [], stats: VaultStats = VaultStats()) {
        self.notes = notes
        self.edges = edges
        self.degree = degree
        self.clusters = clusters
        self.stats = stats
    }

    public static let empty = VaultGraph()

    public func note(_ id: Note.ID) -> Note? { notes[id] }

    public func degree(of id: Note.ID) -> Int { degree[id] ?? 0 }

    /// Bu nota bağlanan notlar (gelen).
    public func incoming(to id: Note.ID) -> [Note.ID] {
        edges.filter { $0.target == id }.map(\.source)
    }

    /// Bu notun bağlandığı notlar (giden).
    public func outgoing(from id: Note.ID) -> [Note.ID] {
        edges.filter { $0.source == id }.map(\.target)
    }

    public func neighbors(of id: Note.ID) -> Set<Note.ID> {
        Set(incoming(to: id)).union(outgoing(from: id))
    }

    /// Kategorideki notlar, bağlantı sayısına göre azalan, sonra en yeni.
    public func notes(in category: NoteCategory) -> [Note] {
        notes.values
            .filter { $0.category == category }
            .sorted { lhs, rhs in
                let (dl, dr) = (degree(of: lhs.id), degree(of: rhs.id))
                return dl != dr ? dl > dr : lhs.modified > rhs.modified
            }
    }

    /// En son değişen notlar.
    public func recent(_ category: NoteCategory? = nil, limit: Int = 10) -> [Note] {
        notes.values
            .filter { category == nil || $0.category == category }
            .sorted { $0.modified > $1.modified }
            .prefix(limit)
            .map { $0 }
    }
}

public struct SearchHit: Identifiable, Hashable, Sendable {
    public let id: Note.ID
    public let score: Double
    /// Eşleşmenin geçtiği kısa metin parçası.
    public let snippet: String

    public init(id: Note.ID, score: Double, snippet: String) {
        self.id = id
        self.score = score
        self.snippet = snippet
    }
}

public enum ViewMode: String, CaseIterable, Identifiable, Sendable {
    case odak, ag, kure, genelBakis

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .odak: "Odak"
        case .ag: "Ağ"
        case .kure: "Küre"
        case .genelBakis: "Genel bakış"
        }
    }

    /// ⌘1…⌘4
    public var shortcutDigit: Character {
        switch self {
        case .odak: "1"
        case .ag: "2"
        case .kure: "3"
        case .genelBakis: "4"
        }
    }
}

public enum DateRangeFilter: String, CaseIterable, Identifiable, Sendable {
    case all, last7, last30, last90

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all: "Tümü"
        case .last7: "Son 7 gün"
        case .last30: "Son 30 gün"
        case .last90: "Son 90 gün"
        }
    }

    var days: Int? {
        switch self {
        case .all: nil
        case .last7: 7
        case .last30: 30
        case .last90: 90
        }
    }
}

public struct GraphFilters: Equatable, Sendable {
    public var categories: Set<NoteCategory> = Set(NoteCategory.allCases)
    /// nil = tüm projeler.
    public var project: String?
    public var dateRange: DateRangeFilter = .all
    public var hidePrivate = false
    public var showIsolated = true

    public init() {}
}

public enum LoadPhase: String, Sendable {
    case scanning, resolving, layout

    public var title: String {
        switch self {
        case .scanning: "Dosyalar taranıyor"
        case .resolving: "Wikilink'ler çözülüyor"
        case .layout: "Düzen hesaplanıyor"
        }
    }
}

/// Yükleme sırasında gösterilecek sayaçlar ("212 / 380 not · 118 bağlantı çözüldü").
public struct LoadingCounts: Equatable, Sendable {
    public var scanned: Int
    public var total: Int
    public var resolvedLinks: Int?

    public init(scanned: Int, total: Int, resolvedLinks: Int? = nil) {
        self.scanned = scanned
        self.total = total
        self.resolvedLinks = resolvedLinks
    }
}

public enum LoadState: Equatable, Sendable {
    case idle
    /// progress 0…1
    case loading(progress: Double, phase: LoadPhase)
    case loaded
    /// Klasör var ama hiç not yok.
    case empty
    /// Kayıtlı klasör yerinde değil.
    case notFound(URL)
}
