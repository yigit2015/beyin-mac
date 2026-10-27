import BeyinCore
import SwiftUI

/// İnceleme paneli (Inceleme.dc.html): 360 genişlik, iç 18, bölümler arası 14, köşe 24.
/// A · normal not · B · private not · C · Beyne sor sonuçları · D · küme özeti (Odak'ta seçim yokken etkin küme).
struct InspectorPanel: View {
    let store: VaultStore
    let shell: ShellState

    var body: some View {
        ZStack(alignment: .top) {
            if shell.inspectorPage == .results, let ask = shell.ask {
                AskResultsView(store: store, shell: shell, ask: ask)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            } else if let id = store.selection, let note = store.graph.note(id) {
                NoteInspector(store: store, shell: shell, note: note)
                    .id(note.id)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            } else if let ask = shell.ask {
                AskResultsView(store: store, shell: shell, ask: ask)
                    .transition(.opacity)
            } else if store.mode == .odak, let cluster = store.activeCluster {
                ClusterInspector(store: store, shell: shell, cluster: cluster)
                    .id(cluster.id)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .panelGlass(cornerRadius: 24)
        .motion(Motion.inspectorSwap, value: store.selection)
        .motion(Motion.inspectorSwap, value: shell.inspectorPage)
        .motion(Motion.inspectorSwap, value: store.activeCluster?.id)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("İnceleme paneli")
    }
}

// MARK: - A / B · Not

private struct NoteInspector: View {
    let store: VaultStore
    let shell: ShellState
    let note: Note

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAllLinks = false

    private var graph: VaultGraph { store.graph }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                titleBlock
                statusCard
                stats
                if note.isPrivate { hiddenPreview } else { preview }
                linkedNotes
            }
            .padding(18)
        }
        .scrollIndicators(.never)
    }

    // Başlık satırı: tür rozeti 30×30 + tür adı 12 Semibold + görünürlük çipi; sağda kapat (28 daire, Esc).
    private var header: some View {
        HStack(spacing: 8) {
            CategoryTile(category: note.category)
                .opacity(note.isPrivate ? 0.6 : 1)
            Text(note.category.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.t2)
            VisibilityChip(note: note)
            Spacer(minLength: 4)
            if shell.ask != nil {
                Button {
                    withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.inspectorPage = .results }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(IconButtonStyle(diameter: 28))
                .accessibilityLabel("Beyne sor sonuçlarına dön")
                .help("Sonuçlara dön")
            }
            Button {
                withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { store.selection = nil }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconButtonStyle(diameter: 28))
            .accessibilityLabel("Paneli kapat")
            .help("Paneli kapat (Esc)")
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            if note.isPrivate {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "lock.fill").font(.system(size: 18))
                    Text(note.title).font(BeyinFont.title1).tracking(-0.26)
                }
                .foregroundStyle(palette.t2)
                .lineLimit(2)
            } else {
                GradientTitle(text: note.title, font: BeyinFont.title1, tracking: -0.26)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(palette.t3)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var subtitle: String {
        let date = note.created ?? note.modified
        let base: String = switch note.category {
        case .chat: "Sohbet arşivi · \(BeyinFormat.longDate(date))"
        case .daily: BeyinFormat.weekday(date)
        default:
            if let project = note.project {
                [project, note.subcluster].compactMap { $0 }.joined(separator: " › ")
            } else {
                folderBreadcrumb
            }
        }
        return note.isPrivate ? "\(base) · görünürlük: private" : base
    }

    private var folderBreadcrumb: String {
        let folders = note.id.split(separator: "/").dropLast().map(String.init)
        return folders.isEmpty ? "Kasa kökü" : folders.joined(separator: " › ")
    }

    // Durum kartı: Aktif (teal) / Arşiv (nötr) + son güncelleme; "Obsidian'da Aç" 34 kapsül.
    private var statusCard: some View {
        let isActive = note.modified > Date.now.addingTimeInterval(-30 * 86_400)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                if isActive {
                    Chip(tint: palette.teal) {
                        Dot(color: palette.teal, size: 5)
                        Text("Aktif")
                    }
                } else {
                    Chip("Arşiv")
                }
                Text("Son güncelleme \(BeyinFormat.dateTime(note.modified))")
                    .font(BeyinFont.caption)
                    .foregroundStyle(palette.t3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                store.openInObsidian(note.id)
            } label: {
                HStack(spacing: 6) {
                    Text("Obsidian’da Aç")
                    Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(CapsuleButtonStyle())
            .help("Obsidian’da aç (⌘O)")
        }
        .padding(12)
        .cardSurface(cornerRadius: 16)
    }

    // İstatistik: 2 sütun, aralık 10.
    private var stats: some View {
        let incoming = Set(graph.incoming(to: note.id)).count
        let outgoing = Set(graph.outgoing(from: note.id)).count
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatCard(symbol: note.isPrivate ? nil : "arrow.down.left", iconColor: palette.teal,
                         value: BeyinFormat.number(incoming), label: "Gelen bağlantı")
                StatCard(symbol: note.isPrivate ? nil : "arrow.up.right", iconColor: palette.violet2,
                         value: BeyinFormat.number(outgoing), label: "Giden bağlantı")
            }
            GridRow {
                if note.isPrivate {
                    StatCard(symbol: nil, iconColor: palette.t3, value: "—", label: "Proje", valueColor: palette.t3)
                    StatCard(symbol: nil, iconColor: palette.t3, value: "—", label: "Kelime (gizli)", valueColor: palette.t3)
                } else {
                    StatCard(symbol: "folder", iconColor: NoteCategory.project.color(palette),
                             value: note.project ?? "—", label: "Proje", isNumeric: false,
                             valueColor: note.project == nil ? palette.t3 : nil)
                    StatCard(symbol: "text.alignleft", iconColor: palette.t3,
                             value: BeyinFormat.number(note.wordCount), label: "Kelime")
                }
            }
        }
        .opacity(note.isPrivate ? 0.75 : 1)
    }

    // Önizleme: köşe 16, gövde 12.5/18, wikilink çipi teal.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                SectionLabel("Önizleme")
                Spacer()
                Chip("Markdown")
            }
            if note.excerpt.isEmpty {
                Text("Bu notun önizlenecek metni yok.")
                    .font(BeyinFont.callout)
                    .foregroundStyle(palette.t3)
            } else {
                MarkdownPreview(text: note.excerpt) { target in
                    guard let linked = graph.resolveWikilink(target) else { return }
                    withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) {
                        shell.show(linked.id, in: store)
                        store.focusedCategory = linked.category
                    }
                }
                .textSelection(.enabled)
            }
            if !note.tags.isEmpty {
                FlowLayout(spacing: 4, lineSpacing: 4) {
                    ForEach(note.tags, id: \.self) { tag in
                        Chip("#\(tag)")
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Markdown önizlemesi")
    }

    // B · Private: iskelet satırlar bulanık, üstte kilit ve açıklama.
    private var hiddenPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel("Önizleme")
                Spacer()
                Chip("gizli")
            }
            ZStack {
                GeometryReader { proxy in
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array([0.46, 0.92, 0.84, 0.66, 0.38, 0.88, 0.72].enumerated()), id: \.offset) { index, width in
                            Capsule()
                                .fill(palette.chipStroke)
                                .frame(width: proxy.size.width * width, height: index == 0 || index == 4 ? 12 : 9)
                                .padding(.top, index == 4 ? 6 : 0)
                        }
                    }
                }
                .frame(height: 140)
                .blur(radius: 3)
                .opacity(0.7)
                .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(palette.t1)
                        .frame(width: 44, height: 44)
                        .floatingGlass(in: Circle())
                    Text("İçerik gizli")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(palette.t1)
                    Text("Private notların önizlemesi gösterilmez. İçeriği Obsidian’da açabilirsin.")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.t3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            .frame(minHeight: 190)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
    }

    // Bağlantılı notlar: satır 30, köşe 9, nokta 7.
    private var linkedNotes: some View {
        let links = linkedList
        let shown = showsAllLinks ? links : Array(links.prefix(5))
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                SectionLabel("Bağlantılı notlar")
                Spacer()
                if links.count > 5 {
                    Button(showsAllLinks ? "Daha az" : "Tümü · \(links.count)") {
                        withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { showsAllLinks.toggle() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.violet2)
                } else if !links.isEmpty {
                    Text("\(links.count)").font(.system(size: 11.5).monospacedDigit()).foregroundStyle(palette.t3)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 6)

            if links.isEmpty {
                EmptyHint(text: "Bu not henüz hiçbir nota bağlı değil.", symbol: "link")
            } else {
                ForEach(shown, id: \.note.id) { link in
                    NoteRow(note: link.note, trailing: link.direction) {
                        withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) {
                            shell.show(link.note.id, in: store)
                            store.focusedCategory = link.note.category
                        }
                    }
                }
            }
        }
    }

    private struct Link {
        let note: Note
        let direction: String
    }

    private var linkedList: [Link] {
        let incoming = Set(graph.incoming(to: note.id))
        let outgoing = Set(graph.outgoing(from: note.id))
        return incoming.union(outgoing)
            .compactMap { id -> Link? in
                guard let other = graph.note(id) else { return nil }
                let direction = incoming.contains(id) && outgoing.contains(id) ? "iki yönlü" : (incoming.contains(id) ? "gelen" : "giden")
                return Link(note: other, direction: direction)
            }
            .sorted { lhs, rhs in
                let (dl, dr) = (graph.degree(of: lhs.note.id), graph.degree(of: rhs.note.id))
                return dl != dr ? dl > dr : lhs.note.title.localizedCompare(rhs.note.title) == .orderedAscending
            }
    }
}

