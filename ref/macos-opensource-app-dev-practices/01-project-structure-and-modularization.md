# Project Structure & SwiftPM Modularization

How six high-traction open-source macOS menu-bar apps (Ice, Maccy, Loop, Easydict, Stats,
MonitorControl) lay out their Xcode projects, manage dependencies, and modularize code.

> Deep-research pass on **2026-06-13** (workflow **wf_011ff0d2-367**, research →
> adversarial-verify). Every factual claim here was independently verified against primary sources:
> GitHub recursive git trees + contents API, each repo's `Package.resolved`, all six
> `project.pbxproj`, and the app entry-point `.swift`/`.m` files. Counts matched almost exactly;
> the two trivial imprecisions are noted inline. Claim 8 (the recommendation) is a
> normative/opinion synthesis, flagged as such. **Reliability: High; all 8 claims confirmed.**

## Headline finding (verified)

All six exemplars ship a **single committed `.xcodeproj`**. NONE use Tuist or XcodeGen, NONE are
SPM-only, and **NONE split app code into local SPM packages**. Dependencies are **remote** SwiftPM
packages managed by Xcode. Modularization happens via feature-named Xcode group folders — or,
uniquely, via Stats' multiple framework targets inside one project.

## No project generators; one `.xcodeproj` each (confirmed)

- Zero `Project.swift` / `project.yml` / `Tuist/` / `Workspace.swift` in any repo.
- The only `Package.swift` anywhere is `Easydict/BuildTools/Package.swift` — package name
  `BuildTools`, a single dependency on `nicklockwood/SwiftFormat` from `0.59.1`. It is a **build
  tool**, not app modularization.
- Easydict alone adds a top-level `.xcworkspace` + `Podfile` + `Pods/`, **only because it also uses
  CocoaPods**.

