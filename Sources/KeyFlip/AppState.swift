import Foundation
import Observation

@Observable
final class AppState {
    private enum Keys {
        static let excludedLayoutIDs = "excludedLayoutIDs"
        static let switchInputSourceAfterConvert = "switchInputSourceAfterConvert"
        static let convertSentenceWhenNoSelection = "convertSentenceWhenNoSelection"
        static let layoutDestinations = "layoutDestinations"
        static let hasLaunchedBefore = "hasLaunchedBefore"
    }

    /// Enabled macOS layouts the user has opted out of the conversion cycle.
    var excludedLayoutIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(excludedLayoutIDs), forKey: Keys.excludedLayoutIDs) }
    }

    /// Whether converting also switches the active input source to the target language.
    var switchInputSourceAfterConvert: Bool {
        didSet { UserDefaults.standard.set(switchInputSourceAfterConvert, forKey: Keys.switchInputSourceAfterConvert) }
    }

    /// With nothing selected, convert the text between the cursor and the previous period.
    var convertSentenceWhenNoSelection: Bool {
        didSet { UserDefaults.standard.set(convertSentenceWhenNoSelection, forKey: Keys.convertSentenceWhenNoSelection) }
    }

    /// Source layout ID → the layout it always converts into. A language with no
    /// entry here cycles to the next enabled one, which is the original behaviour.
    var layoutDestinations: [String: String] {
        didSet { UserDefaults.standard.set(layoutDestinations, forKey: Keys.layoutDestinations) }
    }

    /// False until the app has launched once, so a new install can show Settings.
    var hasLaunchedBefore: Bool {
        didSet { UserDefaults.standard.set(hasLaunchedBefore, forKey: Keys.hasLaunchedBefore) }
    }

    init() {
        excludedLayoutIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.excludedLayoutIDs) ?? [])
        switchInputSourceAfterConvert = UserDefaults.standard.object(forKey: Keys.switchInputSourceAfterConvert) as? Bool ?? true
        convertSentenceWhenNoSelection = UserDefaults.standard.object(forKey: Keys.convertSentenceWhenNoSelection) as? Bool ?? true
        layoutDestinations = UserDefaults.standard.dictionary(forKey: Keys.layoutDestinations) as? [String: String] ?? [:]
        hasLaunchedBefore = UserDefaults.standard.bool(forKey: Keys.hasLaunchedBefore)
    }
}
