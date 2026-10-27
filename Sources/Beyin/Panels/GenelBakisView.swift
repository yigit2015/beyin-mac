import BeyinCore
import SwiftUI

/// Genel bakış (GenelBakis.dc.html): `store.mode == .genelBakis` iken tuvali kaplar.
/// 12 sütun, aralık 12, en fazla 1120 genişlik; < 900 tek sütun. Kartlar 30 ms kademeyle, y 12 → 0 + opaklık.
/// Hiçbir sayı sabit değil: hepsi VaultStore'dan gelir; boş kategoriler "henüz yok" olarak görünür.
struct GenelBakisView: View {
    let store: VaultStore
    let shell: ShellState

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Kabın ölçüsü gelene kadar 0: ızgara yanlış genişlikte bir kez çizilip kaydırmayı kaydırmasın.
    @State private var containerWidth: CGFloat = 0
    @State private var appeared = false

    private static let gap: CGFloat = 12
    /// Alttaki yüzen kontroller: Beyne sor (52) + zaman çizelgesi (38) + aralıklar; son kart bunların üstünde biter.
    private static let bottomInset: CGFloat = 140

    /// Izgara genişliği: kap − yatay boşluk − yüzen panelin örttüğü kısım; en fazla 1120.
    private var contentWidth: CGFloat {
        guard containerWidth > 0 else { return 0 }
        return max(320, min(1120, containerWidth - 44 - shell.canvasTrailingOcclusion))
    }

    var body: some View {
        let model = OverviewModel(graph: store.graph, range: shell.overviewRange)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if contentWidth > 0 {
                    header(model)
                    grid(model)
                }
            }
            .frame(width: max(contentWidth, 1))
            .frame(maxWidth: .infinity)
            .padding(.trailing, shell.canvasTrailingOcclusion)
            .padding(.top, 70)
            .padding(.bottom, Self.bottomInset)
        }
        .scrollIndicators(.never)
        .defaultScrollAnchor(.top)
        // Genişlik kaptan ölçülür (içerikten değil), yoksa sabit genişlikli kartlar kendi ölçüsünü besler.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { containerWidth = $0 }
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .onAppear { appeared = true }
    }

    // MARK: Üst bilgi

    private func header(_ model: OverviewModel) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Genel bakış · \(BeyinFormat.longDate(.now))")
                GradientTitle(text: model.greeting, font: BeyinFont.display, tracking: -0.8)
                Text(summary(model))
                    .font(.system(size: 15))
                    .foregroundStyle(palette.t2)
            }
            Spacer(minLength: 12)
            if let lastSync = store.lastSync {
                Chip(height: 24) {
                    BreathingDot(color: palette.teal, size: 6)
                    Text("Eşitlendi \(BeyinFormat.time(lastSync))").monospacedDigit()
                }
                .font(.system(size: 11))
            }
        }
        .modifier(StaggeredAppear(index: 0, appeared: appeared))
    }

    private func summary(_ model: OverviewModel) -> AttributedString {
        func number(_ value: Int) -> AttributedString {
            var string = AttributedString(BeyinFormat.number(value))
            string.foregroundColor = palette.t1
            return string
        }
        var text = AttributedString("Kasanda ") + number(model.stats.noteCount) + AttributedString(" not ve ")
            + number(model.stats.linkCount) + AttributedString(" bağlantı var. ")
        if model.addedThisWeek > 0 {
            text += AttributedString("Bu hafta ") + number(model.addedThisWeek) + AttributedString(" not eklendi.")
        } else {
            text += AttributedString("Bu hafta yeni not eklenmedi.")
        }
        return text
    }

    // MARK: Izgara

    private var isSingleColumn: Bool { contentWidth < 900 }

    private func span(_ columns: Int) -> CGFloat {
        let unit = (contentWidth - Self.gap * 11) / 12
        return unit * CGFloat(columns) + Self.gap * CGFloat(columns - 1)
    }

    @ViewBuilder
    private func grid(_ model: OverviewModel) -> some View {
        let cards = OverviewCards(store: store, shell: shell, model: model, reduceMotion: reduceMotion)
        if isSingleColumn {
            VStack(spacing: Self.gap) {
                ForEach(Array(OverviewCards.Kind.allCases.enumerated()), id: \.element) { index, kind in
                    cards.card(kind)
                        .modifier(StaggeredAppear(index: index + 1, appeared: appeared))
                }
            }
        } else {
            VStack(alignment: .leading, spacing: Self.gap) {
                HStack(alignment: .top, spacing: Self.gap) {
                    VStack(spacing: Self.gap) {
                        row([(.totalNotes, 3), (.totalLinks, 3), (.core, 3)], cards: cards, startIndex: 1)
                        row([(.activity, 6), (.topConnected, 3)], cards: cards, startIndex: 4)
                    }
                    .frame(width: span(9))
                    cards.card(.daily)
                        .frame(width: span(3))
                        .frame(maxHeight: .infinity)
                        .modifier(StaggeredAppear(index: 6, appeared: appeared))
                }
                .fixedSize(horizontal: false, vertical: true)
                row([(.recentChats, 4), (.categories, 4), (.health, 4)], cards: cards, startIndex: 7)
                row([(.project, 6), (.newFacts, 6)], cards: cards, startIndex: 10)
            }
        }
    }

    private func row(_ items: [(OverviewCards.Kind, Int)], cards: OverviewCards, startIndex: Int) -> some View {
        HStack(alignment: .top, spacing: Self.gap) {
            ForEach(Array(items.enumerated()), id: \.element.0) { offset, item in
                cards.card(item.0)
                    .frame(width: span(item.1))
                    .frame(maxHeight: .infinity)
                    .modifier(StaggeredAppear(index: startIndex + offset, appeared: appeared))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Kart girişi: 30 ms kademe, y 12 → 0 + opaklık, panel yayı. Hareketi azalt: yalnız opaklık, kademe yok.
private struct StaggeredAppear: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    let appeared: Bool

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : Motion.panel.delay(Double(index) * 0.03), value: appeared)
    }
}

