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
                Text("Select mistyped text anywhere, then press 🌐⌘ (Globe + Command). Press it again to convert the result onward.")
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
            Section("Languages") {
                ForEach(layouts) { layout in
                    HStack {
                        Toggle(isOn: inclusionBinding(for: layout)) {
                            Text(layout.name)
                        }
                        Spacer(minLength: 12)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.tertiary)
                        Picker("", selection: destinationBinding(for: layout)) {
                            Text("Next language").tag(String?.none)
                            ForEach(destinationChoices(excluding: layout)) { choice in
                                Text(choice.name).tag(String?.some(choice.id))
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                        .disabled(appState.excludedLayoutIDs.contains(layout.id))
                    }
                }
                if layouts.count < 2 {
                    Text("Enable at least two keyboard layouts in System Settings → Keyboard → Input Sources.")
                        .foregroundStyle(.secondary)
                }
                Text("“Next language” cycles through the languages you've ticked. Pick a language instead and text always converts straight to it — the way to go when two of your layouts are the same language.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .frame(width: 500, height: 560)
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

    /// Where a conversion from `layout` may land: every ticked language but itself.
    private func destinationChoices(excluding layout: KeyboardLayout) -> [KeyboardLayout] {
        layouts.filter { $0.id != layout.id && !appState.excludedLayoutIDs.contains($0.id) }
    }

    /// nil means "no destination set" -- cycle to the next language. A destination
    /// pointing at a language that is gone or unticked also reads back as nil, so
    /// the picker never shows a choice that would not actually be honoured.
    private func destinationBinding(for layout: KeyboardLayout) -> Binding<String?> {
        Binding(
            get: {
                guard let id = appState.layoutDestinations[layout.id],
                      destinationChoices(excluding: layout).contains(where: { $0.id == id })
                else { return nil }
                return id
            },
            set: { destination in
                if let destination {
                    appState.layoutDestinations[layout.id] = destination
                } else {
                    appState.layoutDestinations.removeValue(forKey: layout.id)
                }
            }
        )
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
