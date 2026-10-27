import BeyinCore
import SwiftUI

/// Sol cam kenar çubuğu (Main.dc.html · KENAR ÇUBUĞU).
struct SidebarView: View {
    let store: VaultStore
    let shell: ShellState

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            searchField
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if shell.searchQuery.isEmpty {
                        viewsSection
                        FilterControls(store: store)
                        legend
                        recentChats
                    } else {
                        searchResults
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.never)
            .frame(maxHeight: .infinity, alignment: .top)
            .mask {
                // Kısa pencerede kayan içerik alt kenarda yumuşakça söner.
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: 14)
                }
            }
            footer
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .panelGlass(cornerRadius: 24)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kenar çubuğu")
        .onChange(of: shell.focusRequest) { _, request in
            if request.target == .search { searchFocused = true }
        }
    }

    // MARK: Başlık

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Trafik ışıkları bu satırda durur (gizli başlık çubuğu).
            HStack {
                Spacer()
                Button {
                    withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.sidebarVisible = false }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(IconButtonStyle(diameter: 26))
                .accessibilityLabel("Kenar çubuğunu gizle")
                .help("Kenar çubuğunu gizle (⌃⌘S)")
            }
            .frame(height: 24)

            HStack(spacing: 10) {
                OrbView(size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    GradientTitle(text: "Beyin", font: BeyinFont.brand, tracking: -0.17)
                    Text("İkinci Beyin · salt okunur")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.t3)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(palette.t3)
                .accessibilityHidden(true)
            TextField("Notlarda ara", text: Binding(get: { shell.searchQuery }, set: { shell.searchQuery = $0 }))
                .textFieldStyle(.plain)
                .font(BeyinFont.body)
                .foregroundStyle(palette.t1)
                .focused($searchFocused)
                .onSubmit {
                    if let first = store.search(shell.searchQuery, limit: 1).first { shell.show(first.id, in: store) }
                }
                .accessibilityLabel("Notlarda ara")
            if shell.searchQuery.isEmpty {
                KeyCap("⌘F")
            } else {
                Button { shell.searchQuery = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.t3)
                    .accessibilityLabel("Aramayı temizle")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .cardSurface(cornerRadius: 12)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.violet2.opacity(searchFocused ? 0.45 : 0), lineWidth: 1)
        }
        .motion(Motion.snappy, value: searchFocused)
    }

    // MARK: Görünümler

    private var viewsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel("Görünümler").padding(.horizontal, 10).padding(.bottom, 4)
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(Motion.resolve(Motion.view, reduce: reduceMotion)) { store.mode = mode }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 14))
                            .frame(width: 16)
                        Text(mode.title).frame(maxWidth: .infinity, alignment: .leading)
                        KeyCap("⌘\(mode.shortcutDigit)")
                    }
                }
                .buttonStyle(NavRowButtonStyle(isActive: store.mode == mode))
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(store.mode == mode ? .isSelected : [])
            }
        }
    }

    // MARK: Açıklama

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Açıklama")
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    legendItem("wikilink") {
                        Capsule().fill(palette.edge.opacity(1)).frame(width: 14, height: 1.2)
                    }
                    legendItem("aynı proje") {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: 0.5))
                            path.addLine(to: CGPoint(x: 14, y: 0.5))
                        }
                        .stroke(palette.t3, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                        .frame(width: 14, height: 1.2)
                    }
                }
                GridRow {
                    legendItem("boyut = bağ") {
                        HStack(spacing: 2) {
                            Circle().fill(palette.t3).frame(width: 4, height: 4)
                            Circle().fill(palette.t3).frame(width: 8, height: 8)
                        }
                    }
                    legendItem("private") {
                        Image(systemName: "lock.fill").font(.system(size: 9))
                    }
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(palette.t3)
        }
        .padding(.horizontal, 10)
        .accessibilityElement(children: .combine)
    }

    private func legendItem<Mark: View>(_ title: String, @ViewBuilder mark: () -> Mark) -> some View {
        HStack(spacing: 6) {
            mark().frame(width: 14, height: 10)
            Text(title).lineLimit(1)
        }
    }

    // MARK: Son sohbetler

    private var recentChats: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionLabel("Son sohbetler").padding(.horizontal, 10).padding(.bottom, 6)
            let chats = store.graph.recent(.chat, limit: 4)
            if chats.isEmpty {
                EmptyHint(text: "Henüz sohbet yok", symbol: NoteCategory.chat.symbol)
            } else {
                ForEach(chats) { note in
                    NoteRow(note: note, trailing: BeyinFormat.relative(note.modified),
                            isSelected: store.selection == note.id) {
                        select(note)
                    }
                }
            }
        }
    }

    // MARK: Arama sonuçları

    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 2) {
            let hits = store.search(shell.searchQuery, limit: 12)
            SectionLabel(hits.isEmpty ? "Sonuç yok" : "Sonuçlar · \(hits.count)")
                .padding(.horizontal, 10).padding(.bottom, 6)
            if hits.isEmpty {
                EmptyHint(text: "“\(shell.searchQuery)” için eşleşen not bulunamadı.")
            }
            ForEach(hits) { hit in
                if let note = store.graph.note(hit.id) {
                    NoteRow(note: note, trailing: note.category.title, isSelected: store.selection == note.id) {
                        select(note)
                    }
                }
            }
        }
    }

    // MARK: Alt satır

    private var footer: some View {
        HStack(spacing: 8) {
            SettingsLink {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape").font(.system(size: 13))
                    Text("Ayarlar")
                }
            }
            .buttonStyle(RowButtonStyle())
            .fixedSize()
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                BreathingDot(color: palette.teal)
                // Dar kenar çubuğunda kısalır: "67 not · 09:51" → "67 · 09:51" → "09:51".
                ViewThatFits(in: .horizontal) {
                    ForEach(syncVariants, id: \.self) { variant in
                        Text(variant)
                    }
                }
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(palette.t3)
                .lineLimit(1)
            }
            .padding(.trailing, 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Eşitleme durumu")
            .accessibilityValue(syncText)
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
        .overlay(alignment: .top) { Rectangle().fill(palette.hair).frame(height: 1) }
    }

    private var syncVariants: [String] {
        let count = BeyinFormat.number(store.graph.stats.noteCount)
        guard let lastSync = store.lastSync else { return ["\(count) not", count] }
        let time = BeyinFormat.time(lastSync)
        return ["\(count) not · \(time)", "\(count) · \(time)", time]
    }

    private var syncText: String {
        let count = BeyinFormat.number(store.graph.stats.noteCount)
        guard let lastSync = store.lastSync else { return "\(count) not" }
        return "\(count) not · \(BeyinFormat.time(lastSync))"
    }

    private func select(_ note: Note) {
        withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) {
            shell.show(note.id, in: store)
            store.focusedCategory = note.category
        }
    }
}

