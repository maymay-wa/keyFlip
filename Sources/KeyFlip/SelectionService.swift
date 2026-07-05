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

    /// Reads the current selection. With nothing selected and `sentenceFallback` on,
    /// selects and returns the text between the cursor and the previous period instead.
    static func readSelection(sentenceFallback: Bool) -> Selection? {
        if let element = focusedElement() {
            var textRef: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &textRef)
            if status == .success, let text = textRef as? String {
                if !text.isEmpty {
                    return Selection(text: text, axElement: element)
                }
                return sentenceFallback ? selectSentenceBeforeCursor(in: element) : nil
            }
        }
        // The focused element doesn't answer AX text queries; fall back to simulated ⌘C.
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

    // MARK: - Sentence-before-cursor

    private static let sentenceBoundaries: Set<Character> = [".", "!", "?", "\n", "\r"]

    /// The range and text of the unfinished sentence ending at the cursor: everything after
    /// the last period (or line break), leading whitespace skipped. Offsets are UTF-16,
    /// matching AX range semantics. Pure logic, exposed for tests.
    static func sentenceBeforeCursor(in text: String, cursorUTF16 location: Int) -> (utf16Range: CFRange, text: String)? {
        guard location > 0, location <= text.utf16.count else { return nil }
        let cursor = String.Index(utf16Offset: location, in: text)
        let prefix = text[..<cursor]
        var start = prefix.startIndex
        if let boundary = prefix.lastIndex(where: { sentenceBoundaries.contains($0) }) {
            start = prefix.index(after: boundary)
        }
        while start < prefix.endIndex, prefix[start].isWhitespace {
            start = prefix.index(after: start)
        }
        let sentence = String(prefix[start..<prefix.endIndex])
        guard !sentence.isEmpty else { return nil }
        let startOffset = start.utf16Offset(in: text)
        return (CFRange(location: startOffset, length: location - startOffset), sentence)
    }

    private static func selectSentenceBeforeCursor(in element: AXUIElement) -> Selection? {
        guard let value = stringAttribute(element, kAXValueAttribute),
              let selectedRange = rangeAttribute(element, kAXSelectedTextRangeAttribute),
              selectedRange.length == 0,
              let (range, sentence) = sentenceBeforeCursor(in: value, cursorUTF16: selectedRange.location)
        else { return nil }
        var newRange = range
        guard let rangeValue = AXValueCreate(.cfRange, &newRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, rangeValue) == .success
        else { return nil }
        return Selection(text: sentence, axElement: element)
    }

    // MARK: - Accessibility path

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() else { return nil }
        return (focusedRef as! AXUIElement)
    }

    private static func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success else { return nil }
        return ref as? String
    }

    private static func rangeAttribute(_ element: AXUIElement, _ attribute: String) -> CFRange? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(ref as! AXValue, .cfRange, &range) else { return nil }
        return range
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
