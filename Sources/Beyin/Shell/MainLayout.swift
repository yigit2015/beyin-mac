import BeyinCore
import SwiftUI

/// Ana pencere düzeni (Main.dc.html): sol cam kenar çubuğu · ortada tuval · sağda inceleme paneli.
/// Dış boşluk 10. Pencere 1180 pt'den darsa inceleme paneli tuvalin üstünde yüzer.
struct MainLayout: View {
    let store: VaultStore
    let shell: ShellState

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var windowWidth: CGFloat = 1440

    private var isNarrow: Bool { windowWidth < 1180 }
    private var sidebarWidth: CGFloat { isNarrow ? 220 : 244 }
    private var inspectorWidth: CGFloat { windowWidth >= 1600 ? 380 : 360 }
    private var floatingInspectorWidth: CGFloat { min(inspectorWidth, windowWidth * 0.42) }

    /// Yüzen panelin tuvali örttüğü genişlik + 16 pt; yerleşik ya da kapalıyken 0 (ShellState.canvasTrailingOcclusion).
    private var trailingOcclusion: CGFloat {
        showsInspector && isNarrow ? floatingInspectorWidth + 16 : 0
    }

    var body: some View {
        HStack(spacing: 10) {
            if shell.sidebarVisible {
                SidebarView(store: store, shell: shell)
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            canvas

            if showsInspector, !isNarrow {
                InspectorPanel(store: store, shell: shell)
                    .frame(width: inspectorWidth)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(10)
        .overlay { paletteOverlay }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { windowWidth = $0 }
        .motion(Motion.panel, value: showsInspector)
        .motion(Motion.panel, value: shell.sidebarVisible)
        .onChange(of: trailingOcclusion, initial: true) { _, value in
            withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.canvasTrailingOcclusion = value }
        }
        .onDisappear { shell.canvasTrailingOcclusion = 0 }
    }

    /// Panel; seçili bir not, Beyne sor sonuçları ya da (Odak'ta) etkin küme varken görünür.
    /// Genel bakışta yalnız sonuçlar için açılır.
    private var showsInspector: Bool {
        guard shell.inspectorVisible else { return false }
        if shell.ask != nil { return true }
        if store.mode == .odak, store.activeCluster != nil { return true }
        guard let id = store.selection, store.graph.note(id) != nil else { return false }
        return store.mode != .genelBakis
    }

    // MARK: Tuval

    private var canvas: some View {
        ZStack {
            canvasContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .id(store.mode)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .top) {
            CanvasToolbar(store: store, shell: shell)
                .padding(.top, 8)
        }
        .overlay(alignment: .bottom) { bottomControls }
        .overlay(alignment: .topLeading) {
            if !shell.sidebarVisible {
                Button {
                    withAnimation(Motion.resolve(Motion.panel, reduce: reduceMotion)) { shell.sidebarVisible = true }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .buttonStyle(IconButtonStyle())
                .floatingGlass(in: Circle(), interactive: true)
                .padding(.leading, 84)
                .padding(.top, 8)
                .accessibilityLabel("Kenar çubuğunu göster")
                .help("Kenar çubuğunu göster (⌃⌘S)")
                .transition(.opacity)
            }
        }
        .overlay(alignment: .trailing) {
            if showsInspector, isNarrow {
                // Dar pencere: araç çubuğunun altından Beyne sor çubuğunun üstüne kadar yüzer.
                InspectorPanel(store: store, shell: shell)
                    .frame(width: floatingInspectorWidth)
                    .padding(.top, 60)
                    .padding(.bottom, store.mode == .genelBakis ? 88 : 116)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tuval — \(store.mode.title)")
    }

    @ViewBuilder
    private var canvasContent: some View {
        switch store.mode {
        case .odak: OdakView(store: store)
        case .ag: AgView(store: store)
        case .kure: KureView(store: store)
        case .genelBakis: GenelBakisView(store: store, shell: shell)
        }
    }

    /// Yakın yüzen kontroller tek GlassEffectContainer(spacing: 10) içinde.
    private var bottomControls: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                AskBar(store: store, shell: shell)
                    .padding(.horizontal, 16)
                if store.mode != .genelBakis {
                    TimelineStrip(store: store)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, store.mode == .genelBakis ? 26 : 6)
        }
    }

    // MARK: ⌘K

    @ViewBuilder
    private var paletteOverlay: some View {
        if shell.isPaletteOpen {
            ZStack(alignment: .top) {
                Color(red: 4 / 255, green: 8 / 255, blue: 16 / 255, opacity: palette.isDark ? 0.35 : 0.18)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Motion.paletteOut) { shell.isPaletteOpen = false }
                    }
                    .accessibilityHidden(true)
                CommandPalette(store: store, shell: shell)
                    .padding(.top, 72)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
            .transition(.opacity)
            .zIndex(10)
        }
    }
}