// MARK: - D · Küme özeti

/// Odak'ta seçili not yokken etkin kümenin özeti ve tam listesi (yelpazedeki "+N not daha" buraya açılır).
private struct ClusterInspector: View {
    let store: VaultStore
    let shell: ShellState
    let cluster: Cluster

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let notes = store.rankedNotes(in: cluster)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                header
                VStack(alignment: .leading, spacing: 4) {
                    GradientTitle(text: cluster.title, font: BeyinFont.title1, tracking: -0.26)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.t3)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                stats(notes)
                list(notes)
            }
            .padding(18)
        }
        .scrollIndicators(.never)
    }

    private var header: some View {
        HStack(spacing: 8) {
            CategoryTile(category: cluster.category)
            Text(cluster.category.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.t2)
            Chip("küme")
            Spacer(minLength: 4)
            Button {
                withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.inspectorVisible = false }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconButtonStyle(diameter: 28))
            .accessibilityLabel("Paneli kapat")
            .help("Paneli kapat (⌥⌘I)")
        }
    }

    /// "project:eski-notlar/sohbetler" → "eski-notlar › sohbetler"; diğerleri tür adı.
    private var subtitle: String {
        guard cluster.id.hasPrefix("project:") else { return "\(cluster.category.pluralTitle) · kasa geneli" }
        return cluster.id.dropFirst("project:".count).split(separator: "/").joined(separator: " › ")
    }

    private func stats(_ notes: [Note]) -> some View {
        let links = notes.reduce(0) { $0 + store.graph.degree(of: $1.id) }
        let latest = notes.map(\.modified).max()
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                StatCard(symbol: cluster.category.symbol, iconColor: cluster.category.color(palette),
                         value: BeyinFormat.number(notes.count), label: notes.count == cluster.noteIDs.count
                            ? "Not" : "Not (\(BeyinFormat.number(cluster.noteIDs.count)) içinden)")
                StatCard(symbol: "link", iconColor: palette.violet2, value: BeyinFormat.number(links), label: "Bağ toplamı")
            }
            GridRow {
                StatCard(symbol: "clock", iconColor: palette.teal, value: latest.map { BeyinFormat.relative($0) } ?? "—",
                         label: "Son güncelleme", isNumeric: false)
                StatCard(symbol: "lock", iconColor: palette.t3, value: BeyinFormat.number(notes.filter(\.isPrivate).count),
                         label: "Private")
            }
        }
    }

    private func list(_ notes: [Note]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                SectionLabel("Tüm notlar")
                Spacer()
                Text(BeyinFormat.number(notes.count)).font(.system(size: 11.5).monospacedDigit()).foregroundStyle(palette.t3)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 6)
            if notes.isEmpty {
                EmptyHint(text: "Filtrelerle eşleşen not yok", symbol: "line.3.horizontal.decrease")
            }
            ForEach(notes) { note in
                NoteRow(note: note, trailing: BeyinFormat.relative(note.modified),
                        badge: "\(store.graph.degree(of: note.id)) bağ", isSelected: store.highlighted.contains(note.id)) {
                    withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { shell.show(note.id, in: store) }
                }
            }
        }
    }
}

