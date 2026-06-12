# How Easydict / SelectedTextKit Combines the Methods

Easydict's selection capture is factored into a standalone Swift package, **SelectedTextKit**
(`github.com/tisfeng/SelectedTextKit`), reused by both the Easydict macOS app and the Raycast
extension. This is the closest thing to a reference implementation of "grab selected text from any
macOS app." Everything below is from its README / source and the Easydict FAQ.

## The strategy enum

SelectedTextKit exposes selection strategies (names per its README/API): **verified 3-0.**

| Strategy | Mechanism | Notes |
|----------|-----------|-------|
| `.accessibility` | Read `kAXSelectedTextAttribute` from the focused element (Method 1) | Fast, non-destructive |
| `.appleScript` | Run `getSelection()` in the browser via Apple Events (Method 3) | Browser web content |
| `.menuAction` | `AXPress` the Edit ▸ Copy menu item (Method 4), then read pasteboard | "Most reliable" copy trigger |
| `.shortcut` | Synthesize ⌘C and read `NSPasteboard` (Method 2) | Universal fallback |
| `.auto` | **Accessibility → menu action** | Default; README marks it **"Most reliable"** |

> **Verified (3-0):** SelectedTextKit implements those four strategies plus `.auto`, and the
> recommended default `.auto` chains *accessibility then menu action* and is marked "most reliable."

## `.shortcut` implementation details (verified 3-0)

The simulated-copy path does three things that make it production-grade:

1. **Synthesizes ⌘C using `KeySender`** (a small keystroke library) rather than raw CGEvent calls.
2. **Backs up and restores the `NSPasteboard`** around the copy, so the user's clipboard is
   preserved.
3. **Mutes the system alert volume** during the copy (`withMutedAlertVolume`) so a failed/empty
   copy doesn't play the error "funk" sound.

This trio is the difference between a hacky simulate-⌘C and one users never notice. Replicate all
three in SelectTTS.

## Easydict's runtime fallback order (verified 3-0)

Per the **Easydict FAQ**, when the user triggers "get selected text," Easydict tries, in order:

```
1. Accessibility            (kAXSelectedTextAttribute on the focused element)
2. AppleScript  — browsers  (getSelection(); used because Safari's AXWebArea returns null)
3. Simulated ⌘C             (synthesize the copy keystroke, read & restore the pasteboard)
```

- Step 1 is the default because it is free and side-effect-free.
- Step 2 exists specifically because **Safari/WebKit doesn't expose selected text via AX**
  (`kAXSelectedText` is null on `AXWebArea`) — **verified 3-0.** Easydict detects the browser and
  runs `getSelection()` instead.
- Step 3 is the catch-all for everything AX and AppleScript can't handle (Electron, terminals,
  custom-rendered apps).

> **A nuance the research *refuted*:** a tempting but wrong claim is that browsers use a *different*
> order `[.appleScript, .accessibility, .menuAction, .shortcut]`. The verifiers refuted that exact
> ordering (1-2). The dependable statement is the FAQ's three-step order above; don't over-specify
> the per-browser permutation.

## What the research could NOT confirm about Easydict/PopClip

Be honest about the edges (see `sources.md` for why):

- **"Easydict requires Accessibility specifically to read selection"** was *refuted* (0-3). Reason:
  it's an over-claim — the AppleScript browser path leans on **Automation**, not Accessibility, and
  AppleScript can read a browser selection without the Accessibility grant. Accessibility is
  required for Methods 1/2/4, *not* for the Method-3 browser path. So "Accessibility is required for
  *everything*" is false; "Accessibility is required for the AX and simulated-copy paths" is true.
- **PopClip's exact mechanism** (synthesized ⌘C vs. AX polling), its dependence on the standard
  ⌘C/⌘X/⌘V mapping, and its failures in emacs/vim/MacVim/Alacritty/qutebrowser were *not verified*
  (verifiers abstained — couldn't re-fetch the PopClip KB). They're plausible and match observed
  behavior, but cite them as "reported," not "verified."

## Takeaways for SelectTTS

1. **Copy SelectedTextKit's architecture**: a strategy enum + an `.auto` chain. You can even depend
   on or vendor SelectedTextKit directly (MIT-style, part of Easydict).
2. **Lead with Accessibility**, branch to AppleScript for browser bundle ids, fall back to a
   pasteboard-preserving copy (menu AXPress preferred, simulated ⌘C as the floor).
3. **Port the three `.shortcut` niceties**: pasteboard save/restore, alert-volume muting, and a
   bounded changeCount poll.
