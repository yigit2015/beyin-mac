import BeyinCore
import SwiftUI

/// ⌘K komut paleti (Durumlar · 5): not arama + görünümler + eylemler.
/// 440 genişlik, köşe 18, iç 8; giriş 42 yükseklik 15 pt; satır 32, seçili mor %20 + iç kenar %30; eşleşme altın %22.
/// Klavye: ↑↓ satır, ↵ uygula, ⌘↵ Obsidian'da aç, Esc kapat.
struct CommandPalette: View {
    let store: VaultStore
    let shell: ShellState

    @Environment(\.palette) private var palette
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isFocused: Bool
    @State private var query = ""
    @State private var cursor = 0

    var body: some View {
        let sections = makeSections()
        let items = sections.flatMap(\.items)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.violet2)
                    .accessibilityHidden(true)
                TextField("Not, görünüm ya da eylem ara", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.t1)
                    .focused($isFocused)
                    .onSubmit { perform(items, at: cursor) }
                    .onKeyPress(.upArrow) { move(-1, count: items.count) }
                    .onKeyPress(.downArrow) { move(1, count: items.count) }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.command), items.indices.contains(cursor),
                              case .note(let note) = items[cursor].kind else { return .ignored }
                        store.openInObsidian(note.id)
                        close()
                        return .handled
                    }
                    .accessibilityLabel("Komut paleti araması")
                KeyCap("Esc")
            }
            .padding(.horizontal, 10)
            .frame(height: 42)
            .overlay(alignment: .bottom) { Rectangle().fill(palette.hair).frame(height: 1) }
            .padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if items.isEmpty {
                            EmptyHint(text: "“\(query)” için sonuç yok", symbol: "magnifyingglass")
                                .padding(.vertical, 8)
                        }
                        ForEach(sections) { section in
                            SectionLabel(section.title)
                                .padding(.horizontal, 10)
                                .padding(.top, section.id == sections.first?.id ? 4 : 8)
                                .padding(.bottom, 4)
                            ForEach(section.items) { item in
                                let index = items.firstIndex(where: { $0.id == item.id }) ?? 0
                                row(item, isSelected: index == cursor) { perform(items, at: index) }
                                    .id(item.id)
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(maxHeight: 420)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: cursor) { _, newValue in
                    guard items.indices.contains(newValue) else { return }
                    proxy.scrollTo(items[newValue].id, anchor: nil)
                }
            }
        }
        .padding(8)
        .frame(width: 440)
        .panelGlass(cornerRadius: 18)
        .onAppear { isFocused = true }
        .onChange(of: query) { _, _ in cursor = 0 }
        .onChange(of: shell.focusRequest) { _, request in
            if request.target == .palette { isFocused = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Komut paleti")
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Satır

    private func row(_ item: PaletteItem, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                switch item.kind {
                case .note(let note):
                    Dot(color: note.category.color(palette)).opacity(note.isPrivate ? 0.4 : 1)
                default:
                    Image(systemName: item.symbol)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.t2)
                        .frame(width: 16)
                }
                Text(Highlight.attributed(item.title, matching: query, palette: palette))
                    .foregroundStyle(isSelected ? palette.t1 : palette.t2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let detail = item.detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(palette.t3).lineLimit(1)
                }
                if let shortcut = item.shortcut {
                    KeyCap(shortcut)
                } else if isSelected {
                    KeyCap("↵")
                }
            }
            .font(BeyinFont.callout)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(isSelected ? palette.violetFill : .clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(palette.violet2.opacity(0.3), lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.detail ?? "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Klavye

    private func move(_ delta: Int, count: Int) -> KeyPress.Result {
        guard count > 0 else { return .handled }
        cursor = (cursor + delta + count) % count
        return .handled
    }

    private func close() {
        withAnimation(Motion.paletteOut) { shell.isPaletteOpen = false }
    }

    private func perform(_ items: [PaletteItem], at index: Int) {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        close()
        let animation = Motion.resolve(Motion.view, reduce: reduceMotion)
        switch item.kind {
        case .note(let note):
            withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) {
                store.focusedCategory = note.category
                shell.show(note.id, in: store)
                if store.mode == .genelBakis { store.mode = .odak }
            }
        case .view(let mode):
            withAnimation(animation) { store.mode = mode }
        case .reload:
            Task { await store.reload() }
        case .settings:
            openSettings()
        case .reveal:
            store.revealVaultInFinder()
        case .openSelected:
            if let id = store.selection { store.openInObsidian(id) }
        case .toggleIsolated:
            store.filters.showIsolated.toggle()
        case .togglePrivate:
            store.filters.hidePrivate.toggle()
        case .toggleSidebar:
            withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.sidebarVisible.toggle() }
        case .ask:
            shell.requestFocus(.ask)
        }
    }

    // MARK: İçerik

    private func makeSections() -> [PaletteSection] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        func matches(_ text: String) -> Bool {
            trimmed.isEmpty || text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive], locale: BeyinFormat.locale) != nil
        }

        let notes: [Note] = trimmed.isEmpty
            ? store.graph.recent(limit: 5)
            : store.search(trimmed, limit: 6).compactMap { store.graph.note($0.id) }
        let noteItems = notes.map { note in
            PaletteItem(id: "note:\(note.id)", kind: .note(note), title: note.title, symbol: note.category.symbol,
                        detail: note.category == .chat || note.category == .daily
                            ? "\(note.category.title) · \(BeyinFormat.dayMonth(note.modified))" : note.category.title,
                        shortcut: nil)
        }

        let viewItems = ViewMode.allCases.map { mode in
            PaletteItem(id: "view:\(mode.rawValue)", kind: .view(mode),
                        title: mode == .genelBakis ? "Genel bakışı göster" : "\(mode.title) görünümüne geç",
                        symbol: mode.symbol, detail: nil, shortcut: "⌘\(mode.shortcutDigit)")
        }
        .filter { matches($0.title) }

        var actions: [PaletteItem] = [
            PaletteItem(id: "act:ask", kind: .ask, title: "Beyne sor", symbol: "sparkle", detail: nil, shortcut: "⌘L"),
            PaletteItem(id: "act:reload", kind: .reload, title: "Kasayı yeniden oku", symbol: "arrow.clockwise", detail: nil, shortcut: "⌘R"),
            PaletteItem(id: "act:settings", kind: .settings, title: "Kasa klasörünü değiştir…", symbol: "folder", detail: nil, shortcut: "⌘,"),
            PaletteItem(id: "act:reveal", kind: .reveal, title: "Kasayı Finder’da göster", symbol: "macwindow", detail: nil, shortcut: nil),
            PaletteItem(id: "act:isolated", kind: .toggleIsolated,
                        title: store.filters.showIsolated ? "Bağlantısızları gizle" : "Bağlantısızları göster",
                        symbol: "circle.dashed", detail: nil, shortcut: nil),
            PaletteItem(id: "act:private", kind: .togglePrivate,
                        title: store.filters.hidePrivate ? "Private notları göster" : "Private notları gizle",
                        symbol: "lock", detail: nil, shortcut: nil),
            PaletteItem(id: "act:sidebar", kind: .toggleSidebar,
                        title: shell.sidebarVisible ? "Kenar çubuğunu gizle" : "Kenar çubuğunu göster",
                        symbol: "sidebar.left", detail: nil, shortcut: "⌃⌘S"),
        ]
        if let id = store.selection, let note = store.graph.note(id) {
            actions.insert(PaletteItem(id: "act:open", kind: .openSelected, title: "“\(note.title)” notunu Obsidian’da aç",
                                       symbol: "arrow.up.right.square", detail: nil, shortcut: "⌘O"), at: 0)
        }
        actions = actions.filter { matches($0.title) }

        return [
            PaletteSection(id: "notes", title: trimmed.isEmpty ? "Son notlar" : "Notlar", items: noteItems),
            PaletteSection(id: "views", title: "Görünümler", items: viewItems),
            PaletteSection(id: "actions", title: "Eylemler", items: actions),
        ]
        .filter { !$0.items.isEmpty }
    }
}

private struct PaletteSection: Identifiable {
    let id: String
    let title: String
    let items: [PaletteItem]
}

private struct PaletteItem: Identifiable {
    enum Kind {
        case note(Note)
        case view(ViewMode)
        case reload, settings, reveal, openSelected, toggleIsolated, togglePrivate, toggleSidebar, ask
    }

    let id: String
    let kind: Kind
    let title: String
    let symbol: String
    let detail: String?
    let shortcut: String?
}
