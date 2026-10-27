import BeyinCore
import SwiftUI

/// Kasa bulunamadı (Durumlar · 3): kayıtlı klasör yerinde değil.
struct VaultNotFoundView: View {
    let store: VaultStore
    let url: URL

    @Environment(\.palette) private var palette
    @State private var isRetrying = false

    var body: some View {
        StateScaffold {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(palette.orange)
                .frame(width: 76, height: 76)
                .floatingGlass(in: Circle())
                .overlay(Circle().strokeBorder(palette.orange.opacity(0.35), lineWidth: 1))
                .shadow(color: palette.orange.opacity(0.22), radius: 20)
                .accessibilityHidden(true)

            StateTitle("Kasa bulunamadı").padding(.top, 6)

            Text(BeyinFormat.path(url))
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(palette.orange)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(palette.orangeFill, in: Capsule())
                .overlay(Capsule().strokeBorder(palette.orange.opacity(0.4), lineWidth: 1))
                .accessibilityLabel("Klasör yolu \(BeyinFormat.path(url))")

            StateMessage("Klasör taşınmış, yeniden adlandırılmış ya da bağlı olmayan bir diskte olabilir. Beyin hiçbir dosyayı değiştirmez; yalnızca okur.")

            HStack(spacing: 10) {
                Button("Başka klasör seç…") { VaultPicker.choose(for: store) }
                    .buttonStyle(PrimaryButtonStyle())
                Button {
                    isRetrying = true
                    Task {
                        await store.load()
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRetrying { ProgressView().controlSize(.mini) }
                        Text("Tekrar dene")
                    }
                }
                .buttonStyle(CapsuleButtonStyle())
                .disabled(isRetrying)
            }
            .padding(.top, 6)
        }
    }
}