Sources: [Ice](https://github.com/jordanbaird/Ice), [Maccy](https://github.com/p0deje/Maccy),
[Loop](https://github.com/MrKai77/Loop), [Stats](https://github.com/exelban/stats),
[MonitorControl](https://github.com/MonitorControl/MonitorControl),
[Easydict](https://github.com/tisfeng/Easydict),
[Easydict BuildTools/Package.swift](https://github.com/tisfeng/Easydict/blob/dev/BuildTools/Package.swift).

## Dependencies are remote SwiftPM, managed by Xcode (confirmed)

Deps are consumed as **remote** SwiftPM references; `Package.resolved` lives under
`<proj>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`.

| App | Remote SwiftPM dependencies |
|-----|-----------------------------|
| Ice | AXSwift, CompactSlider, Ifrit, LaunchAtLogin-Modern, Sparkle |
| Maccy | Defaults, fuse-swift, KeyboardShortcuts, LaunchAtLogin-Modern, Sauce, Settings, Sparkle, swift-log, SwiftHEXColors |
| MonitorControl | KeyboardShortcuts, MediaKeyTap, Settings, SimplyCoreAudio, Sparkle, swift-atomics |
| Loop (no committed `Package.resolved`) | pbxproj `repositoryURL`s: MrKai77/Luminare, SenpaiHunters/Scribe, sindresorhus/Defaults, weichsel/ZIPFoundation |
| Stats | **NONE** — 0 `XCRemoteSwiftPackageReference`; LaunchAtLogin is vendored in-repo |
| Easydict | SwiftPM (Defaults, Sparkle, SettingsAccess, Alamofire, firebase-ios-sdk, openai, AXSwift) **+** CocoaPods (Masonry, ReactiveObjC, JLRoutes) |

Sources: each repo's `Package.resolved` / `project.pbxproj` / `Podfile`.

## Stats is the only true module split (confirmed)

Stats uses multiple Xcode **framework** targets inside one `.xcodeproj`. The `project.pbxproj`
product-type counts: **11 framework, 2 application, 1 app-extension, 2 tool, 1 unit-test**.

- `productNames`: **Kit** + ten monitor frameworks (CPU/GPU/Memory/Disk/Net/Battery/Sensors/
  Bluetooth/Clock/Remote) + Stats, WidgetsExtension, SMC, Helper, LaunchAtLogin, Tests.
- Each `Modules/<Name>/` has a standardized layout:
  `main.swift`, `popup.swift`, `settings.swift`, `widget.swift`, `readers.swift`, `portal.swift`,
  `notifications.swift`, `preview.swift`, `config.plist`, `Info.plist`, `bridge.h`.
- `Stats/AppDelegate.swift` does `import Kit`, then imports each module framework.
- **Imprecision noted:** the Memory framework's source folder is named `Modules/RAM`.
- The second "application" target is the vendored **LaunchAtLogin helper app** — *inferred from
  its `productName`* (the verifier resolved this in favor; see open questions).

Sources:
[Stats.xcodeproj/project.pbxproj](https://github.com/exelban/stats/blob/master/Stats.xcodeproj/project.pbxproj),
[Stats/AppDelegate.swift](https://github.com/exelban/stats/blob/master/Stats/AppDelegate.swift),
[Kit tree](https://github.com/exelban/stats/tree/master/Kit),
[Modules/CPU tree](https://github.com/exelban/stats/tree/master/Modules/CPU).

## App lifecycle: SwiftUI `@main App` vs pure AppKit (confirmed)

| App | Entry point | Detail |
|-----|-------------|--------|
| Ice | `@main struct IceApp: App` + `@NSApplicationDelegateAdaptor` | `body`: `SettingsWindow(...)` + `PermissionsWindow(...)`. Ice manages `NSStatusItem` in AppKit — **no MenuBarExtra**. |
| Maccy | `@main` SwiftUI App + delegate | `MenuBarExtra("", isInserted: $hiddenMenu){ EmptyView() }` — a hidden-MenuBarExtra hack. |
| Loop | `@main` SwiftUI App + delegate | `MenuBarExtra(Bundle.main.appName, image: "menubarIcon", isInserted: ...)`. |
| Stats | `@main class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate` | Pure AppKit (AppDelegate.swift L39-40). |
| MonitorControl | `main.swift` storyboard-driven | `NSStoryboard(name:"Main")`, then `autoreleasepool { let mc = NSApplication.shared; let mcDelegate = AppDelegate(); mc.delegate = mcDelegate; mc.run() }` — **no `@main`**. |
| Easydict | `@main enum EasydictCmpatibilityEntry { static func main() {...; EasydictApp.main() } }` | Hybrid: wraps `struct EasydictApp: App` (MenuBarExtra + ObjC `AppDelegate.m`). |

Sources: Ice/Main/IceApp.swift, Maccy/MaccyApp.swift, Loop/App/LoopApp.swift,
Stats/AppDelegate.swift, MonitorControl/main.swift, Easydict/App/EasydictApp.swift.

## Minimum macOS deployment targets (confirmed)

Counted from `MACOSX_DEPLOYMENT_TARGET` in each `project.pbxproj`:

| App | Min macOS |
|-----|-----------|
| Ice | 14.0 |
| Maccy | 14.0 |
| Loop | 13.0 |
| Easydict | 13.0 (+14.1 on some targets) |
| Stats | 12.0 main (×32) + 10.15 SMC/Helper (×2) + 14.0 WidgetsExtension (×2) |
| MonitorControl | 10.14 (×4) + 10.15 (×2) — oldest; supports Mojave/Catalina |

Source: each `project.pbxproj`.

## Feature-folder organization (confirmed)

The single app target is organized by feature/domain folders; secondary functionality lives in
separate small targets plus a `Shared/` folder.

- **Ice/** (14 folders, single app target): Main, MenuBar, Hotkeys, Events, Permissions, Settings,
  Updates, UserNotifications, Bridging, Swizzling, UI, Utilities, Resources, Assets.xcassets.
- **Loop/**: App, Core, Window Management, Window Action Indicators, Settings Window, Updater,
  Migration, Stashing, Private APIs, Extensions, Utilities, Resources + 14 `.lproj`. Targets:
  `LoopDockTile` (bundle), `LoopUpdaterHelper` (CLI tool); top-level `Shared/`
  (`LoopSupportPaths.swift`, `PrivilegedInstallerProtocol.swift`).
- **Maccy/**: Models, Observables, Views, Settings, Intents, Extensions, Sounds + Core Data
  `.xcdatamodeld` + **41** `.lproj` (digest corrects an earlier "~45").
- **MonitorControl**: 2 app targets — `MonitorControl.OSX` (main) + `MonitorControlHelper`
  (login-item).

Sources: tree views of each repo.

## Tooling seen across the set (confirmed)

| Tool | Config file | Present in |
|------|-------------|-----------|
| SwiftLint | `.swiftlint.yml` | Ice, Maccy, Stats, MonitorControl, Easydict |
| SwiftFormat | `.swiftformat` | Loop, MonitorControl, Easydict |
| Periphery | `.periphery.yml` | Maccy |
| BartyCrouch | `.bartycrouch.toml` | Maccy, MonitorControl |

**None adopt local SPM packages for app code.** Sparkle is used by Ice, Maccy, MonitorControl, and
Easydict (not Loop or Stats).

Sources: the repos above, plus
[sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) and
[sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle).

## The synthesized recommendation (opinion, anchors verified)

For a **new** menu-bar app: one `.xcodeproj`; SwiftUI `@main App` +
`@NSApplicationDelegateAdaptor(AppDelegate.self)`; `MenuBarExtra` (macOS 13+) for a simple dropdown
**or** an AppKit `NSStatusItem` in the delegate for a custom panel (the Ice pattern); **macOS 14
deployment target**; feature folders; remote SPM deps (Sparkle, sindresorhus Defaults /
KeyboardShortcuts / Settings / LaunchAtLogin-Modern); small separate targets for
login-item / updater / privileged helpers; Stats-style framework targets only when it outgrows
folders.

## Open questions (honest caveats)

- **No exemplar validates a "thin `.xcodeproj` app target + local SPM packages" pattern.** A
  different sample set would be needed to confirm it.
- Stats' second "application" target (the LaunchAtLogin helper) is **inferred from `productName`**,
  not from reading each `PBXNativeTarget` in full — though the verifier resolved it in favor.
- Whether Ice intentionally ships **no test target** (only 1 application product type found).
- Branch caveat: default branches as of mid-2026 — Ice `main`, Maccy `master`, Loop `develop`,
  Easydict `dev`, Stats `master`, MonitorControl `main`; Ice's last push was 2025-09-20.

## Implications for SelectTTS

- **Match the exemplars on the basics:** a single committed `.xcodeproj`, remote SwiftPM deps,
  feature/domain folders, and small separate targets for any login-item / updater / privileged
  helper.
- **Deliberate deviation — local SPM packages for testable cores.** SelectTTS will extract its
  pure cores (e.g. provider adapters, selection-capture logic) into **local SPM packages**, even
  though *no* surveyed exemplar does this. The benefit is fast, GUI-free unit tests of the cores;
  the cost is being off the validated path (see the open question above). Adopt it as an
  intentional, isolated departure, not a wholesale restructure — the app target itself stays a
  single `.xcodeproj` organized by feature folders, exactly like Ice/Maccy/Loop.
- **Target macOS 14** (the Ice/Maccy floor), and lean on the sindresorhus + Sparkle dependency set.
- **Adopt the tooling baseline:** SwiftLint + SwiftFormat at minimum (Periphery/BartyCrouch
  optional).
