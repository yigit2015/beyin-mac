import BeyinCore
import SwiftUI

/// Düğüm türü renkleri ve SF Symbol'leri (Tokenlar · 03 "Düğüm türü").
extension NoteCategory {
    func color(_ palette: Palette) -> Color {
        palette.isDark ? darkColor : lightColor
    }

    /// İkon karosu dolgusu: tür rengi %12 (sohbet %10, proje %14).
    func tileFill(_ palette: Palette) -> Color {
        let opacity: Double = switch self {
        case .chat: 0.10
        case .project: 0.14
        default: 0.12
        }
        return color(palette).opacity(opacity)
    }

    var symbol: String {
        switch self {
        case .core: "sparkle"
        case .fact: "lightbulb"
        case .person: "person"
        case .task: "checkmark.circle"
        case .daily: "calendar"
        case .chat: "bubble.left.and.bubble.right"
        case .project: "folder"
        }
    }

    private var darkColor: Color {
        switch self {
        case .core: Color(hex: 0xB79CFF)
        case .fact: Color(hex: 0x2DD4BF)
        case .person: Color(hex: 0xFF7AB8)
        case .task: Color(hex: 0xB4E36A)
        case .daily: Color(hex: 0x6CA8FF)
        case .chat: Color(hex: 0xE6EAF2)
        case .project: Color(hex: 0x8E9AAE)
        }
    }

    private var lightColor: Color {
        switch self {
        case .core: Color(hex: 0x7C3AED)
        case .fact: Color(hex: 0x0E9F8E)
        case .person: Color(hex: 0xD6337F)
        case .task: Color(hex: 0x4D8C12)
        case .daily: Color(hex: 0x2563EB)
        case .chat: Color(hex: 0x475569)
        case .project: Color(hex: 0x8C97A8)
        }
    }
}

extension ViewMode {
    /// Araç çubuğu ve kenar çubuğu ikonları (Bileşenler · 08).
    var symbol: String {
        switch self {
        case .odak: "scope"
        case .ag: "point.3.connected.trianglepath.dotted"
        case .kure: "globe"
        case .genelBakis: "square.grid.2x2"
        }
    }
}
