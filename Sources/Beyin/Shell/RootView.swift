import BeyinCore
import SwiftUI

/// Pencere kökü: zemin, tema, durum ekranları ve ana düzen.
struct RootView: View {
    let store: VaultStore
    let shell: ShellState
    let launch: LaunchOptions

    @AppStorage(SettingKey.theme) private var theme: ThemePreference = .system
    @AppStorage(SettingKey.privateNotes) private var privatePreference: PrivateNotePreference = .dimmed
    @AppStorage(SettingKey.watchChanges) private var watchChanges = true
    @Environment(\.openSettings) private var openSettings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Backdrop()
            content
                .ignoresSafeArea(.container, edges: .top)
        }
        .background(TrafficLightInset(origin: trafficLightOrigin))
        .background(EscapeKeyMonitor {
            var handled = false
            withAnimation(Motion.resolve(Motion.focus, reduce: reduceMotion)) { handled = shell.escape(store: store) }
            return handled
        })
        .providesPalette()
        .environment(shell)
        .onAppear { theme.apply() }
        .onChange(of: theme) { _, newValue in newValue.apply() }
        .onChange(of: privatePreference, initial: true) { _, newValue in
            store.filters.hidePrivate = newValue == .hidden
        }
        .onChange(of: store.filters.hidePrivate) { _, hidden in
            privatePreference = hidden ? .hidden : .dimmed
        }
        .onChange(of: watchChanges) { _, enabled in store.watchesChanges = enabled }
        .task {
            // İzleme tercihi yüklemeden önce uygulanır: kapalıysa load() izlemeyi hiç başlatmaz.
            store.watchesChanges = watchChanges
            applyLaunchOptions()
            if !launch.isPreview { await store.load() }
            if let title = launch.select {
                store.selection = title == "none" ? nil : store.graph.notes.values.first { $0.title == title }?.id
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch store.state {
            case .idle, .loading:
                LoadingView(store: store)
            case .empty:
                EmptyVaultView(store: store)
            case .notFound(let url):
                VaultNotFoundView(store: store, url: url)
            case .loaded:
                MainLayout(store: store, shell: shell)
            }
        }
        .transition(.opacity)
        .motion(Motion.view, value: stateKey)
    }

    /// Ana düzende kenar çubuğunun ilk satırı; durum ekranlarında 56 pt'lik rayın üstü.
    private var trafficLightOrigin: CGPoint {
        store.state == .loaded ? CGPoint(x: 28, y: 27) : CGPoint(x: 18, y: 16)
    }

    /// Durum geçişleri için kaba anahtar: ilerleme değişimlerinde çapraz geçiş yapılmasın.
    private var stateKey: Int {
        switch store.state {
        case .idle, .loading: 0
        case .empty: 1
        case .notFound: 2
        case .loaded: 3
        }
    }

    private func applyLaunchOptions() {
        if let mode = launch.mode { store.mode = mode }
        if let query = launch.askQuery { shell.runAsk(query, scope: .all, store: store) }
        if launch.opensPalette { shell.isPaletteOpen = true }
        if launch.opensSettings { openSettings() }
        // BEYIN_WINDOW=1100x800: test için pencere boyutu (görünür alana sığdırılır, ortalanır).
        if let size = launch.windowSize,
           let window = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) && $0.identifier?.rawValue.localizedCaseInsensitiveContains("settings") != true }) {
            let visible = window.screen?.visibleFrame.size ?? size
            window.setContentSize(CGSize(width: min(size.width, visible.width), height: min(size.height, visible.height)))
            window.center()
        }
    }
}