// MARK: - C · Beyne sor sonuçları

private struct AskResultsView: View {
    let store: VaultStore
    let shell: ShellState
    let ask: AskSession

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            queryCard
            if !ask.hits.isEmpty { categoryChips }
            results
            footer
        }
        .padding(18)
        .onAppear { appeared = true }
    }

    private var header: some View {
        HStack(spacing: 8) {
            OrbView(size: 30, pulseTrigger: shell.askPulse)
            Text("Beyne sor")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.t2)
            Chip("salt okunur arama")
            Spacer(minLength: 4)
            Button {
                withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.clearAsk(in: store) }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(IconButtonStyle(diameter: 28))
            .accessibilityLabel("Aramayı temizle")
            .help("Aramayı temizle (Esc)")
        }
    }

    private var queryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ask.query)
                .font(.system(size: 15))
                .foregroundStyle(palette.t1)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Dot(color: ask.hits.isEmpty ? palette.t3 : palette.gold, glow: ask.hits.isEmpty ? nil : palette.goldGlow)
                if ask.hits.isEmpty {
                    Text("Eşleşen not yok · başka sözcüklerle dene")
                } else {
                    Text("\(Text("\(ask.hits.count)").foregroundStyle(palette.t1).monospacedDigit()) not eşleşti · grafikte parlıyor")
                }
            }
            .font(BeyinFont.caption)
            .foregroundStyle(palette.t3)
            if ask.scope != .all {
                Text("Kapsam: \(ask.scope.title)")
                    .font(BeyinFont.caption)
                    .foregroundStyle(palette.t3)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }

    private var categoryChips: some View {
        let counts = Dictionary(grouping: ask.hits.compactMap { store.graph.note($0.id)?.category }, by: { $0 }).mapValues(\.count)
        return FlowLayout(spacing: 6, lineSpacing: 6) {
            filterChip(title: "Tümü", count: ask.hits.count, color: nil, isOn: ask.categoryFilter == nil) {
                setFilter(nil)
            }
            ForEach(NoteCategory.allCases.filter { (counts[$0] ?? 0) > 0 }) { category in
                filterChip(title: category.title, count: counts[category] ?? 0, color: category.color(palette),
                           isOn: ask.categoryFilter == category) {
                    setFilter(category)
                }
            }
        }
    }

    private func filterChip(title: String, count: Int, color: Color?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let color { Dot(color: color, size: 6) }
                Text(title)
                Text("\(count)").monospacedDigit()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isOn ? palette.t1 : palette.t2)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(isOn ? palette.violetFill : .clear, in: Capsule())
            .chipSurface()
            .overlay { if isOn { Capsule().strokeBorder(palette.violet2.opacity(0.35), lineWidth: 1) } }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(count) sonuç")
        .accessibilityAddTraits(isOn ? [.isSelected, .isToggle] : .isToggle)
    }

    private func setFilter(_ category: NoteCategory?) {
        withAnimation(Motion.resolve(Motion.snappy, reduce: reduceMotion)) {
            var updated = ask
            updated.categoryFilter = category
            shell.ask = updated
            shell.askCursor = 0
        }
    }

    private var results: some View {
        let hits = shell.visibleHits(in: store)
        let top = hits.map(\.score).max() ?? 1
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(hits.enumerated()), id: \.element.id) { rank, hit in
                        if let note = store.graph.note(hit.id) {
                            ResultRow(rank: rank + 1, note: note, hit: hit, query: ask.query,
                                      relevance: top > 0 ? hit.score / top : 0,
                                      isHighlighted: rank == shell.askCursor) {
                                open(note)
                            }
                            .id(hit.id)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared || reduceMotion ? 0 : 6)
                            .animation(reduceMotion ? .easeInOut(duration: 0.2)
                                       : Motion.pop.delay(Double(min(rank, 12)) * 0.03), value: appeared)
                        }
                    }
                }
            }
            .scrollIndicators(.never)
            .onChange(of: shell.askCursor) { _, cursor in
                guard hits.indices.contains(cursor) else { return }
                withAnimation(Motion.snappy) { proxy.scrollTo(hits[cursor].id, anchor: .center) }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sonuçlar, alaka sırasıyla")
    }

    private func open(_ note: Note) {
        withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) {
            shell.show(note.id, in: store)
            store.focusedCategory = note.category
        }
    }

    private var footer: some View {
        FlowLayout(spacing: 10, lineSpacing: 6) {
            hint("↑↓", "gezin")
            hint("↵", "odakla")
            hint("⌘↵", "Obsidian’da aç")
            hint("Esc", "temizle")
        }
        .font(.system(size: 11))
        .foregroundStyle(palette.t3)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(palette.hair).frame(height: 1) }
        .accessibilityHidden(true)
    }

    private func hint(_ key: String, _ text: String) -> some View {
        HStack(spacing: 5) {
            KeyCap(key)
            Text(text).lineLimit(1)
        }
    }
}

