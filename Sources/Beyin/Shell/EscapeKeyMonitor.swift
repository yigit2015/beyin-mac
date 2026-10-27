import AppKit
import SwiftUI

/// Esc sırası (Hareket · 06): önce açık panel, sonra arama, en son seçim.
/// Menü kısayolu yerine pencereye bağlı yerel olay izleyicisi: böylece
/// - açılır paneller (filtre) ve kalıcı paneller Esc'i kendileri alır,
/// - Ayarlar penceresinde Esc pencereyi kapatır,
/// - ana pencerede Esc `action` ile işlenir; işlenecek bir şey yoksa sisteme geçer.
struct EscapeKeyMonitor: NSViewRepresentable {
    /// Esc'i tükettiyse `true` döner.
    let action: @MainActor () -> Bool

    func makeNSView(context: Context) -> EscapeMonitorView {
        let view = EscapeMonitorView()
        view.action = action
        return view
    }

    func updateNSView(_ view: EscapeMonitorView, context: Context) {
        view.action = action
    }
}

final class EscapeMonitorView: NSView {
    var action: (@MainActor () -> Bool)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Yerel izleyiciler ana iş parçacığında çağrılır.
            let handled = MainActor.assumeIsolated { self?.handle(event) ?? false }
            return handled ? nil : event
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        guard event.keyCode == 53, modifiers.isEmpty, NSApp.modalWindow == nil else { return false }
        guard let mainWindow = window, let eventWindow = event.window else { return false }

        if eventWindow !== mainWindow {
            // Ayarlar penceresi Esc ile kapanır; açılır paneller ve diğer pencereler Esc'i kendileri işler.
            if Self.isSettingsWindow(eventWindow) {
                eventWindow.performClose(nil)
                return true
            }
            return false
        }
        guard mainWindow.attachedSheet == nil else { return false }
        // Yazı girişi bileşimi (ör. aksan) sürüyorsa Esc onundur.
        if let editor = mainWindow.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        return action?() ?? false
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        let identifier = window.identifier?.rawValue ?? ""
        return identifier.localizedCaseInsensitiveContains("settings") || window.frameAutosaveName.localizedCaseInsensitiveContains("settings")
    }

    override func removeFromSuperview() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        super.removeFromSuperview()
    }
}