// MARK: - Veri

/// Genel bakışın türetilmiş değerleri; tek geçişte hesaplanır.
struct OverviewModel {
    let graph: VaultGraph
    let stats: VaultStats
    let notes: [Note]
    let greeting: String
    let addedThisWeek: Int
    let weekly: [Bucket]
    let daily: [Bucket]
    let today: Note?
    let latestDaily: Note?

    struct Bucket: Identifiable {
        let id: Int
        let start: Date
        let count: Int
    }

    init(graph: VaultGraph, range: DateRangeFilter, now: Date = .now) {
        self.graph = graph
        stats = graph.stats
        notes = Array(graph.notes.values)

        let hour = Calendar.current.component(.hour, from: now)
        greeting = switch hour {
        case 5..<12: "Günaydın."
        case 12..<18: "İyi günler."
        case 18..<23: "İyi akşamlar."
        default: "İyi geceler."
        }

        let weekAgo = now.addingTimeInterval(-7 * 86_400)
        addedThisWeek = notes.filter { ($0.created ?? $0.modified) >= weekAgo }.count

        let calendar = Calendar(identifier: .iso8601)
        let weekCount: Int = switch range {
        case .last7: 4
        case .last30: 5
        case .last90: 13
        case .all: 26
        }
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        weekly = (0..<weekCount).map { offset in
            let start = calendar.date(byAdding: .weekOfYear, value: offset - (weekCount - 1), to: thisWeek) ?? thisWeek
            return Bucket(id: offset, start: start, count: 0)
        }
        .map { bucket in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: bucket.start) ?? bucket.start
            let count = graph.notes.values.filter { let d = $0.created ?? $0.modified; return d >= bucket.start && d < end }.count
            return Bucket(id: bucket.id, start: bucket.start, count: count)
        }

        let startOfToday = Calendar.current.startOfDay(for: now)
        daily = (0..<14).map { offset in
            let start = Calendar.current.date(byAdding: .day, value: offset - 13, to: startOfToday) ?? startOfToday
            let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
            let count = graph.notes.values.filter { let d = $0.created ?? $0.modified; return d >= start && d < end }.count
            return Bucket(id: offset, start: start, count: count)
        }

