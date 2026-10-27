import BeyinCore
import Observation
import SwiftUI

/// Kabuğun yalnız arayüze ait durumu (kasa verisi VaultStore'da kalır).
/// Ortama `.environment(shell)` ile konur. Tuvalin tepki verdiği değerler (zoom, relayout, Beyne sor vurgusu)
/// sözleşme gereği VaultStore'da durur: `store.zoom`, `store.relayout()`, `store.highlighted`.
@Observable
@MainActor
final class ShellState {
    // Paneller
    var sidebarVisible = true
    var inspectorVisible = true
    var isPaletteOpen = false
    /// Araç çubuğundaki filtre açılır paneli; Esc önce bunu kapatır.
    var isFilterPopoverOpen = false

    /// Kenar çubuğundaki "Notlarda ara" (⌘F).
    var searchQuery = ""

    /// "Beyne sor" oturumu; doluyken inceleme paneli C halindedir.
    var ask: AskSession?
    var inspectorPage: InspectorPage = .note
    /// Beyne sor gönderildiğinde orb tek nabız atar.
    var askPulse = 0
    /// C halinde ↑↓ ile gezilen sonuç satırı.
    var askCursor = 0

    /// Yüzen inceleme panelinin tuvali sağdan örttüğü genişlik (pt): pencere 1180 pt'den darken panel tuvalin
    /// üstünde yüzer; değer = panel genişliği + 16 pt boşluk. Panel yerleşikken (geniş pencere) ya da kapalıyken 0.
    /// MainLayout Motion.panel ile animasyonlu yazar; graf görünümleri tuvali bu kadar daraltır.
    var canvasTrailingOcclusion: CGFloat = 0

    /// Genel bakış dönem menüsü.
    var overviewRange: DateRangeFilter = .last90

    /// Klavye odağı istekleri (⌘F, ⌘L, ⌘K); `token` her istekte değişir.
    private(set) var focusRequest = FocusRequest(target: .none, token: 0)

    func requestFocus(_ target: FocusTarget) {
        focusRequest = FocusRequest(target: target, token: focusRequest.token + 1)
    }

    /// Esc sırası (Hareket · 06): paleti kapat → aramayı temizle → odaktan çık.
    /// Açık panel yoksa seçimi kaldırır. Yapacak bir şey kalmadıysa `false` döner (Esc sisteme geçer).
    @discardableResult
    func escape(store: VaultStore) -> Bool {
        if isFilterPopoverOpen {
            isFilterPopoverOpen = false
        } else if isPaletteOpen {
            isPaletteOpen = false
        } else if ask != nil {
            clearAsk(in: store)
        } else if !searchQuery.isEmpty {
            searchQuery = ""
        } else if store.selection != nil {
            store.selection = nil
        } else {
            return false
        }
        return true
    }

    func runAsk(_ query: String, scope: AskScope, store: VaultStore) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let hits = store.search(trimmed, limit: 40).filter { hit in
            guard let note = store.graph.note(hit.id) else { return false }
            return scope.contains(note)
        }
        ask = AskSession(query: trimmed, scope: scope, hits: Array(hits.prefix(20)))
        store.highlighted = Set(ask?.matchedIDs ?? [])
        askCursor = 0
        inspectorPage = .results
        inspectorVisible = true
        askPulse += 1
    }

    func clearAsk(in store: VaultStore) {
        ask = nil
        store.highlighted = []
        askCursor = 0
        inspectorPage = .note
    }

    /// C halinde süzgeçten geçen sonuçlar.
    func visibleHits(in store: VaultStore) -> [SearchHit] {
        guard let ask else { return [] }
        guard let category = ask.categoryFilter else { return ask.hits }
        return ask.hits.filter { store.graph.note($0.id)?.category == category }
    }

    func moveAskCursor(by delta: Int, store: VaultStore) {
        let count = visibleHits(in: store).count
        guard count > 0 else { return }
        askCursor = min(max(askCursor + delta, 0), count - 1)
    }

    /// İnceleme panelinden ya da listelerden bir not seçildi.
    func show(_ id: Note.ID, in store: VaultStore) {
        store.selection = id
        inspectorPage = .note
        inspectorVisible = true
    }
}

enum InspectorPage: Equatable {
    case note
    case results
}

enum FocusTarget: Equatable {
    case none, search, ask, palette
}

struct FocusRequest: Equatable {
    let target: FocusTarget
    let token: Int
}

/// "Beyne sor" kapsamı: tüm kasa, bir proje ya da bir tür.
enum AskScope: Hashable {
    case all
    case project(String)
    case category(NoteCategory)

    var title: String {
        switch self {
        case .all: "Tüm kasa"
        case .project(let name): name
        case .category(let category): category.pluralTitle
        }
    }

    func contains(_ note: Note) -> Bool {
        switch self {
        case .all: true
        case .project(let name): note.project == name
        case .category(let category): note.category == category
        }
    }
}

struct AskSession: Equatable {
    let query: String
    let scope: AskScope
    let hits: [SearchHit]
    /// C halindeki tür süzgeci (nil = Tümü).
    var categoryFilter: NoteCategory?

    init(query: String, scope: AskScope, hits: [SearchHit], categoryFilter: NoteCategory? = nil) {
        self.query = query
        self.scope = scope
        self.hits = hits
        self.categoryFilter = categoryFilter
    }

    /// Grafikte parlaması gereken notlar, alaka sırasıyla.
    var matchedIDs: [Note.ID] { hits.map(\.id) }
}
