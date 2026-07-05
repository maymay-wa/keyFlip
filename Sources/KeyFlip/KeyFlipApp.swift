import SwiftUI
import ApplicationServices

@main
struct KeyFlipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("KeyFlip", systemImage: "keyboard") {
            Button("Convert Selected Text  🌐⌘") {
                delegate.convertFromMenu()
            }
            Divider()
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit KeyFlip") {
                NSApplication.shared.terminate(nil)
            }
        }
        Settings {
            SettingsView(appState: delegate.appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private(set) lazy var controller = ConversionController(appState: appState)
    private let hotkey = HotkeyMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        hotkey.onTrigger = { [weak self] in
            self?.controller.performConversion()
        }
        hotkey.start()
    }

    func convertFromMenu() {
        // Give the menu time to close so focus returns to the app with the selection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.controller.performConversion()
        }
    }
}
