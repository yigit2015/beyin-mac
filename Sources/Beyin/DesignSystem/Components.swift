import BeyinCore
import SwiftUI

// Bileşen listesi (Bilesenler.dc.html): rozet, çip, KeyCap, düğme stilleri, satırlar, istatistik kartı.

/// Tür noktası: 7 pt daire.
struct Dot: View {
    let color: Color
    var size: CGFloat = 7
    var glow: Color? = nil

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: glow ?? .clear, radius: glow == nil ? 0 : 4)
            .accessibilityHidden(true)
    }
}

/// Nefes alan eşitleme noktası (4 sn, opaklık .7 ↔ 1, ölçek 1 ↔ 1.05).
struct BreathingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let color: Color
    var size: CGFloat = 7

    var body: some View {
        Dot(color: color, size: size, glow: color)
            .phaseAnimator([false, true]) { view, on in
                view.opacity(reduceMotion ? 1 : (on ? 1 : 0.7)).scaleEffect(reduceMotion ? 1 : (on ? 1.05 : 1))
            } animation: { _ in .easeInOut(duration: 2) }
    }
}

/// KeyCap: 10.5 Medium, iç 2×5, köşe 6, üçüncül renk; menü kısayollarıyla aynı metin.
struct KeyCap: View {
    @Environment(\.palette) private var palette
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
            .foregroundStyle(palette.t3)
            .padding(.vertical, 2)
            .padding(.horizontal, 5)
            .chipSurface(in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Temel çip: yükseklik 18, yatay iç 7, badge yazısı, kapsül.
struct Chip<Content: View>: View {
    @Environment(\.palette) private var palette
    var height: CGFloat = 18
    var tint: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 4) { content }
            .font(BeyinFont.badge)
            .tracking(0.2)
            .foregroundStyle(tint ?? palette.t2)
            .lineLimit(1)
            .padding(.horizontal, height > 20 ? 10 : 7)
            .frame(height: height)
            .background((tint ?? .clear).opacity(tint == nil ? 0 : 0.12), in: Capsule())
            .chipSurface()
            .overlay {
                if let tint { Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1) }
            }
    }
}

extension Chip where Content == Text {
    init(_ text: String, height: CGFloat = 18, tint: Color? = nil) {
        self.height = height
        self.tint = tint
        self.content = Text(text)
    }
}

/// Görünürlük çipi: "internal" ya da kilitli "private".
struct VisibilityChip: View {
    let note: Note

