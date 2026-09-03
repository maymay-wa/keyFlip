<div align="center">

## [⬇️ Download KeyFlip __VERSION__ for macOS](https://github.com/maymay-wa/keyFlip/releases/download/v__VERSION__/KeyFlip-__VERSION__.dmg)

[![Download the DMG](https://img.shields.io/badge/KeyFlip%20__VERSION__-Download%20.dmg-5b2fa8?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/maymay-wa/keyFlip/releases/download/v__VERSION__/KeyFlip-__VERSION__.dmg)

**macOS 14+** · Universal (Apple silicon & Intel) · signed and notarized by Apple

</div>

---

**Fix text you typed in the wrong keyboard language — with one keystroke.**

Select the mistyped text (or just leave the cursor after it), press **🌐⌘ (Globe + Command)**, and it is retyped as if you had pressed the same keys in your next keyboard language.

## Install

1. Open the downloaded **`KeyFlip-__VERSION__.dmg`**.
2. Drag **KeyFlip** into **Applications**.
3. Launch it. Settings opens on the first run; KeyFlip then lives in the menu bar.

Because the app is notarized, it opens without any Gatekeeper warnings.

On first launch KeyFlip asks for **Accessibility** access. It needs that to read the selected text, replace it, and listen for the hotkey. That is the only permission it uses — KeyFlip never phones home and touches nothing but your current selection.

## What's new in 1.1.0

**A destination per language.** Cycling assumes one layout per language. Keep Hebrew (QWERTY), Hebrew (PC) and English enabled and converting English landed in whichever Hebrew came next in the system list — a coin flip. Each language can now name the layout it converts into, so English → Hebrew (QWERTY) always means that one, and a second press flips straight back instead of walking on to Hebrew (PC).

**Ligature keys and combining marks convert correctly.** Arabic – PC types لا from a single key, which used to come back as the two separate letters it resembles — "brown" round-tripped to "ghrown". Thai and Devanagari put a letter and its mark on separate keys, and marked letters passed through untouched, so Thai text came back half-converted. Both are fixed, and the conversion is now checked against **every one of the 251 keyboard layouts macOS installs**.

**A rebuilt Settings window.** Each language is one popup that states the whole outcome — "Hebrew → English", or "Don't convert" — instead of a switch, an arrow and a menu to combine in your head. The window sizes to its content rather than leaving a slab of empty grey, shows the app icon and version, and raises the Accessibility warning as a warning, only while access is actually missing.

**Settings opens on first launch,** so a menu bar app with no Dock icon isn't a guessing game.

## Everything KeyFlip does

- One hotkey: Globe(fn) + Command. Hold Globe and tap Command to cycle quickly.
- Works with nothing selected — converts from the cursor back to the last period or line break.
- Works across whatever keyboard layouts you have enabled; input methods like Chinese and Japanese are skipped, having no key-for-key mapping.
- Handles stubborn apps: Electron (WhatsApp, Slack, Claude) and Catalyst (WhatsApp's Mac app).
- Detects which layout the text was typed in, so the first press usually does the right thing.
- Optionally switches your input source after converting, so you can keep typing.
- Launch at login, and per-language destinations in a small Settings window.

<details>
<summary>Verify your download</summary>

```sh
shasum -a 256 -c SHA256SUMS
```

</details>
