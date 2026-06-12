# Sources & Verification Provenance

Compiled by a deep-research workflow: 5 search angles → 15 sources fetched → 62 claims extracted →
25 claims put through 3-vote adversarial verification (a claim needed to survive 2/3 refutation
attempts). Run stats: 97 agent calls, 6 claims confirmed, 19 "killed."

> **How to read "killed."** The verifier panel was strict and *abstained* when it could not
> independently re-fetch a source page. Many "killed" claims (Apple docs for `kAXSelectedTextAttribute`,
> the system-wide AX walk, Electron MAS patch, AX failing on Mail/Chrome/Firefox) are
> well-established facts that were killed for **lack of re-confirmation, not disproof**. They are
> retained in the reference and flagged "abstained — treat as illustrative." Only claims with
> *active* refutation votes (e.g. 0-3, 1-2) are genuinely doubted.

## Primary sources (annotated)

| Source | Quality | What it establishes |
|--------|---------|--------------------|
| [tisfeng/SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) | Primary (reference impl) | The 4 strategies + `.auto`; `.shortcut` does KeySender ⌘C + pasteboard backup/restore + muted alert volume; `.auto` = accessibility→menuAction, "most reliable." **Verified.** |
| [tisfeng/Easydict — FAQ](https://github.com/tisfeng/Easydict/wiki/FAQ) | Primary | Runtime fallback order: Accessibility → AppleScript (browsers) → simulated ⌘C. Safari `AXWebArea` returns null. **Verified.** |
| [p0deje/Maccy — Clipboard.swift](https://github.com/p0deje/Maccy/blob/master/Maccy/Clipboard.swift) | Primary | CGEvent key-synthesis is the standard simulate-paste/copy mechanism; gated on Accessibility (`AXIsProcessTrusted`). **Verified.** |
| [tisfeng/Raycast-Easydict](https://github.com/tisfeng/Raycast-Easydict) | Primary | Easydict's logic ported to a Raycast extension; corroborates the strategy set. |
| [Apple — `kAXSelectedTextAttribute`](https://developer.apple.com/documentation/applicationservices/kaxselectedtextattribute) | Primary (Apple) | The canonical AX attribute for selected text. *(Verifiers abstained — couldn't re-fetch; it is nonetheless Apple's documented attribute.)* |
| [Apple — `NSAccessibilityProtocol.accessibilitySelectedText()`](https://developer.apple.com/documentation/appkit/nsaccessibilityprotocol/accessibilityselectedtext()) | Primary (Apple) | AppKit-side accessor; the *server* (app exposing) side counterpart to the AX client read. *(One refute vote on the exact framing.)* |
| [Apple Dev Forums #707680](https://developer.apple.com/forums/thread/707680) | Primary (forum) | Accessibility vs. Input Monitoring for event taps vs. NSEvent monitors; sandbox suitability. *(Abstained — treat MAS-policy specifics as lore.)* |
| [Apple Dev Forums #122492](https://developer.apple.com/forums/thread/122492) | Forum | Permissions discussion for reading other apps. |
| [PopClip — Troubleshooting KB](https://www.popclip.app/kb/troubleshooting) | Primary | Requires Accessibility; remove/re-add after macOS upgrades; ⌘C/⌘X/⌘V dependence; fails in emacs/vim/MacVim/Alacritty/qutebrowser. *(Abstained — cite as "reported.")* |
| [PopClip — Script Variables](https://www.popclip.app/dev/script-variables) | Primary | How PopClip passes the captured selection to extensions. |
| [electron/electron #22908](https://github.com/electron/electron/issues/22908) | Forum | MAS builds disable `selectedText`/`selectedTextRange`/`selectedTextMarkerRange` via `mas_no_private_api.patch`. *(Abstained — but a real, known Electron behavior.)* |
| [electron/electron #36337](https://github.com/electron/electron/issues/36337) | Primary | Electron AX selection-range bugs (leading-whitespace off-by-one; trailing line break). |
| [macdevelopers — text value via AX (2014)](https://macdevelopers.wordpress.com/2014/01/31/accessing-text-value-from-any-system-wide-application-via-accessibility-api/) | Blog | The `AXUIElementCreateSystemWide` → `kAXFocusedUIElementAttribute` → value walk; needs assistive-access. *(Abstained — standard technique.)* |
| [macdevelopers — selected text + coords via AX (2014)](https://macdevelopers.wordpress.com/2014/02/05/how-to-get-selected-text-and-its-coordinates-from-any-system-wide-application-using-accessibility-api/) | Blog | System-wide → focused element → `kAXSelectedTextAttribute`; reports AX selection failing in Mail/Chrome/Firefox. *(Abstained — illustrative.)* |
| [Swift Forums — reading from clipboard](https://forums.swift.org/t/solved-reading-from-clipboard/49129) | Forum | `NSPasteboard` read patterns / `changeCount`. |

## Confirmed claims (survived adversarial verification, 3-0 unless noted)

1. SelectedTextKit implements `.accessibility`, `.shortcut`, `.appleScript`, `.menuAction`, plus `.auto`.
2. Default `.auto` = accessibility → menu action, marked "most reliable."
3. Easydict's order: Accessibility → AppleScript (browser-only) → simulated ⌘C.
4. `.shortcut` synthesizes ⌘C (KeySender), backs up/restores the pasteboard, mutes alert volume.
5. Safari lacks AX selection (`kAXSelectedText` null on `AXWebArea`) → Easydict uses AppleScript `getSelection()`.
6. CGEvent key-synthesis is the standard simulated-copy mechanism and needs Accessibility (as in Maccy).

## Actively refuted claims (genuine doubt — do NOT repeat as fact)

- **Browser-specific order `[.appleScript, .accessibility, .menuAction, .shortcut]`** — refuted 1-2.
  Use the FAQ's plain 3-step order instead.
- **"Easydict requires Accessibility *specifically* to read selection"** — refuted 0-3. Over-claim:
  the browser AppleScript path uses **Automation**, not Accessibility.
- **`accessibilitySelectedText()` framed as the exact client-side counterpart of `kAXSelectedTextAttribute`** — 0-1 (the AppKit method is the app's *server* side, not the cross-app *reader* side).
- **"`kAXSelectedTextAttribute` is required for all editable text elements"** — refuted 1-2 (not guaranteed for static text).

## Claims retained but unverified (verifiers abstained — "treat as illustrative/reported")

These appear in the reference with explicit hedges: the system-wide AX walk being the canonical
technique; AX selection failing in Mail/Chrome/Firefox; Electron MAS `mas_no_private_api.patch`
disabling AX selection; Input-Monitoring-vs-Accessibility sandbox specifics; PopClip's exact
mechanism, ⌘C dependence, and terminal-app failures.

## Open questions the research did not close

- Exact **Automation/Apple-Events permission** requirements for the AppleScript browser path under
  hardened runtime vs. sandbox.
- The precise **menu traversal** SelectedTextKit uses for `.menuAction` (localized titles, role
  matching) — read the SelectedTextKit source directly for the implementation.
