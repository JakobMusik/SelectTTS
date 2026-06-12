# Permissions, Entitlements, Sandboxing & App-Specific Caveats

## TCC permissions

macOS gates each technique behind a different Transparency-Consent-Control (TCC) permission. Users
grant these in **System Settings ▸ Privacy & Security**.

| Permission | TCC service | Needed for | API to check | Granted how |
|------------|-------------|-----------|--------------|-------------|
| **Accessibility** | `kTCCServiceAccessibility` | Reading AX attributes of *other* apps (Method 1 & 4) **and** posting synthetic key events to them (Method 2) | `AXIsProcessTrusted()` | User toggles in Privacy ▸ Accessibility |
| **Automation** | `kTCCServiceAppleEvents` | AppleScript controlling browsers (Method 3) | (prompted on first AppleEvent) | Per-target-app prompt, Privacy ▸ Automation |
| **Input Monitoring** | `kTCCServiceListenEvent` | *Listening* to global key events via `CGEventTap` (e.g. a global hotkey to trigger capture) | `CGPreflightListenEventAccess()` / `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` | User toggles in Privacy ▸ Input Monitoring |

Key distinctions worth getting right:

- **Posting vs. listening to events.** *Posting* synthetic events (Method 2) and reading AX both
  fall under **Accessibility**. **Input Monitoring** is only about *receiving/observing* input —
  you need it if SelectTTS registers a global hotkey via a `CGEventTap`. An `NSEvent` global
  monitor for hotkeys, by contrast, requires **Accessibility**, not Input Monitoring.
- **Accessibility cannot be granted programmatically.** You can only *prompt*:
  ```swift
  let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
  let trusted = AXIsProcessTrustedWithOptions(opts)
  ```
  After the user enables it, the process usually must be **relaunched** to pick up the grant.
- **Automation prompts per controlled app.** The first time you AppleScript Safari, the user sees
  a prompt; again for Chrome; etc. Denials are sticky until reset (`tccutil reset AppleEvents`).

## Entitlements (direct distribution)

For a **notarized, directly-distributed** app (the realistic path for SelectTTS):

- **Hardened Runtime** is required for notarization.
- If you script other apps you need `com.apple.security.automation.apple-events` **and** an
  `NSAppleEventsUsageDescription` string. (Outside the sandbox these entitlements gate the
  hardened-runtime checks rather than the sandbox container.)
- **Accessibility needs no entitlement** — it's purely a runtime TCC grant. But a hardened-runtime
  app reading AX from others is fine once the user grants Accessibility.

## The App Store sandbox problem

This is the decisive constraint for a selection-grabber:

- The App Sandbox **blocks reading the Accessibility tree of other apps** and **blocks arbitrary
  Apple Events**. A sandboxed MAS app effectively cannot implement Methods 1, 3, or 4 against other
  applications.
- Therefore tools like **Easydict ship outside the sandbox** (notarized direct download / Homebrew),
  not as pure sandboxed MAS apps. Plan SelectTTS the same way: **direct, notarized distribution.**
- PopClip is distributed both via its website and the Mac App Store, but the selection mechanism
  fundamentally depends on the (non-sandbox) Accessibility grant; MAS distribution of such tools
  involves special handling and historically friction. Treat "ship the full selection-grabber on
  the MAS sandbox" as **not viable**.

> Research note: the specific forum claims about "Input Monitoring being available to sandboxed
> apps / Accessibility causing MAS rejection" were *abstained on* by the verifiers (couldn't
> re-fetch the Apple Dev Forums thread), so treat the exact MAS-policy wording as engineering lore,
> not a verified citation. The architectural takeaway — selection-grabbers run unsandboxed — is
> solid and is how Easydict actually ships.

## App-specific failure matrix

Which method works where. "✅ best" = the method these tools actually use for that target.

| Target app / surface | Method 1 (AX) | Method 3 (AppleScript) | Method 2/4 (⌘C / AXPress) |
|----------------------|:---:|:---:|:---:|
| Native AppKit (Notes, TextEdit, Xcode, Mail) | ✅ best | — | ✅ |
| **Safari** web content | ❌ `AXWebArea` null *(verified)* | ✅ best | ✅ |
| **Chrome / Edge / Brave / Arc** web content | ⚠️ off unless renderer a11y on | ✅ best | ✅ |
| **Firefox** | ⚠️ unreliable | ❌ no AppleScript | ✅ best |
| **Electron** apps (Slack, VS Code, Discord) | ⚠️ buggy; ❌ on MAS builds (`mas_no_private_api.patch`) | ❌ | ✅ best |
| Terminals (Terminal, iTerm2, Alacritty) | ❌ | ❌ | ✅ (varies) |
| Java/Swing apps | ⚠️ varies | ❌ | ✅ |
| Password fields | ❌ | ❌ | ❌ (copy blocked) |

### Notable per-target facts (from the sources)

- **Safari / WebKit**: `kAXSelectedText` on the `AXWebArea` returns null — *this is why Easydict
  branches to AppleScript for browsers.* **Verified (3-0).**
- **Mail, Chrome, Firefox**: a 2014 macdevelopers write-up found the AX selection approach failed to
  return text in Mail, Chrome, and Firefox specifically. *(Source cited; verifiers abstained —
  treat as illustrative; modern versions differ, but the browser-AX weakness persists.)*
- **Electron MAS builds**: `selectedText`, `selectedTextRange`, `selectedTextMarkerRange` AX
  properties are removed by Chromium's `mas_no_private_api.patch` (`#ifndef MAS_BUILD`). So AX
  selection reading is dead on Mac-App-Store Electron apps. *(Source: electron/electron#22908;
  verifiers abstained, but this is a well-known, real Electron behavior.)*
- **Electron selection-range bugs**: off-by-one when a line starts with whitespace, and trailing
  line-break inclusion at end-of-line. *(electron/electron#36337.)* → prefer simulated ⌘C on Electron.

## Practical reliability tips

- **Always pair the destructive methods with pasteboard backup/restore** and **muted alert volume**
  (Easydict's `withMutedAlertVolume`) — verified behavior, and it's what makes simulated-copy feel
  invisible to the user.
- **Detect the frontmost app** (`NSWorkspace.shared.frontmostApplication`) to branch: browser
  bundle ids → AppleScript; otherwise AX-first.
- **Time-box the clipboard poll** (~100 ms) and treat "no change" as "no selection."
- **Re-add to the Accessibility list after macOS upgrades** if capture silently stops — a common
  PopClip troubleshooting step; the TCC grant can desync after OS updates. *(PopClip KB; abstained,
  but widely reported.)*
