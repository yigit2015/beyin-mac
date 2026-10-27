import SwiftUI

/// Orb (Bileşenler · 01): Core'un, "Ben"in görsel karşılığı.
/// Boyutlar: L 132 (Odak) · M 54 (Ağ) · S 28–30 (logo, Beyne sor). Girdap ve parçacıklar yalnız M ve üstünde döner.
struct OrbView: View {
    enum Phase: Equatable {
        case idle
        /// Nabız: 1.4 sn döngü, ölçek 0.94 ↔ 1.04, parıltı .45 ↔ .9.
        case loading
        /// 2 pt altın halka.
        case focused
        /// Doygunluk .35, parlaklık .8, opaklık .75.
        case dimmed
    }

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let size: CGFloat
    var phase: Phase = .idle
    /// Yalnız L boyutta: radyal hale (2.6× çap) ve 4 sn nefes.
    var showsHalo = false
    /// Tek seferlik nabız tetikleyicisi (Beyne sor gönderildiğinde artar).
    var pulseTrigger = 0

    private var isLarge: Bool { size >= 54 }
    private var scale: CGFloat { size / 132 }

    var body: some View {
        let pulseScale: Double = reduceMotion ? 1 : 1.12
        Group {
            if isLarge {
                TimelineView(.animation(paused: reduceMotion || phase == .dimmed)) { context in
                    layers(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                layers(time: 0)
            }
        }
        .frame(width: size, height: size)
        .modifier(OrbPhaseEffect(phase: phase, glow: palette.violet, reduceMotion: reduceMotion))
        .keyframeAnimator(initialValue: 1.0, trigger: pulseTrigger) { content, value in
            content.scaleEffect(value)
        } keyframes: { _ in
            SpringKeyframe(pulseScale, duration: 0.25, spring: .snappy)
            SpringKeyframe(1.0, duration: 0.35, spring: .smooth)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func layers(time: TimeInterval) -> some View {
        ZStack {
            if showsHalo {
                Circle()
                    .fill(RadialGradient(stops: [
                        .init(color: Color(hex: 0x8B5CF6, opacity: 0.34), location: 0),
                        .init(color: Color(hex: 0x8B5CF6, opacity: 0.08), location: 0.45),
                        .init(color: .clear, location: 0.68),
                    ], center: .center, startRadius: 0, endRadius: size * 1.3))
                    .frame(width: size * 2.6, height: size * 2.6)
                    .scaleEffect(1 + 0.025 * (1 + sin(time * .pi / 2)))
                    .opacity(0.85 + 0.15 * sin(time * .pi / 2))
                    .allowsHitTesting(false)
            }

            sphere(time: time)
                .shadow(color: palette.violet.opacity(palette.isDark ? 0.75 : 0.6), radius: max(7, 17 * scale))
                .shadow(color: palette.violet.opacity(palette.isDark ? 0.42 : 0.30), radius: isLarge ? 55 * scale : 0)
        }
    }

    private func sphere(time: TimeInterval) -> some View {
        ZStack {
            Circle().fill(
                RadialGradient(stops: [
                    .init(color: Color(hex: 0xF6F1FF), location: 0),
                    .init(color: Color(hex: 0xD4C2FF), location: 0.09),
                    .init(color: Color(hex: 0xA57BFF), location: 0.28),
                    .init(color: Color(hex: 0x6D3AE0), location: 0.52),
                    .init(color: Color(hex: 0x3B1690), location: 0.74),
                    .init(color: Color(hex: 0x1A0A45), location: 1),
                ], center: UnitPoint(x: 0.36, y: 0.30), startRadius: 0, endRadius: size * 0.95)
                .shadow(.inner(color: Color(hex: 0x120434, opacity: 0.72), radius: 19 * scale, x: -14 * scale, y: -18 * scale))
                .shadow(.inner(color: .white.opacity(0.20), radius: 13 * scale, x: 10 * scale, y: 12 * scale))
            )

            if isLarge {
                OrbSwirl(size: size)
                    .rotationEffect(.degrees(time / 36 * 360))
                    .blendMode(.screen)
            }

            OrbParticles(size: size)
                .rotationEffect(.degrees(-time / 22 * 360))
                .blendMode(.screen)
                .opacity(0.9)

            // Teal alt ışık + beyaz speküler leke (0.32, 0.26).
            Circle().fill(RadialGradient(colors: [Color(hex: 0x2DD4BF, opacity: 0.30), .clear],
                                         center: UnitPoint(x: 0.5, y: 1.16), startRadius: 0, endRadius: size * 0.63))
            Circle().fill(RadialGradient(colors: [.white.opacity(0.55), .clear],
                                         center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: size * 0.16))
        }
        // Girdap ve parçacık katmanları gövdeden büyük çerçeveli; gövde tam `size` olsun.
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color(red: 214 / 255, green: 196 / 255, blue: 1, opacity: 0.35), lineWidth: 1))
    }
}

/// Faz efektleri: yükleniyor nabzı, odak halkası, sönük hal.
private struct OrbPhaseEffect: ViewModifier {
    let phase: OrbView.Phase
    let glow: Color
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        switch phase {
        case .idle:
            content
        case .loading:
            if reduceMotion {
                // Hareketi azalt: ölçek yok, opaklık .6 ↔ 1, 2 sn.
                content.phaseAnimator([false, true]) { view, on in
                    view.opacity(on ? 1 : 0.6)
                } animation: { _ in .easeInOut(duration: 1.0) }
            } else {
                content.phaseAnimator([false, true]) { view, on in
                    view
                        .scaleEffect(on ? 1.04 : 0.94)
                        .shadow(color: glow.opacity(on ? 0.9 : 0.45), radius: on ? 20 : 12)
                } animation: { _ in .easeInOut(duration: 0.7) }
            }
        case .focused:
            content.overlay(Circle().strokeBorder(Color(hex: 0xF2B84B), lineWidth: 2).padding(-3))
        case .dimmed:
            content
                .saturation(0.35)
                .brightness(-0.12)
                .opacity(0.75)
        }
    }
}

/// Girdap: 40 ışın, 36 sn/tur, merkezden dışa sönen radyal maske.
private struct OrbSwirl: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let radius = canvasSize.width / 2
            let color = Color(red: 235 / 255, green: 225 / 255, blue: 1, opacity: 0.16)
            for i in 0..<40 {
                let start = Angle.degrees(Double(i) * 9 + 8)
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: radius, startAngle: start, endAngle: start + .degrees(1), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(color))
            }
        }
        .frame(width: size * 1.5, height: size * 1.5)
        .mask(RadialGradient(stops: [
            .init(color: .black, location: 0.18),
            .init(color: .clear, location: 0.64),
        ], center: .center, startRadius: 0, endRadius: size * 1.06))
        .frame(width: size, height: size)
    }
}

