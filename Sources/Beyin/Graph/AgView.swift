import BeyinCore
import SwiftUI

/// Ağ görünümü (⌘2): kuvvet yönelimli ağ, tek Canvas katmanında.
/// Üzerine gelince komşular parlar, gerisi söner; tıkla seç, çift tıkla Obsidian'da aç.
struct AgView: View {
    let store: VaultStore

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ShellState.self) private var shell
    @State private var hovered: Note.ID?
    @State private var pan: CGSize = .zero
    @State private var panAtDragStart: CGSize?
    @State private var zoomAtPinchStart: Double?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            // Küme etiketleri ve haleler için kenar payı.
            let bounds = store.network.bounds.insetBy(dx: -40, dy: -48)
            let transform = GraphTransform(bounds: bounds, in: size, zoom: store.zoom, pan: pan, trailingOcclusion: occlusion)
            let scene = AgScene(store: store, hovered: hovered, palette: palette)
            ZStack(alignment: .topLeading) {
                Canvas(rendersAsynchronously: true) { context, _ in
                    scene.draw(in: &context, transform: transform)
                }
                .accessibilityHidden(true)

                orb(transform: transform, focus: scene.focus)

                if let id = hovered, let note = store.graph.note(id), let point = store.network.positions[id] {
                    HoverCard(note: note, degree: store.graph.degree(of: id), cluster: note.placeTitle)
                        .position(cardPosition(for: transform.apply(point), in: size))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                header
                    .padding(.leading, 18)
                    .padding(.top, 66)

                MiniMap(store: store, transform: transform, canvasSize: size)
                    .frame(width: 164, height: 104)
                    .position(x: size.width - 16 - 82, y: size.height - 110 - 52)
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let hit = scene.hitTest(location, transform: transform)
                    if hit != hovered { withAnimation(Motion.resolve(Motion.hoverIn, reduce: reduceMotion)) { hovered = hit } }
                case .ended:
                    withAnimation(Motion.resolve(Motion.hoverOut, reduce: reduceMotion)) { hovered = nil }
                }
            }
            .gesture(SpatialTapGesture(count: 2).onEnded { value in
                if let id = scene.hitTest(value.location, transform: transform) { store.openInObsidian(id) }
            })
            .simultaneousGesture(SpatialTapGesture(count: 1).onEnded { value in
                let hit = scene.hitTest(value.location, transform: transform)
                withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { store.selection = hit }
            })
            .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                let start = panAtDragStart ?? pan
                panAtDragStart = start
                pan = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
            }.onEnded { _ in panAtDragStart = nil })
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                let start = zoomAtPinchStart ?? store.zoom
                zoomAtPinchStart = start
                store.zoom = start * value.magnification
            }.onEnded { _ in zoomAtPinchStart = nil })
            .onChange(of: store.zoom) { _, zoom in
                if zoom == 1 { withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { pan = .zero } }
            }
            // Odak kamerası: seçilen not görünür alanın dışında ya da kenarındaysa ortaya kaydır.
            .onChange(of: store.selection) { _, id in
                guard let id, let point = store.network.positions[id] else { return }
                let screen = transform.apply(point)
                let comfortable = CGRect(origin: .zero, size: size)
                    .inset(by: GraphTransform.canvasInsets)
                    .inset(by: EdgeInsets(top: 40, leading: 60, bottom: 40, trailing: 60 + occlusion))
                guard !comfortable.contains(screen) else { return }
                let target = GraphTransform.visibleCenter(in: size, trailingOcclusion: occlusion)
                withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) {
                    pan = CGSize(width: pan.width + target.x - screen.x, height: pan.height + target.y - screen.y)
                }
            }
            .onAppear { centerSelectionIfHidden(size: size, transform: transform) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ağ görünümü: \(store.graph.stats.noteCount) not, \(store.graph.stats.linkCount) bağlantı")
    }

    /// Yüzen inceleme panelinin tuvali örttüğü genişlik (ShellState.canvasTrailingOcclusion).
    private var occlusion: CGFloat { shell.canvasTrailingOcclusion }

    /// Görünüm açılırken seçili not örtülü kalıyorsa onu ortaya getir (animasyonsuz).
    private func centerSelectionIfHidden(size: CGSize, transform: GraphTransform) {
        guard let id = store.selection, let point = store.network.positions[id] else { return }
        let screen = transform.apply(point)
        let visible = CGRect(origin: .zero, size: size)
            .inset(by: GraphTransform.canvasInsets)
            .inset(by: EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: occlusion))
        guard !visible.contains(screen) else { return }
        let target = GraphTransform.visibleCenter(in: size, trailingOcclusion: occlusion)
        pan = CGSize(width: pan.width + target.x - screen.x, height: pan.height + target.y - screen.y)
    }

    // MARK: Parçalar

    private var header: some View {
        let stats = store.graph.stats
        return VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Ağ")
            HStack(spacing: 4) {
                stat(stats.noteCount, "not")
                Text("·").foregroundStyle(palette.t3)
                stat(stats.linkCount, "bağlantı")
                Text("·").foregroundStyle(palette.t3)
                stat(stats.isolatedCount, "bağlantısız")
            }
            .font(BeyinFont.body)
        }
    }

    private func stat(_ value: Int, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(BeyinFormat.number(value)).fontWeight(.semibold).foregroundStyle(palette.t1).monospacedDigit()
            Text(label).foregroundStyle(palette.t2)
        }
    }

    /// Çekirdek orbu: grafiğin merkezinde (yerleşimde 0,0), boyu yakınlaştırmayla.
    private func orb(transform: GraphTransform, focus: Note.ID?) -> some View {
        let center = transform.apply(.zero)
        let diameter = min(max(54 * transform.scale, 30), 110)
        let isCoreFocused = focus.flatMap { store.graph.note($0) }?.category == .core
        return ZStack {
            DottedRing(diameter: diameter * 2.2)
            OrbView(size: diameter, phase: isCoreFocused ? .focused : (focus == nil ? .idle : .dimmed))
            Text("Ben")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(palette.t1)
                .offset(y: diameter / 2 + 12)
        }
        .position(center)
        .allowsHitTesting(false)
    }

    private func cardPosition(for point: CGPoint, in size: CGSize) -> CGPoint {
        let x = min(max(point.x + 118, 112), size.width - 112)
        let y = min(max(point.y - 34, 40), size.height - 40)
        return CGPoint(x: x, y: y)
    }
}

