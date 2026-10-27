import BeyinCore
import SwiftUI
import simd

/// Küre görünümü (⌘3): notlar dönen bir kürenin yüzeyinde, kümeler "kıta" gibi.
/// Ortografik izdüşüm, Canvas ile (Veri kuralları · 05); SceneKit yok.
struct KureView: View {
    let store: VaultStore

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var yawOffset: Double = 32
    @State private var tilt: Double = 0.38
    @State private var autoRotate = true
    @State private var density: LabelDensity = .medium
    @State private var hovered: Note.ID?
    @State private var dragStart: (yaw: Double, tilt: Double)?
    @State private var rotationStart = Date()

    enum LabelDensity: String, CaseIterable, Identifiable {
        case low = "Az", medium = "Orta", high = "Çok"
        var id: String { rawValue }
        var noteLabels: Int {
            switch self {
            case .low: 0
            case .medium: 8
            case .high: 20
            }
        }
    }

    private var isRotating: Bool { autoRotate && !reduceMotion && dragStart == nil && hovered == nil }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !isRotating)) { timeline in
                let yaw = currentYaw(at: timeline.date)
                let globe = Globe(center: CGPoint(x: size.width / 2, y: min(size.height * 0.47, size.height - 300)),
                                  radius: min(250, min(size.width - 600, size.height - 220) / 2).clamped(140, 250) * store.zoom,
                                  yaw: yaw * .pi / 180, tilt: tilt)
                let scene = KureScene(store: store, globe: globe, hovered: hovered, palette: palette)
                ZStack(alignment: .topLeading) {
                    Canvas(rendersAsynchronously: true) { context, _ in
                        scene.draw(in: &context)
                    }
                    .accessibilityHidden(true)

                    ForEach(scene.labels(density: density)) { label in
                        RegionLabel(label: label)
                            .position(label.point)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location): hovered = scene.hitTest(location)
                    case .ended: hovered = nil
                    }
                }
                .gesture(SpatialTapGesture(count: 2).onEnded { value in
                    if let id = scene.hitTest(value.location) { store.openInObsidian(id) }
                })
                .simultaneousGesture(SpatialTapGesture(count: 1).onEnded { value in
                    withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { store.selection = scene.hitTest(value.location) }
                })
                .simultaneousGesture(DragGesture(minimumDistance: 3).onChanged { value in
                    let start = dragStart ?? (yaw, tilt)
                    if dragStart == nil { dragStart = start }
                    if NSEvent.modifierFlags.contains(.option) {
                        tilt = (start.tilt + value.translation.height * 0.006).clamped(-1.2, 1.2)
                    } else {
                        yawOffset = start.yaw + value.translation.width * 0.4
                        rotationStart = .now
                    }
                }.onEnded { _ in dragStart = nil; rotationStart = .now })
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    store.zoom = (store.zoom * (1 + (value.magnification - 1) * 0.08))
                })
            }

            KasaHUD(store: store, autoRotate: $autoRotate, density: $density)
                .frame(width: 260)
                .position(x: 16 + 130, y: 70 + hudHeight(size) / 2)
                .frame(maxHeight: .infinity, alignment: .top)

            RecentHUD(store: store)
                .frame(width: 260)
                .position(x: size.width - 16 - 130, y: 70 + 170)

            Text("Sürükle: döndür · ⌥ sürükle: eğ · Tıkla: odak · Çift tıkla: Obsidian’da aç")
                .font(.system(size: 11))
                .foregroundStyle(palette.t3)
                .position(x: size.width / 2, y: size.height - 150)
                .allowsHitTesting(false)
        }
        .onChange(of: autoRotate) { _, on in
            if on { rotationStart = .now }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Küre görünümü")
    }

    private func hudHeight(_ size: CGSize) -> CGFloat { min(520, size.height - 220) }

    /// Otomatik dönüş: 6°/sn; sürüklenince kaldığı yerden devam eder.
    private func currentYaw(at date: Date) -> Double {
        guard isRotating else { return yawOffset }
        return yawOffset + date.timeIntervalSince(rotationStart) * 6
    }
}

