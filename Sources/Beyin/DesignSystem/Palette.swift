import SwiftUI

/// Tema token'ları (Tokenlar · 01–03, 07). Koyu birincil, açık ikincil.
/// Görünümler `@Environment(\.palette)` ile okur; kök görünüm renk şemasına göre doldurur.
struct Palette: Sendable {
    let isDark: Bool

    // Zemin
    let bg0, bg1, bg2: Color
    let glowViolet, glowTeal: Color
    let starOpacity: Double
    let grainOpacity: Double

    // Metin ve çizgi
    let t1, t2, t3: Color
    let hair: Color
    let edge, edgeDim: Color

    // Cam
    let glassTint: Color
    let rimA, rimB, rimC: Color
    let glassHighlight: Color
    let shadowStrong, shadowSoft: Color

    // Kart ve çip
    let card, cardStroke: Color
    let chip, chipStroke: Color

    // Vurgular
    let gold, goldGlow, goldFill: Color
    let violet, violet2, violetFill: Color
    let teal, tealFill: Color
    let orange, orangeFill: Color

    let titleGradient: LinearGradient

    static let dark = Palette(
        isDark: true,
        bg0: Color(hex: 0x071214), bg1: Color(hex: 0x0A1B21), bg2: Color(hex: 0x120E2A),
        glowViolet: Color(hex: 0x7C5CF6, opacity: 0.24), glowTeal: Color(hex: 0x2DD4BF, opacity: 0.09),
        starOpacity: 1, grainOpacity: 0.05,
        t1: Color(hex: 0xF2F4F8), t2: Color(hex: 0xE8EEFF, opacity: 0.74), t3: Color(hex: 0xE8EEFF, opacity: 0.56),
        hair: .white.opacity(0.08),
        edge: Color(hex: 0xCDE4F0, opacity: 0.26), edgeDim: Color(hex: 0xCDE4F0, opacity: 0.08),
        glassTint: Color(hex: 0x0E1822, opacity: 0.46),
        rimA: .white.opacity(0.38), rimB: .white.opacity(0.05), rimC: .white.opacity(0.16),
        glassHighlight: .white.opacity(0.10),
        shadowStrong: .black.opacity(0.45), shadowSoft: .black.opacity(0.25),
        card: .white.opacity(0.045), cardStroke: .white.opacity(0.085),
        chip: .white.opacity(0.07), chipStroke: .white.opacity(0.12),
        gold: Color(hex: 0xF2B84B), goldGlow: Color(hex: 0xF2B84B, opacity: 0.42), goldFill: Color(hex: 0xF2B84B, opacity: 0.08),
        violet: Color(hex: 0x8B5CF6), violet2: Color(hex: 0xB79CFF), violetFill: Color(hex: 0x8B5CF6, opacity: 0.20),
        teal: Color(hex: 0x2DD4BF), tealFill: Color(hex: 0x2DD4BF, opacity: 0.12),
        orange: Color(hex: 0xFB923C), orangeFill: Color(hex: 0xFB923C, opacity: 0.12),
        titleGradient: LinearGradient(stops: [
            .init(color: Color(hex: 0x8EC5FF), location: 0),
            .init(color: Color(hex: 0xA9A6FF), location: 0.48),
            .init(color: Color(hex: 0xD2A6FF), location: 1),
        ], startPoint: .leading, endPoint: .trailing))

    static let light = Palette(
        isDark: false,
        bg0: Color(hex: 0xF6F8FC), bg1: Color(hex: 0xEEF2F9), bg2: Color(hex: 0xE9E5F7),
        glowViolet: Color(hex: 0x8B5CF6, opacity: 0.16), glowTeal: Color(hex: 0x2DD4BF, opacity: 0.12),
        starOpacity: 0, grainOpacity: 0.03,
        t1: Color(hex: 0x0E1424), t2: Color(hex: 0x0E1424, opacity: 0.74), t3: Color(hex: 0x0E1424, opacity: 0.62),
        hair: Color(hex: 0x0E1424, opacity: 0.08),
        edge: Color(hex: 0x323C6E, opacity: 0.26), edgeDim: Color(hex: 0x323C6E, opacity: 0.09),
        glassTint: .white.opacity(0.54),
        rimA: .white, rimB: .white.opacity(0.45), rimC: .white.opacity(0.8),
        glassHighlight: .white.opacity(0.95),
        shadowStrong: Color(hex: 0x30246E, opacity: 0.14), shadowSoft: Color(hex: 0x30246E, opacity: 0.08),
        card: .white.opacity(0.58), cardStroke: Color(hex: 0x0E1424, opacity: 0.07),
        chip: Color(hex: 0x0E1424, opacity: 0.05), chipStroke: Color(hex: 0x0E1424, opacity: 0.10),
        gold: Color(hex: 0xB7791F), goldGlow: Color(hex: 0xD99628, opacity: 0.32), goldFill: Color(hex: 0xD99628, opacity: 0.10),
        violet: Color(hex: 0x7C3AED), violet2: Color(hex: 0x6D28D9), violetFill: Color(hex: 0x7C3AED, opacity: 0.12),
        teal: Color(hex: 0x0A7C70), tealFill: Color(hex: 0x0E9F8E, opacity: 0.12),
        orange: Color(hex: 0xB4500B), orangeFill: Color(hex: 0xC2560C, opacity: 0.10),
        titleGradient: LinearGradient(stops: [
            .init(color: Color(hex: 0x2563EB), location: 0),
            .init(color: Color(hex: 0x5B3FE0), location: 0.50),
            .init(color: Color(hex: 0x9333EA), location: 1),
        ], startPoint: .leading, endPoint: .trailing))

    /// Mor gradyanlı birincil düğme ve "Sor" düğmesi (her iki temada aynı).
    static let primaryGradient = LinearGradient(colors: [Color(hex: 0xA57BFF), Color(hex: 0x6D3AE0)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension EnvironmentValues {
    @Entry var palette: Palette = .dark
}

/// Kök görünümde bir kez: renk şemasından paleti seçer.
private struct PaletteProvider: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.environment(\.palette, colorScheme == .dark ? .dark : .light)
    }
}

extension View {
    func providesPalette() -> some View { modifier(PaletteProvider()) }
}
