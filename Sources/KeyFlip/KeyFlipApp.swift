import SwiftUI
import ApplicationServices

@main
struct KeyFlipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
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
        } label: {
            MenuBarLabel(appState: delegate.appState)
        }
        Settings {
            SettingsView(appState: delegate.appState)
        }
    }
}

/// The menu bar icon -- and the app's only view that exists from launch, with no
/// window to be shown in. That makes it the one place a fresh install can open
/// Settings from: `openSettings` is a SwiftUI environment action, and AppDelegate
/// has no supported way to reach the Settings scene.
private struct MenuBarLabel: View {
    let appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image("MenuBarIcon")
            .task {
                guard !appState.hasLaunchedBefore else { return }
                appState.hasLaunchedBefore = true
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
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