// MARK: - İzdüşüm

private struct Globe {
    let center: CGPoint
    let radius: CGFloat
    let yaw: Double
    let tilt: Double

    /// Önce y ekseni çevresinde dönüş, sonra x ekseni çevresinde eğim; ortografik.
    func project(_ v: SIMD3<Double>) -> (point: CGPoint, z: Double) {
        let x = v.x * cos(yaw) + v.z * sin(yaw)
        let z0 = -v.x * sin(yaw) + v.z * cos(yaw)
        let y = v.y * cos(tilt) - z0 * sin(tilt)
        let z = v.y * sin(tilt) + z0 * cos(tilt)
        return (CGPoint(x: center.x + radius * x, y: center.y - radius * y), z)
    }
}

private struct KureScene {
    struct Projected {
        let id: Note.ID
        let note: Note
        let point: CGPoint
        let z: Double
        let diameter: CGFloat
    }

    struct Label: Identifiable {
        let id: String
        let text: String
        let count: Int?
        let color: Color
        let point: CGPoint
        let isRegion: Bool
        let isLit: Bool
    }

    let graph: VaultGraph
    let sphere: SphereLayout
    let visible: Set<Note.ID>
    let highlighted: Set<Note.ID>
    let globe: Globe
    let palette: Palette
    let focus: Note.ID?
    let lit: Set<Note.ID>
    let nodes: [Projected]

    @MainActor
    init(store: VaultStore, globe: Globe, hovered: Note.ID?, palette: Palette) {
        graph = store.graph
        sphere = store.sphere
        highlighted = store.highlighted
        self.globe = globe
        self.palette = palette
        let focus = hovered ?? store.selection
        self.focus = focus
        lit = focus.map { store.graph.neighbors(of: $0).union([$0]) } ?? []
        let visible = store.visibleNoteIDs
        self.visible = visible
        let hubs = Set(store.graph.stats.topConnected.prefix(12).map(\.id))
        nodes = store.sphere.points.compactMap { id, v in
            guard visible.contains(id), let note = store.graph.note(id) else { return nil }
            let (p, z) = globe.project(v)
            let base: CGFloat = note.category == .core ? 7 : (hubs.contains(id) ? 7 : (note.category == .project ? 2.8 : 3.6))
            return Projected(id: id, note: note, point: p, z: z, diameter: z < 0 ? 1.8 : base)
        }
        .sorted { $0.z < $1.z }
    }

    func draw(in context: inout GraphicsContext) {
        let c = globe.center, r = globe.radius
        // Küre gövdesi: hafif ışıma ve kenar.
        let body = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        context.fill(Path(ellipseIn: CGRect(x: c.x - r * 1.3, y: c.y - r * 1.3, width: 2.6 * r, height: 2.6 * r)),
                     with: .radialGradient(Gradient(colors: [palette.violet.opacity(0.16), .clear]), center: c, startRadius: r * 0.6, endRadius: r * 1.3))
        context.fill(body, with: .radialGradient(Gradient(colors: [palette.violet.opacity(0.10), palette.bg2.opacity(0.35)]),
                                                 center: CGPoint(x: c.x - r * 0.3, y: c.y - r * 0.35), startRadius: 0, endRadius: r * 1.2))
        context.stroke(body, with: .color(palette.violet2.opacity(0.28)), lineWidth: 1)
        drawGrid(&context)
        drawEdges(&context)
        for node in nodes {
            let color = node.note.category.color(palette)
            var opacity: Double = node.z < 0 ? 0.10 : 1
            if graph.degree(of: node.id) == 0 && node.z >= 0 { opacity = 0.55 }
            if node.note.isPrivate { opacity = min(opacity, 0.4) }
            if (focus != nil || !highlighted.isEmpty) && !lit.contains(node.id) && !highlighted.contains(node.id) {
                opacity = min(opacity, 0.22)
            }
            context.opacity = opacity
            let d = node.diameter
            if node.z >= 0 && d >= 7 {
                let g = d * 1.8
                context.fill(Path(ellipseIn: CGRect(x: node.point.x - g, y: node.point.y - g, width: 2 * g, height: 2 * g)),
                             with: .radialGradient(Gradient(colors: [color.opacity(0.5), .clear]), center: node.point, startRadius: 0, endRadius: g))
            }
            context.fill(Path(ellipseIn: CGRect(x: node.point.x - d / 2, y: node.point.y - d / 2, width: d, height: d)), with: .color(color))
            if node.id == focus || highlighted.contains(node.id) {
                context.opacity = 1
                let ring = CGRect(x: node.point.x - d / 2 - 3, y: node.point.y - d / 2 - 3, width: d + 6, height: d + 6)
                context.stroke(Path(ellipseIn: ring), with: .color(palette.gold), lineWidth: 2)
            }
        }
        context.opacity = 1
    }

