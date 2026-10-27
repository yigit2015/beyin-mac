import BeyinCore
import SwiftUI

/// Boş kasa (Durumlar · 1): kasa seçili ama hiç not yok.
struct EmptyVaultView: View {
    let store: VaultStore

    @Environment(\.palette) private var palette

    var body: some View {
        StateScaffold {
            ZStack {
                DottedRing(diameter: 132)
                OrbView(size: 72, phase: .dimmed)
            }
            .frame(width: 150, height: 150)
            .padding(.bottom, 4)

            StateTitle("Kasan henüz boş")
            StateMessage("Beyin, Obsidian kasandaki notları gösterir. Obsidian’da ilk notunu yazdığında burada belirecek.",
                         maxWidth: 380)

            HStack(spacing: 10) {
                Button("Obsidian’ı aç") { VaultPicker.openObsidian(vault: store.vaultURL) }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Başka kasa seç…") { VaultPicker.choose(for: store) }
                    .buttonStyle(CapsuleButtonStyle())
            }
            .padding(.top, 6)

            Chip(height: 22) {
                Text("\(BeyinFormat.path(store.vaultURL)) · 0 not")
            }
            .font(.system(size: 11.5, weight: .medium, design: .monospaced))
            .padding(.top, 4)
        }
    }
}
