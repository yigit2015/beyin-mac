import SwiftUI

/// Cam seviyeleri (Tokenlar · 02): panel, floating, card, label, chip.
/// Panel ve floating sistemin Liquid Glass'ını kullanır; dolgu tonu, ışıklı kenar ve gölge token'lardan gelir.
enum GlassLevel {
    /// Kenar çubuğu, inceleme, HUD, genel bakış kartları. Köşe 24 (genel bakış 20, HUD 22).
    case panel
    /// Araç çubuğu, Beyne sor, zaman çizelgesi. Kapsül.
    case floating
    /// Küre etiketleri, araç ipucu. Köşe 9.
    case label
}

extension View {
    /// Panel camı: `.glassEffect(.regular.tint(…))` + 165° ışıklı kenar + panel gölgesi.
    func panelGlass(cornerRadius: CGFloat = 24) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), level: .panel))
    }

    /// Yüzen kontrol camı. Etkileşimli kontrollerde `interactive: true`.
    func floatingGlass<S: InsettableShape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, level: .floating, interactive: interactive))
    }

    /// Etiket camı: küre etiketleri, ipucu kartı.
    func labelGlass(cornerRadius: CGFloat = 9) -> some View {
        modifier(GlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), level: .label))
    }

    /// Panel içi kart: beyaz %4.5 + 1 pt %8.5 kenar (açık: beyaz %58 + #0E1424 %7).
    func cardSurface(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
    }

    /// Çip: beyaz %7 + %12 kenar, kapsül.
    func chipSurface() -> some View {
        modifier(ChipSurface(shape: Capsule()))
    }

    func chipSurface<S: InsettableShape>(in shape: S) -> some View {
        modifier(ChipSurface(shape: shape))
    }
}

private struct GlassSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.palette) private var palette
    let shape: S
    let level: GlassLevel
    var interactive = false

    func body(content: Content) -> some View {
        content
            .glassEffect(glass, in: shape)
            .overlay {
                shape
                    .strokeBorder(rim, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .background {
                switch level {
                case .panel, .floating:
                    OuterShadow(shape: shape, primary: palette.shadowStrong, primaryRadius: 30, primaryY: 24,
                                secondary: palette.shadowSoft, secondaryRadius: 5, secondaryY: 2)
                case .label:
                    OuterShadow(shape: shape, primary: .black.opacity(palette.isDark ? 0.28 : 0.10), primaryRadius: 8,
                                primaryY: 6, secondary: .clear, secondaryRadius: 0, secondaryY: 0)
                }
            }
    }

    private var glass: Glass {
        let base: Glass = switch level {
        case .panel, .floating: .regular.tint(palette.glassTint)
        case .label: .regular
        }
        return interactive ? base.interactive() : base
    }

    /// Işıklı kenar: 1 pt, 165°; %38 → %5 (.34) → %5 (.72) → %16.
    private var rim: LinearGradient {
        switch level {
        case .panel, .floating:
            LinearGradient(stops: [
                .init(color: palette.rimA, location: 0),
                .init(color: palette.rimB, location: 0.34),
                .init(color: palette.rimB, location: 0.72),
                .init(color: palette.rimC, location: 1),
            ], startPoint: UnitPoint(x: 0.37, y: 0), endPoint: UnitPoint(x: 0.63, y: 1))
        case .label:
            LinearGradient(colors: [palette.glassHighlight, palette.hair], startPoint: .top, endPoint: .bottom)
        }
    }
}

/// Yalnız dışa düşen gölge: şeklin içi maskelenir, böylece cam altındaki metin gölgelenmez.
struct OuterShadow<S: Shape>: View {
    let shape: S
    let primary: Color
    let primaryRadius: CGFloat
    let primaryY: CGFloat
    let secondary: Color
    let secondaryRadius: CGFloat
    let secondaryY: CGFloat

    var body: some View {
        shape
            .fill(Color.black)
            .shadow(color: primary, radius: primaryRadius, y: primaryY)
            .shadow(color: secondary, radius: secondaryRadius, y: secondaryY)
            .mask {
                Rectangle()
                    .padding(-160)
                    .overlay { shape.fill(Color.black).blendMode(.destinationOut) }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct CardSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.palette) private var palette
    let shape: S

    func body(content: Content) -> some View {
        content
            .background(palette.card, in: shape)
            .overlay { shape.strokeBorder(palette.cardStroke, lineWidth: 1).allowsHitTesting(false) }
    }
}

private struct ChipSurface<S: InsettableShape>: ViewModifier {
    @Environment(\.palette) private var palette
    let shape: S

    func body(content: Content) -> some View {
        content
            .background(palette.chip, in: shape)
            .overlay { shape.strokeBorder(palette.chipStroke, lineWidth: 1).allowsHitTesting(false) }
    }
}
