import SwiftUI

/// Yazı ölçeği (Tokenlar · 04). SF Pro; sistem Text/Display'i kendisi seçer. Sayılar `.monospacedDigit()`.
enum BeyinFont {
    static let display = Font.system(size: 40, weight: .light)
    static let hudXL = Font.system(size: 44, weight: .ultraLight).monospacedDigit()
    static let hudL = Font.system(size: 36, weight: .light).monospacedDigit()
    static let hudM = Font.system(size: 28, weight: .light).monospacedDigit()
    static let title1 = Font.system(size: 26, weight: .light)
    static let title2 = Font.system(size: 22, weight: .semibold)
    static let hudS = Font.system(size: 20, weight: .light).monospacedDigit()
    static let title3 = Font.system(size: 20, weight: .medium)
    static let brand = Font.system(size: 17, weight: .semibold)
    static let headline = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13)
    static let callout = Font.system(size: 12.5)
    static let caption = Font.system(size: 11.5)
    static let label = Font.system(size: 10.5, weight: .semibold)
    static let badge = Font.system(size: 10, weight: .semibold)
    static let mono = Font.system(size: 11.5, design: .monospaced)
}

/// Bölüm etiketi: 10.5 Semibold, +%8 izleme, büyük harf, üçüncül.
struct SectionLabel: View {
    @Environment(\.palette) private var palette
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(BeyinFont.label)
            .tracking(0.84)
            .textCase(.uppercase)
            .foregroundStyle(palette.t3)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Başlık gradyanı yalnız büyük başlıklarda (≥ 26 pt) ve logoda.
struct GradientTitle: View {
    @Environment(\.palette) private var palette
    let text: String
    let font: Font
    var tracking: CGFloat = 0

    var body: some View {
        Text(text)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(palette.titleGradient)
    }
}

/// Türkçe sayı ve tarih biçimleri: 1.284 · 24 Eki 2026, 18:02 · bugün / dün / 3 g.
enum BeyinFormat {
    static let locale = Locale(identifier: "tr_TR")

    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute().locale(locale))
    }

    /// "24 Eki 2026"
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    /// "24 Eki"
    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(locale))
    }

    /// "24 Eki 2026, 18:02"
    static func dateTime(_ date: Date) -> String {
        "\(shortDate(date)), \(time(date))"
    }

    /// "26 Ekim 2026, Pazartesi"
    static func longDate(_ date: Date) -> String {
        let day = date.formatted(.dateTime.day().month(.wide).year().locale(locale))
        return "\(day), \(weekday(date))"
    }

    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).locale(locale))
    }

    static func month(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).locale(locale))
    }

    /// Liste satırları için kısa göreli zaman: bugün · dün · 3 g · 24 Eki.
    static func relative(_ date: Date, now: Date = .now) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "bugün"
        case 1: return "dün"
        case 2..<7: return "\(days) g"
        default: return dayMonth(date)
        }
    }

    /// Çekirdek kartı: bugünse saat, değilse dün / 3 gün / 24 Eki.
    static func coreStamp(_ date: Date, now: Date = .now) -> (text: String, isToday: Bool) {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return (time(date), true)
        case 1: return ("dün", false)
        case 2..<7: return ("\(days) gün", false)
        default: return (dayMonth(date), false)
        }
    }

    /// Ev klasörünü ~ ile kısaltır.
    static func path(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}
