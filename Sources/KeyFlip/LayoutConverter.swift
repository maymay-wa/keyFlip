import Carbon
import Foundation

/// A physical key press: virtual key code plus whether Shift was held.
struct KeyStroke: Hashable {
    let keyCode: UInt16
    let shift: Bool
}

/// Character tables for one keyboard layout.
struct LayoutMaps {
    /// (key, shift) → the text that key types in this layout.
    var forward: [KeyStroke: String] = [:]
    /// Text → the key that produces it (unshifted mappings win on collisions).
    var reverse: [String: KeyStroke] = [:]
    /// Longest run of scalars any single key produces. Arabic – PC puts لا on one
    /// key, so matching one scalar at a time would never find it again.
    var longestOutput = 1
}

/// Remaps text between keyboard layouts: the characters you typed in one layout,
/// re-interpreted as the same physical key presses in another.
final class LayoutConverter {
    private var cache: [String: LayoutMaps] = [:]

    func convert(_ text: String, from source: KeyboardLayout, to target: KeyboardLayout) -> String {
        guard let sourceMaps = maps(for: source), let targetMaps = maps(for: target) else { return text }
        // Scalars, not Characters: Thai and Devanagari put a base letter and its
        // mark on separate keys, and Swift would glue those into one Character that
        // matches no single key press.
        let scalars = Array(text.unicodeScalars)
        var result = ""
        var index = 0
        while index < scalars.count {
            // Longest match first: a key that types several scalars has to be
            // recognised as one key press, not mistaken for that many separate ones.
            var matchedLength = 0
            let longest = min(sourceMaps.longestOutput, scalars.count - index)
            for length in stride(from: longest, through: 1, by: -1) {
                let candidate = String(String.UnicodeScalarView(scalars[index..<(index + length)]))
                if let stroke = sourceMaps.reverse[candidate],
                   let replacement = targetMaps.forward[stroke] {
                    result += replacement
                    matchedLength = length
                    break
                }
            }
            if matchedLength == 0 {
                result.unicodeScalars.append(scalars[index])
                matchedLength = 1
            }
            index += matchedLength
        }
        return result
    }

    /// Fraction of the text's letter-like characters this layout could have produced.
    /// Used to guess which layout a mistyped selection belongs to.
    func coverage(of text: String, by layout: KeyboardLayout) -> Double {
        guard let layoutMaps = maps(for: layout) else { return 0 }
        let relevant = text.unicodeScalars.filter { !$0.properties.isWhitespace && !("0"..."9").contains($0) }
        guard !relevant.isEmpty else { return 0 }
        let covered = relevant.filter { layoutMaps.reverse[String($0)] != nil }
        return Double(covered.count) / Double(relevant.count)
    }

    func maps(for layout: KeyboardLayout) -> LayoutMaps? {
        if let cached = cache[layout.id] { return cached }
        guard let built = Self.buildMaps(for: layout.source) else { return nil }
        cache[layout.id] = built
        return built
    }

    /// Runs UCKeyTranslate over every typing key (codes 0–50) in both shift states
    /// to learn what characters the layout produces.
    private static func buildMaps(for source: TISInputSource) -> LayoutMaps? {
        guard let dataPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil // Not a key layout (e.g. a Chinese/Japanese input method).
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(dataPointer).takeUnretainedValue() as Data
        let keyboardType = UInt32(LMGetKbdType())
        var maps = LayoutMaps()

        layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let layoutPointer = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }
            for shift in [false, true] {
                let modifierState: UInt32 = shift ? UInt32((shiftKey >> 8) & 0xFF) : 0
                for keyCode in UInt16(0)...50 {
                    var deadKeyState: UInt32 = 0
                    var characters = [UniChar](repeating: 0, count: 4)
                    var length = 0
                    let status = UCKeyTranslate(layoutPointer,
                                                keyCode,
                                                UInt16(kUCKeyActionDisplay),
                                                modifierState,
                                                keyboardType,
                                                OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                                &deadKeyState,
                                                characters.count,
                                                &length,
                                                &characters)
                    guard status == noErr, length > 0 else { continue }
                    let output = String(utf16CodeUnits: characters, count: Int(length))
                    guard !output.isEmpty,
                          output.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
                    else { continue }
                    let stroke = KeyStroke(keyCode: keyCode, shift: shift)
                    maps.forward[stroke] = output
                    if maps.reverse[output] == nil {
                        maps.reverse[output] = stroke
                    }
                    maps.longestOutput = max(maps.longestOutput, output.unicodeScalars.count)
                }
            }
        }
        return maps.forward.isEmpty ? nil : maps
    }
}
