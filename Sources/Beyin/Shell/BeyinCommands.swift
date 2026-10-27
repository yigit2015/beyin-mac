import BeyinCore
import SwiftUI

/// Menü çubuğu komutları (Hareket · 06 etkileşim haritası). Kısayollar menüde de görünür.
struct BeyinCommands: Commands {
    let store: VaultStore
    let shell: ShellState

    var body: some Commands {
        // Tek pencereli uygulama: Yeni pencere yok.
        CommandGroup(replacing: .newItem) {}

        CommandGroup(replacing: .sidebar) {
            ForEach(ViewMode.allCases) { mode in
                Button(mode.title) { switchMode(to: mode) }
                    .keyboardShortcut(KeyEquivalent(mode.shortcutDigit), modifiers: .command)
            }
            Divider()
            Button(shell.sidebarVisible ? "Kenar çubuğunu gizle" : "Kenar çubuğunu göster") {
                withAnimation(Motion.panel) { shell.sidebarVisible.toggle() }
            }
            .keyboardShortcut("s", modifiers: [.control, .command])
            Button(shell.inspectorVisible ? "İnceleme panelini gizle" : "İnceleme panelini göster") {
                withAnimation(Motion.panel) { shell.inspectorVisible.toggle() }
            }
            .keyboardShortcut("i", modifiers: [.option, .command])
            Divider()
            Button("Yakınlaştır") { withAnimation(Motion.snappy) { store.zoomIn() } }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(store.zoom >= 4)
            Button("Uzaklaştır") { withAnimation(Motion.snappy) { store.zoomOut() } }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(store.zoom <= 0.25)
            Button("Sığdır") { withAnimation(Motion.focus) { store.resetZoom() } }
                .keyboardShortcut("0", modifiers: .command)
            Button("Düzeni yeniden hesapla") { store.relayout() }
            Divider()
        }

        CommandMenu("Kasa") {
            Button("Notlarda ara") {
                if shell.sidebarVisible {
                    shell.requestFocus(.search)
                } else {
                    withAnimation(Motion.panel) { shell.sidebarVisible = true }
                    // Kenar çubuğu hiyerarşiye girdikten sonra odak iste.
                    Task { @MainActor in shell.requestFocus(.search) }
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            Button("Beyne sor") { shell.requestFocus(.ask) }
                .keyboardShortcut("l", modifiers: .command)
            Button("Komut paleti") {
                withAnimation(Motion.snappy) { shell.isPaletteOpen.toggle() }
            }
            .keyboardShortcut("k", modifiers: .command)
            Divider()
            Button("Seçili notu Obsidian'da aç") {
                if let id = store.selection { store.openInObsidian(id) }
            }
            .keyboardShortcut("o", modifiers: .command)
            .disabled(store.selection == nil)
            // Esc bu öğeye bağlı değil: menü kısayolu Esc'i her pencerede yutardı. Esc'i EscapeKeyMonitor ele alır.
            Button("Seçimi kaldır") {
                withAnimation(Motion.focus) { _ = shell.escape(store: store) }
            }
            .disabled(store.selection == nil)
            Divider()
            Button("Yeniden oku") {
                Task { await store.reload() }
            }
            .keyboardShortcut("r", modifiers: .command)
            Button("Kasayı Finder'da göster") { store.revealVaultInFinder() }
        }
    }

    private func switchMode(to mode: ViewMode) {
        withAnimation(Motion.view) { store.mode = mode }
    }
}