/// Bir karede çizilecek her şey; Canvas kapanışı yalnız buna dokunur.
private struct AgScene {
    let graph: VaultGraph
    let layout: NetworkLayout
    let visible: Set<Note.ID>
    let focus: Note.ID?
    let lit: Set<Note.ID>
    let highlighted: Set<Note.ID>
    let palette: Palette
    let coreID: Note.ID?

    @MainActor
    init(store: VaultStore, hovered: Note.ID?, palette: Palette) {
        graph = store.graph
        layout = store.network
        visible = store.visibleNoteIDs
        focus = hovered ?? store.selection
        highlighted = store.highlighted
        self.palette = palette
        coreID = store.graph.notes.values.first { $0.category == .core && $0.title.lowercased() == "core" }?.id
        if let focus {
            lit = graph.neighbors(of: focus).union([focus])
        } else {
            lit = []
        }
    }

    /// Bir şey seçili ya da aranmışsa geri kalanı söner.
    private var dimsOthers: Bool { focus != nil || !highlighted.isEmpty }

    private func isLit(_ id: Note.ID) -> Bool {
        lit.contains(id) || highlighted.contains(id)
    }

    func draw(in context: inout GraphicsContext, transform t: GraphTransform) {
        var placer = LabelPlacer()
        // Orb ve "Ben" etiketi için yer ayır.
        let orb = t.apply(.zero)
        _ = placer.reserve(CGRect(x: orb.x - 30, y: orb.y - 30, width: 60, height: 76))
        drawClusters(&context, t, placer: &placer)
        drawEdges(&context, t)
        drawNodes(&context, t)
        drawLabels(&context, t, placer: &placer)
    }

