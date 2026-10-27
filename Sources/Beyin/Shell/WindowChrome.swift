import AppKit
import SwiftUI

/// Gizli başlık çubuğunda trafik ışıklarını kenar çubuğunun içine yerleştirir (Main.dc.html: kenar çubuğunun
/// ilk satırı; pencere kenarından 10 + iç boşluk 12 + 6). Pencere yeniden boyutlanınca ve tam ekrandan dönünce
/// yeniden uygulanır. Görünmez; yalnız pencereye erişmek için arka plana konur.
struct TrafficLightInset: NSViewRepresentable {
    var origin: CGPoint = CGPoint(x: 28, y: 28)

    func makeNSView(context: Context) -> TrafficLightAnchorView {
        let view = TrafficLightAnchorView()
        view.origin = origin
        return view
    }

    func updateNSView(_ view: TrafficLightAnchorView, context: Context) {
        view.origin = origin
        view.apply()
    }
}

final class TrafficLightAnchorView: NSView {
    var origin: CGPoint = .zero
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }
        let names: [Notification.Name] = [
            NSWindow.didResizeNotification, NSWindow.didEndLiveResizeNotification,
            NSWindow.didExitFullScreenNotification, NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.apply() }
            }
        }
        apply()
    }

    override func layout() {
        super.layout()
        apply()
    }

    func apply() {
        guard let window, !window.styleMask.contains(.fullScreen),
              let close = window.standardWindowButton(.closeButton),
              let miniaturize = window.standardWindowButton(.miniaturizeButton),
              let zoom = window.standardWindowButton(.zoomButton),
              let container = close.superview?.superview else { return }
        // Başlık kabı düğmeleri alt kenarına sabitler: kabı uzatmak düğmeleri aşağı iter.
        // Düğmenin pencere üstüne uzaklığını ölç, hedefle farkı kadar kabı uzat.
        let buttonTop = window.frame.height - close.convert(close.bounds, to: nil).maxY
        let delta = origin.y - buttonTop
        if abs(delta) > 0.5 {
            var frame = container.frame
            frame.size.height = min(max(close.frame.height, frame.height + delta), origin.y + close.frame.height + 24)
            frame.origin.y = window.frame.height - frame.height
            container.frame = frame
        }
        let spacing = miniaturize.frame.minX - close.frame.minX
        for (index, button) in [close, miniaturize, zoom].enumerated() {
            let target = CGPoint(x: origin.x + CGFloat(index) * spacing, y: button.frame.minY)
            if button.frame.origin != target { button.setFrameOrigin(target) }
        }
    }
}
