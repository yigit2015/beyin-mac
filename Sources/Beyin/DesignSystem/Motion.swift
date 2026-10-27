import SwiftUI

/// Hareket şartnamesi · 01, birebir. Durum değişiklikleri `withAnimation(Motion.resolve(…))` ile yapılır.
enum Motion {
    static let snappy = Animation.spring(duration: 0.25, bounce: 0)      // üzerine gelme, basma
    static let panel = Animation.spring(duration: 0.40, bounce: 0.10)    // paneller, kartlar
    static let focus = Animation.spring(duration: 0.50, bounce: 0.12)    // odak kamerası
    static let view = Animation.spring(duration: 0.60, bounce: 0.08)     // ⌘1–⌘4 geçişleri
    static let pop = Animation.spring(duration: 0.45, bounce: 0.35)      // yeni düğüm, rozet
    static let scrub = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.86)

    /// Hareketi azalt açıksa tüm yaylar kısa bir opaklık geçişine iner.
    static func resolve(_ a: Animation, reduce: Bool) -> Animation {
        reduce ? .easeInOut(duration: 0.2) : a
    }

    // Hareket şartnamesi · 02, zamanlanmış geçişler.
    static let hoverIn = Animation.easeOut(duration: 0.18)
    static let hoverOut = Animation.easeOut(duration: 0.28)
    static let inspectorSwap = Animation.easeInOut(duration: 0.20)
    static let paletteOut = Animation.easeIn(duration: 0.12)
}

extension View {
    /// `.animation(_:value:)` ama Hareketi azalt'a uyar.
    func motion<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(MotionModifier(animation: animation, value: value))
    }
}

private struct MotionModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(Motion.resolve(animation, reduce: reduceMotion), value: value)
    }
}
