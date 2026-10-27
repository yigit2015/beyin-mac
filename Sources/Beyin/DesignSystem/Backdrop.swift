import SwiftUI

/// Pencere zemini (Tokenlar · 01): ZStack'in en altında, `.ignoresSafeArea()` ile pencerenin tamamı.
/// Graf görünümleri kendi zeminlerini çizmez; bunun üstüne çizilir.
struct Backdrop: View {
    @Environment(\.palette) private var palette
    @AppStorage(SettingKey.backdrop) private var style: BackdropStyle = .space

    var body: some View {
        Group {
            if palette.isDark, style == .nightscape {
                NightscapeBackdrop()
            } else {
                SpaceBackdrop()
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Uzay: 158° doğrusal gradyan + mor ve teal ışık lekeleri + yıldız tozu + gren.
struct SpaceBackdrop: View {
    @Environment(\.palette) private var palette

    var body: some View {
        LinearGradient(stops: [
            .init(color: palette.bg0, location: 0),
            .init(color: palette.bg1, location: 0.40),
            .init(color: palette.bg2, location: 1),
        ], startPoint: UnitPoint(x: 0.31, y: 0), endPoint: UnitPoint(x: 0.69, y: 1))
        .overlay(RadialGradient(colors: [palette.glowViolet, .clear],
                                center: UnitPoint(x: 0.24, y: 0.44), startRadius: 0, endRadius: 640))
        .overlay(RadialGradient(colors: [palette.glowTeal, .clear],
                                center: UnitPoint(x: 0.88, y: 0.04), startRadius: 0, endRadius: 520))
        .overlay {
            if palette.starOpacity > 0 {
                StarDust().opacity(palette.starOpacity)
            }
        }
        .overlay(Grain(opacity: palette.grainOpacity, multiply: !palette.isDark))
    }
}

/// Yıldız tozu: 6 katman, her katman bir noktanın döşenmesi; 1–1.6 pt, opaklık .30–.70, döşeme 190–430 pt.
struct StarDust: View {
    private struct Layer {
        let point: CGPoint
        let size: CGFloat
        let color: Color
        let tile: CGFloat
    }

    // Main.dc.html `.stars` katmanları; tasarımda döşemenin dışında kalan iki konum döşemeye katlanır.
    private static let layers: [Layer] = [
        Layer(point: CGPoint(x: 23, y: 41), size: 1, color: .white.opacity(0.7), tile: 240),
        Layer(point: CGPoint(x: 151, y: 97), size: 1, color: .white.opacity(0.45), tile: 310),
        Layer(point: CGPoint(x: 79, y: 187), size: 1.4, color: Color(red: 220 / 255, green: 210 / 255, blue: 1, opacity: 0.55), tile: 370),
        Layer(point: CGPoint(x: 211, y: 13), size: 1, color: .white.opacity(0.35), tile: 190),
        Layer(point: CGPoint(x: 301, y: 233), size: 1.6, color: Color(red: 180 / 255, green: 240 / 255, blue: 1, opacity: 0.4), tile: 430),
        Layer(point: CGPoint(x: 347, y: 151), size: 1, color: .white.opacity(0.3), tile: 280),
    ]

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            for layer in Self.layers {
                let origin = CGPoint(x: layer.point.x.truncatingRemainder(dividingBy: layer.tile),
                                     y: layer.point.y.truncatingRemainder(dividingBy: layer.tile))
                let diameter = layer.size * 1.6
                var y = origin.y
                while y < size.height {
                    var x = origin.x
                    while x < size.width {
                        let rect = CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter)
                        context.fill(Path(ellipseIn: rect), with: .color(layer.color))
                        x += layer.tile
                    }
                    y += layer.tile
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Gren: önceden üretilmiş 256×256 gürültü dokusu; koyu temada %5 overlay, açıkta %3 multiply.
struct Grain: View {
    let opacity: Double
    var multiply = false

    var body: some View {
        Image(decorative: NoiseTexture.image, scale: 1)
            .resizable(resizingMode: .tile)
            .blendMode(multiply ? .multiply : .overlay)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

@MainActor
private enum NoiseTexture {
    static let image: CGImage = make(side: 256, seed: 0x5EED)

    /// Sabit tohumlu gri gürültü; fractalNoise'un iki oktavına yakın: ince + kaba katman karışımı.
    private static func make(side: Int, seed: UInt64) -> CGImage {
        var state = seed
        func next() -> UInt8 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return UInt8(truncatingIfNeeded: state >> 56)
        }
        var coarse = [UInt8](repeating: 0, count: (side / 2) * (side / 2))
        for i in coarse.indices { coarse[i] = next() }
        var pixels = [UInt8](repeating: 0, count: side * side)
        for y in 0..<side {
            for x in 0..<side {
                let fine = Int(next())
                let low = Int(coarse[(y / 2) * (side / 2) + x / 2])
                pixels[y * side + x] = UInt8((fine * 2 + low) / 3)
            }
        }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
}

/// Gece manzarası (Ayarlar'dan seçilen ikinci mod): gökyüzü gradyanı, üç dağ katmanı, ufuk ışığı.
struct NightscapeBackdrop: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Color(hex: 0x050915), location: 0),
            .init(color: Color(hex: 0x0B1230), location: 0.38),
            .init(color: Color(hex: 0x1A1838), location: 0.62),
            .init(color: Color(hex: 0x35263F), location: 0.80),
            .init(color: Color(hex: 0x4B3138), location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .overlay(alignment: .top) {
            StarDust()
                .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
        }
        .overlay(RadialGradient(colors: [Color(hex: 0xFB923C, opacity: 0.20), .clear],
                                center: UnitPoint(x: 0.5, y: 1), startRadius: 0, endRadius: 520))
        .overlay {
            ZStack {
                Ridge(baseline: 0.70, amplitude: 0.10, seed: 1).fill(Color(hex: 0x1E2546))
                Ridge(baseline: 0.78, amplitude: 0.08, seed: 2).fill(Color(hex: 0x141A36))
                Ridge(baseline: 0.88, amplitude: 0.06, seed: 3).fill(Color(hex: 0x0A0E1F))
            }
            .blur(radius: 3)
        }
        .overlay(Grain(opacity: 0.05))
    }
}

/// Yumuşak dağ silueti: birkaç sinüsün toplamı, alt kenara kapanır.
private struct Ridge: Shape {
    let baseline: CGFloat
    let amplitude: CGFloat
    let seed: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 64
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let wave = sin(t * 5.1 + seed * 1.7) * 0.55 + sin(t * 11.3 + seed * 3.1) * 0.3 + sin(t * 23.7 + seed) * 0.15
            let y = rect.height * (baseline - amplitude * CGFloat(wave))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * t, y: rect.minY + y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
