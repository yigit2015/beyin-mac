import BeyinCore
import SwiftUI

@main
struct BeyinApp: App {
    @State private var store: VaultStore
    @State private var shell = ShellState()
    private let launch = LaunchOptions.current

    init() {
        let options = LaunchOptions.current
        _store = State(initialValue: options.makeStore())
    }

    var body: some Scene {
        WindowGroup("Beyin") {
            RootView(store: store, shell: shell, launch: launch)
                .frame(minWidth: 1024, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 900)
        // İlk açılış: 1440×900, ekran küçükse görünür alana sığacak kadar (en az 1024×700). Kayıtlı pencere
        // çerçevesi varsa sistem onu geri yükler; bu yerleşim yalnız kayıt yokken kullanılır.
        .defaultWindowPlacement { _, context in
            let visible = context.defaultDisplay.visibleRect
            let size = CGSize(width: max(1024, min(1440, visible.width - 40)),
                              height: max(700, min(900, visible.height - 40)))
            return WindowPlacement(.center, size: size)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            BeyinCommands(store: store, shell: shell)
        }

        Settings {
            SettingsView(store: store)
        }
    }
}

/// Geliştirme ve ekran görüntüsü için ortam değişkenleri. Hiçbiri yoksa gerçek kasa yüklenir.
/// - `BEYIN_PREVIEW=1` önizleme verisi; `empty`, `loading`, `notfound` ilgili durum.
/// - `BEYIN_MODE=odak|ag|kure|genelBakis` açılış görünümü.
/// - `BEYIN_SETTINGS=1` Ayarlar'ı açar, `BEYIN_PALETTE=1` ⌘K paletini açar, `BEYIN_ASK="…"` Beyne sor'u çalıştırır.
/// - `BEYIN_SELECT="başlık"` o notu seçer; `BEYIN_SELECT=none` seçimi kaldırır.
/// - `BEYIN_SETTINGS=gorunum|kisayollar` Ayarlar'ı o sekmede açar; `BEYIN_WINDOW=1024x700` pencere boyutu.
struct LaunchOptions {
    let preview: String?
    let mode: ViewMode?
    let opensSettings: Bool
    let opensPalette: Bool
    let askQuery: String?
    let select: String?
    let settingsTab: String?
    let windowSize: CGSize?

    static let current: LaunchOptions = {
        let env = ProcessInfo.processInfo.environment
        func flag(_ key: String) -> Bool { ["1", "true", "evet"].contains(env[key]?.lowercased() ?? "") }
        return LaunchOptions(preview: env["BEYIN_PREVIEW"].flatMap { $0.isEmpty || $0 == "0" ? nil : $0.lowercased() },
                             mode: env["BEYIN_MODE"].flatMap(ViewMode.init(rawValue:)),
                             opensSettings: flag("BEYIN_SETTINGS") || ["gorunum", "kisayollar"].contains(env["BEYIN_SETTINGS"] ?? ""),
                             opensPalette: flag("BEYIN_PALETTE"),
                             askQuery: env["BEYIN_ASK"].flatMap { $0.isEmpty ? nil : $0 },
                             select: env["BEYIN_SELECT"].flatMap { $0.isEmpty ? nil : $0 },
                             settingsTab: env["BEYIN_SETTINGS"],
                             windowSize: env["BEYIN_WINDOW"].flatMap { value in
                                 let parts = value.split(separator: "x").compactMap { Double($0) }
                                 return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
                             })
    }()

    var isPreview: Bool { preview != nil }

    @MainActor
    func makeStore() -> VaultStore {
        switch preview {
        case nil:
            // Öncelik: BEYIN_VAULT > Ayarlar'da seçilen klasör > ~/Beyin.
            let env = ProcessInfo.processInfo.environment["BEYIN_VAULT"] ?? ""
            if env.isEmpty, let saved = UserDefaults.standard.string(forKey: SettingKey.vaultPath), !saved.isEmpty {
                return VaultStore(vaultURL: URL(fileURLWithPath: saved, isDirectory: true))
            }
            return VaultStore()
        case "empty":
            return .preview(state: .empty)
        case "loading":
            return .preview(state: .loading(progress: 0.48, phase: .resolving))
        case "notfound":
            return .preview(state: .notFound(URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Beyin")))
        default:
            return .preview
        }
    }
}
