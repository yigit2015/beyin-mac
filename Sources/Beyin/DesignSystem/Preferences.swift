import AppKit
import SwiftUI

/// Ayarlar'daki (⌘,) kalıcı tercihler. `@AppStorage` anahtarları tek yerde.
enum SettingKey {
    static let theme = "tema"
    static let backdrop = "arkaPlan"
    static let privateNotes = "privateNotlar"
    static let vaultPath = "kasaYolu"
    /// Dosya değişince otomatik yeniden oku (VaultStore.watchesChanges). Varsayılan açık.
    static let watchChanges = "otomatikYenidenOku"
}

enum ThemePreference: String, CaseIterable, Identifiable {
    case system = "sistem"
    case dark = "koyu"
    case light = "acik"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistem"
        case .dark: "Koyu"
        case .light: "Açık"
        }
    }

    /// NSApp.appearance üzerinden uygulanır: Ayarlar penceresi ve menüler de aynı temayı alır.
    @MainActor
    func apply() {
        NSApp.appearance = switch self {
        case .system: nil
        case .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        }
    }
}

enum BackdropStyle: String, CaseIterable, Identifiable {
    case space = "uzay"
    case nightscape = "geceManzarasi"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .space: "Uzay gradyanı"
        case .nightscape: "Gece manzarası"
        }
    }
}

enum PrivateNotePreference: String, CaseIterable, Identifiable {
    case dimmed = "soluk"
    case hidden = "gizle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dimmed: "Soluk göster"
        case .hidden: "Gizle"
        }
    }
}
