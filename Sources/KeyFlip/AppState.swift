import Foundation
import Observation

@Observable
final class AppState {
    private enum Keys {
        static let excludedLayoutIDs = "excludedLayoutIDs"
        static let switchInputSourceAfterConvert = "switchInputSourceAfterConvert"
        static let convertSentenceWhenNoSelection = "convertSentenceWhenNoSelection"
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

    init() {
        excludedLayoutIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.excludedLayoutIDs) ?? [])
        switchInputSourceAfterConvert = UserDefaults.standard.object(forKey: Keys.switchInputSourceAfterConvert) as? Bool ?? true
        convertSentenceWhenNoSelection = UserDefaults.standard.object(forKey: Keys.convertSentenceWhenNoSelection) as? Bool ?? true
    }
}
