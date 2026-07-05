import Foundation
import Observation

@Observable
final class AppState {
    private enum Keys {
        static let excludedLayoutIDs = "excludedLayoutIDs"
        static let switchInputSourceAfterConvert = "switchInputSourceAfterConvert"
    }

    /// Enabled macOS layouts the user has opted out of the conversion cycle.
    var excludedLayoutIDs: Set<String> {
        didSet { UserDefaults.standard.set(Array(excludedLayoutIDs), forKey: Keys.excludedLayoutIDs) }
    }

    /// Whether converting also switches the active input source to the target language.
    var switchInputSourceAfterConvert: Bool {
        didSet { UserDefaults.standard.set(switchInputSourceAfterConvert, forKey: Keys.switchInputSourceAfterConvert) }
    }

    init() {
        excludedLayoutIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.excludedLayoutIDs) ?? [])
        switchInputSourceAfterConvert = UserDefaults.standard.object(forKey: Keys.switchInputSourceAfterConvert) as? Bool ?? true
    }
}
