# The Four Methods for Capturing Selected Text

Every macOS selection-grabber (Easydict, PopClip, LookUp, Shottr, etc.) is built from some subset
of these four techniques. None works everywhere, so they are chained as fallbacks.

---

## Method 1 — Accessibility API (`kAXSelectedTextAttribute`)

**The preferred primary method.** Reads the selection straight out of the focused UI element via
Apple's Accessibility (AX) framework. No clipboard mutation, no synthetic keystrokes, instant.

### How it works

1. Create a **system-wide** accessibility element: `AXUIElementCreateSystemWide()`.
2. Ask it for the **focused UI element**: `AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute, …)`.
3. Read `kAXSelectedTextAttribute` from that focused element.
   - (Fallback: read `kAXValueAttribute` for the whole field, or `kAXSelectedTextRangeAttribute`
     + `kAXValueAttribute` to slice the substring.)

> This `system-wide → focused element → selected text` walk is the textbook technique. The
> research verifiers *abstained* on the third-party blog write-ups (couldn't re-fetch them), so
> they show as "killed" in the raw run, but it is the standard, correct approach. See `sources.md`.

### Swift

```swift
import ApplicationServices

func axSelectedText() -> String? {
    let systemWide = AXUIElementCreateSystemWide()

    var focused: AnyObject?
    guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focused
          ) == .success,
          let element = focused
    else { return nil }
    let axElement = element as! AXUIElement

    var selected: AnyObject?
    let err = AXUIElementCopyAttributeValue(
        axElement, kAXSelectedTextAttribute as CFString, &selected
    )
    guard err == .success, let text = selected as? String, !text.isEmpty
    else { return nil }   // .noValue / .attributeUnsupported → element has no AX selection
    return text
}
```

### Pros
- **No side effects** — clipboard untouched, no beep, no flicker. Ideal for a TTS app.
- **Instant** and synchronous; no polling.
- Can also read selection bounds (`kAXBoundsForRangeParameterizedAttribute`) for overlay UI.

### Cons / where it fails
- **WebKit (Safari)**: the `AXWebArea` returns `null` for `kAXSelectedText` — verified. Use
  AppleScript instead.
- **Chrome / Chromium**: AX selection is off unless renderer accessibility is enabled.
- **Firefox**: unreliable / off by default.
- **Electron, Mac App Store builds**: the `selectedText` AX property is compiled out by
  `mas_no_private_api.patch` (it relies on a private API). AX selection reading returns nothing
  on MAS-distributed Electron apps. Electron also has off-by-one selection-range bugs.
- **Terminals** (Terminal.app, iTerm2, Alacritty), some **Java/Swing** apps, password fields.
- Native AppKit text (`NSTextView`, `NSTextField`, `WKWebView` in *some* apps) works well.

### Permission
- **Accessibility** (`Privacy & Security ▸ Accessibility`). Check with `AXIsProcessTrusted()`;
  prompt with `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): true])`.
  Cannot be granted programmatically — the user must toggle it.

---

## Method 2 — Simulated ⌘C + `NSPasteboard` (the universal fallback)

**Works almost everywhere** because it drives the app's own copy command, then reads the clipboard.
The price: it *uses* the clipboard, so you must save and restore it.

### How it works
1. Snapshot the current pasteboard: read every item's data for every type, and record
   `NSPasteboard.general.changeCount`.
2. (Optionally clear it / just remember the count.)
3. **Synthesize ⌘C** with `CGEvent` and post it to the HID event tap.
4. **Poll** `NSPasteboard.general.changeCount` until it increments (with a timeout, e.g. 100 ms),
   then read the new string.
5. **Restore** the original pasteboard contents.
6. **Mute the system alert volume** during the operation so that, if nothing was selected and the
   copy fails, the user doesn't hear the "funk" error beep. (Easydict does exactly this —
   `withMutedAlertVolume`. Verified.)

### Swift (synthesizing the keystroke)

```swift
import Carbon       // kVK_ANSI_C
import AppKit

func simulateCmdC() {
    let src = CGEventSource(stateID: .combinedSessionState)
    // optional: src?.setLocalEventsFilterDuringSuppressionState(...) to avoid races
    let cDown = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
    let cUp   = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
    cDown?.flags = .maskCommand
    cUp?.flags   = .maskCommand
    let loc: CGEventTapLocation = .cghidEventTap
    cDown?.post(tap: loc)
    cUp?.post(tap: loc)
}
```

### Swift (save / copy / read / restore)

```swift
func captureViaSimulatedCopy(timeout: TimeInterval = 0.1) -> String? {
    let pb = NSPasteboard.general

    // 1. back up every item × type
    let saved = pb.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
        var dict: [NSPasteboard.PasteboardType: Data] = [:]
        for type in item.types { if let d = item.data(forType: type) { dict[type] = d } }
        return dict
    } ?? []
    let startCount = pb.changeCount

    // 2. fire ⌘C  (wrap in muted-alert-volume to suppress the failure beep)
    simulateCmdC()

    // 3. poll for the clipboard to change
    let deadline = Date().addingTimeInterval(timeout)
    var copied: String?
    while Date() < deadline {
        if pb.changeCount != startCount {
            copied = pb.string(forType: .string)
            break
        }
        usleep(8000)   // 8 ms
    }

    // 4. restore the original clipboard
    pb.clearContents()
    for dict in saved {
        let item = NSPasteboardItem()
        for (type, data) in dict { item.setData(data, forType: type) }
        pb.writeObjects([item])
    }
    return copied
}
```

