import AppKit

/// Watches for the Globe(fn)+Command chord pressed on its own, and fires on release.
/// Pressing any regular key while the chord is held cancels it, so shortcuts like
/// fn+cmd+arrow don't trigger a conversion. Holding fn and tapping cmd cycles repeatedly.
final class HotkeyMonitor {
    var onTrigger: (() -> Void)?

    private static let combo: NSEvent.ModifierFlags = [.function, .command]
    private static let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
    private var armed = false
    private var monitors: [Any] = []

    func start() {
        guard monitors.isEmpty else { return }
        if let flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event)
        }) {
            monitors.append(flagsMonitor)
        }
        if let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] _ in
            self?.armed = false
        }) {
            monitors.append(keyMonitor)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(Self.relevant)
        if flags == Self.combo {
            armed = true
        } else if armed {
            armed = false
            // Fire only if a modifier was released; adding another modifier cancels.
            if flags.subtracting(Self.combo).isEmpty {
                onTrigger?()
            }
        }
    }
}