    var body: some View {
        Chip {
            if note.isPrivate {
                Image(systemName: "lock.fill").font(.system(size: 8, weight: .semibold))
                Text("private")
            } else {
                Text("internal")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(note.isPrivate ? "Görünürlük: private" : "Görünürlük: internal")
    }
}

/// Tür ikon karosu: 30×30, köşe 10, tür rengi %12 dolgu.
struct CategoryTile: View {
    @Environment(\.palette) private var palette
    let category: NoteCategory
    var side: CGFloat = 30
    var iconSize: CGFloat = 15

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundStyle(category.color(palette))
            .frame(width: side, height: side)
            .background(category.tileFill(palette), in: RoundedRectangle(cornerRadius: side / 3, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Düğme stilleri

/// Hover durumunu ButtonStyle içinde tutmak için küçük sarmalayıcı.
private struct HoverReader<Content: View>: View {
    @State private var isHovered = false
    let content: (Bool) -> Content

    var body: some View {
        content(isHovered)
            .onHover { hovering in
                withAnimation(hovering ? Motion.hoverIn : Motion.hoverOut) { isHovered = hovering }
            }
    }
}

/// İkon düğmesi: 34 daire (ya da verilen çap), ikon 16; üzerine gelince %7 dolgu; aktifken mor %20 + iç kenar.
struct IconButtonStyle: ButtonStyle {
    var diameter: CGFloat = 34
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, diameter: diameter, isActive: isActive)
    }

    private struct IconButtonBody: View {
        @Environment(\.palette) private var palette
        @Environment(\.isEnabled) private var isEnabled
        let configuration: Configuration
        let diameter: CGFloat
        let isActive: Bool

        var body: some View {
            HoverReader { hovered in
                configuration.label
                    .font(.system(size: diameter >= 34 ? 15 : 13, weight: .medium))
                    .foregroundStyle(isActive || hovered ? palette.t1 : palette.t2)
                    .frame(width: diameter, height: diameter)
                    .background {
                        Circle().fill(isActive ? palette.violetFill : (hovered || configuration.isPressed ? palette.chip : .clear))
                    }
                    .overlay {
                        if isActive {
                            Circle().strokeBorder(palette.violet2.opacity(palette.isDark ? 0.35 : 0.30), lineWidth: 1)
                        }
                    }
                    .contentShape(Circle())
                    .scaleEffect(configuration.isPressed ? 0.94 : 1)
                    .opacity(isEnabled ? 1 : 0.4)
                    .motion(Motion.snappy, value: configuration.isPressed)
            }
        }
    }
}

/// İkincil kapsül düğme: 34 yükseklik, %7 dolgu + %12 kenar, 12.5 Semibold.
struct CapsuleButtonStyle: ButtonStyle {
    var height: CGFloat = 34

    func makeBody(configuration: Configuration) -> some View {
        CapsuleBody(configuration: configuration, height: height)
    }

    private struct CapsuleBody: View {
        @Environment(\.palette) private var palette
        let configuration: Configuration
        let height: CGFloat

        var body: some View {
            HoverReader { hovered in
                configuration.label
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(palette.t1)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: height)
                    .background(hovered ? palette.chipStroke : .clear, in: Capsule())
                    .chipSurface()
                    .contentShape(Capsule())
                    .scaleEffect(configuration.isPressed ? 0.97 : 1)
                    .motion(Motion.snappy, value: configuration.isPressed)
            }
        }
    }
}

/// Birincil kapsül düğme: mor gradyan #A57BFF → #6D3AE0, beyaz metin, parıltı 18 %45.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Palette.primaryGradient, in: Capsule())
            .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                           startPoint: .top, endPoint: .center), lineWidth: 1))
            .shadow(color: Color(hex: 0x8B5CF6, opacity: 0.45), radius: 9)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .motion(Motion.snappy, value: configuration.isPressed)
    }
}

/// Liste satırı: 30 yükseklik, köşe 9, iç 8; üzerine gelince %7 dolgu.
struct RowButtonStyle: ButtonStyle {
    var height: CGFloat = 30
    var isHighlighted = false

    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration, height: height, isHighlighted: isHighlighted)
    }

    private struct RowBody: View {
        @Environment(\.palette) private var palette
        let configuration: Configuration
        let height: CGFloat
        let isHighlighted: Bool

        var body: some View {
            HoverReader { hovered in
                configuration.label
                    .font(BeyinFont.callout)
                    .foregroundStyle(hovered ? palette.t1 : palette.t2)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
                    .background(isHighlighted || hovered || configuration.isPressed ? palette.chip : .clear,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
        }
    }
}

/// Kenar çubuğu gezinme satırı: 32, köşe 10, iç 10; aktif: mor %24 → %6 gradyan + 1 pt iç kenar %24.
struct NavRowButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        NavRowBody(configuration: configuration, isActive: isActive)
    }

    private struct NavRowBody: View {
        @Environment(\.palette) private var palette
        let configuration: Configuration
        let isActive: Bool
        private let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        var body: some View {
            HoverReader { hovered in
                configuration.label
                    .font(BeyinFont.body)
                    .foregroundStyle(isActive || hovered ? palette.t1 : palette.t2)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                    .background {
                        if isActive {
                            shape.fill(LinearGradient(colors: [palette.violet.opacity(palette.isDark ? 0.24 : 0.18),
                                                               palette.violet.opacity(palette.isDark ? 0.06 : 0.04)],
                                                      startPoint: .leading, endPoint: .trailing))
                        } else if hovered || configuration.isPressed {
                            shape.fill(palette.chip)
                        }
                    }
                    .overlay {
                        if isActive { shape.strokeBorder(palette.violet2.opacity(palette.isDark ? 0.24 : 0.20), lineWidth: 1) }
                    }
                    .contentShape(shape)
            }
        }
    }
}

