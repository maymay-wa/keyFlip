import SwiftUI
import Combine
import ServiceManagement
import ApplicationServices

/// What happens to text typed in one language. Three states in one control, so a
/// row reads as a sentence -- "Hebrew → English" -- instead of asking the reader
/// to combine a switch, an arrow and a menu in their head.
private enum Destination: Hashable {
    case off
    case next
    case layout(String)
}

struct SettingsView: View {
    @Bindable var appState: AppState
    @State private var layouts: [KeyboardLayout] = []
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Form {
                if !accessibilityGranted {
                    Section { accessibilityWarning }
                }
                Section {
                    if layouts.count < 2 {
                        needsMoreLayouts
                    } else {
                        ForEach(layouts) { layout in
                            languageRow(for: layout)
                        }
                    }
                } header: {
                    Text("Languages")
                } footer: {
                    Text("Each language converts to what you pick beside it. **Next language** cycles through the ones that are on — pick a language instead to always land there.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                Section {
                    Toggle("Switch keyboard language after converting", isOn: $appState.switchInputSourceAfterConvert)
                    Toggle("Convert the sentence before the cursor when nothing is selected",
                           isOn: $appState.convertSentenceWhenNoSelection)
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480)
        .frame(minHeight: 300, maxHeight: 620)
        .onAppear(perform: reload)
        .onReceive(refresh) { _ in reload() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("KeyFlip").font(.system(size: 16, weight: .semibold))
                    Text(Self.version).font(.callout).foregroundStyle(.tertiary)
                }
                Text("Fixes text you typed in the wrong keyboard language.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    Text("Select it, then press").font(.callout).foregroundStyle(.secondary)
                    keyCap("🌐")
                    keyCap("⌘")
                }
                .padding(.top, 1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func keyCap(_ symbol: String) -> some View {
        Text(symbol)
            .font(.system(size: 12))
            .frame(minWidth: 21, minHeight: 19)
            .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.tertiary, lineWidth: 0.5))
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: - Rows

    /// Only shown when access is missing -- when it is granted there is nothing to
    /// say, and a permanent green tick is just another row to read past.
    private var accessibilityWarning: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("KeyFlip can't convert anything yet").fontWeight(.medium)
                Text("It needs Accessibility access to read the selected text, replace it, and hear the hotkey.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Open Settings…") { openAccessibilitySettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }

    private var needsMoreLayouts: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "keyboard").foregroundStyle(.secondary).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text("Only one keyboard layout").fontWeight(.medium)
                Text("KeyFlip needs at least two to convert between. Add one in System Settings → Keyboard → Input Sources.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func languageRow(for layout: KeyboardLayout) -> some View {
        let isOff = appState.excludedLayoutIDs.contains(layout.id)
        return HStack(spacing: 10) {
            Text(layout.name)
                .foregroundStyle(isOff ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
            Spacer(minLength: 12)
            Picker("", selection: destinationBinding(for: layout)) {
                Text("Next language").tag(Destination.next)
                ForEach(otherLayouts(than: layout)) { other in
                    Text(other.name).tag(Destination.layout(other.id))
                }
                Divider()
                Text("Don't convert").tag(Destination.off)
            }
            .labelsHidden()
            .frame(width: 200)
        }
    }

    // MARK: - State

    private func reload() {
        layouts = InputSourceManager.enabledKeyboardLayouts()
        accessibilityGranted = AXIsProcessTrusted()
    }

    private func otherLayouts(than layout: KeyboardLayout) -> [KeyboardLayout] {
        layouts.filter { $0.id != layout.id && !appState.excludedLayoutIDs.contains($0.id) }
    }

    /// A destination naming a language that is now off or gone reads back as
    /// "Next language", so the menu never shows a choice that would be ignored.
    private func destinationBinding(for layout: KeyboardLayout) -> Binding<Destination> {
        Binding(
            get: {
                if appState.excludedLayoutIDs.contains(layout.id) { return .off }
                guard let id = appState.layoutDestinations[layout.id],
                      otherLayouts(than: layout).contains(where: { $0.id == id })
                else { return .next }
                return .layout(id)
            },
            set: { destination in
                switch destination {
                case .off:
                    appState.excludedLayoutIDs.insert(layout.id)
                    appState.layoutDestinations.removeValue(forKey: layout.id)
                case .next:
                    appState.excludedLayoutIDs.remove(layout.id)
                    appState.layoutDestinations.removeValue(forKey: layout.id)
                case .layout(let id):
                    appState.excludedLayoutIDs.remove(layout.id)
                    appState.layoutDestinations[layout.id] = id
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
