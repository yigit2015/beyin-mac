import BeyinCore
import SwiftUI

/// Odak görünümü (⌘1): solda "Ben" orbu, ortada kategori sütunu, sağda seçili kümenin
/// en çok bağlantılı 15 notu yelpaze olarak (Main.dc.html + Veri kuralları · 02).
/// Maket 796×880'lik bir düzlemde çizilir ve tuvale ölçeklenir.
struct OdakView: View {
    let store: VaultStore

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ShellState.self) private var shell
    @State private var hoveredNote: Note.ID?

    // Maket ölçüleri
    private let plane = CGSize(width: 796, height: 880)
    private let orbCenter = CGPoint(x: 170, y: 400)
    private let columnX: CGFloat = 300
    private let cardSize = CGSize(width: 152, height: 48)
    private let fanLimit = 15
    private let fanStep: CGFloat = 34
    private let fanRY: CGFloat = 280

    var body: some View {
        GeometryReader { proxy in
            let usableWidth = proxy.size.width - occlusion
            let fit = min(usableWidth / plane.width,
                          (proxy.size.height - 40) / plane.height)
            let scale = max(fit, 0.5) * store.zoom
            let column = ColumnLayout(store: store, top: 144, columnX: columnX, card: cardSize)
            ZStack(alignment: .topLeading) {
                content(column: column)
                    .frame(width: plane.width, height: plane.height, alignment: .topLeading)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: plane.width * scale, height: plane.height * scale, alignment: .topLeading)
                    .position(x: usableWidth / 2, y: plane.height * scale / 2 + 8)

                breadcrumb(cluster: column.active)
                    .padding(.leading, 18)
                    .padding(.top, 66)
            }
        }
    }

    /// Yüzen inceleme panelinin tuvali örttüğü genişlik (ShellState.canvasTrailingOcclusion).
    private var occlusion: CGFloat { shell.canvasTrailingOcclusion }

    // MARK: Düzlem

    @ViewBuilder
    private func content(column: ColumnLayout) -> some View {
        let fan = FanLayout(store: store, origin: column.selectedAnchor, limit: fanLimit, step: fanStep, ry: fanRY)
        ZStack(alignment: .topLeading) {
            connectors(column: column, fan: fan)
            orbGroup
            ForEach(column.rows) { row in
                rowView(row, column: column)
            }
            fanItems(fan)
        }
    }

    /// Orb → kartlar ve seçili kart → yelpaze çizgileri (tek Canvas).
    private func connectors(column: ColumnLayout, fan: FanLayout) -> some View {
        Canvas { context, _ in
            let start = CGPoint(x: orbCenter.x + 66, y: orbCenter.y)
            var dim = Path(), selected = Path()
            for row in column.rows where row.kind == .card {
                let end = CGPoint(x: columnX, y: row.y + cardSize.height / 2)
                var path = Path()
                path.move(to: start)
                path.addCurve(to: end, control1: CGPoint(x: start.x + 34, y: start.y), control2: CGPoint(x: end.x - 34, y: end.y))
                if row.clusterID == column.active?.id { selected.addPath(path) } else { dim.addPath(path) }
            }
            context.stroke(dim, with: .color(palette.edge), lineWidth: 1)
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: palette.gold.opacity(0.7), radius: 2.2))
                layer.stroke(selected, with: .linearGradient(Gradient(colors: [palette.violet2.opacity(0.9), palette.gold]),
                                                             startPoint: start, endPoint: CGPoint(x: columnX, y: start.y)),
                             lineWidth: 1.6)
            }
            var fanPath = Path()
            for item in fan.items {
                fanPath.addPath(fan.branch(to: item.point))
            }
            context.drawLayer { layer in
                layer.addFilter(.shadow(color: palette.gold.opacity(0.35), radius: 2))
                layer.stroke(fanPath, with: .linearGradient(Gradient(colors: [palette.gold.opacity(0.6), palette.edge.opacity(0.4)]),
                                                            startPoint: fan.origin, endPoint: CGPoint(x: fan.origin.x + 268, y: fan.origin.y)),
                             lineWidth: 1)
            }
            if let more = fan.more {
                context.stroke(fan.branch(to: CGPoint(x: more.x, y: more.y + 13)), with: .color(palette.edge),
                               style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }
        }
        .frame(width: plane.width, height: plane.height)
        .allowsHitTesting(false)
    }

    /// "Ben" orbu, halkalar, çekirdek uyduları, özet çipleri.
    private var orbGroup: some View {
        let core = store.graph.notes(in: .core)
        let stats = store.graph.stats
        return ZStack(alignment: .topLeading) {
            ZStack {
                DottedRing(diameter: 280, color: palette.violet2.opacity(0.22), lineWidth: 1.5)
                DottedRing(diameter: 244)
                Circle().stroke(palette.violet2.opacity(0.12), lineWidth: 1).frame(width: 192, height: 192)
                OrbView(size: 132, phase: core.contains { $0.id == store.selection } ? .focused : .idle, showsHalo: true)
            }
            .position(orbCenter)

            VStack(spacing: 4) {
                Text("Ben").font(BeyinFont.title2).foregroundStyle(palette.t1)
                Text("Core kimlik notu").font(.system(size: 11.5)).foregroundStyle(palette.t3)
            }
            .frame(width: 200)
            .position(x: orbCenter.x, y: 186)

            ForEach(Array(satellites(core).enumerated()), id: \.element.note.id) { _, sat in
                Button {
                    select(sat.note.id)
                } label: {
                    Dot(color: NoteCategory.core.color(palette), size: 8, glow: NoteCategory.core.color(palette))
                        .frame(width: 22, height: 22)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(sat.note.title)
                .position(sat.point)
                .simultaneousGesture(TapGesture(count: 2).onEnded { store.openInObsidian(sat.note.id) })

                Text(sat.note.title)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(store.selection == sat.note.id ? palette.t1 : palette.t2)
                    .fixedSize()
                    .position(x: sat.point.x, y: sat.point.y + (sat.labelAbove ? -18 : 17))
                    .allowsHitTesting(false)
            }

            HStack(spacing: 6) {
                Chip("\(BeyinFormat.number(stats.noteCount)) not")
                Chip("\(BeyinFormat.number(stats.linkCount)) bağlantı")
            }
            .frame(width: 220)
            .position(x: orbCenter.x, y: 581)
        }
    }

    private struct Satellite {
        let note: Note
        let point: CGPoint
        let labelAbove: Bool
    }

    /// Maketteki beş uydu konumu; not sayısı farklıysa yay üzerinde eşit dağıtılır.
    private func satellites(_ core: [Note]) -> [Satellite] {
        let order = ["core", "kurallar", "journal", "last-session", "threads"]
        let sorted = core.sorted { (order.firstIndex(of: $0.title.lowercased()) ?? 99) < (order.firstIndex(of: $1.title.lowercased()) ?? 99) }
        return sorted.enumerated().map { i, note in
            // Sol yarım çember: -90°'den +90°'ye, sola doğru.
            let t = sorted.count == 1 ? 0.5 : Double(i) / Double(sorted.count - 1)
            let angle = (-90 - 180 * t) * .pi / 180
            let point = CGPoint(x: orbCenter.x + cos(angle) * 122, y: orbCenter.y + sin(angle) * 122)
            return Satellite(note: note, point: point, labelAbove: t < 0.5)
        }
    }

    // MARK: Kategori sütunu

    @ViewBuilder
    private func rowView(_ row: ColumnLayout.Row, column: ColumnLayout) -> some View {
        switch row.kind {
        case .header(let title, let trailing):
            HStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(trailing == nil ? 0.8 : 0.2)
                    .textCase(trailing == nil ? .uppercase : nil)
                    .foregroundStyle(palette.t3)
                    .lineLimit(1)
                    .layoutPriority(1)
                Spacer(minLength: 2)
                if let trailing {
                    ShareBar(fraction: trailing.fraction)
                    Text(trailing.text).font(.system(size: 10).monospacedDigit()).foregroundStyle(palette.t3)
                        .lineLimit(1).fixedSize()
                }
            }
            .frame(width: cardSize.width - 2)
            .offset(x: columnX + 2, y: row.y)
        case .card:
            if let cluster = row.cluster {
                CategoryCard(cluster: cluster, title: row.title, isSelected: cluster.id == column.active?.id) {
                    withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) {
                        store.focusedCluster = cluster.id
                        store.selection = nil
                    }
                }
                .frame(width: cardSize.width, height: cardSize.height)
                .offset(x: columnX, y: row.y)
            }
        case .empty(let categories):
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel("Boş")
                ForEach(categories, id: \.self) { category in
                    EmptyCategoryChip(category: category)
                }
            }
            .offset(x: columnX + 2, y: row.y)
        }
    }

    // MARK: Yelpaze

    @ViewBuilder
    private func fanItems(_ fan: FanLayout) -> some View {
        ForEach(fan.items) { item in
            FanItemView(item: item,
                        isSelected: store.selection == item.note.id,
                        isLit: store.highlighted.contains(item.note.id) || hoveredNote == item.note.id) {
                withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { store.selection = item.note.id }
            } open: {
                store.openInObsidian(item.note.id)
            } hover: { inside in
                hoveredNote = inside ? item.note.id : (hoveredNote == item.note.id ? nil : hoveredNote)
            }
            .offset(x: item.point.x - 4, y: item.point.y - 12)
        }
        if let more = fan.more {
            Button {
                withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { store.selection = nil }
            } label: {
                HStack(spacing: 6) {
                    Text("+\(BeyinFormat.number(more.remaining)) not daha")
                    Image(systemName: "list.bullet").font(.system(size: 10, weight: .semibold))
                }
                .font(.system(size: 11.5))
                .foregroundStyle(palette.t1)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .labelGlass(cornerRadius: 13)
            }
            .buttonStyle(.plain)
            .help("Tam listeyi inceleme panelinde göster")
            .offset(x: more.x, y: more.y)
        }
    }

    // MARK: Üst bilgi

    private func breadcrumb(cluster: Cluster?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Odak")
            HStack(spacing: 6) {
                Text("Ben").foregroundStyle(palette.t2)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(palette.t3)
                Text(cluster?.title ?? "—").fontWeight(.semibold).foregroundStyle(palette.t1)
            }
            .font(.system(size: 13))
            HStack(spacing: 6) {
                KeyCap("Esc")
                Text("odaktan çık").font(.system(size: 11)).foregroundStyle(palette.t3)
            }
        }
    }

    private func select(_ id: Note.ID) {
        withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { store.selection = id }
    }
}