/// Sonuç satırı: sıra · tür noktası + başlık · meta · eşleşen parça · alaka yüzdesi ve çubuğu.
private struct ResultRow: View {
    @Environment(\.palette) private var palette
    let rank: Int
    let note: Note
    let hit: SearchHit
    let query: String
    let relevance: Double
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(rank)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(palette.t3)
                    .frame(width: 18, alignment: .leading)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Dot(color: note.category.color(palette)).opacity(note.isPrivate ? 0.4 : 1)
                        Text(note.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.t1)
                            .lineLimit(1)
                        if note.isPrivate {
                            Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(palette.t3)
                        }
                    }
                    Text(meta)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.t3)
                        .lineLimit(1)
                    if !hit.snippet.isEmpty {
                        Text(Highlight.attributed("…\(hit.snippet)…", matching: query, palette: palette, alpha: 0.18))
                            .font(.system(size: 12))
                            .foregroundStyle(palette.t2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 6) {
                    Text("%\(Int((relevance * 100).rounded()))")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(palette.t1)
                    Capsule()
                        .fill(palette.chip)
                        .frame(width: 40, height: 3)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(colors: [palette.teal, palette.violet2], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 40 * relevance, height: 3)
                        }
                }
                .frame(width: 44, alignment: .trailing)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .background(isHighlighted ? palette.chip : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank). \(note.title)")
        .accessibilityValue("\(meta), alaka yüzde \(Int((relevance * 100).rounded()))")
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    private var meta: String {
        var parts = [note.category.title]
        if let project = note.project, note.category != .chat { parts.append(project) }
        if note.category == .chat || note.category == .daily { parts.append(BeyinFormat.dayMonth(note.modified)) }
        return parts.joined(separator: " · ")
    }
}