### Pros
- **Near-universal coverage** — anything with a working Copy command: browsers, Electron,
  terminals, custom-rendered editors.

### Cons
- **Mutates the clipboard** — race conditions with clipboard managers; restore is best-effort
  (rich types, promised data, and file URLs can be lossy).
- **Timing-sensitive** — needs a poll/timeout; too short misses slow apps, too long feels laggy.
- **Audible beep** if nothing is selected (mitigate by muting alert volume).
- Breaks if the app has **remapped ⌘C** or lacks a copy command; password fields won't copy.

### Permission
- **Accessibility** — posting synthetic events to *other* apps requires the process to be AX-trusted.
  (Input Monitoring governs *listening* to events, not posting; see `02-permissions-and-caveats.md`.)

---

## Method 3 — AppleScript / Apple Events (browser web content)

The clean way to read a **browser** selection that the AX API can't see — ask the browser's
scripting interface to run `getSelection()` in the page.

### Safari

```applescript
tell application "Safari"
    set sel to do JavaScript "window.getSelection().toString()" in current tab of front window
end tell
```
Requires Safari ▸ Develop ▸ **"Allow JavaScript from Apple Events"** to be enabled.

### Google Chrome (and Chromium forks: Edge, Brave, Arc)

```applescript
tell application "Google Chrome"
    set sel to execute front window's active tab javascript "window.getSelection().toString();"
end tell
```
Requires View ▸ Developer ▸ **"Allow JavaScript from Apple Events"** in Chrome.

### Driving it from Swift

```swift
func browserSelection(appName: String, script: String) -> String? {
    guard let apple = NSAppleScript(source: script) else { return nil }
    var err: NSDictionary?
    let out = apple.executeAndReturnError(&err)
    if err != nil { return nil }
    return out.stringValue
}
```

### Pros
- **Non-destructive** — no clipboard use; reads exactly the page selection.
- Reliable for Safari/Chrome where AX returns nothing. **This is Easydict's browser path** (verified).

### Cons
- **Browser-specific** — needs per-browser scripts and bundle-id detection. **Firefox has no
  AppleScript** support → must fall through to simulated ⌘C.
- Requires the user to enable "Allow JavaScript from Apple Events" per browser.
- Triggers the **Automation** TCC prompt the first time (one prompt per controlled app).

### Permission
- **Automation / Apple Events** (`Privacy & Security ▸ Automation`). Sandboxed apps additionally
  need the `com.apple.security.automation.apple-events` entitlement and a usage description.

---

## Method 4 — Menu-bar action / `AXPress` "Copy" (the robust copy trigger)

A variant of Method 2 that triggers the app's **Edit ▸ Copy** menu item directly through the
Accessibility tree instead of synthesizing a keystroke. In SelectedTextKit this is the
`.menuAction` strategy, and `.auto` pairs it with the AX read as **"most reliable"** (verified).

### How it works
1. Get the frontmost app's `AXUIElement` (`AXUIElementCreateApplication(pid)`).
2. Read `kAXMenuBarAttribute`, walk to the **Edit** menu, find the **Copy** item.
3. `AXUIElementPerformAction(copyItem, kAXPressAction as CFString)`.
4. Then read & restore the pasteboard exactly as in Method 2.

### Swift (sketch)

```swift
func pressCopyMenuItem(pid: pid_t) -> Bool {
    let app = AXUIElementCreateApplication(pid)
    var menuBar: AnyObject?
    guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBar) == .success
    else { return false }
    // …descend menuBar → "Edit" → "Copy" by matching kAXTitleAttribute…
    // guard let copyItem = findItem(in: menuBar, titled: "Copy") else { return false }
    // return AXUIElementPerformAction(copyItem, kAXPressAction as CFString) == .success
    return false   // see SelectedTextKit for the full traversal
}
```

### Pros
- **Doesn't depend on the ⌘C key mapping** — fires the real menu command, so it survives custom
  keybindings and works in some contexts where synthetic keystrokes are dropped.
- More deterministic completion than a posted keystroke.

### Cons
- **Still a real copy** → mutate-and-restore the clipboard like Method 2.
- Fails if the app has **no standard Edit ▸ Copy** menu item, uses non-localized/odd titles, or a
  fully custom menu (some Electron/Java apps). Menu titles are localized → match by role/position,
  not just English "Copy".

### Permission
- **Accessibility** (same as Method 1 — it's an AX action).

---

## Choosing per situation

```
is the selection in a browser web view?     → Method 3 (AppleScript getSelection)
does AX return kAXSelectedText?              → Method 1 (use it; free, non-destructive)
neither (Electron/terminal/custom render)?   → Method 4 (AXPress Copy) or Method 2 (simulate ⌘C),
                                               with pasteboard backup/restore + muted alert volume
```

See [`03-easydict-selectedtextkit.md`](./03-easydict-selectedtextkit.md) for how Easydict wires
these into a single `.auto` strategy.