        let dailies = graph.recent(.daily, limit: 1)
        latestDaily = dailies.first
        today = graph.notes.values.first { note in
            note.category == .daily && Calendar.current.isDate(note.created ?? note.modified, inSameDayAs: now)
        }
    }

    func count(_ category: NoteCategory) -> Int { stats.count(category) }

    /// Proje alt kümeleri: en kalabalık proje ve alt klasörleri (bySubcluster anahtarları "project:<ad>/<alt>").
    var largestProject: (name: String, total: Int, subclusters: [(name: String, count: Int)])? {
        var totals: [String: Int] = [:]
        for note in notes { if let project = note.project { totals[project, default: 0] += 1 } }
        guard let (name, total) = totals.max(by: { $0.value < $1.value }) else { return nil }
        let prefix = "project:\(name)/"
        let subs = stats.bySubcluster
            .filter { $0.key.hasPrefix(prefix) }
            .map { (name: String($0.key.dropFirst(prefix.count)), count: $0.value) }
            .sorted { $0.count > $1.count }
        return (name, total, subs)
    }
}

// MARK: - Kartlar

@MainActor
private struct OverviewCards {
    enum Kind: CaseIterable, Hashable {
        case totalNotes, totalLinks, core, daily, activity, topConnected, recentChats, categories, health, project, newFacts
    }

    let store: VaultStore
    let shell: ShellState
    let model: OverviewModel
    let reduceMotion: Bool

    @ViewBuilder
    func card(_ kind: Kind) -> some View {
        switch kind {
        case .totalNotes: TotalNotesCard(model: model)
        case .totalLinks: TotalLinksCard(model: model)
        case .core: CoreCard(model: model, open: open)
        case .daily: DailyCard(model: model, store: store, open: open)
        case .activity: ActivityCard(model: model)
        case .topConnected: TopConnectedCard(model: model, open: open)
        case .recentChats: RecentChatsCard(model: model, open: open, openChats: openChats)
        case .categories: CategoriesCard(model: model)
        case .health: HealthCard(model: model)
        case .project: ProjectCard(model: model, showInNetwork: showProject)
        case .newFacts: NewFactsCard(model: model, open: open)
        }
    }

    /// Genel bakıştan bir nota tıklamak onu Odak'ta açar.
    private func open(_ note: Note) {
        withAnimation(Motion.resolve(Motion.view, reduce: reduceMotion)) {
            store.focusedCategory = note.category
            shell.show(note.id, in: store)
            store.mode = .odak
        }
    }

    private func openChats() {
        withAnimation(Motion.resolve(Motion.view, reduce: reduceMotion)) {
            store.focusedCategory = .chat
            store.mode = .odak
        }
    }

    private func showProject(_ name: String) {
        withAnimation(Motion.resolve(Motion.view, reduce: reduceMotion)) {
            store.filters.project = name
            store.mode = .ag
        }
    }
}

/// Genel bakış kartı: panel camı, köşe 20, iç 16, aralık 12.
private struct OverviewCard<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .panelGlass(cornerRadius: 20)
    }
}

private struct CardTitle: View {
    @Environment(\.palette) private var palette
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(BeyinFont.headline).foregroundStyle(palette.t1)
            if let subtitle {
                Text(subtitle).font(BeyinFont.caption).foregroundStyle(palette.t3)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Karo + başlık (12.5, ikincil): "Toplam not" gibi HUD kartlarının üst satırı.
private struct TileTitle: View {
    @Environment(\.palette) private var palette
    let symbol: String
    let color: Color
    let fill: Color
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            Text(title).font(.system(size: 12.5)).foregroundStyle(palette.t2)
        }
    }
}

