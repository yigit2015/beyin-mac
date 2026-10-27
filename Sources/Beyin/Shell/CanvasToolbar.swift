import BeyinCore
import SwiftUI

/// Yüzen araç çubuğu (Bileşenler · 08): floating cam, 44 yükseklik, iç 5; düğme 34 daire.
/// Görünüm segmenti · yakınlaştır/uzaklaştır ve yüzde · filtre (altın sayaç) · düzeni yenile.
/// Genel bakışta yakınlaştırma yerine dönem menüsü gelir.
struct CanvasToolbar: View {
    let store: VaultStore
    let shell: ShellState

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            viewSegment
            separator
            if store.mode == .genelBakis {
                periodMenu
            } else {
                zoomControls
                separator
                filterButton
                Button {
                    withAnimation(Motion.resolve(Motion.view, reduce: reduceMotion)) { store.relayout() }
                } label: {
                    Image(systemName: "circle.grid.cross")
                }
                .buttonStyle(IconButtonStyle())
                .accessibilityLabel("Düzeni yeniden hesapla")
                .help("Düzeni yeniden hesapla")
            }
        }
        .padding(5)
        .floatingGlass(in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Araç çubuğu")
    }

    private var separator: some View {
        Rectangle()
            .fill(palette.hair)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
            .accessibilityHidden(true)
    }

    private var viewSegment: some View {
        HStack(spacing: 2) {
            ForEach(ViewMode.allCases) { mode in
                Button {
                    withAnimation(Motion.resolve(Motion.view, reduce: reduceMotion)) { store.mode = mode }
                } label: {
                    Image(systemName: mode.symbol)
                }
                .buttonStyle(IconButtonStyle(isActive: store.mode == mode))
                .accessibilityLabel(mode == .genelBakis ? mode.title : "\(mode.title) görünümü")
                .accessibilityAddTraits(store.mode == mode ? .isSelected : [])
                .help(Text(verbatim: "\(mode.title) (⌘\(mode.shortcutDigit))"))
            }
        }
        .padding(2)
        .background(palette.chip, in: Capsule())
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button { withAnimation(Motion.resolve(Motion.snappy, reduce: reduceMotion)) { store.zoomOut() } } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(IconButtonStyle())
            .disabled(store.zoom <= 0.25)
            .accessibilityLabel("Uzaklaştır")
            .help("Uzaklaştır (⌘−)")

            // Türkçe yazımda yüzde işareti başa gelir: %100.
            Text("%\(Int((store.zoom * 100).rounded()))")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(palette.t2)
                .frame(width: 40)
                .contentTransition(.numericText(value: store.zoom))
                .accessibilityLabel("Yakınlaştırma")
                .accessibilityValue("yüzde \(Int((store.zoom * 100).rounded()))")

            Button { withAnimation(Motion.resolve(Motion.snappy, reduce: reduceMotion)) { store.zoomIn() } } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(IconButtonStyle())
            .disabled(store.zoom >= 4)
            .accessibilityLabel("Yakınlaştır")
            .help("Yakınlaştır (⌘+)")
        }
    }

    private var filterButton: some View {
        Button { shell.isFilterPopoverOpen.toggle() } label: {
            Image(systemName: "line.3.horizontal.decrease")
        }
        .buttonStyle(IconButtonStyle(isActive: shell.isFilterPopoverOpen))
        .overlay(alignment: .topTrailing) {
            if activeFilterCount > 0 {
                Text("\(activeFilterCount)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color(hex: 0x1A1204))
                    .frame(minWidth: 14, minHeight: 14)
                    .background(palette.gold, in: Capsule())
                    .offset(x: -3, y: 3)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .motion(Motion.pop, value: activeFilterCount)
        .accessibilityLabel(activeFilterCount == 0 ? "Filtreler" : "Filtreler — \(activeFilterCount) etkin")
        .help("Filtreler")
        .popover(isPresented: Binding(get: { shell.isFilterPopoverOpen }, set: { shell.isFilterPopoverOpen = $0 }),
                 arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel("Filtreler")
                    Spacer()
                    Button("Sıfırla") { store.filters = GraphFilters() }
                        .buttonStyle(.link)
                        .font(.system(size: 11.5))
                        .disabled(activeFilterCount == 0)
                }
                .padding(.horizontal, 10)
                FilterControls(store: store, showsLabel: false)
            }
            .padding(12)
            .frame(width: 260)
            .providesPalette()
        }
    }

    /// Varsayılandan farklı filtre sayısı.
    private var activeFilterCount: Int {
        let filters = store.filters
        let defaults = GraphFilters()
        var count = NoteCategory.allCases.filter { !filters.categories.contains($0) }.count
        if filters.project != defaults.project { count += 1 }
        if filters.dateRange != defaults.dateRange { count += 1 }
        if filters.hidePrivate != defaults.hidePrivate { count += 1 }
        if filters.showIsolated != defaults.showIsolated { count += 1 }
        return count
    }

    private var periodMenu: some View {
        Menu {
            ForEach([DateRangeFilter.last30, .last90, .all]) { range in
                Button(range.title) { shell.overviewRange = range }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar").font(.system(size: 13))
                Text(shell.overviewRange.title)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
            }
            .font(.system(size: 12.5))
            .foregroundStyle(palette.t2)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .contentShape(Capsule())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Dönem")
        .accessibilityValue(shell.overviewRange.title)
    }
}