// MARK: - Sütun yerleşimi

/// Kategori sütununun satırları: "Türler" + kartlar, her proje için başlık + alt küme kartları, "Boş" satırı.
private struct ColumnLayout {
    enum Kind: Equatable {
        struct Share: Equatable {
            let text: String
            let fraction: Double
        }
        case header(String, Share?)
        case card
        case empty([NoteCategory])
    }

    struct Row: Identifiable {
        let id: String
        let kind: Kind
        let y: CGFloat
        var cluster: Cluster?
        var title = ""
        var clusterID: String? { cluster?.id }
    }

    let rows: [Row]
    let active: Cluster?
    /// Seçili kartın sağ kenar ortası: yelpazenin kökü.
    let selectedAnchor: CGPoint

    @MainActor
    init(store: VaultStore, top: CGFloat, columnX: CGFloat, card: CGSize) {
        let graph = store.graph
        let step: CGFloat = 54
        var y = top
        var rows: [Row] = []
        let typeOrder: [NoteCategory] = [.fact, .person, .task, .chat, .daily]
        let byID = Dictionary(uniqueKeysWithValues: graph.clusters.map { ($0.id, $0) })

        let typeClusters = typeOrder.compactMap { byID[$0.rawValue] }.filter { !$0.noteIDs.isEmpty }
        if !typeClusters.isEmpty {
            rows.append(Row(id: "h:türler", kind: .header("Türler", nil), y: y))
            y += 16
            for cluster in typeClusters {
                rows.append(Row(id: cluster.id, kind: .card, y: y, cluster: cluster, title: cluster.category.pluralTitle))
                y += step
            }
            y += 8
        }

        // Projeler: başlık + alt kümeler (not sayısına göre azalan).
        let total = max(graph.stats.noteCount, 1)
        let projects = Dictionary(grouping: graph.clusters.filter { $0.category == .project }) { cluster in
            String(cluster.id.dropFirst("project:".count).split(separator: "/").first ?? "")
        }
        for (project, clusters) in projects.sorted(by: { $0.value.reduce(0) { $0 + $1.noteIDs.count } > $1.value.reduce(0) { $0 + $1.noteIDs.count } }) {
            let count = clusters.reduce(0) { $0 + $1.noteIDs.count }
            let fraction = Double(count) / Double(total)
            rows.append(Row(id: "h:\(project)", kind: .header(project, .init(text: "\(count)·%\(Int((fraction * 100).rounded()))", fraction: fraction)), y: y))
            y += 26
            for cluster in clusters.sorted(by: { $0.noteIDs.count > $1.noteIDs.count }) {
                let title = cluster.id.contains("/") ? cluster.title : "Diğer"
                rows.append(Row(id: cluster.id, kind: .card, y: y, cluster: cluster, title: title))
                y += step
            }
            y += 8
        }

        let empty = typeOrder.filter { graph.stats.count($0) == 0 }
        if !empty.isEmpty {
            rows.append(Row(id: "boş", kind: .empty(empty), y: y + 4))
        }
        self.rows = rows
        let active = store.activeCluster
        self.active = active
        let selectedRow = rows.first { $0.kind == .card && $0.cluster?.id == active?.id }
        selectedAnchor = CGPoint(x: columnX + card.width, y: (selectedRow?.y ?? 400) + card.height / 2)
    }
}

