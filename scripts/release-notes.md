**Fix text you typed in the wrong keyboard language — with one keystroke.**

Select the mistyped text (or just leave the cursor after it), press **🌐⌘ (Globe + Command)**, and it is retyped as if you had pressed the same keys in your next keyboard language. Press again to cycle.

## Install

1. Download the **`.dmg`** below and open it.
2. Drag **KeyFlip** into **Applications**.
3. Launch it — KeyFlip lives in the menu bar, with no windows of its own.

The app is signed and notarized by Apple, so it opens without any Gatekeeper warnings.

On first launch KeyFlip asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). It needs that to read the selected text, replace it, and listen for the hotkey. That is the only permission it uses — KeyFlip never phones home and touches nothing but your current selection.

You will also want at least **two keyboard layouts** enabled in System Settings → Keyboard → Input Sources.

## Requirements

macOS 14 (Sonoma) or later. Apple silicon and Intel.

## What's in this release

- One hotkey: Globe(fn) + Command. Hold Globe and tap Command to cycle through languages.
- Works with nothing selected — converts from the cursor back to the last period or line break.
- Cycles through whatever keyboard layouts you have enabled; input methods like Chinese and Japanese are skipped.
- Handles stubborn apps: Electron (WhatsApp, Slack, Claude) and Catalyst (WhatsApp's Mac app).
- Detects which layout the text was typed in, so the first press usually does the right thing.
- Optionally switches your input source after converting, so you can keep typing.
- Launch at login and per-language include/exclude in a small Settings window.

Verify your download against `SHA256SUMS`:

```sh
shasum -a 256 -c SHA256SUMS
```
