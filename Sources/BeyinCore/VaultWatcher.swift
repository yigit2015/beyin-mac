import CoreServices
import Foundation

/// Kasa klasörünü FSEvents ile izler; art arda gelen değişiklikleri 300 ms'de birleştirir.
final class VaultWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "io.github.yigit2015.beyin.watcher")
    private let onChange: @Sendable () -> Void
    private var pending: DispatchWorkItem?

    init(url: URL, latency: TimeInterval = 0.3, onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<VaultWatcher>.fromOpaque(info).takeUnretainedValue()
            let changed = unsafeBitCast(paths, to: NSArray.self) as? [String] ?? []
            // Gizli klasörlerdeki (.obsidian/workspace.json gibi) değişiklikler grafiği etkilemez.
            if changed.prefix(count).contains(where: { !$0.contains("/.") && $0.hasSuffix(".md") || !$0.contains(".") }) {
                watcher.schedule()
            }
        }
        stream = FSEventStreamCreate(
            kCFAllocatorDefault, callback, &context, [url.path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents))
        if let stream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
        }
    }

    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [onChange] in onChange() }
        pending = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
