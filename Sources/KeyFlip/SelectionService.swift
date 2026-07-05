import AppKit
import Carbon

/// Reads and replaces the selected text in whatever app is frontmost.
/// Prefers the Accessibility API; falls back to simulated ⌘C/⌘V with
/// clipboard save & restore for apps with poor AX support.
enum SelectionService {
    struct Selection {
        let text: String
        let axElement: AXUIElement?
    }

    static func readSelection() -> Selection? {
        if let (element, text) = accessibilitySelection() {
            return Selection(text: text, axElement: element)
        }
        if let text = copySelectionViaClipboard(), !text.isEmpty {
            return Selection(text: text, axElement: nil)
        }
        return nil
    }

    /// Replaces the selection and leaves the new text selected so the hotkey can cycle again.
    @discardableResult
    static func replace(_ selection: Selection, with newText: String) -> Bool {
        if let element = selection.axElement, replaceViaAccessibility(element, newText: newText) {
            return true
        }
        return replaceViaPaste(newText)
    }

    // MARK: - Accessibility path

    private static func accessibilitySelection() -> (AXUIElement, String)? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return nil }
        let element = focusedRef as! AXUIElement
        var textRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textRef) == .success,
              let text = textRef as? String, !text.isEmpty else { return nil }
        return (element, text)
    }

    private static func replaceViaAccessibility(_ element: AXUIElement, newText: String) -> Bool {
        var rangeRef: CFTypeRef?
        let hasRange = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success
        guard AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, newText as CFString) == .success else {
            return false
        }
        // Re-select the replacement so another hotkey press keeps cycling.
        if hasRange, let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID() {
            var oldRange = CFRange()
            if AXValueGetValue(rangeRef as! AXValue, .cfRange, &oldRange) {
                var newRange = CFRange(location: oldRange.location, length: newText.utf16.count)
                if let value = AXValueCreate(.cfRange, &newRange) {
                    AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
                }
            }
        }
        return true
    }

    // MARK: - Clipboard fallback

    private static func copySelectionViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)
        let changeCount = pasteboard.changeCount
        postKeystroke(CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
        var attempts = 0
        while pasteboard.changeCount == changeCount && attempts < 25 {
            usleep(20_000)
            attempts += 1
        }
        let text = pasteboard.changeCount == changeCount ? nil : pasteboard.string(forType: .string)
        restore(saved, to: pasteboard)
        return text
    }

    private static func replaceViaPaste(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(of: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postKeystroke(CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        usleep(150_000)
        // Best-effort re-selection of the pasted text so the hotkey can cycle again.
        for _ in 0..<text.count {
            postKeystroke(CGKeyCode(kVK_LeftArrow), flags: .maskShift)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            restore(saved, to: pasteboard)
        }
        return true
    }

    private static func snapshot(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }

    private static func restore(_ items: [NSPasteboardItem], to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }

    private static func postKeystroke(_ keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
