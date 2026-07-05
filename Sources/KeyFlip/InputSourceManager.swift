import Carbon
import Foundation

/// A keyboard layout, wrapped for use in SwiftUI lists and the conversion cycle.
struct KeyboardLayout: Identifiable, Equatable {
    let id: String
    let name: String
    let source: TISInputSource

    static func == (lhs: KeyboardLayout, rhs: KeyboardLayout) -> Bool { lhs.id == rhs.id }
}

enum InputSourceManager {
    /// Keyboard layouts the user has enabled in System Settings, in system order.
    /// Input methods without key layout data (Chinese, Japanese, …) are excluded.
    static func enabledKeyboardLayouts() -> [KeyboardLayout] {
        let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as Any] as CFDictionary
        return inputSources(matching: filter, includeAllInstalled: false).compactMap { source in
            guard boolProperty(source, kTISPropertyInputSourceIsEnabled),
                  boolProperty(source, kTISPropertyInputSourceIsSelectCapable) else { return nil }
            return layout(for: source)
        }
    }

    /// Looks a layout up among all installed sources, enabled or not. Used by tests.
    static func installedLayout(withID id: String) -> KeyboardLayout? {
        let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
        return inputSources(matching: filter, includeAllInstalled: true).first.flatMap(layout(for:))
    }

    static func currentLayoutID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return stringProperty(source, kTISPropertyInputSourceID)
    }

    static func select(_ layout: KeyboardLayout) {
        TISSelectInputSource(layout.source)
    }

    private static func layout(for source: TISInputSource) -> KeyboardLayout? {
        guard let id = stringProperty(source, kTISPropertyInputSourceID) else { return nil }
        return KeyboardLayout(id: id,
                              name: stringProperty(source, kTISPropertyLocalizedName) ?? id,
                              source: source)
    }

    private static func inputSources(matching filter: CFDictionary, includeAllInstalled: Bool) -> [TISInputSource] {
        guard let cfList = TISCreateInputSourceList(filter, includeAllInstalled)?.takeRetainedValue() else { return [] }
        return (0..<CFArrayGetCount(cfList)).compactMap { index in
            guard let pointer = CFArrayGetValueAtIndex(cfList, index) else { return nil }
            return unsafeBitCast(pointer, to: TISInputSource.self)
        }
    }

    private static func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private static func boolProperty(_ source: TISInputSource, _ key: CFString) -> Bool {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return false }
        return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(pointer).takeUnretainedValue())
    }
}
