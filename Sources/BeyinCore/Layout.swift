import CoreGraphics
import Foundation
import simd

/// Ağ görünümü için yerleşim: kümeler bir halkada, bağlı notlar kuvvet yönelimli,
/// bağlantısız notlar kümenin çevresinde ayçiçeği deseninde (soluk "yörünge").
/// Koordinatlar sanal bir düzlemde (merkez 0,0); görünüm ölçekler.
public struct NetworkLayout: Sendable {
    public struct ClusterShape: Sendable, Identifiable {
        public let id: String
        public let title: String
        public let category: NoteCategory
        public let center: CGPoint
        public let radius: Double
        public let count: Int
    }

    public var positions: [Note.ID: CGPoint]
    public var clusters: [ClusterShape]
    /// Tüm noktaları kapsayan dikdörtgen.
    public var bounds: CGRect

    public static let empty = NetworkLayout(positions: [:], clusters: [], bounds: .zero)

    /// Çekirdek notların yörünge yarıçapı (orb merkezde).
    static let coreRadius = 64.0

    public static func compute(_ graph: VaultGraph, seed: UInt64 = 1) -> NetworkLayout {
        var rng = SeededRandom(seed: seed)
        var positions: [Note.ID: CGPoint] = [:]
        var shapes: [ClusterShape] = []

        // Çekirdek: merkezde, notlar orbun çevresinde.
        let others = graph.clusters.filter { $0.category != .core }
        if let core = graph.clusters.first(where: { $0.category == .core }) {
            for (i, id) in core.noteIDs.enumerated() {
                let angle = -Double.pi / 2 + Double(i) / Double(max(core.noteIDs.count, 1)) * 2 * .pi
                positions[id] = CGPoint(x: cos(angle) * coreRadius, y: sin(angle) * coreRadius)
            }
            shapes.append(ClusterShape(id: core.id, title: core.title, category: .core, center: .zero,
                                       radius: coreRadius + 18, count: core.noteIDs.count))
        }

        // Diğer kümeler: çekirdeğin çevresinde tek halka. Büyük ve küçük kümeler sırayla dizilir;
        // her kümeye yarıçapı kadar yay payı verilir ki komşular değmesin.
        let bySize = others.sorted { $0.noteIDs.count > $1.noteIDs.count }
        var sorted: [Cluster] = []
        var low = 0, high = bySize.count - 1
        while low <= high {
            sorted.append(bySize[low]); low += 1
            if low <= high { sorted.append(bySize[high]); high -= 1 }
        }
        let radii = sorted.map { clusterRadius($0, graph: graph) }
        let gap = 34.0
        let circumference = radii.reduce(0) { $0 + 2 * $1 + gap }
        let ring = max(coreRadius + 70 + (radii.max() ?? 0), circumference / (2 * .pi))
        var angle = -Double.pi / 2
        for (cluster, radius) in zip(sorted, radii) {
            let span = (2 * radius + gap) / circumference * 2 * .pi
            let mid = angle + span / 2
            angle += span
            let center = CGPoint(x: cos(mid) * ring, y: sin(mid) * ring)
            shapes.append(ClusterShape(id: cluster.id, title: cluster.title, category: cluster.category,
                                       center: center, radius: radius, count: cluster.noteIDs.count))
            place(cluster, center: center, graph: graph, rng: &rng, into: &positions)
        }

        relaxConnected(graph, shapes: shapes, positions: &positions)
        placeIsolated(graph, shapes: shapes, positions: &positions)

        let xs = positions.values.map(\.x), ys = positions.values.map(\.y)
        let bounds = xs.isEmpty ? .zero : CGRect(x: xs.min()!, y: ys.min()!,
                                                  width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        return NetworkLayout(positions: positions, clusters: shapes, bounds: bounds)
    }

    /// Bağlı kısım için alan + bağlantısızların ayçiçeği bandı.
    static func clusterRadius(_ cluster: Cluster, graph: VaultGraph) -> Double {
        let connected = cluster.noteIDs.filter { graph.degree(of: $0) > 0 }.count
        let isolated = cluster.noteIDs.count - connected
        let inner = connected > 0 ? 22 + 11 * sqrt(Double(connected)) : 0
        return inner + 10 + 5.2 * sqrt(Double(isolated))
    }

    private static func place(_ cluster: Cluster, center: CGPoint, graph: VaultGraph, rng: inout SeededRandom,
                              into positions: inout [Note.ID: CGPoint]) {
        for id in cluster.noteIDs where graph.degree(of: id) > 0 {
            let r = rng.next() * 30
            let a = rng.next() * 2 * .pi
            positions[id] = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        }
    }

    /// Bağlı notlar: itme (O(n²), yalnız bağlı notlar), kenar yayı, kendi kümesine çekim.
    private static func relaxConnected(_ graph: VaultGraph, shapes: [ClusterShape],
                                       positions: inout [Note.ID: CGPoint]) {
        let coreIDs = Set(graph.clusters.first { $0.category == .core }?.noteIDs ?? [])
        let ids = positions.keys.filter { !coreIDs.contains($0) && graph.degree(of: $0) > 0 }.sorted()
        guard ids.count > 1 else { return }
        let index = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        var p = ids.map { positions[$0]! }
        let homes: [CGPoint] = ids.map { id in
            let cid = graph.notes[id].map { GraphBuilder.clusterID(for: $0).0 } ?? ""
            return shapes.first { $0.id == cid }?.center ?? .zero
        }
        let springs: [(Int, Int)] = graph.edges.compactMap { edge in
            guard let a = index[edge.source], let b = index[edge.target] else { return nil }
            return (a, b)
        }
        var temperature = 12.0
        for _ in 0..<260 {
            var force = [CGVector](repeating: .zero, count: p.count)
            for i in 0..<p.count {
                for j in (i + 1)..<p.count {
                    var dx = p[i].x - p[j].x, dy = p[i].y - p[j].y
                    var d2 = dx * dx + dy * dy
                    if d2 < 0.01 { dx = 0.1; dy = 0.1; d2 = 0.02 }
                    let f = 90 / d2
                    force[i].dx += dx * f; force[i].dy += dy * f
                    force[j].dx -= dx * f; force[j].dy -= dy * f
                }
            }
            for (a, b) in springs {
                let dx = p[b].x - p[a].x, dy = p[b].y - p[a].y
                let d = max(sqrt(dx * dx + dy * dy), 0.01)
                let f = (d - 24) * 0.05 / d
                force[a].dx += dx * f; force[a].dy += dy * f
                force[b].dx -= dx * f; force[b].dy -= dy * f
            }
            for i in 0..<p.count {
                force[i].dx += (homes[i].x - p[i].x) * 0.07
                force[i].dy += (homes[i].y - p[i].y) * 0.07
                let len = max(sqrt(force[i].dx * force[i].dx + force[i].dy * force[i].dy), 0.0001)
                let step = min(len, temperature)
                p[i].x += force[i].dx / len * step
                p[i].y += force[i].dy / len * step
            }
            temperature = max(temperature * 0.985, 0.6)
        }
        // Kümeler arası bağlantılar notu kümesinden çekip çıkarmasın: her kümenin bağlı kısmı
        // kendi alanına sığana dek bütün olarak küçültülür (biçim korunur, kenarda yığılma olmaz).
        var members: [String: [Int]] = [:]
        for (i, home) in homes.enumerated() { members["\(home.x),\(home.y)", default: []].append(i) }
        for indices in members.values {
            let home = homes[indices[0]]
            let shape = shapes.first { $0.center == home }
            let connected = Double(indices.count)
            let limit = shape.map { _ in 22 + 11 * sqrt(connected) } ?? 60
            let reach = indices.map { hypot(p[$0].x - home.x, p[$0].y - home.y) }.max() ?? 0
            let factor = reach > limit ? limit / reach : 1
            for i in indices {
                positions[ids[i]] = CGPoint(x: home.x + (p[i].x - home.x) * factor, y: home.y + (p[i].y - home.y) * factor)
            }
        }
    }

    /// Bağlantısızlar: bağlı çekirdeğin dışında, altın açıyla dizilmiş soluk noktalar.
    private static func placeIsolated(_ graph: VaultGraph, shapes: [ClusterShape],
                                      positions: inout [Note.ID: CGPoint]) {
        let golden = Double.pi * (3 - sqrt(5))
        for cluster in graph.clusters where cluster.category != .core {
            guard let shape = shapes.first(where: { $0.id == cluster.id }) else { continue }
            let connected = cluster.noteIDs.filter { graph.degree(of: $0) > 0 }
            var inner = 0.0
            for id in connected {
                guard let q = positions[id] else { continue }
                inner = max(inner, hypot(q.x - shape.center.x, q.y - shape.center.y))
            }
            if !connected.isEmpty { inner += 12 }
            let isolated = cluster.noteIDs.filter { graph.degree(of: $0) == 0 }
            for (i, id) in isolated.enumerated() {
                let r = sqrt(inner * inner + 27 * Double(i + 1))
                let a = Double(i) * golden
                positions[id] = CGPoint(x: shape.center.x + cos(a) * r, y: shape.center.y + sin(a) * r * 0.9)
            }
        }
    }
}

/// Küre görünümü: her küme kürede bir "kıta"; notlar birim kürede.
public struct SphereLayout: Sendable {
    public struct Region: Sendable, Identifiable {
        public let id: String
        public let title: String
        public let category: NoteCategory
        public let center: SIMD3<Double>
        public let count: Int
    }

