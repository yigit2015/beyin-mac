import BeyinCore
import SwiftUI

/// Sanal yerleşim düzlemini ekrana taşıyan dönüşüm: sığdır, yakınlaştır, kaydır.
struct GraphTransform {
    var scale: CGFloat
    var offset: CGPoint

    /// `bounds`'u, üstte araç çubuğu ve altta Beyne sor/zaman çizelgesi payı bırakarak sığdırır.
    init(bounds: CGRect, in size: CGSize, zoom: Double, pan: CGSize, trailingOcclusion: CGFloat = 0,
         insets base: EdgeInsets = GraphTransform.canvasInsets) {
        var insets = base
        insets.trailing += trailingOcclusion
        let usable = CGSize(width: max(size.width - insets.leading - insets.trailing, 1),
                            height: max(size.height - insets.top - insets.bottom, 1))
        let fit = min(usable.width / max(bounds.width, 1), usable.height / max(bounds.height, 1))
        scale = fit * zoom
        let center = CGPoint(x: insets.leading + usable.width / 2 + pan.width,
                             y: insets.top + usable.height / 2 + pan.height)
        offset = CGPoint(x: center.x - bounds.midX * scale, y: center.y - bounds.midY * scale)
    }

    /// Araç çubuğu (üst), Beyne sor + zaman çizelgesi (alt) payları.
    static let canvasInsets = EdgeInsets(top: 84, leading: 36, bottom: 128, trailing: 36)

    /// Tuvalin yüzen panellerle örtülmeyen kısmının merkezi.
    static func visibleCenter(in size: CGSize, trailingOcclusion: CGFloat) -> CGPoint {
        let insets = canvasInsets
        let width = size.width - insets.leading - insets.trailing - trailingOcclusion
        return CGPoint(x: insets.leading + width / 2, y: insets.top + (size.height - insets.top - insets.bottom) / 2)
    }

    func apply(_ point: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + point.x * scale, y: offset.y + point.y * scale)
    }
}

/// Düğüm boyu: bağlantı sayısıyla büyür (Bileşenler · 02), bağlantısızlar küçük.
func nodeDiameter(degree: Int) -> CGFloat {
    degree == 0 ? 3 : min(15, max(3, 2.6 + sqrt(CGFloat(degree)) * 1.5))
}

/// İki nokta arasında hafif kavisli kenar (Ağ maketi: Q eğrisi, ±0.12).
func curvedEdge(from a: CGPoint, to b: CGPoint, bend: CGFloat) -> Path {
    var path = Path()
    path.move(to: a)
    let control = CGPoint(x: (a.x + b.x) / 2 - (b.y - a.y) * bend, y: (a.y + b.y) / 2 + (b.x - a.x) * bend)
    path.addQuadCurve(to: b, control: control)
    return path
}

extension CGRect {
    /// SwiftUI kenar paylarıyla içe daralt (macOS'ta UIKit'in inset(by:) karşılığı).
    func inset(by insets: EdgeInsets) -> CGRect {
        CGRect(x: minX + insets.leading, y: minY + insets.top,
               width: max(0, width - insets.leading - insets.trailing),
               height: max(0, height - insets.top - insets.bottom))
    }
}

/// Etiket çakışmasını önler: önce önemli etiketler yerleşir, çakışan sonrakiler atlanır.
struct LabelPlacer {
    private var placed: [CGRect] = []

    /// 10.5 pt yazı için yaklaşık genişlik.
    static func estimatedWidth(_ text: String, fontSize: CGFloat = 10.5) -> CGFloat {
        CGFloat(text.count) * fontSize * 0.56 + 6
    }

    /// Yer boşsa ayırır ve true döner.
    mutating func reserve(_ rect: CGRect) -> Bool {
        let padded = rect.insetBy(dx: -2, dy: -1)
        guard !placed.contains(where: { $0.intersects(padded) }) else { return false }
        placed.append(padded)
        return true
    }
}

/// Bir kümenin okunur adı ve rengi (küme etiketleri için).
extension NetworkLayout.ClusterShape {
    func color(_ palette: Palette) -> Color { category.color(palette) }
}
