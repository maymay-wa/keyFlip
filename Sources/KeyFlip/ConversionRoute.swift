import Foundation

/// Decides where a conversion goes.
///
/// By default KeyFlip cycles: each press hands the text to the next enabled
/// layout. That falls apart once you keep two layouts for the same language --
/// with Hebrew (QWERTY), Hebrew (PC) and English enabled, converting English
/// lands in whichever Hebrew happens to be next in the list. So a language can
/// instead name its own destination, and conversions from it always go there.
enum ConversionRoute {
    /// The layout `source` converts into. Returns nil when there is nothing to
    /// convert into (fewer than two usable layouts).
    ///
    /// A destination that is no longer enabled -- the user removed the layout in
    /// System Settings, or unticked it here -- is ignored rather than honoured,
    /// so a stale preference degrades to cycling instead of breaking conversion.
    static func target(from source: KeyboardLayout,
                       among layouts: [KeyboardLayout],
                       destinations: [String: String]) -> KeyboardLayout? {
        guard layouts.count >= 2 else { return nil }
        if let destinationID = destinations[source.id],
           destinationID != source.id,
           let destination = layouts.first(where: { $0.id == destinationID }) {
            return destination
        }
        guard let index = layouts.firstIndex(of: source) else { return layouts.first }
        return layouts[(index + 1) % layouts.count]
    }
}
