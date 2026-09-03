<div align="center">

## [⬇️ Download KeyFlip __VERSION__ for macOS](https://github.com/maymay-wa/keyFlip/releases/download/v__VERSION__/KeyFlip-__VERSION__.dmg)

[![Download the DMG](https://img.shields.io/badge/KeyFlip%20__VERSION__-Download%20.dmg-5b2fa8?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/maymay-wa/keyFlip/releases/download/v__VERSION__/KeyFlip-__VERSION__.dmg)

**macOS 14+** · Universal (Apple silicon & Intel) · signed and notarized by Apple

</div>

---

**Fix text you typed in the wrong keyboard language — with one keystroke.**

Select the mistyped text (or just leave the cursor after it), press **🌐⌘ (Globe + Command)**, and it is retyped as if you had pressed the same keys in your next keyboard language. Press again to cycle.

## Install

1. Open the downloaded **`KeyFlip-__VERSION__.dmg`**.
2. Drag **KeyFlip** into **Applications**.
3. Launch it — KeyFlip lives in the menu bar, with no windows of its own.

Because the app is notarized, it opens without any Gatekeeper warnings.

On first launch KeyFlip asks for **Accessibility** access (System Settings → Privacy & Security → Accessibility). It needs that to read the selected text, replace it, and listen for the hotkey. That is the only permission it uses — KeyFlip never phones home and touches nothing but your current selection.

You will also want at least **two keyboard layouts** enabled in System Settings → Keyboard → Input Sources.

## What's in this release

- One hotkey: Globe(fn) + Command. Hold Globe and tap Command to cycle through languages.
- Works with nothing selected — converts from the cursor back to the last period or line break.
- Cycles through whatever keyboard layouts you have enabled; input methods like Chinese and Japanese are skipped.
- Handles stubborn apps: Electron (WhatsApp, Slack, Claude) and Catalyst (WhatsApp's Mac app).
- Detects which layout the text was typed in, so the first press usually does the right thing.
- Optionally switches your input source after converting, so you can keep typing.
- Launch at login and per-language include/exclude in a small Settings window.

<details>
<summary>Verify your download</summary>

```sh
shasum -a 256 -c SHA256SUMS
```

</details>
