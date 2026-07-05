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
- **Smart detection**: figures out which layout the text was typed in, so the first press almost always does the right thing.
- **Switches your keyboard too** (optional): after converting, your input source flips to the target language so you can keep typing. Toggle it off in Settings.
- **Menu bar app**: with launch-at-login and per-language include/exclude in a small Settings window.

## Install

Build from source (requires Xcode 15+):

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

On first launch, KeyFlip asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). It needs this to read the selected text, replace it, and listen for the hotkey. That's the only permission it uses — KeyFlip never phones home and touches nothing but your current selection.

You'll also need at least **two keyboard layouts** enabled in System Settings → Keyboard → Input Sources.

## How it works

Every keyboard layout on macOS ships a table of *physical key → character*. KeyFlip reads those tables with `UCKeyTranslate`, inverts the one your text was typed in to recover the key presses, and replays them through the next layout's table. Selected text is read and replaced through the Accessibility API (with a clipboard-preserving ⌘C/⌘V fallback for apps with poor accessibility support).

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
