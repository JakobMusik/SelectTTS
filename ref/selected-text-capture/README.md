# Capturing Selected Text on macOS — Reference

Research reference for **SelectTTS**: how to grab the user's currently-selected text from *any*
application on macOS, the way Easydict / PopClip / LookUp / similar selection utilities do it.

> Compiled via a multi-source, adversarially-verified deep-research pass (15 sources, 25 claims
> verified). See [`sources.md`](./sources.md) for provenance and per-claim verification status.

## Documents

| File | Contents |
|------|----------|
| [`01-methods.md`](./01-methods.md) | The four capture methods in detail, with Swift code: Accessibility API, simulated Cmd+C, AppleScript/Apple Events, menu-bar AXPress. |
| [`02-permissions-and-caveats.md`](./02-permissions-and-caveats.md) | Required TCC permissions, entitlements, sandboxing limits, Electron/WebKit caveats, per-app failure table. |
| [`03-easydict-selectedtextkit.md`](./03-easydict-selectedtextkit.md) | Exactly how Easydict / SelectedTextKit combines the methods and orders its fallbacks. |
| [`sources.md`](./sources.md) | Annotated bibliography + what the research verified vs. inferred. |

## TL;DR

There is **no single API** that reliably returns the selection from every app. Production tools
chain several methods and fall back when one fails. The canonical chain (Easydict's) is:

```
1. Accessibility API   (kAXSelectedTextAttribute on the focused element)   ← fast, no clipboard side-effects
2. AppleScript         (getSelection() in the browser)                      ← for Safari/Chrome web content
3. Simulated Cmd+C     (synthesize ⌘C, read NSPasteboard, restore it)       ← universal last resort
   └─ menu-bar AXPress (trigger Edit ▸ Copy directly)                        ← variant of #3, "most reliable"
```

## Method comparison

| Method | Clipboard touched? | Visual flicker | Speed | Coverage | Permission |
|--------|:---:|:---:|:---:|----------|------------|
| **Accessibility (AX)** | No | No | Instant | Native AppKit text; **fails** on Safari/Chrome web, Electron MAS, terminals, some Java | Accessibility |
| **AppleScript (browser)** | No | No | ~10–50 ms | Safari & Chrome web content only (needs "Allow JS from Apple Events") | Automation / Apple Events |
| **Menu-bar AXPress** | Yes (a real copy) | No | Fast | Any app with an Edit ▸ Copy menu item | Accessibility |
| **Simulated ⌘C** | Yes (save+restore) | No | ~100 ms (poll) | Almost everything that supports copy | Accessibility |

## Recommended chain for SelectTTS

A TTS reader should **avoid clobbering the user's clipboard** whenever possible, so prefer the
non-destructive methods first — this is exactly why Easydict leads with Accessibility:

1. **Accessibility API** — try `kAXSelectedTextAttribute` on the system-wide focused element.
   Zero side effects, instant. Covers most native macOS apps (Notes, TextEdit, Xcode, Mail
   compose, NSTextView-based editors).
2. **AppleScript** — if the frontmost app is a known browser (Safari/Chrome bundle id), run
   `getSelection().toString()`. Non-destructive, gets web-page selections that AX can't see.
3. **Menu-bar AXPress or simulated ⌘C** — last resort for everything else (Electron, terminals,
   custom-rendered UIs). **Back up the pasteboard, copy, read, then restore** so the user's
   clipboard is untouched. Mute the system alert volume to suppress the "no-selection" beep.

Required entitlements/permissions for SelectTTS: **Accessibility** (mandatory) and **Automation**
(for the AppleScript step). This combination is **incompatible with the Mac App Store sandbox** —
plan on direct/notarized distribution, like Easydict. See `02-permissions-and-caveats.md`.