    private func drawClusters(_ context: inout GraphicsContext, _ t: GraphTransform, placer: inout LabelPlacer) {
        let focusCluster = focus.flatMap { graph.note($0) }.map(\.clusterID)
        for shape in layout.clusters where shape.category != .core {
            let c = t.apply(shape.center)
            let r = shape.radius * t.scale
            let halo = CGRect(x: c.x - r * 1.35, y: c.y - r * 1.2, width: r * 2.7, height: r * 2.4)
            let tint = shape.id == focusCluster ? palette.gold : shape.color(palette)
            context.fill(Path(ellipseIn: halo), with: .radialGradient(
                Gradient(colors: [tint.opacity(0.10), .clear]), center: c, startRadius: 0, endRadius: r * 1.35))
            let ring = CGRect(x: c.x - r - 6, y: c.y - (r + 6) * 0.9, width: (r + 6) * 2, height: (r + 6) * 1.8)
            context.stroke(Path(ellipseIn: ring), with: .color(palette.edge.opacity(0.6)),
                           style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
            // Küme etiketi: üst kenarda çip.
            let name = Text(shape.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(shape.id == focusCluster ? palette.t1 : palette.t2)
            let count = Text(BeyinFormat.number(shape.count))
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(palette.t3)
            let label = Text("\(name)  \(count)")
            let at = CGPoint(x: c.x, y: c.y - (r + 6) * 0.9 - 12)
            let width = LabelPlacer.estimatedWidth("\(shape.title)  \(shape.count)")
            guard placer.reserve(CGRect(x: at.x - width / 2, y: at.y - 7, width: width, height: 14)) else { continue }
            context.opacity = shape.id == focusCluster ? 1 : 0.7
            context.draw(label, at: at, anchor: .center)
            context.opacity = 1
        }
    }

    private func drawEdges(_ context: inout GraphicsContext, _ t: GraphTransform) {
        var dim = Path(), hot = Path()
        for (i, edge) in graph.edges.enumerated() {
            guard visible.contains(edge.source), visible.contains(edge.target),
                  let a = layout.positions[edge.source], let b = layout.positions[edge.target] else { continue }
            let path = curvedEdge(from: t.apply(a), to: t.apply(b), bend: i.isMultiple(of: 2) ? 0.12 : -0.12)
            if let focus, edge.source == focus || edge.target == focus {
                hot.addPath(path)
            } else {
                dim.addPath(path)
            }
        }
        context.stroke(dim, with: .color(dimsOthers ? palette.edgeDim : palette.edge.opacity(0.55)), lineWidth: 0.8)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: palette.gold.opacity(0.8), radius: 2.4))
            layer.stroke(hot, with: .color(palette.gold.opacity(0.95)), lineWidth: 1.4)
        }
    }

    private func drawNodes(_ context: inout GraphicsContext, _ t: GraphTransform) {
        for (id, point) in layout.positions where visible.contains(id) && id != coreID {
            guard let note = graph.note(id) else { continue }
            let degree = graph.degree(of: id)
            let p = t.apply(point)
            var d = note.category == .core ? 7 : nodeDiameter(degree: degree)
            if id == focus { d = max(d, 12) }
            d *= min(max(t.scale, 0.7), 1.6)
            let color = note.category.color(palette)
            var opacity: Double = degree == 0 ? 0.3 : 1
            if note.isPrivate { opacity = min(opacity, 0.4) }
            if dimsOthers && !isLit(id) { opacity = min(opacity, 0.2) }
            context.opacity = opacity
            if degree > 0 || id == focus {
                let g = d * 1.8
                context.fill(Path(ellipseIn: CGRect(x: p.x - g, y: p.y - g, width: g * 2, height: g * 2)),
                             with: .radialGradient(Gradient(colors: [color.opacity(0.45), .clear]),
                                                   center: p, startRadius: 0, endRadius: g))
            }
            context.fill(Path(ellipseIn: CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)), with: .color(color))
            if id == focus || highlighted.contains(id) {
                context.opacity = 1
                let ring = CGRect(x: p.x - d / 2 - 2, y: p.y - d / 2 - 2, width: d + 4, height: d + 4)
                context.stroke(Path(ellipseIn: ring), with: .color(palette.gold), lineWidth: 2)
                let outer = ring.insetBy(dx: -4, dy: -4)
                context.stroke(Path(ellipseIn: outer), with: .color(palette.gold.opacity(0.16)), lineWidth: 4)
            }
            context.opacity = 1
        }
    }

    private func drawLabels(_ context: inout GraphicsContext, _ t: GraphTransform, placer: inout LabelPlacer) {
        // Öncelik: odak, komşuları, arama sonuçları, en çok bağlantılılar, çekirdek (Kurallar · 04: ~30 etiket).
        var order: [Note.ID] = []
        if let focus { order.append(focus) }
        order += lit.sorted { graph.degree(of: $0) > graph.degree(of: $1) }
        order += highlighted.sorted { graph.degree(of: $0) > graph.degree(of: $1) }
        order += graph.stats.topConnected.prefix(12).map(\.id)
        order += graph.notes.values.filter { $0.category == .core && $0.id != coreID }.map(\.id).sorted()
        var seen = Set<Note.ID>()
        let center = t.apply(.zero)
        for id in order where visible.contains(id) && seen.insert(id).inserted && seen.count <= 30 {
            guard let note = graph.note(id), let point = layout.positions[id] else { continue }
            let p = t.apply(point)
            let hot = isLit(id) || id == focus
            let width = LabelPlacer.estimatedWidth(note.title)
            // Çekirdek uyduları merkezden dışa doğru yazılır; diğerleri sağa.
            let leftward = note.category == .core && p.x < center.x
            let anchorPoint = CGPoint(x: leftward ? p.x - 9 : p.x + 9, y: p.y - 9)
            let rect = CGRect(x: leftward ? anchorPoint.x - width : anchorPoint.x, y: anchorPoint.y - 7, width: width, height: 14)
            guard placer.reserve(rect) || id == focus else { continue }
            let text = Text(note.title)
                .font(.system(size: 10.5, weight: hot ? .semibold : .medium))
                .foregroundStyle(hot ? palette.t1 : palette.t2)
            context.opacity = dimsOthers && !hot ? 0.42 : 1
            context.draw(text, at: anchorPoint, anchor: leftward ? .trailing : .leading)
        }
        context.opacity = 1
    }

    /// Ekran noktasına en yakın düğüm (yarıçap içinde).
    func hitTest(_ location: CGPoint, transform t: GraphTransform) -> Note.ID? {
        var best: (Note.ID, CGFloat)?
        for (id, point) in layout.positions where visible.contains(id) {
            let p = t.apply(point)
            let distance = hypot(p.x - location.x, p.y - location.y)
            let reach = id == coreID ? 30 : max(8, nodeDiameter(degree: graph.degree(of: id)) / 2 + 5)
            if distance <= reach, distance < (best?.1 ?? .infinity) { best = (id, distance) }
        }
        return best?.0
    }
}

