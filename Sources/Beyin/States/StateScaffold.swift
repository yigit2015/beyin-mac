import AppKit
import BeyinCore
import SwiftUI

/// Durum ekranlarının ortak iskeleti (Durumlar.dc.html): solda 56 pt sönük cam ray, ortada içerik.
struct StateScaffold<Content: View>: View {
    @Environment(\.palette) private var palette
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            rail
            VStack(spacing: 12) { content }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(8)
    }

    /// Görünüm ikonları: kasa yüklenmeden işlevsiz, yalnız düzeni gösterir.
    private var rail: some View {
        VStack(spacing: 10) {
            ForEach(ViewMode.allCases) { mode in
                Image(systemName: mode.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.t3)
                    .frame(width: 34, height: 34)
                    .opacity(0.6)
            }
            Spacer()
        }
        .padding(.top, 40)
        .frame(width: 56)
        .frame(maxHeight: .infinity)
        .panelGlass(cornerRadius: 18)
        .accessibilityHidden(true)
    }
}

/// Durum başlığı: title3 (20/26 Medium).
struct StateTitle: View {
    @Environment(\.palette) private var palette
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(BeyinFont.title3)
            .foregroundStyle(palette.t1)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Durum gövde metni: 13/19, ikincil, en fazla ~400 genişlik.
struct StateMessage: View {
    @Environment(\.palette) private var palette
    let text: String
    var maxWidth: CGFloat = 400

    init(_ text: String, maxWidth: CGFloat = 400) {
        self.text = text
        self.maxWidth = maxWidth
    }

    var body: some View {
        Text(text)
            .font(BeyinFont.body)
            .lineSpacing(6)
            .foregroundStyle(palette.t2)
            .frame(maxWidth: maxWidth)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Kasa klasörü seçimi: NSOpenPanel → store.changeVault. Seçim Ayarlar'a da kaydedilir.
enum VaultPicker {
    @MainActor
    static func choose(for store: VaultStore) {
        let panel = NSOpenPanel()
        panel.title = "Kasa klasörünü seç"
        panel.message = "Beyin bu klasördeki Markdown notlarını yalnızca okur; hiçbir dosyayı değiştirmez."
        panel.prompt = "Kasayı seç"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = store.vaultURL.deletingLastPathComponent()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: SettingKey.vaultPath)
        Task { await store.changeVault(to: url) }
    }

    /// Obsidian'ı açar (kurulu değilse obsidian:// şemasına düşer).
    @MainActor
    static func openObsidian(vault: URL) {
        let workspace = NSWorkspace.shared
        if let app = workspace.urlForApplication(withBundleIdentifier: "md.obsidian") {
            workspace.openApplication(at: app, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "vault", value: vault.lastPathComponent)]
        if let url = components.url { workspace.open(url) }
    }
}