// MARK: - Yelpaze yerleşimi

private struct FanLayout {
    struct Item: Identifiable {
        let note: Note
        let rank: Int
        let degree: Int
        let point: CGPoint
        let barWidth: CGFloat
        var id: Note.ID { note.id }
    }

    struct More {
        let x: CGFloat
        let y: CGFloat
        let remaining: Int
    }

    let origin: CGPoint
    let items: [Item]
    let more: More?

    @MainActor
    init(store: VaultStore, origin: CGPoint, limit: Int, step: CGFloat, ry: CGFloat) {
        let notes = store.activeCluster.map { store.rankedNotes(in: $0) } ?? []
        let shown = Array(notes.prefix(limit))
        // Yelpaze seçili kartın hizasında; düzlemin dışına taşmasın.
        let span = CGFloat(max(shown.count - 1, 0)) * step
        let extra: CGFloat = notes.count > limit ? step + 4 : 0
        let top = min(max(origin.y - span / 2, 60), 860 - span - extra)
        let center = top + span / 2
        self.origin = origin
        items = shown.enumerated().map { k, note in
            let y = top + CGFloat(k) * step
            let d = (y - center) / ry
            let x = (470 + 150 * sqrt(max(0, 1 - d * d))).rounded()
            return Item(note: note, rank: k + 1, degree: store.graph.degree(of: note.id),
                        point: CGPoint(x: x, y: y), barWidth: max(6, 34 - CGFloat(k) * 1.8))
        }
        if notes.count > limit {
            let y = top + CGFloat(shown.count) * step + 4
            let d = min(1, (y - center) / ry)
            more = More(x: (470 + 150 * sqrt(max(0, 1 - d * d))).rounded(), y: y, remaining: notes.count - limit)
        } else {
            more = nil
        }
    }

