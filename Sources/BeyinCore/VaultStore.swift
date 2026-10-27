import AppKit
import Foundation
import Observation

/// Arayüzün tek veri kaynağı. Kasayı okur, izler, filtreler; asla yazmaz.
@Observable
@MainActor
public final class VaultStore {
    public private(set) var state: LoadState = .idle
    public private(set) var graph: VaultGraph = .empty
    public private(set) var vaultURL: URL
    public private(set) var lastSync: Date?
    /// Ağ görünümü yerleşimi (yükleme sırasında arka planda hesaplanır).
    public private(set) var network: NetworkLayout = .empty
    /// Küre görünümü yerleşimi.
    public private(set) var sphere: SphereLayout = .empty
    /// Araç çubuğundaki yakınlaştırma; graf görünümleri uygular. 0.25…4
    public var zoom: Double = 1 {
        didSet { if zoom < 0.25 || zoom > 4 { zoom = min(max(zoom, 0.25), 4) } }
    }

    /// İnceleme panelinde gösterilen not.
    public var selection: Note.ID?
    /// Odak görünümünde açık kategori.
    public var focusedCategory: NoteCategory = .chat
    /// Odak görünümünde seçili küme (Cluster.id). nil → en büyük küme.
    /// Bir küme seçili ve `selection` boşken inceleme paneli küme özetini / tam listeyi gösterir.
    public var focusedCluster: String?

    /// Odakta gösterilen küme: seçili olan; yoksa en çok bağlantısı olan (eşitlikte en büyük).
    public var activeCluster: Cluster? {
        let candidates = graph.clusters.filter { $0.category != .core }
        if let id = focusedCluster, let match = candidates.first(where: { $0.id == id }) { return match }
        func links(_ cluster: Cluster) -> Int { cluster.noteIDs.reduce(0) { $0 + graph.degree(of: $1) } }
        return candidates.max { (links($0), $0.noteIDs.count) < (links($1), $1.noteIDs.count) }
    }

    /// Küme notları: bağlantı sayısına göre azalan, eşitlikte son güncellenen önce (Kurallar · 6).
    public func rankedNotes(in cluster: Cluster) -> [Note] {
        cluster.noteIDs.compactMap { graph.note($0) }
            .filter { visibleNoteIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let (dl, dr) = (graph.degree(of: lhs.id), graph.degree(of: rhs.id))
                return dl != dr ? dl > dr : lhs.modified > rhs.modified
            }
    }
    public var mode: ViewMode = .odak
    public var filters = GraphFilters()
    /// "Beyne sor" sonuçları: graf görünümlerinde parlar. Boşsa vurgu yok.
    public var highlighted: Set<Note.ID> = []

    /// Yükleme sırasında sayaçlar; yükleme bitince nil.
    public private(set) var loadingCounts: LoadingCounts?
    /// "Dosya değişince otomatik yeniden oku" (Ayarlar). Kapatınca izleme durur; ⌘R yine çalışır.
    public var watchesChanges = true {
        didSet {
            guard watchesChanges != oldValue else { return }
            if watchesChanges { startWatching() } else { watcher = nil }
        }
    }

    @ObservationIgnored private var watcher: VaultWatcher?
    @ObservationIgnored private var index: SearchIndex = .empty
    @ObservationIgnored private var layoutSeed: UInt64 = 1
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    public init(vaultURL: URL = VaultStore.defaultVaultURL) {
        self.vaultURL = vaultURL
        // Geliştirme ve ekran görüntüsü doğrulaması: BEYIN_MODE=odak|ag|kure|genelBakis
        if let raw = ProcessInfo.processInfo.environment["BEYIN_MODE"], let mode = ViewMode(rawValue: raw) { self.mode = mode }
    }

    /// `BEYIN_VAULT` ortam değişkeni, yoksa ~/Beyin.
    public nonisolated static var defaultVaultURL: URL {
        if let path = ProcessInfo.processInfo.environment["BEYIN_VAULT"], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Beyin", isDirectory: true)
    }

    // MARK: Yükleme

    /// İlk yükleme: tarar, grafiği kurar, klasörü izlemeye başlar.
    public func load() async {
        await rebuild(showProgress: true)
        startWatching()
    }

    /// ⌘R: baştan oku.
    public func reload() async {
        await rebuild(showProgress: true)
    }

