import SwiftUI
import Combine
import ServiceManagement
import ApplicationServices

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var layouts: [KeyboardLayout] = []
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Text("Select mistyped text anywhere, then press 🌐⌘ (Globe + Command). Press it again to cycle to the next language.")
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(accessibilityGranted ? Color.green : Color.orange)
                    Text(accessibilityGranted
                         ? "Accessibility access granted"
                         : "KeyFlip needs Accessibility access to read and replace the selected text.")
                    Spacer()
                    if !accessibilityGranted {
                        Button("Open System Settings") { openAccessibilitySettings() }
                    }
                }
            }
            Section("Languages in the cycle") {
                ForEach(layouts) { layout in
                    Toggle(layout.name, isOn: inclusionBinding(for: layout))
                }
                if layouts.count < 2 {
                    Text("Enable at least two keyboard layouts in System Settings → Keyboard → Input Sources.")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Toggle("Switch keyboard language after converting", isOn: $appState.switchInputSourceAfterConvert)
                Toggle("With nothing selected, convert back to the last period", isOn: $appState.convertSentenceWhenNoSelection)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 460)
        .onAppear {
            layouts = InputSourceManager.enabledKeyboardLayouts()
            accessibilityGranted = AXIsProcessTrusted()
            NSApp.activate(ignoringOtherApps: true)
        }
        .onReceive(refresh) { _ in
            accessibilityGranted = AXIsProcessTrusted()
            layouts = InputSourceManager.enabledKeyboardLayouts()
        }
    }

    private func inclusionBinding(for layout: KeyboardLayout) -> Binding<Bool> {
        Binding(
            get: { !appState.excludedLayoutIDs.contains(layout.id) },
            set: { included in
                if included {
                    appState.excludedLayoutIDs.remove(layout.id)
                } else {
                    appState.excludedLayoutIDs.insert(layout.id)
                }
            }
        )
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