    /// Meridyenler ve paraleller; arka yüz çok soluk.
    private func drawGrid(_ context: inout GraphicsContext) {
        var front = Path(), back = Path()
        func trace(_ points: [SIMD3<Double>]) {
            var previous: (CGPoint, Double)?
            for v in points {
                let p = globe.project(v)
                if let (q, qz) = previous {
                    var segment = Path()
                    segment.move(to: q)
                    segment.addLine(to: p.point)
                    if (qz + p.z) / 2 >= 0 { front.addPath(segment) } else { back.addPath(segment) }
                }
                previous = (p.point, p.z)
            }
        }
        for lat in stride(from: -60.0, through: 60, by: 30) {
            let phi = lat * .pi / 180
            trace((0...72).map { i in
                let t = Double(i) / 72 * 2 * .pi
                return SIMD3(cos(phi) * sin(t), sin(phi), cos(phi) * cos(t))
            })
        }
        for lon in stride(from: 0.0, to: 180, by: 30) {
            let t = lon * .pi / 180
            trace((0...72).map { i in
                let phi = Double(i) / 72 * 2 * .pi
                return SIMD3(cos(phi) * sin(t), sin(phi), cos(phi) * cos(t))
            })
        }
        context.stroke(back, with: .color(palette.edge.opacity(0.10)), lineWidth: 0.6)
        context.stroke(front, with: .color(palette.edge.opacity(0.32)), lineWidth: 0.7)
    }

    /// Bağlantılar: iki ucu da ön yüzdeyse, ortası 1.06–1.12 R yükselen büyük daire yayı.
    private func drawEdges(_ context: inout GraphicsContext) {
        var dim = Path(), hot = Path()
        for edge in graph.edges {
            guard let a = sphere.points[edge.source], let b = sphere.points[edge.target],
                  visible.contains(edge.source), visible.contains(edge.target) else { continue }
            guard globe.project(a).z > -0.05, globe.project(b).z > -0.05 else { continue }
            let lift = 1.06 + 0.06 * min(1, simd_distance(a, b) / 2)
            var path = Path()
            for i in 0...14 {
                let t = Double(i) / 14
                let v = simd_normalize(a * (1 - t) + b * t) * (1 + (lift - 1) * sin(t * .pi))
                let p = globe.project(v).point
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            if let focus, edge.source == focus || edge.target == focus { hot.addPath(path) } else { dim.addPath(path) }
        }
        context.stroke(dim, with: .color(palette.edge.opacity(focus == nil ? 0.5 : 0.18)), lineWidth: 0.7)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: palette.gold.opacity(0.7), radius: 2))
            layer.stroke(hot, with: .color(palette.gold), lineWidth: 1.3)
        }
    }

    /// Bölge etiketleri (küme adı + sayı) ve yoğunluğa göre en çok bağlantılı notlar; yalnız ön yüzde.
    func labels(density: KureView.LabelDensity) -> [Label] {
        var result: [Label] = sphere.regions.compactMap { region in
            let (p, z) = globe.project(region.center * 1.04)
            guard z > 0.15 else { return nil }
            return Label(id: "r:" + region.id, text: region.title, count: region.count,
                         color: region.category.color(palette), point: CGPoint(x: p.x, y: p.y - 14),
                         isRegion: true, isLit: false)
        }
        // Çakışma: önce bölgeler (cam etiket ~22 pt), sonra önemli notlar; çakışan atlanır.
        var placer = LabelPlacer()
        result = result.filter { label in
            let width = LabelPlacer.estimatedWidth(label.text + " \(label.count ?? 0)", fontSize: 11) + 22
            return placer.reserve(CGRect(x: label.point.x - width / 2, y: label.point.y - 11, width: width, height: 22))
        }
        let ranked = graph.stats.topConnected.prefix(density.noteLabels).map(\.id)
        let order = (focus.map { [$0] } ?? []) + ranked
        let byID = Dictionary(nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for id in order {
            guard let node = byID[id], node.z > 0.2 else { continue }
            let width = LabelPlacer.estimatedWidth(node.note.title)
            let point = CGPoint(x: node.point.x + 8 + width / 2, y: node.point.y - 12)
            guard placer.reserve(CGRect(x: point.x - width / 2, y: point.y - 7, width: width, height: 14)) || id == focus else { continue }
            result.append(Label(id: node.id, text: node.note.title, count: nil, color: node.note.category.color(palette),
                                point: point, isRegion: false, isLit: node.id == focus))
        }
        return result
    }

    func hitTest(_ location: CGPoint) -> Note.ID? {
        var best: (Note.ID, CGFloat)?
        for node in nodes where node.z >= 0 {
            let distance = hypot(node.point.x - location.x, node.point.y - location.y)
            if distance <= max(7, node.diameter / 2 + 5), distance < (best?.1 ?? .infinity) { best = (node.id, distance) }
        }
        return best?.0
    }
}