    /// Ayarlar'dan başka kasa seçildiğinde.
    public func changeVault(to url: URL) async {
        watcher = nil
        vaultURL = url
        selection = nil
        await load()
    }

    private func rebuild(showProgress: Bool) async {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: vaultURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            graph = .empty
            state = .notFound(vaultURL)
            return
        }
        if showProgress { state = .loading(progress: 0, phase: .scanning) }
        let url = vaultURL
        let loaded = await VaultLoader.load(vaultURL: url) { [weak self] progress, phase, counts in
            Task { @MainActor in
                guard let self, showProgress, case .loading = self.state else { return }
                self.state = .loading(progress: progress, phase: phase)
                self.loadingCounts = counts
            }
        }
        loadingCounts = nil
        graph = loaded.graph
        index = loaded.index
        network = loaded.network
        sphere = loaded.sphere
        lastSync = Date()
        if let selection, loaded.graph.notes[selection] == nil { self.selection = nil }
        state = loaded.graph.notes.isEmpty ? .empty : .loaded
    }

    private func startWatching() {
        guard watcher == nil, watchesChanges else { return }
        watcher = VaultWatcher(url: vaultURL) { [weak self] in
            Task { @MainActor in await self?.rebuild(showProgress: false) }
        }
    }

    // MARK: Görünüm denetimleri

    public func zoomIn() { zoom = (zoom * 1.25 * 100).rounded() / 100 }
    public func zoomOut() { zoom = (zoom / 1.25 * 100).rounded() / 100 }
    public func resetZoom() { zoom = 1 }

    /// "Düzeni yeniden hesapla": Ağ yerleşimini yeni bir tohumla kurar.
    public func relayout() {
        layoutSeed &+= 1
        let graph = self.graph, seed = layoutSeed
        Task.detached(priority: .userInitiated) {
            let layout = NetworkLayout.compute(graph, seed: seed)
            await MainActor.run { self.network = layout }
        }
    }

    // MARK: Filtre ve arama

    /// Filtrelerden geçen notlar.
    public var visibleNoteIDs: Set<Note.ID> {
        let cutoff = filters.dateRange.days.map { Calendar.current.date(byAdding: .day, value: -$0, to: Date()) ?? .distantPast }
        return Set(graph.notes.values.lazy.filter { note in
            guard self.filters.categories.contains(note.category) else { return false }
            if let project = self.filters.project, note.project != project { return false }
            if self.filters.hidePrivate, note.isPrivate { return false }
            if !self.filters.showIsolated, self.graph.degree(of: note.id) == 0 { return false }
            if let cutoff, note.modified < cutoff { return false }
            return true
        }.map(\.id))
    }

    /// Tüm projelerin adları (filtre menüsü için).
    public var projects: [String] {
        Array(Set(graph.notes.values.compactMap(\.project))).sorted()
    }

    /// "Beyne sor": yerel tam metin arama, alakaya göre azalan.
    public func search(_ query: String, limit: Int = 20) -> [SearchHit] {
        index.search(query, in: graph, includePrivate: !filters.hidePrivate, limit: limit)
    }

    // MARK: Dış eylemler

    /// Notu Obsidian'da açar. Kasa adı klasör adıdır ("Beyin").
    public func openInObsidian(_ id: Note.ID) {
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: vaultURL.lastPathComponent),
            URLQueryItem(name: "file", value: id),
        ]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }

    /// Kasa klasörünü Finder'da gösterir.
    public func revealVaultInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([vaultURL])
    }
}

// MARK: - Önizleme verisi

extension VaultStore {
    /// Arayüz geliştirmek için sahte ama gerçek kasanın şeklini taşıyan veri.
    /// Kişi, Görev ve Günlük bilerek boş: boş durumlar da tasarlanmalı.
    public static var preview: VaultStore {
        let store = VaultStore(vaultURL: previewVaultURL)
        store.graph = PreviewData.graph()
        store.index = SearchIndex(graph: store.graph)
        store.network = NetworkLayout.compute(store.graph)
        store.sphere = SphereLayout.compute(store.graph)
        store.state = .loaded
        store.lastSync = Date()
        store.selection = "projects/sohbet-arsivi/2026-10/2026-10-26 Haftalık plan.md"
        return store
    }

