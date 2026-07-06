# KeyFlip 🌐⌘

**Fix text you typed in the wrong keyboard language — with one keystroke.**

You know the moment: you type a whole sentence, look up, and it's gibberish because your keyboard was still in the other language. `akuo` instead of `שלום`. KeyFlip fixes it in place:

1. Select the mistyped text.
2. Press **🌐⌘ (Globe + Command)**.
3. The text is retyped as if you had pressed the same keys in your next keyboard language.
4. Press again to cycle to the next language.

KeyFlip lives quietly in your menu bar. No windows, no fuss.

## Features

- **One hotkey**: Globe(fn) + Command, pressed together. Hold Globe and tap Command to cycle through languages quickly.
- **No selection needed**: with nothing selected, KeyFlip converts what you just typed — from the cursor back to the last period (or line break). Toggle it off in Settings.
- **Works with all your layouts**: cycles through whatever keyboard layouts you have enabled in macOS (input methods like Chinese/Japanese are skipped — they have no key-for-key mapping).
- **Works in stubborn apps**: Electron apps (WhatsApp, Slack, Claude) and Catalyst apps (WhatsApp's Mac app) need special handling to read and replace text — KeyFlip does it automatically.
- **Smart detection**: figures out which layout the text was typed in, so the first press almost always does the right thing.
- **Switches your keyboard too** (optional): after converting, your input source flips to the target language so you can keep typing. Toggle it off in Settings.
- **Menu bar app**: with launch-at-login and per-language include/exclude in a small Settings window.

## Install

### Download

Grab `KeyFlip-x.y.z.dmg` from the [latest release](../../releases/latest), open it, and drag **KeyFlip** to **Applications**.

The app is not notarized (no Apple Developer subscription), so the first launch needs one extra step: **right-click KeyFlip.app → Open → Open**. If macOS still refuses, approve it under System Settings → Privacy & Security → "Open Anyway", or clear the quarantine flag:

```sh
xattr -cr /Applications/KeyFlip.app
```

### Build from source

Requires Xcode 15+:

```sh
git clone <this repo>
cd KeyFlip
open KeyFlip.xcodeproj   # then ⌘R
```

Or from the command line:

```sh
xcodebuild -project KeyFlip.xcodeproj -scheme KeyFlip -configuration Release -derivedDataPath build build
open build/Build/Products/Release/KeyFlip.app
```

To produce the distributable DMG and zip in `dist/`, run `scripts/package.sh`.

### Releasing (signed + notarized)

One-time setup, with an Apple Developer account:

1. **Developer ID certificate**: Xcode → Settings → Accounts → add the account → Manage Certificates → **+** → *Developer ID Application* (Account Holder role required).
2. **App-specific password**: create one at [account.apple.com](https://account.apple.com) → Sign-In and Security → App-Specific Passwords.
3. **Store notary credentials** (Team ID is under Membership at [developer.apple.com/account](https://developer.apple.com/account)):

   ```sh
   xcrun notarytool store-credentials keyflip \
     --apple-id <account email> --team-id <TEAMID> --password <app-specific password>
   ```

Then each release is one command — it builds, signs, notarizes, staples, and verifies with Gatekeeper:

```sh
SIGN_IDENTITY="Developer ID Application: <Name> (<TEAMID>)" NOTARY_PROFILE=keyflip scripts/package.sh
```

On first launch, KeyFlip asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). It needs this to read the selected text, replace it, and listen for the hotkey. That's the only permission it uses — KeyFlip never phones home and touches nothing but your current selection.

You'll also need at least **two keyboard layouts** enabled in System Settings → Keyboard → Input Sources.

## How it works

Every keyboard layout on macOS ships a table of *physical key → character*. KeyFlip reads those tables with `UCKeyTranslate`, inverts the one your text was typed in to recover the key presses, and replays them through the next layout's table.

Reading and replacing the text goes through the Accessibility API, with fallbacks for apps that don't play nice:

- **Electron apps** (WhatsApp, Slack, Claude) keep their accessibility tree disabled until asked — KeyFlip enables it via `AXManualAccessibility` and retries.
- **Catalyst apps** (WhatsApp's Mac app) expose no text attributes, or accept AX writes without applying them — KeyFlip verifies each AX operation actually took effect and otherwise falls back to synthetic keystrokes (⇧⌘← to select, clipboard-preserving ⌘C/⌘V to read and replace), waiting for all physical modifiers to be released first so the hotkey's own keys don't corrupt the synthetic events.

If conversion misbehaves in a specific app, logs are available under the `com.barakmayer.KeyFlip` subsystem in Console.app.

Regenerate the Xcode project after changing `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
xcodegen generate
```

Run the tests:

```sh
xcodebuild -project KeyFlip.xcodeproj -scheme KeyFlip test
```

## Contributing

Issues and PRs welcome — this is a small, fun project and easy to hack on. The interesting bits:

| File | What it does |
| --- | --- |
| `Sources/KeyFlip/LayoutConverter.swift` | The key-remapping engine |
| `Sources/KeyFlip/HotkeyMonitor.swift` | Globe+Cmd chord detection |
| `Sources/KeyFlip/SelectionService.swift` | Reading/replacing the selection |
| `Sources/KeyFlip/ConversionController.swift` | Detection, cycling, orchestration |

## License

[MIT](LICENSE)