// MARK: - Etiket ve HUD'lar

private struct RegionLabel: View {
    @Environment(\.palette) private var palette
    let label: KureScene.Label

    var body: some View {
        HStack(spacing: 5) {
            if label.isRegion { Dot(color: label.color, size: 6) }
            Text(label.text)
                .font(.system(size: label.isRegion ? 11 : 10.5, weight: label.isRegion || label.isLit ? .semibold : .medium))
                .foregroundStyle(label.isRegion || label.isLit ? palette.t1 : palette.t2)
            if let count = label.count {
                Text(BeyinFormat.number(count)).font(.system(size: 10.5).monospacedDigit()).foregroundStyle(palette.t3)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, label.isRegion ? 8 : 0)
        .frame(height: label.isRegion ? 22 : 14)
        .background {
            if label.isRegion { Color.clear.labelGlass(cornerRadius: 9) }
        }
    }
}

/// Sol HUD: kasa özeti, tür dağılımı, sağlık, otomatik dönüş, etiket yoğunluğu.
private struct KasaHUD: View {
    @Environment(\.palette) private var palette
    let store: VaultStore
    @Binding var autoRotate: Bool
    @Binding var density: KureView.LabelDensity

    var body: some View {
        let stats = store.graph.stats
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionLabel("Kasa")
                Spacer()
                Text("salt okunur").font(.system(size: 11)).foregroundStyle(palette.t3)
            }
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                big(stats.noteCount, "Not")
                big(stats.linkCount, "Bağlantı")
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Tür dağılımı").font(.system(size: 12, weight: .semibold)).foregroundStyle(palette.t1)
                distributionBar(stats)
                ForEach(categoriesBySize(stats), id: \.self) { category in
                    HStack(spacing: 6) {
                        Dot(color: category.color(palette), size: 6)
                        Text(category.title).foregroundStyle(stats.count(category) == 0 ? palette.t3 : palette.t2)
                        Spacer()
                        Text(BeyinFormat.number(stats.count(category))).monospacedDigit().foregroundStyle(palette.t2)
                    }
                    .font(.system(size: 11.5))
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                row("Görünürlük", "\(stats.noteCount - stats.privateCount) internal · \(stats.privateCount) private")
                row("Çözülmemiş wikilink", BeyinFormat.number(stats.unresolvedLinkCount), warn: stats.unresolvedLinkCount > 0)
                row("Bağlantısız not", BeyinFormat.number(stats.isolatedCount), warn: false)
            }
            Divider().overlay(palette.hair)
            Toggle("Otomatik dönüş", isOn: $autoRotate)
                .toggleStyle(.switch)
                .font(.system(size: 12))
                .foregroundStyle(palette.t2)
            VStack(alignment: .leading, spacing: 6) {
                Text("Etiket yoğunluğu").font(.system(size: 12)).foregroundStyle(palette.t2)
                Picker("Etiket yoğunluğu", selection: $density) {
                    ForEach(KureView.LabelDensity.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .padding(16)
        .panelGlass(cornerRadius: 22)
    }

    private func big(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(BeyinFormat.number(value)).font(BeyinFont.hudL).foregroundStyle(palette.t1)
            Text(label).font(.system(size: 11.5)).foregroundStyle(palette.t3)
        }
    }

    private func row(_ title: String, _ value: String, warn: Bool = false) -> some View {
        HStack {
            Text(title).fontWeight(.semibold).foregroundStyle(palette.t1)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(warn ? palette.orange : palette.t3)
        }
        .font(.system(size: 12))
    }

    private func categoriesBySize(_ stats: VaultStats) -> [NoteCategory] {
        NoteCategory.allCases.sorted { stats.count($0) != stats.count($1) ? stats.count($0) > stats.count($1) : $0.title < $1.title }
    }

    private func distributionBar(_ stats: VaultStats) -> some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(categoriesBySize(stats).filter { stats.count($0) > 0 }, id: \.self) { category in
                    Rectangle()
                        .fill(category.color(palette))
                        .frame(width: max(3, proxy.size.width * CGFloat(stats.count(category)) / CGFloat(max(stats.noteCount, 1)) - 2))
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

/// Sağ HUD: son eklenen notlar ve son 7 günün sayıları.
private struct RecentHUD: View {
    @Environment(\.palette) private var palette
    let store: VaultStore

    var body: some View {
        let recent = store.graph.notes.values
            .sorted { ($0.created ?? $0.modified) > ($1.created ?? $1.modified) }
            .prefix(5)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Son eklenenler")
            VStack(spacing: 0) {
                ForEach(Array(recent)) { note in
                    let date = note.created ?? note.modified
                    Button { store.selection = note.id } label: {
                        HStack(spacing: 8) {
                            Text(Calendar.current.isDateInToday(date) ? BeyinFormat.time(date) : BeyinFormat.dayMonth(date))
                                .font(.system(size: 11).monospacedDigit())
                                .foregroundStyle(palette.t3)
                                .frame(width: 44, alignment: .leading)
                            Text(note.title).font(.system(size: 12)).foregroundStyle(palette.t1).lineLimit(1)
                            Spacer(minLength: 4)
                            Dot(color: note.category.color(palette), size: 6)
                        }
                        .frame(height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider().overlay(palette.hair)
                }
            }
            SectionLabel("Son 7 gün")
            weekBars
        }
        .padding(16)
        .panelGlass(cornerRadius: 22)
    }

    private var weekBars: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let counts: [(Date, Int)] = (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let count = store.graph.notes.values.filter { calendar.isDate($0.created ?? $0.modified, inSameDayAs: day) }.count
            return (day, count)
        }
        let maxCount = max(counts.map(\.1).max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(counts, id: \.0) { day, count in
                VStack(spacing: 4) {
                    Text(count > 0 ? BeyinFormat.number(count) : "").font(.system(size: 9).monospacedDigit()).foregroundStyle(palette.t3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [palette.teal, palette.teal.opacity(0.25)], startPoint: .top, endPoint: .bottom))
                        .frame(height: max(2, 44 * CGFloat(count) / CGFloat(maxCount)))
                    Text(BeyinFormat.weekday(day).prefix(2)).font(.system(size: 9.5)).foregroundStyle(palette.t3)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 76)
        .accessibilityLabel("Son 7 günde eklenen notlar")
    }
}

private extension Comparable {
    func clamped(_ low: Self, _ high: Self) -> Self { min(max(self, low), high) }
}