    /// Belirli bir durumdaki önizleme (boş, yükleniyor, bulunamadı).
    public static func preview(state: LoadState) -> VaultStore {
        let store = VaultStore(vaultURL: previewVaultURL)
        store.state = state
        return store
    }

    private static var previewVaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Beyin", isDirectory: true)
    }
}

/// Uydurma örnek kasa: gerçek bir kişiye ait değil.
enum PreviewData {
    static func graph() -> VaultGraph {
        let now = Date()
        func day(_ n: Int) -> Date { now.addingTimeInterval(Double(-n) * 86_400) }
        var notes: [Note] = []
        func add(_ id: String, _ title: String, _ category: NoteCategory, project: String? = nil, sub: String? = nil,
                 kind: String? = nil, age: Int = 0, words: Int = 300, links: [String] = [], excerpt: String = "",
                 visibility: Visibility = .internal) {
            notes.append(Note(id: id, title: title, category: category, kind: kind, project: project, subcluster: sub,
                              visibility: visibility, created: day(age), modified: day(age), wordCount: words,
                              outgoingLinks: links, excerpt: excerpt))
        }
        let c = "🔮 850-Companion/"
        add(c + "Core.md", "Core", .core, words: 180, excerpt: "Kullanıcının düşünme ortağı ve ikinci beyniyim.")
        add(c + "Kurallar.md", "Kurallar", .core, age: 1, words: 120)
        add(c + "Last-Session.md", "Last-Session", .core, words: 240)
        add(c + "Threads.md", "Threads", .core, words: 90)
        add(c + "Journal.md", "Journal", .core, age: 1, words: 40)
        add("knowledge/okuma-ozeti.md", "Bu yıl okuduklarım", .fact, project: "eski-notlar",
            kind: "fact", words: 410, links: ["Core"], excerpt: "Atomik Alışkanlıklar, Derin Çalışma, Sapiens…")
        add("projects/sohbet-arsivi/2026-10/2026-10-26 Haftalık plan.md", "Haftalık plan", .chat, project: "sohbet-arsivi",
            sub: "2026-10", words: 1284, links: ["Core", "Last-Session"],
            excerpt: "Haftanın hedefleri çıkarıldı, okuma listesi güncellendi, uygulama fikri not edildi.")
        let e = "projects/eski-notlar/"
        let hubs = ["00-Indeks", "Genel", "Okuma listesi", "Proje panosu", "Mobil uygulama fikri", "Bütçe takibi",
                    "Yazılım öğrenme yolu", "Obsidian düzeni", "Ev tadilatı", "Sesli asistan denemeleri",
                    "Haftalık rutin", "Tarif defteri"]
        for (i, hub) in hubs.enumerated() {
            let others = hubs.enumerated().filter { $0.offset != i && ($0.offset + i) % 3 == 0 }.map(\.element)
            add(e + "vaultlar/eski-kasa/\(hub).md", hub, .project, project: "eski-notlar", sub: "vaultlar",
                age: 3 + i, words: 200 + i * 40, links: others + (i < 3 ? ["Genel", "00-Indeks"] : []))
        }
        let groups: [(String, Int, [String])] = [
            ("sohbetler", 20, ["Logo fikirleri", "Swift öğrenme planı", "Tatil rotası", "Laptop karşılaştırması",
                               "Kitap kulübü listesi", "Sunum taslağı", "Bahçe sulama sistemi", "Kısa film senaryosu",
                               "Mobil uygulama fikri", "Spor programı"]),
            ("masaustu", 12, ["Toplantı notları", "Klavye kısayolları", "Alışveriş listesi"]),
            ("indirilenler", 8, ["README", "Kurulum rehberi"]),
            ("claude", 6, ["oturum-protokolu", "proje-hafizasi", "skill-notlari"]),
            ("icloud", 2, ["Okuma listesi"]),
        ]
        for (sub, count, titles) in groups {
            for k in 0..<count {
                let title = k < titles.count ? titles[k] : "\(sub) notu \(k + 1)"
                let links = k % 4 == 0 ? [hubs[k % hubs.count]] : []
                add(e + "\(sub)/\(title).md", title, .project, project: "eski-notlar", sub: sub, age: 4 + k, words: 150 + k * 25,
                    links: links)
            }
        }
        return GraphBuilder.build(notes: notes)
    }
}