/// Filtre çipi: 24 yükseklik, iç 9, 11.5 Medium, tür noktası 7; kapalıyken opaklık .5.
struct FilterChip: View {
    @Environment(\.palette) private var palette
    let title: String
    let color: Color
    let isOn: Bool
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Dot(color: color)
                Text(title)
                if let count {
                    Text(BeyinFormat.number(count)).monospacedDigit().foregroundStyle(palette.t3)
                }
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(palette.t2)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .chipSurface()
            .contentShape(Capsule())
            .opacity(isOn ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "gösteriliyor" : "gizli")
        .accessibilityAddTraits(.isToggle)
        .motion(Motion.snappy, value: isOn)
    }
}

/// İstatistik kartı: köşe 14, iç 12, satır aralığı 6; ikon 18 + hudM sayı ya da 15 Medium metin.
struct StatCard: View {
    @Environment(\.palette) private var palette
    let symbol: String?
    let iconColor: Color
    let value: String
    let label: String
    var isNumeric = true
    var valueColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor)
                        .frame(width: 18)
                }
                Text(value)
                    .font(isNumeric ? BeyinFont.hudM : .system(size: 15, weight: .medium))
                    .foregroundStyle(valueColor ?? palette.t1)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(height: 30)
            }
            Text(label)
                .font(BeyinFont.caption)
                .foregroundStyle(palette.t3)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value == "—" ? "yok" : value)
    }
}

/// Not satırı: tür noktası + başlık + sağda meta (zaman, "gelen" vb.).
struct NoteRow: View {
    @Environment(\.palette) private var palette
    let note: Note
    var trailing: String? = nil
    var badge: String? = nil
    var isSelected = false
    var height: CGFloat = 30
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Dot(color: isSelected ? palette.gold : note.category.color(palette),
                    glow: isSelected ? palette.goldGlow : nil)
                    .opacity(note.isPrivate ? 0.4 : 1)
                Text(note.title)
                    .foregroundStyle(palette.t1)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if note.isPrivate {
                    Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(palette.t3)
                }
                if let badge {
                    Chip(badge).monospacedDigit()
                }
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.t3)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(RowButtonStyle(height: height, isHighlighted: isSelected))
        .accessibilityLabel(note.title)
        .accessibilityValue([note.category.title, trailing].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// "Henüz yok" boş hali: zarif, tek satırlık açıklama.
struct EmptyHint: View {
    @Environment(\.palette) private var palette
    let text: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 12)).foregroundStyle(palette.t3)
            }
            Text(text)
                .font(BeyinFont.caption)
                .foregroundStyle(palette.t3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
    }
}

/// Bir metindeki eşleşmeyi altın arka planla vurgular (palet ve "Beyne sor" sonuçları).
enum Highlight {
    static func attributed(_ text: String, matching query: String, palette: Palette, alpha: Double = 0.22) -> AttributedString {
        var result = AttributedString(text)
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init).filter { $0.count >= 2 }
        guard !terms.isEmpty else { return result }
        for term in terms {
            var searchStart = text.startIndex
            while let range = text.range(of: term, options: [.caseInsensitive, .diacriticInsensitive],
                                         range: searchStart..<text.endIndex, locale: BeyinFormat.locale) {
                if let lower = AttributedString.Index(range.lowerBound, within: result),
                   let upper = AttributedString.Index(range.upperBound, within: result) {
                    result[lower..<upper].backgroundColor = Color(hex: 0xF2B84B, opacity: alpha)
                    result[lower..<upper].foregroundColor = palette.t1
                }
                searchStart = range.upperBound
            }
        }
        return result
    }
}
