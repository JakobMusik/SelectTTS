# macOS Open-Source App Dev Practices — Reference

Research reference for **SelectTTS** (Phase 2): how established open-source macOS menu-bar
apps actually structure their projects, build their menu-bar UI, pick their libraries, ship
notarized builds, and license their code — and what that implies for a new menu-bar utility.

> Compiled via a multi-source, adversarially-verified deep-research pass on **2026-06-13**
> (deep-research workflow **wf_011ff0d2-367**, research → adversarial-verify). Every factual
> claim below was independently checked against primary sources (GitHub trees/contents API + raw
> file fetches, Apple developer docs, project READMEs, license files). All five topic findings
> reported **confirmed**. Where a claim rests on absence-of-evidence, a mis-cited source, or an
> opinion synthesis, that is flagged inline and in [`sources.md`](./sources.md). Nothing here is
> legal or security advice.

## Survey set

Six high-traction open-source macOS menu-bar apps were the exemplar sample. Stars and minimum
macOS deployment targets are as recorded in the digest:

| App | Stars | Min macOS | Lifecycle | Notes |
|-----|------:|-----------|-----------|-------|
| [Stats](https://github.com/exelban/stats) | 39,574 | 12.0 (main) | Pure AppKit | Only true module split — many framework targets |
| [MonitorControl](https://github.com/MonitorControl/MonitorControl) | 33,424 | 10.14 / 10.15 | Pure AppKit | Oldest floor (Mojave/Catalina); storyboard-driven |
| [Ice](https://github.com/jordanbaird/Ice) | 28,426 | 14.0 | SwiftUI `@main App` + delegate | Raw `NSStatusItem`, no MenuBarExtra |
| [Maccy](https://github.com/p0deje/Maccy) | 20,286 | 14.0 | SwiftUI `@main App` + delegate | Hidden-`MenuBarExtra` hack |
| [Loop](https://github.com/MrKai77/Loop) | 10,937 | 13.0 | SwiftUI `@main App` + delegate | `MenuBarExtra(... isInserted:)` |
| [Easydict](https://github.com/tisfeng/Easydict) | n/a (not in digest) | 13.0 (+14.1 some) | Hybrid `@main enum` → `App` | Mixes SwiftPM + CocoaPods; GPL-3.0 |

## Documents

| File | Contents |
|------|----------|
| [`01-project-structure-and-modularization.md`](./01-project-structure-and-modularization.md) | Single committed `.xcodeproj`, remote-only SwiftPM deps, Stats' framework-target split, lifecycle styles, deployment targets, feature-folder layouts, tooling. |
| [`02-menubar-ui-and-settings.md`](./02-menubar-ui-and-settings.md) | MenuBarExtra styles & limits, FluidMenuBarExtra / MenuBarExtraAccess wrappers, raw NSStatusItem, LSUIElement, Settings scene + the macOS-14 SettingsLink/openSettings gate, floating NSPanel recipe. |
| [`03-libraries.md`](./03-libraries.md) | KeyboardShortcuts, Defaults, LaunchAtLogin-Modern + SMAppService, Sparkle, KeychainAccess — versions, licenses, min OS, hardened-runtime/MAS notes. |
| [`04-distribution-signing-ci.md`](./04-distribution-signing-ci.md) | Developer ID + hardened runtime + notarytool + stapler + DMG + GitHub Releases + Homebrew cask + Sparkle appcast/EdDSA; entitlement nuances; GitHub Actions cert-import sequence. |
| [`05-licensing.md`](./05-licensing.md) | Easydict GPL-3.0 vs SelectedTextKit MIT, the per-scenario conclusion, the "don't copy from the GPL repo" trap, MIT vs Apache-2.0 vs MPL-2.0. The SelectTTS decision: **MIT**. |
| [`sources.md`](./sources.md) | Annotated bibliography grouped by topic + verification & caveats note. |

## TL;DR — Recommended stack for a new macOS menu-bar app

This is the synthesized recommendation from the `structure` finding (an opinion, but anchored on
verified facts about the six exemplars), combined with the verified `libs` and `dist` findings:

- **One committed `.xcodeproj`.** None of the six use Tuist/XcodeGen; none are SPM-only; none
  split *app* code into local SPM packages.
- **SwiftUI lifecycle:** `@main struct App: App` + `@NSApplicationDelegateAdaptor(AppDelegate.self)`
  (Ice/Maccy/Loop pattern). Pure AppKit is the older path (Stats, MonitorControl).
- **Menu-bar surface:** `MenuBarExtra` (macOS 13+) for a simple dropdown, **or** an AppKit
  `NSStatusItem` managed in the delegate for a custom panel (the Ice pattern).
- **Deployment target: macOS 14** — unlocks first-party `SettingsLink`/`openSettings`, which are
  macOS 14+ only.
- **Organize by feature/domain folders** (Xcode groups); add small separate targets for
  login-item / updater / privileged helpers; reach for Stats-style framework targets only when a
  single app target outgrows folders.
- **Remote SwiftPM dependencies** managed by Xcode: Sparkle plus the sindresorhus stack
  (Defaults, KeyboardShortcuts, Settings, LaunchAtLogin-Modern).
- **Distribution:** Developer ID Application cert + hardened runtime, `notarytool submit --wait`,
  `xcrun stapler staple`, ship a notarized+stapled DMG (create-dmg), publish to GitHub Releases,
  distribute via Homebrew cask, deliver in-app updates with Sparkle (EdDSA appcast).
- **Tooling seen across the set:** SwiftLint, SwiftFormat, Periphery, BartyCrouch.

## Implications for SelectTTS

- **Single `.xcodeproj`**, matching every exemplar — no Tuist/XcodeGen, no SPM-only layout.
- **Deliberate deviation:** SelectTTS will *additionally* extract its pure, testable cores into
  **local SPM packages**. No exemplar in this survey validates a "thin `.xcodeproj` app target +
  local SPM packages" pattern — they all modularize via feature folders (or, uniquely, Stats'
  framework targets). This is an intentional, eyes-open departure for testability, not a copy of a
  proven exemplar; see [`01-…`](./01-project-structure-and-modularization.md) for the open
  question this leaves.
- **Target macOS 14** (Ice/Maccy floor) to get first-party Settings-opening APIs and modern
  SMAppService/MenuBarExtra behavior.
- **Adopt the sindresorhus + Sparkle stack** (Defaults, KeyboardShortcuts, Settings,
  LaunchAtLogin-Modern, Sparkle) as remote SwiftPM deps.
