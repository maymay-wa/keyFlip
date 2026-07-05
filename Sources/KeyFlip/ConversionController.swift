import AppKit
import ApplicationServices

/// Ties everything together: hotkey → read selection → convert → replace → switch layout.
final class ConversionController {
    private let appState: AppState
    private let converter = LayoutConverter()

    /// Cycle state so repeated presses keep advancing through the languages.
    private var lastOutput: String?
    private var lastTargetID: String?
    private var lastConversionTime = Date.distantPast
    private static let cycleWindow: TimeInterval = 15

    init(appState: AppState) {
        self.appState = appState
    }

    func performConversion() {
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            return
        }
        let layouts = InputSourceManager.enabledKeyboardLayouts()
            .filter { !appState.excludedLayoutIDs.contains($0.id) }
        guard layouts.count >= 2,
              let selection = SelectionService.readSelection(sentenceFallback: appState.convertSentenceWhenNoSelection) else {
            NSSound.beep()
            return
        }

        let sourceLayout = sourceLayout(for: selection.text, among: layouts)
        guard let sourceIndex = layouts.firstIndex(of: sourceLayout) else { return }
        let targetLayout = layouts[(sourceIndex + 1) % layouts.count]

        let converted = converter.convert(selection.text, from: sourceLayout, to: targetLayout)
        guard SelectionService.replace(selection, with: converted) else {
            NSSound.beep()
            return
        }

        lastOutput = converted
        lastTargetID = targetLayout.id
        lastConversionTime = Date()

        if appState.switchInputSourceAfterConvert {
            InputSourceManager.select(targetLayout)
        }
    }

    /// The layout the selection was (mis)typed in: the previous conversion's target if we're
    /// mid-cycle, otherwise the enabled layout whose characters best cover the text.
    private func sourceLayout(for text: String, among layouts: [KeyboardLayout]) -> KeyboardLayout {
        if let lastOutput, let lastTargetID,
           text == lastOutput,
           Date().timeIntervalSince(lastConversionTime) < Self.cycleWindow,
           let previousTarget = layouts.first(where: { $0.id == lastTargetID }) {
            return previousTarget
        }
        let currentID = InputSourceManager.currentLayoutID()
        let best = layouts.max { lhs, rhs in
            score(of: text, for: lhs, currentID: currentID) < score(of: text, for: rhs, currentID: currentID)
        }
        return best ?? layouts[0]
    }

    private func score(of text: String, for layout: KeyboardLayout, currentID: String?) -> Double {
        var value = converter.coverage(of: text, by: layout)
        if layout.id == currentID {
            value += 0.01 // Tie-break toward the active layout.
        }
        return value
    }
}