/// Parçacıklar: sabit tohumlu küçük ışık noktaları; ters yönde 22 sn/tur.
private struct OrbParticles: View {
    let size: CGFloat

    private struct Particle {
        let x, y, d: CGFloat
        let tint: Color
    }

    private var particles: [Particle] {
        var state: UInt64 = 0x0B1E_51A7
        func rnd() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(state >> 33) / CGFloat(1 << 31)
        }
        let count = Int(min(120, max(8, size * 0.9)))
        let tints: [Color] = [.white, .white, Color(hex: 0xEDE4FF), Color(hex: 0xE0F7FF)]
        return (0..<count).map { i in
            let angle = rnd() * 2 * .pi
            let r = sqrt(rnd()) * 0.6
            return Particle(x: 0.5 + r * cos(angle), y: 0.5 + r * sin(angle), d: 1 + rnd() * 0.6, tint: tints[i % tints.count])
        }
    }

    var body: some View {
        Canvas { context, canvasSize in
            for particle in particles {
                let rect = CGRect(x: particle.x * canvasSize.width - particle.d / 2,
                                  y: particle.y * canvasSize.height - particle.d / 2,
                                  width: particle.d, height: particle.d)
                context.fill(Path(ellipseIn: rect), with: .color(particle.tint))
            }
        }
        .frame(width: size * 1.2, height: size * 1.2)
        .frame(width: size, height: size)
    }
}

/// Noktalı halka: çizgi 2, dash [0.1, 6], yuvarlak uç; 90 sn/tur döner.
struct DottedRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var diameter: CGFloat
    var color: Color = Color(red: 200 / 255, green: 188 / 255, blue: 1, opacity: 0.35)
    var lineWidth: CGFloat = 1.6
    var rotates = true

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !rotates)) { context in
            Circle()
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [0.1, 6]))
                .rotationEffect(.degrees(context.date.timeIntervalSinceReferenceDate / 90 * 360))
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }
}
