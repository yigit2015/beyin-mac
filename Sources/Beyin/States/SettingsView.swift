import BeyinCore
import SwiftUI

/// Ayarlar (⌘,) — Durumlar · 4: kasa klasörü, tema, arka plan, private notlar. Tercihler @AppStorage'da.
struct SettingsView: View {
    let store: VaultStore

    @State private var tab = LaunchOptions.current.settingsTab ?? "genel"

    var body: some View {
        TabView(selection: $tab) {
            Tab("Genel", systemImage: "gearshape", value: "genel") {
                GeneralSettings(store: store)
            }
            Tab("Görünüm", systemImage: "circle.lefthalf.filled", value: "gorunum") {
                AppearanceSettings()
            }
            Tab("Kısayollar", systemImage: "command", value: "kisayollar") {
                ShortcutSettings()
            }
        }
        .frame(width: 560)
        .providesPalette()
    }
}

/// Ayar sayfası iskeleti: zemin + bölüm etiketleri + kart grupları.
private struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background { SpaceBackdrop().opacity(0.9) }
    }
}

/// Form satırı: 150 pt etiket sütunu, en az 36 yükseklik, alt çizgi.
private struct SettingsRow<Content: View>: View {
    @Environment(\.palette) private var palette
    let title: String
    var showsDivider = true
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(BeyinFont.callout)
                .foregroundStyle(palette.t2)
                .frame(width: 150, alignment: .leading)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: 36)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(palette.hair).frame(height: 1) }
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .cardSurface(cornerRadius: 12)
    }
}

private struct GeneralSettings: View {
    let store: VaultStore
    @Environment(\.palette) private var palette
    @AppStorage(SettingKey.watchChanges) private var watchChanges = true

    var body: some View {
        SettingsPage {
            SectionLabel("Kasa").padding(.leading, 4)
            SettingsGroup {
                SettingsRow(title: "Kasa klasörü") {
                    HStack(spacing: 8) {
                        Text(BeyinFormat.path(store.vaultURL))
                            .font(BeyinFont.mono)
                            .foregroundStyle(palette.t1)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
                            .chipSurface(in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .textSelection(.enabled)
                            .help(store.vaultURL.path)
                        Button("Değiştir…") { VaultPicker.choose(for: store) }
                            .controlSize(.small)
                    }
                }
                SettingsRow(title: "Dosya değişince") {
                    Toggle(isOn: $watchChanges) {
                        Text("Otomatik yeniden oku")
                            .font(BeyinFont.callout)
                            .foregroundStyle(palette.t1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(palette.violet)
                }
                SettingsRow(title: "Durum") {
                    Text(statusText)
                        .font(BeyinFont.callout)
                        .foregroundStyle(palette.t1)
                        .monospacedDigit()
                }
                SettingsRow(title: "Finder", showsDivider: false) {
                    Button("Kasayı Finder’da göster") { store.revealVaultInFinder() }
                        .controlSize(.small)
                }
            }
            Text(watchChanges
                 ? "Beyin kasaya asla yazmaz. Notlar Obsidian’da yazılır; değişiklikler otomatik olarak yeniden okunur."
                 : "Beyin kasaya asla yazmaz. Otomatik okuma kapalı: değişiklikleri görmek için ⌘R ile yeniden oku.")
                .font(.system(size: 11))
                .foregroundStyle(palette.t3)
                .padding(.leading, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statusText: String {
        switch store.state {
        case .idle: "Bekliyor"
        case .loading(let progress, let phase): "\(phase.title) · %\(Int(progress * 100))"
        case .empty: "Klasör boş · 0 not"
        case .notFound: "Klasör bulunamadı"
        case .loaded:
            "\(BeyinFormat.number(store.graph.stats.noteCount)) not · \(BeyinFormat.number(store.graph.stats.linkCount)) bağlantı"
                + (store.lastSync.map { " · \(BeyinFormat.time($0))" } ?? "")
        }
    }
}

private struct AppearanceSettings: View {
    @Environment(\.palette) private var palette
    @AppStorage(SettingKey.theme) private var theme: ThemePreference = .system
    @AppStorage(SettingKey.backdrop) private var backdrop: BackdropStyle = .space
    @AppStorage(SettingKey.privateNotes) private var privateNotes: PrivateNotePreference = .dimmed

    var body: some View {
        SettingsPage {
            SectionLabel("Görünüm").padding(.leading, 4)
            SettingsGroup {
                SettingsRow(title: "Tema") {
                    Picker("Tema", selection: $theme) {
                        ForEach(ThemePreference.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                SettingsRow(title: "Arka plan") {
                    HStack(spacing: 12) {
                        ForEach(BackdropStyle.allCases) { style in
                            BackdropThumbnail(style: style, isSelected: backdrop == style) { backdrop = style }
                        }
                    }
                    .padding(.vertical, 4)
                }
                SettingsRow(title: "Private notlar", showsDivider: false) {
                    Picker("Private notlar", selection: $privateNotes) {
                        ForEach(PrivateNotePreference.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                if backdrop == .nightscape {
                    Text("Gece manzarası yalnız koyu temada görünür.")
                }
                Text("Hareket, sistemdeki “Hareketi azalt” ayarına uyar.")
            }
            .font(.system(size: 11))
            .foregroundStyle(palette.t3)
            .padding(.leading, 4)
        }
    }
}

/// Arka plan seçeneği: 76×44 küçük resim; seçiliyken 2 pt altın halka + parıltı.
private struct BackdropThumbnail: View {
    @Environment(\.palette) private var palette
    let style: BackdropStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    switch style {
                    case .space:
                        LinearGradient(colors: [Color(hex: 0x071214), Color(hex: 0x120E2A)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            .overlay(RadialGradient(colors: [Color(hex: 0x7C5CF6, opacity: 0.5), .clear],
                                                    center: UnitPoint(x: 0.3, y: 0.5), startRadius: 0, endRadius: 40))
                    case .nightscape:
                        NightscapeBackdrop()
                    }
                }
                .frame(width: 76, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? palette.gold : palette.chipStroke, lineWidth: isSelected ? 2 : 1)
                }
                .shadow(color: isSelected ? palette.goldGlow : .clear, radius: 6)
                Text(style.title)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? palette.t1 : palette.t2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct ShortcutSettings: View {
    @Environment(\.palette) private var palette

    private let shortcuts: [(String, String)] = [
        ("⌘1 – ⌘4", "Odak · Ağ · Küre · Genel bakış"),
        ("⌘F", "Notlarda ara"),
        ("⌘L", "Beyne sor alanına odak"),
        ("⌘K", "Komut paleti"),
        ("⌘O", "Seçili notu Obsidian’da aç"),
        ("⌘R", "Kasayı yeniden oku"),
        ("⌘+ · ⌘− · ⌘0", "Yakınlaştır · uzaklaştır · sığdır"),
        ("⌃⌘S", "Kenar çubuğunu gizle / göster"),
        ("⌥⌘I", "İnceleme panelini gizle / göster"),
        ("Esc", "Paleti kapat → aramayı temizle → seçimi kaldır"),
        ("⌘,", "Ayarlar"),
    ]

    var body: some View {
        SettingsPage {
            SectionLabel("Klavye kısayolları").padding(.leading, 4)
            SettingsGroup {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, item in
                    SettingsRow(title: item.0, showsDivider: index < shortcuts.count - 1) {
                        Text(item.1)
                            .font(BeyinFont.callout)
                            .foregroundStyle(palette.t1)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