    func branch(to point: CGPoint) -> Path {
        var path = Path()
        path.move(to: origin)
        path.addCurve(to: point, control1: CGPoint(x: origin.x + 70, y: origin.y), control2: CGPoint(x: point.x - 80, y: point.y))
        return path
    }
}

// MARK: - Küçük bileşenler

private struct CategoryCard: View {
    @Environment(\.palette) private var palette
    @State private var isHovered = false
    let cluster: Cluster
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                CategoryTile(category: cluster.category)
                VStack(alignment: .leading, spacing: 0) {
                    Text(BeyinFormat.number(cluster.noteIDs.count))
                        .font(.system(size: 20, weight: .light).monospacedDigit())
                        .foregroundStyle(palette.t1)
                    Text(title)
                        .font(.system(size: 11))
                        .foregroundStyle(isSelected ? palette.t1 : palette.t2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? palette.goldFill : (isHovered ? palette.chip : palette.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? palette.gold : (isHovered ? palette.chipStroke : palette.cardStroke), lineWidth: 1)
            )
            .shadow(color: isSelected ? palette.goldGlow : .clear, radius: 12)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(title), \(cluster.noteIDs.count) not")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Boş tür: tıklanamaz kesikli çip (Kurallar · 3).
private struct EmptyCategoryChip: View {
    @Environment(\.palette) private var palette
    let category: NoteCategory

    var body: some View {
        HStack(spacing: 6) {
            Dot(color: category.color(palette).opacity(0.6), size: 6)
            Text("\(category.title) · 0")
        }
        .font(.system(size: 11))
        .foregroundStyle(palette.t3)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .overlay(Capsule().strokeBorder(palette.chipStroke, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        .help("Henüz \(category.title.lowercased()) notu yok. Obsidian’da yazıldıkça burada belirir.")
        .accessibilityLabel("\(category.title): henüz not yok")
    }
}

/// Proje başlığındaki pay çubuğu ("370 · %97").
private struct ShareBar: View {
    @Environment(\.palette) private var palette
    let fraction: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(palette.chip)
            Capsule().fill(NoteCategory.project.color(palette)).frame(width: 22 * max(0.06, min(fraction, 1)))
        }
        .frame(width: 22, height: 4)
        .accessibilityHidden(true)
    }
}

private struct FanItemView: View {
    @Environment(\.palette) private var palette
    let item: FanLayout.Item
    let isSelected: Bool
    let isLit: Bool
    let select: () -> Void
    let open: () -> Void
    let hover: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(isSelected ? palette.gold : item.note.category.color(palette))
                .frame(width: 8, height: 8)
                .shadow(color: isSelected ? palette.goldGlow : item.note.category.color(palette).opacity(0.6), radius: isSelected ? 7 : 5)
                .padding(.top, 8)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    Text(String(format: "%02d", item.rank)).foregroundStyle(palette.t3).monospacedDigit()
                    Text(" · ").foregroundStyle(palette.t3)
                    Text(item.note.title)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected || isLit ? palette.t1 : palette.t2)
                    if item.note.isPrivate {
                        Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(palette.t3).padding(.leading, 3)
                    }
                }
                .font(.system(size: 11.5))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
                HStack(spacing: 6) {
                    Chip("\(item.degree) bağ", height: 15)
                    Capsule()
                        .fill(LinearGradient(colors: [palette.teal, palette.violet2], startPoint: .leading, endPoint: .trailing))
                        .frame(width: item.barWidth, height: 3)
                        .opacity(0.75)
                }
            }
        }
        .opacity(item.note.isPrivate ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: open)
        .onTapGesture(count: 1, perform: select)
        .onHover(perform: hover)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.rank). \(item.note.title), \(item.degree) bağlantı")
        .accessibilityAddTraits(.isButton)
    }
}