/// Filtre çipleri, Proje ve Tarih menüleri, iki anahtar. Kenar çubuğunda ve araç çubuğu açılır panelinde ortak.
struct FilterControls: View {
    let store: VaultStore
    var showsLabel = true

    @Environment(\.palette) private var palette

    /// Çekirdek her zaman merkezde (orb) durduğu için filtrelenmez.
    private let categories = NoteCategory.allCases.filter { $0 != .core }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsLabel { SectionLabel("Filtreler").padding(.horizontal, 10) }
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(categories) { category in
                    let isOn = store.filters.categories.contains(category)
                    FilterChip(title: category.title, color: category.color(palette), isOn: isOn) {
                        if isOn { store.filters.categories.remove(category) } else { store.filters.categories.insert(category) }
                    }
                    .help(store.graph.stats.count(category) == 0 ? "\(category.title): henüz not yok" : "\(category.title) notlarını göster/gizle")
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 6) {
                MenuField(title: "Proje", value: store.filters.project ?? "Tümü") {
                    Button("Tümü") { store.filters.project = nil }
                    if !store.projects.isEmpty { Divider() }
                    ForEach(store.projects, id: \.self) { project in
                        Button(project) { store.filters.project = project }
                    }
                }
                MenuField(title: "Tarih", value: store.filters.dateRange.title) {
                    ForEach(DateRangeFilter.allCases) { range in
                        Button(range.title) { store.filters.dateRange = range }
                    }
                }
                SwitchRow(title: "Private notları gizle",
                          isOn: Binding(get: { store.filters.hidePrivate }, set: { store.filters.hidePrivate = $0 }))
                SwitchRow(title: "Bağlantısızları göster",
                          isOn: Binding(get: { store.filters.showIsolated }, set: { store.filters.showIsolated = $0 }))
            }
            .padding(.horizontal, 4)
        }
    }
}

/// "Proje · Tümü ⌄" biçiminde kart düğmesi; tıklayınca menü açar.
struct MenuField<Items: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    let value: String
    @ViewBuilder let items: Items

    var body: some View {
        Menu {
            items
        } label: {
            HStack(spacing: 4) {
                Text(title).foregroundStyle(palette.t3)
                Spacer(minLength: 8)
                Text(value).foregroundStyle(palette.t1).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(palette.t3)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .cardSurface(cornerRadius: 10)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

/// Etiket + sağda anahtar: 30 yükseklik, 12 pt ikincil metin, mor dolgu.
struct SwitchRow: View {
    @Environment(\.palette) private var palette
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(palette.t2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .tint(palette.violet)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 30)
    }
}