    public var points: [Note.ID: SIMD3<Double>]
    public var regions: [Region]

    public static let empty = SphereLayout(points: [:], regions: [])

    public static func compute(_ graph: VaultGraph) -> SphereLayout {
        let clusters = graph.clusters.sorted { $0.noteIDs.count > $1.noteIDs.count }
        let golden = Double.pi * (3 - sqrt(5))
        var points: [Note.ID: SIMD3<Double>] = [:]
        var regions: [Region] = []
        let totalNotes = max(Double(graph.notes.count), 1)
        for (k, cluster) in clusters.enumerated() {
            // Bölge merkezleri: kümeler üzerinde Fibonacci dağılımı (en büyük ön yüzde).
            let y = clusters.count == 1 ? 0 : 1 - 2 * (Double(k) + 0.5) / Double(clusters.count)
            let ring = sqrt(max(0, 1 - y * y))
            let theta = Double(k) * golden
            let center = simd_normalize(SIMD3(ring * sin(theta), y * 0.8, ring * cos(theta)))
            regions.append(Region(id: cluster.id, title: cluster.title, category: cluster.category,
                                  center: center, count: cluster.noteIDs.count))
            // Bölge içi: teğet düzlemde ayçiçeği, yayılım kümenin payına göre.
            let spread = 0.12 + 1.1 * sqrt(Double(cluster.noteIDs.count) / totalNotes)
            let helper = abs(center.y) < 0.9 ? SIMD3<Double>(0, 1, 0) : SIMD3<Double>(1, 0, 0)
            let u = simd_normalize(simd_cross(helper, center))
            let v = simd_cross(center, u)
            let ordered = cluster.noteIDs.sorted { graph.degree(of: $0) > graph.degree(of: $1) }
            for (i, id) in ordered.enumerated() {
                let r = spread * sqrt((Double(i) + 0.5) / Double(ordered.count))
                let a = Double(i) * golden
                points[id] = simd_normalize(center + u * (cos(a) * r) + v * (sin(a) * r))
            }
        }
        return SphereLayout(points: points, regions: regions)
    }
}

/// Deterministik yerleşim için küçük üreteç (aynı kasa → aynı resim).
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }
}