/// Üzerine gelme kartı (Ağ maketi).
private struct HoverCard: View {
    @Environment(\.palette) private var palette
    let note: Note
    let degree: Int
    let cluster: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Dot(color: note.category.color(palette), size: 7)
                Text(note.title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(palette.t1).lineLimit(1)
                if note.isPrivate { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(palette.t3) }
            }
            Text("\(note.category.title) · \(cluster) · \(degree) bağlantı")
                .font(.system(size: 11)).foregroundStyle(palette.t3).lineLimit(1)
            Divider().overlay(palette.hair)
            Text("Tıkla: odak · Çift tıkla: Obsidian’da aç")
                .font(.system(size: 10.5)).foregroundStyle(palette.t3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 206, alignment: .leading)
        .labelGlass(cornerRadius: 14)
    }
}

/// Mini harita: tüm notlar küçültülmüş, görünür alan altın çerçeve.
private struct MiniMap: View {
    @Environment(\.palette) private var palette
    let store: VaultStore
    let transform: GraphTransform
    let canvasSize: CGSize

    var body: some View {
        Canvas { context, size in
            let bounds = store.network.bounds.insetBy(dx: -20, dy: -20)
            guard bounds.width > 0, bounds.height > 0 else { return }
            let s = min(size.width / bounds.width, size.height / bounds.height)
            let ox = (size.width - bounds.width * s) / 2 - bounds.minX * s
            let oy = (size.height - bounds.height * s) / 2 - bounds.minY * s
            for (id, p) in store.network.positions {
                guard let note = store.graph.note(id) else { continue }
                let q = CGPoint(x: ox + p.x * s, y: oy + p.y * s)
                context.fill(Path(ellipseIn: CGRect(x: q.x - 1, y: q.y - 1, width: 2, height: 2)),
                             with: .color(note.category.color(palette).opacity(0.8)))
            }
            // Ekranda görünen alanın yerleşimdeki karşılığı.
            let topLeft = CGPoint(x: -transform.offset.x / transform.scale, y: -transform.offset.y / transform.scale)
            let visible = CGRect(x: ox + topLeft.x * s, y: oy + topLeft.y * s,
                                 width: canvasSize.width / transform.scale * s, height: canvasSize.height / transform.scale * s)
            context.stroke(Path(roundedRect: visible.intersection(CGRect(origin: .zero, size: size)), cornerRadius: 5),
                           with: .color(palette.gold), lineWidth: 1)
        }
        .padding(6)
        .panelGlass(cornerRadius: 14)
        .accessibilityLabel("Mini harita")
    }
}