private struct TotalNotesCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel

    var body: some View {
        OverviewCard {
            HStack {
                TileTitle(symbol: "doc.text", color: palette.teal, fill: palette.tealFill, title: "Toplam not")
                Spacer(minLength: 4)
                if model.addedThisWeek > 0 {
                    Chip("+\(BeyinFormat.number(model.addedThisWeek)) bu hafta", tint: palette.teal)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                Text(BeyinFormat.number(model.stats.noteCount))
                    .font(BeyinFont.hudXL)
                    .tracking(-0.88)
                    .foregroundStyle(palette.t1)
                    .contentTransition(.numericText(value: Double(model.stats.noteCount)))
                Spacer(minLength: 4)
                Sparkline(values: cumulative)
                    .frame(width: 96, height: 40)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Toplam not")
        .accessibilityValue("\(model.stats.noteCount), bu hafta \(model.addedThisWeek) yeni")
    }

    /// Haftalık birikimli not sayısı.
    private var cumulative: [Double] {
        let before = model.stats.noteCount - model.weekly.reduce(0) { $0 + $1.count }
        var running = Double(max(0, before))
        return model.weekly.map { running += Double($0.count); return running }
    }
}

private struct Sparkline: View {
    @Environment(\.palette) private var palette
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, let lo = values.min(), let hi = values.max() else { return }
            let range = max(hi - lo, 1)
            let points = values.enumerated().map { index, value in
                CGPoint(x: 1 + CGFloat(index) / CGFloat(values.count - 1) * (size.width - 2),
                        y: size.height - 2 - CGFloat((value - lo) / range) * (size.height - 6))
            }
            var line = Path()
            line.addLines(points)
            var area = line
            area.addLine(to: CGPoint(x: points.last!.x, y: size.height))
            area.addLine(to: CGPoint(x: points[0].x, y: size.height))
            area.closeSubpath()
            context.fill(area, with: .linearGradient(Gradient(colors: [palette.teal.opacity(0.28), .clear]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(palette.teal), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct TotalLinksCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel

    var body: some View {
        OverviewCard {
            TileTitle(symbol: "link", color: palette.violet2, fill: palette.violetFill, title: "Toplam bağlantı")
            HStack(alignment: .bottom, spacing: 8) {
                Text(BeyinFormat.number(model.stats.linkCount))
                    .font(BeyinFont.hudXL)
                    .tracking(-0.88)
                    .foregroundStyle(palette.t1)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Text(average).foregroundStyle(palette.t2).monospacedDigit()) bağ / not")
                    Text("\(Text(BeyinFormat.number(model.stats.unresolvedLinkCount)).foregroundStyle(palette.t2).monospacedDigit()) çözülmemiş")
                }
                .font(.system(size: 11))
                .foregroundStyle(palette.t3)
                .padding(.bottom, 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Toplam bağlantı")
        .accessibilityValue("\(model.stats.linkCount), not başına \(average)")
    }

    private var average: String {
        guard model.stats.noteCount > 0 else { return "0" }
        let value = Double(model.stats.linkCount * 2) / Double(model.stats.noteCount)
        return value.formatted(.number.precision(.fractionLength(1)).locale(BeyinFormat.locale))
    }
}

private struct CoreCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel
    let open: (Note) -> Void

    var body: some View {
        OverviewCard(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    OrbView(size: 22)
                    Text("Çekirdek").font(.system(size: 12.5)).foregroundStyle(palette.t2)
                }
                Spacer()
                Text("son güncelleme").font(.system(size: 11)).foregroundStyle(palette.t3)
            }
            let core = model.graph.recent(.core, limit: 5)
            if core.isEmpty {
                EmptyHint(text: "Çekirdek not henüz yok")
            } else {
                VStack(spacing: 0) {
                    ForEach(core) { note in
                        let stamp = BeyinFormat.coreStamp(note.modified)
                        Button { open(note) } label: {
                            HStack(spacing: 7) {
                                Dot(color: NoteCategory.core.color(palette), size: 6)
                                Text(note.title).foregroundStyle(palette.t1).lineLimit(1)
                                Spacer(minLength: 6)
                                Text(stamp.text)
                                    .monospacedDigit()
                                    .foregroundStyle(stamp.isToday ? palette.teal : palette.t3)
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(RowButtonStyle(height: 22))
                        .accessibilityLabel(note.title)
                        .accessibilityValue("son güncelleme \(stamp.text)")
                    }
                }
                .padding(.horizontal, -8)
            }
        }
    }
}

private struct DailyCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel
    let store: VaultStore
    let open: (Note) -> Void

    var body: some View {
        OverviewCard {
            HStack {
                TileTitle(symbol: "calendar", color: NoteCategory.daily.color(palette),
                          fill: NoteCategory.daily.color(palette).opacity(0.14), title: "Bugünün notu")
                Spacer()
                Chip("Günlük")
            }
            if let note = model.today {
                content(for: note)
            } else {
                emptyState
            }
        }
    }

    @ViewBuilder
    private func content(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(note.title)
                .font(.system(size: 20))
                .foregroundStyle(palette.t1)
                .lineLimit(2)
            Text("\(BeyinFormat.weekday(note.created ?? note.modified)) · \(model.graph.degree(of: note.id)) bağlantı · \(note.visibility.rawValue)")
                .font(.system(size: 12))
                .foregroundStyle(palette.t3)
        }
        VStack(alignment: .leading, spacing: 8) {
            if note.isPrivate {
                Label("Private notun içeriği gösterilmez.", systemImage: "lock.fill")
                    .foregroundStyle(palette.t3)
            } else if note.excerpt.isEmpty {
                Text("Bu günlük notta henüz metin yok.").foregroundStyle(palette.t3)
            } else {
                MarkdownPreview(text: note.excerpt) { target in
                    if let linked = model.graph.resolveWikilink(target) { open(linked) }
                }
            }
            Spacer(minLength: 0)
            Label("Salt okunur — görevler Obsidian’da işaretlenir", systemImage: "lock")
                .font(.system(size: 11))
                .foregroundStyle(palette.t3)
        }
        .font(BeyinFont.callout)
        .lineSpacing(5.5)
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardSurface(cornerRadius: 14)
        Button {
            store.openInObsidian(note.id)
        } label: {
            HStack(spacing: 6) {
                Text("Obsidian’da Aç")
                Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(CapsuleButtonStyle())
    }

    /// Günlük not yoksa zarif boş durum kartı.
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(NoteCategory.daily.color(palette).opacity(0.8))
                .frame(width: 56, height: 56)
                .background(NoteCategory.daily.color(palette).opacity(0.10), in: Circle())
            Text(model.latestDaily == nil ? "Henüz günlük not yok" : "Bugün için günlük not yok")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.t1)
            Text(emptyMessage)
                .font(.system(size: 12))
                .foregroundStyle(palette.t3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let latest = model.latestDaily {
                Button { open(latest) } label: {
                    Text("Son günlük: \(latest.title)").lineLimit(1)
                }
                .buttonStyle(CapsuleButtonStyle(height: 30))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cardSurface(cornerRadius: 14)
        .accessibilityElement(children: .combine)
    }

    private var emptyMessage: String {
        model.latestDaily == nil
            ? "Obsidian’da günlük not tuttuğunda bugünün notu burada görünecek."
            : "Obsidian’da bugünün notunu açtığında burada belirecek."
    }
}

private struct ActivityCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel
    @State private var byDay = false

    var body: some View {
        let buckets = byDay ? model.daily : model.weekly
        OverviewCard {
            HStack(alignment: .top) {
                CardTitle(title: "Aktivite", subtitle: byDay ? "Günlük yeni not" : "Haftalık yeni not")
                Spacer()
                Picker("Aralık", selection: $byDay) {
                    Text("Gün").tag(true)
                    Text("Hafta").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .tint(palette.violet)
                .fixedSize()
            }
            ActivityBars(buckets: buckets, byDay: byDay)
                .frame(height: 150)
            HStack {
                Text(buckets.first.map { BeyinFormat.dayMonth($0.start) } ?? "")
                Spacer()
                if let spike = ActivityBars.spikeIndex(in: buckets) {
                    Text("\(BeyinFormat.dayMonth(buckets[spike].start)) · toplu ekleme").foregroundStyle(palette.t2)
                    Spacer()
                }
                Text(byDay ? "Bugün" : "Bu hafta").foregroundStyle(palette.t1)
            }
            .font(.system(size: 11))
            .foregroundStyle(palette.t3)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Sütunlar: normal haftalar taralı teal, bu hafta teal → mor gradyan + parıltı; sıçrama (toplu içe aktarma) kırık sütun.
private struct ActivityBars: View {
    @Environment(\.palette) private var palette
    let buckets: [OverviewModel.Bucket]
    let byDay: Bool

    /// En büyük değer diğerlerinin 3 katından fazlaysa (ve > 40) kırık sütun olarak gösterilir.
    static func spikeIndex(in buckets: [OverviewModel.Bucket]) -> Int? {
        guard let maxIndex = buckets.indices.max(by: { buckets[$0].count < buckets[$1].count }) else { return nil }
        let peak = buckets[maxIndex].count
        let others = buckets.enumerated().filter { $0.offset != maxIndex }.map(\.element.count).max() ?? 0
        return peak > 40 && peak > others * 3 ? maxIndex : nil
    }

    var body: some View {
        let spike = Self.spikeIndex(in: buckets)
        let normalMax = max(1, buckets.enumerated().filter { $0.offset != spike }.map(\.element.count).max() ?? 1)
        HStack(alignment: .bottom, spacing: byDay ? 6 : 10) {
            ForEach(buckets) { bucket in
                let isLast = bucket.id == buckets.last?.id
                let isSpike = bucket.id == spike
                let height: CGFloat = isSpike ? 128 : (bucket.count == 0 ? 3 : 8 + CGFloat(bucket.count) / CGFloat(normalMax) * 96)
                VStack(spacing: 4) {
                    Text(isLast || isSpike ? BeyinFormat.number(bucket.count) : " ")
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(isLast ? palette.t1 : palette.t3)
                    bar(isLast: isLast, isSpike: isSpike, isEmpty: bucket.count == 0)
                        .frame(height: height)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(BeyinFormat.dayMonth(bucket.start))
                .accessibilityValue("\(bucket.count) not")
            }
        }
        .padding(.top, 18)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .overlay(alignment: .bottom) { Rectangle().fill(palette.hair).frame(height: 1) }
    }

    @ViewBuilder
    private func bar(isLast: Bool, isSpike: Bool, isEmpty: Bool) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 2, bottomTrailingRadius: 2, topTrailingRadius: 6)
        if isLast {
            shape
                .fill(LinearGradient(colors: [palette.teal, palette.violet], startPoint: .top, endPoint: .bottom))
                .shadow(color: palette.teal.opacity(0.45), radius: 11)
        } else {
            Hatch(color: palette.teal.opacity(isEmpty ? 0.25 : 0.5))
                .clipShape(shape)
                .overlay(alignment: .top) {
                    if !isEmpty { Rectangle().fill(palette.teal).frame(height: 2).clipShape(shape) }
                }
                .mask {
                    if isSpike {
                        // Kırık: yükseklik ölçeğe sığmadığını gösteren boşluk (%30–%37).
                        GeometryReader { proxy in
                            VStack(spacing: 0) {
                                Rectangle().frame(height: proxy.size.height * 0.30)
                                Color.clear.frame(height: proxy.size.height * 0.07)
                                Rectangle()
                            }
                        }
                    } else {
                        Rectangle()
                    }
                }
        }
    }
}

/// 135° tarama: 1.5 pt çizgi, 6 pt adım.
private struct Hatch: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 6
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}

private struct TopConnectedCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel
    let open: (Note) -> Void

    var body: some View {
        OverviewCard(spacing: 8) {
            HStack {
                CardTitle(title: "En çok bağlanan")
                Spacer()
                Text("bağ").font(.system(size: 11)).foregroundStyle(palette.t3)
            }
            let top = model.stats.topConnected.prefix(6).compactMap { ranked in
                model.graph.note(ranked.id).map { (note: $0, degree: ranked.degree) }
            }
            if top.isEmpty || top.allSatisfy({ $0.degree == 0 }) {
                EmptyHint(text: "Henüz bağlantılı not yok", symbol: "link")
            } else {
                let maxDegree = max(1, top.map(\.degree).max() ?? 1)
                VStack(spacing: 4) {
                    ForEach(top, id: \.note.id) { item in
                        Button { open(item.note) } label: {
                            HStack(spacing: 10) {
                                HStack(spacing: 7) {
                                    Dot(color: item.note.category.color(palette), size: 6)
                                    Text(item.note.title).foregroundStyle(palette.t1).lineLimit(1).truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Capsule()
                                    .fill(palette.chip)
                                    .frame(width: 56, height: 4)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(item.note.category.color(palette))
                                            .frame(width: 56 * CGFloat(item.degree) / CGFloat(maxDegree), height: 4)
                                    }
                                Text(BeyinFormat.number(item.degree))
                                    .monospacedDigit()
                                    .foregroundStyle(palette.t2)
                                    .frame(width: 24, alignment: .trailing)
                            }
                            .font(BeyinFont.callout)
                        }
                        .buttonStyle(RowButtonStyle(height: 24))
                        .accessibilityLabel(item.note.title)
                        .accessibilityValue("\(item.degree) bağlantı")
                    }
                }
                .padding(.horizontal, -8)
            }
        }
    }
}

private struct RecentChatsCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel
    let open: (Note) -> Void
    let openChats: () -> Void

    var body: some View {
        OverviewCard(spacing: 6) {
            HStack {
                CardTitle(title: "Son sohbetler")
                Spacer()
                if model.count(.chat) > 0 {
                    Button("Odakta aç", action: openChats)
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5))
                        .foregroundStyle(palette.violet2)
                }
            }
            let chats = model.graph.recent(.chat, limit: 5)
            if chats.isEmpty {
                EmptyHint(text: "Henüz sohbet yok", symbol: NoteCategory.chat.symbol)
            } else {
                VStack(spacing: 0) {
                    ForEach(chats) { note in
                        NoteRow(note: note, trailing: BeyinFormat.relative(note.modified),
                                badge: BeyinFormat.number(model.graph.degree(of: note.id)), height: 28) {
                            open(note)
                        }
                    }
                }
                .padding(.horizontal, -8)
            }
        }
    }
}

private struct CategoriesCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel

    var body: some View {
        OverviewCard(spacing: 10) {
            HStack {
                CardTitle(title: "Kategori dağılımı")
                Spacer()
                Chip("\(BeyinFormat.number(model.stats.noteCount)) not").monospacedDigit()
            }
            // Yığılmış çubuk: yalnız dolu kategoriler.
            let total = max(1, model.stats.noteCount)
            GeometryReader { proxy in
                let filled = NoteCategory.allCases.filter { model.count($0) > 0 }
                let available = proxy.size.width - CGFloat(max(0, filled.count - 1)) * 2
                HStack(spacing: 2) {
                    ForEach(filled) { category in
                        Rectangle()
                            .fill(category.color(palette))
                            .frame(width: max(3, available * CGFloat(model.count(category)) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                ForEach(NoteCategory.allCases) { category in
                    let count = model.count(category)
                    GridRow {
                        HStack(spacing: 7) {
                            Dot(color: category.color(palette), size: 6).opacity(count == 0 ? 0.4 : 1)
                            Text(category.pluralTitle).foregroundStyle(count == 0 ? palette.t3 : palette.t2)
                        }
                        Spacer(minLength: 0)
                        Text(count == 0 ? "henüz yok" : BeyinFormat.number(count))
                            .monospacedDigit()
                            .foregroundStyle(count == 0 ? palette.t3 : palette.t1)
                            .gridColumnAlignment(.trailing)
                    }
                    .font(.system(size: 12))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(category.pluralTitle)
                    .accessibilityValue(count == 0 ? "henüz yok" : "\(count) not")
                }
            }
        }
    }
}

private struct HealthCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel

    var body: some View {
        let stats = model.stats
        OverviewCard(spacing: 10) {
            HStack {
                CardTitle(title: "Kasa sağlığı")
                Spacer()
                if stats.unresolvedLinkCount == 0 && stats.isolatedCount == 0 {
                    Chip("Temiz", tint: palette.teal)
                } else {
                    Chip("\(issueCount) uyarı", tint: palette.orange)
                }
            }
            VStack(spacing: 8) {
                metric(symbol: "link.badge.plus", title: "Çözülmeyen wikilink", value: stats.unresolvedLinkCount,
                       hint: "Hedef notu olmayan bağlantılar", warns: true)
                metric(symbol: "circle.dashed", title: "Bağlantısız not", value: stats.isolatedCount,
                       hint: "Hiçbir nota bağlı olmayan notlar", warns: true)
                metric(symbol: "lock", title: "Private not", value: stats.privateCount,
                       hint: "Önizlemesi gizli notlar", warns: false)
            }
            Spacer(minLength: 0)
            Text("Beyin yalnızca okur; düzeltmeler Obsidian’da yapılır.")
                .font(.system(size: 11))
                .foregroundStyle(palette.t3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var issueCount: Int {
        (model.stats.unresolvedLinkCount > 0 ? 1 : 0) + (model.stats.isolatedCount > 0 ? 1 : 0)
    }

    private func metric(symbol: String, title: String, value: Int, hint: String, warns: Bool) -> some View {
        let color = warns && value > 0 ? palette.orange : palette.t3
        return HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(warns && value > 0 ? palette.orangeFill : palette.chip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5)).foregroundStyle(palette.t1)
                Text(hint).font(.system(size: 11)).foregroundStyle(palette.t3).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(BeyinFormat.number(value))
                .font(BeyinFont.hudS)
                .foregroundStyle(warns && value > 0 ? palette.orange : palette.t1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value)")
    }
}

private struct ProjectCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel
    let showInNetwork: (String) -> Void

    var body: some View {
        OverviewCard(spacing: 8) {
            if let project = model.largestProject {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "folder").foregroundStyle(NoteCategory.project.color(palette))
                        Text(project.name).font(BeyinFont.headline).foregroundStyle(palette.t1)
                    }
                    .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Chip("\(BeyinFormat.number(project.total)) not").monospacedDigit()
                }
                let subs = Array(project.subclusters.prefix(4))
                let opacities: [Double] = [1, 0.75, 0.55, 0.38]
                if !subs.isEmpty {
                    GeometryReader { proxy in
                        let total = max(1, subs.reduce(0) { $0 + $1.count })
                        let available = proxy.size.width - CGFloat(subs.count - 1) * 2
                        HStack(spacing: 2) {
                            ForEach(Array(subs.enumerated()), id: \.element.name) { index, sub in
                                Rectangle()
                                    .fill(NoteCategory.project.color(palette).opacity(opacities[index]))
                                    .frame(width: max(3, available * CGFloat(sub.count) / CGFloat(total)))
                            }
                        }
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                        ForEach(0..<((subs.count + 1) / 2), id: \.self) { rowIndex in
                            GridRow {
                                ForEach(subs[(rowIndex * 2)..<min(rowIndex * 2 + 2, subs.count)], id: \.name) { sub in
                                    HStack {
                                        Text(sub.name).foregroundStyle(palette.t2).lineLimit(1)
                                        Spacer(minLength: 6)
                                        Text(BeyinFormat.number(sub.count)).monospacedDigit().foregroundStyle(palette.t1)
                                    }
                                    .font(.system(size: 12))
                                }
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                Button("Ağda kümeyi göster") { showInNetwork(project.name) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.violet2)
            } else {
                CardTitle(title: "Projeler")
                EmptyHint(text: "Henüz proje klasörü yok", symbol: "folder")
            }
        }
    }
}

private struct NewFactsCard: View {
    @Environment(\.palette) private var palette
    let model: OverviewModel
    let open: (Note) -> Void

    var body: some View {
        let weekAgo = Date.now.addingTimeInterval(-7 * 86_400)
        let facts = model.graph.recent(.fact, limit: 50).filter { ($0.created ?? $0.modified) >= weekAgo }
        OverviewCard(spacing: 6) {
            HStack {
                CardTitle(title: "Bu hafta yeni bilgiler")
                Spacer()
                Chip("\(facts.count)", tint: facts.isEmpty ? nil : palette.teal).monospacedDigit()
            }
            if facts.isEmpty {
                EmptyHint(text: model.count(.fact) == 0 ? "Henüz bilgi notu yok" : "Bu hafta yeni bilgi notu eklenmedi",
                          symbol: NoteCategory.fact.symbol)
            } else {
                VStack(spacing: 0) {
                    ForEach(facts.prefix(4)) { note in
                        NoteRow(note: note, trailing: BeyinFormat.relative(note.created ?? note.modified), height: 28) {
                            open(note)
                        }
                    }
                }
                .padding(.horizontal, -8)
            }
        }
    }
}
