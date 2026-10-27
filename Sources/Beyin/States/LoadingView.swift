import BeyinCore
import SwiftUI

/// Yükleniyor (Durumlar · 2): orb nabız gibi atar, ilerleme halkası dolar, LoadPhase adımları sırayla tamamlanır.
struct LoadingView: View {
    let store: VaultStore

    @Environment(\.palette) private var palette

    private static let phases: [LoadPhase] = [.scanning, .resolving, .layout]

    var body: some View {
        StateScaffold {
            ZStack {
                DottedRing(diameter: 132, color: Color(red: 200 / 255, green: 188 / 255, blue: 1, opacity: 0.14), lineWidth: 2,
                           rotates: false)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [palette.teal, palette.violet2], startPoint: .topLeading, endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 132, height: 132)
                    .motion(Motion.panel, value: progress)
                OrbView(size: 72, phase: .loading)
            }
            .frame(width: 150, height: 150)
            .padding(.bottom, 4)
            .accessibilityElement()
            .accessibilityLabel("Kasa okunuyor")
            .accessibilityValue("yüzde \(Int((progress * 100).rounded()))")
            .accessibilityAddTraits(.updatesFrequently)

            StateTitle("Kasa okunuyor…")

            countsLine
                .font(BeyinFont.body.monospacedDigit())
                .foregroundStyle(palette.t2)
                .contentTransition(.numericText(value: progress))
                .accessibilityElement(children: .combine)

            HStack(spacing: 14) {
                ForEach(Self.phases, id: \.self) { phase in
                    step(phase)
                }
            }
            .font(.system(size: 12))
            .padding(.top, 6)

            Text("İlk açılış kasa boyutuna göre sürer. Beyin hiçbir dosyayı değiştirmez; yalnızca okur.")
                .font(BeyinFont.caption)
                .foregroundStyle(palette.t3)
                .padding(.top, 6)
        }
    }

    /// "212 / 380 not · 118 bağlantı çözüldü" (Durumlar · 2). Sayaç yoksa yüzde ve kasa yolu.
    @ViewBuilder
    private var countsLine: some View {
        if let counts = store.loadingCounts, counts.total > 0 {
            let notes = Text("\(Text(BeyinFormat.number(counts.scanned)).foregroundStyle(palette.t1)) / \(BeyinFormat.number(counts.total)) not")
            if let links = counts.resolvedLinks {
                Text("\(notes) · \(Text(BeyinFormat.number(links)).foregroundStyle(palette.t1)) bağlantı çözüldü")
            } else {
                notes
            }
        } else {
            Text("\(Text("%\(Int((progress * 100).rounded()))").foregroundStyle(palette.t1)) · \(BeyinFormat.path(store.vaultURL))")
        }
    }

    private var progress: Double {
        if case .loading(let progress, _) = store.state { return min(max(progress, 0), 1) }
        return 0
    }

    private var currentIndex: Int {
        if case .loading(_, let phase) = store.state { return Self.phases.firstIndex(of: phase) ?? 0 }
        return 0
    }

    @ViewBuilder
    private func step(_ phase: LoadPhase) -> some View {
        let index = Self.phases.firstIndex(of: phase) ?? 0
        HStack(spacing: 6) {
            if index < currentIndex {
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                Text(doneTitle(phase))
            } else if index == currentIndex {
                BreathingDot(color: palette.violet2, size: 8)
                Text(phase.title)
            } else {
                Circle().strokeBorder(palette.t3, lineWidth: 1.5).frame(width: 8, height: 8)
                Text(phase.title)
            }
        }
        .foregroundStyle(index < currentIndex ? palette.teal : (index == currentIndex ? palette.t1 : palette.t3))
        .accessibilityElement(children: .combine)
        .accessibilityValue(index < currentIndex ? "tamamlandı" : (index == currentIndex ? "sürüyor" : "bekliyor"))
    }

    private func doneTitle(_ phase: LoadPhase) -> String {
        switch phase {
        case .scanning: "Dosyalar tarandı"
        case .resolving: "Wikilink’ler çözüldü"
        case .layout: "Düzen hesaplandı"
        }
    }
}
