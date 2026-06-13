# Sources & Verification — macOS Open-Source App Dev Practices

> Provenance: deep-research workflow **wf_011ff0d2-367**, **2026-06-13**, pipeline
> **research → adversarial-verify**. Five topics in scope (structure, menubar, libs, dist,
> license); **all topic findings reported confirmed** (structure 8/8, menubar 13/14 + 1 synthesis,
> libs 7/7, dist 20/20, license 10/10). Citations below are the primary/secondary sources behind
> the `[source:]` tags in the digest. A "verification & caveats" note at the end records which
> items rest on weaker ground.

## Topic: Project structure & modularization

| Source | Used for |
|--------|----------|
| github.com/jordanbaird/Ice | Ice repo tree, folders, IceApp.swift, pbxproj, deployment target, stars |
| github.com/p0deje/Maccy | Maccy repo, MaccyApp.swift, folders, `.lproj` count, deps |
| github.com/MrKai77/Loop | Loop repo, LoopApp.swift, folders, targets, pbxproj repositoryURLs |
| github.com/exelban/stats | Stats repo, AppDelegate.swift, `Modules/*`, `Kit` |
| github.com/exelban/stats/blob/master/Stats.xcodeproj/project.pbxproj | Stats framework-target product-type counts |
| github.com/MonitorControl/MonitorControl | MonitorControl repo, main.swift, two app targets, oldest deployment floor |
| github.com/tisfeng/Easydict | Easydict repo, EasydictApp.swift, SPM+CocoaPods mix, `.xcworkspace` |
| github.com/tisfeng/Easydict/blob/dev/BuildTools/Package.swift | The only `Package.swift` = a build tool (SwiftFormat) |
| each repo's `Package.resolved` / `project.pbxproj` / `Podfile` | Remote SwiftPM dep lists, deployment targets |
| github.com/exelban/stats tree `/Kit`, `/Modules/CPU` | Standardized per-module folder layout |
| github.com/sindresorhus/KeyboardShortcuts, sparkle-project/Sparkle | Anchors for the recommendation |

## Topic: Menu-bar UI & Settings

| Source | Used for |
|--------|----------|
| developer.apple.com/documentation/swiftui/menubarextra | MenuBarExtra scene, macOS 13.0, LSUIElement recommendation, auto-terminate |
| developer.apple.com/documentation/swiftui/menubarextrastyle | `menu`/`window`/`automatic` styles |
| nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/ | Style behaviors |
| medium.com/better-programming/create-menu-bar-apps-for-macos-ventura-or-higher-4c05a5b28e31 | Menu-style limits (text/buttons/dividers) |
| github.com/orchetect/MenuBarExtraAccess | No first-party presentation-state / NSStatusItem access |
| github.com/lfroms/fluid-menu-bar-extra (README) | Window-style fade-out/highlight/resize fixes |
| polpiella.dev/a-menu-bar-only-macos-app-using-appkit/ | Reasons apps use raw NSStatusItem |
| multi.app/blog/pushing-the-limits-nsstatusitem | Raw NSStatusItem capabilities |
| cocoadev.github.io/LSUIElement/, hints.macworld.com | `LSUIElement=true` behavior + Xcode label |
| developer.apple.com/documentation/swiftui/settings | Settings scene (macOS 11.0) |
| github.com/sindresorhus/Settings (+ raw Package.swift) | sindresorhus Settings package (macOS 10.15+) |
| steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items | Opening Settings from a menu-bar app; macOS 26 breakage |
| developer.apple.com/documentation/swiftui/settingslink | macOS 14.0+ availability |
| developer.apple.com/documentation/swiftui/environmentvalues/opensettings | macOS 14.0+ availability |
| developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel | nonactivatingPanel style mask |
| cindori.com/developer/floating-panel | Floating NSPanel recipe |

## Topic: Libraries

| Source | Used for |
|--------|----------|
| github.com/sindresorhus/KeyboardShortcuts | v2.4.0, MIT, macOS 10.15+, sandbox/MAS notes |
| github.com/sindresorhus/Defaults | v9.0.8, MIT, macOS 11+ |
| github.com/sindresorhus/LaunchAtLogin-Modern | v1.1.0, MIT, macOS 13+, SMAppService-backed |
| developer.apple.com/documentation/servicemanagement/smappservice | SMAppService API, macOS 13 |
| theevilbit.github.io/posts/smappservice/ | SMAppService usage detail |
| github.com/sparkle-project/Sparkle | v2.9.3, component licenses, appcast/EdDSA tools |
| sparkle-project.org/documentation/ | Update mechanism, keys |
| sparkle-project.org/documentation/sandboxing/ | MAS incompatibility, mach-lookup exceptions |
| avanderlee.com/xcode/sparkle-distribution-apps-in-and-out-of-the-mac-app-store/ | In/out of MAS pattern |
| github.com/kishikawakatsumi/KeychainAccess | v4.2.2, MIT, unmaintained, entitlement notes |

## Topic: Distribution, signing & CI

| Source | Used for |
|--------|----------|
| gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5 | Developer ID signing, bottom-up, notarization flow, DMG |
| developer.apple.com/developer-id/ | Developer ID program |
| lapcatsoftware.com/articles/hardened-runtime-sandboxing.html | Apple Events entitlement + same-Team-ID exemption |
| github.com/Hammerspoon/hammerspoon/.../Hammerspoon-Info.plist | Real-world entitlement/Info.plist example |
| developer.apple.com/forums/thread/108526 | (cited for Apple Events exemption — see caveats) |
| eclecticlight.co/2021/01/07/notarization-the-hardened-runtime/ | Hardened-runtime `cs.*` entitlement catalog |
| jano.dev (Accessibility-Permission) | Counter-claim on accessibility entitlement (likely misconception) |
| developer.apple.com/news/?id=y5mjxqmn, /news/upcoming-requirements/?id=11012023a | altool notarization deprecation (Nov 1 2023) |
| keith.github.io/xcode-man-pages/notarytool.1.html | notarytool subcommands + auth |
| defn.io/2023/09/22/distributing-mac-apps-with-github-actions/ | DMG + GitHub Actions pipeline |
| github.com/create-dmg/create-dmg | create-dmg syntax/options |
| docs.brew.sh/Cask-Cookbook, .../How-To-Open-a-Homebrew-Pull-Request | Homebrew cask DSL + PR flow |
| github.com/Homebrew/homebrew-cask/blob/main/CONTRIBUTING.md | Cask submission |
| github.com/orgs/Homebrew/discussions/3808, marketplace/actions/homebrew-bump-cask | Cask updates need a PR; bump automation |
| sparkle-project.org/documentation/ + /publishing/ | SUFeedURL/SUPublicEDKey, generate_appcast |
| github.com/sparkle-project/Sparkle/discussions/2308 | CI key-via-stdin, GitHub Pages appcast |
| github.com/AlexPerathoner/SparkleReleaseTest/.../release.yml | End-to-end CI reference |
| github.com/steipete/CodexBar/blob/main/docs/RELEASING.md | Embed & Sign Sparkle components |
| medium.com/@alex.pera/automating-xcode-sparkle-releases-with-github-actions | Sparkle release automation |
| docs.github.com/.../installing-an-apple-certificate-on-macos-runners-for-xcode-development | Cert-import sequence |
| federicoterzi.com/.../automatic-code-signing-and-notarization-...-github-actions | Required secrets list |
| github.com/jordanbaird/Ice/blob/main/.github/workflows/lint.yml | SwiftLint action (Ice) |
| norio-nomura/action-swiftlint, cirruslabs/swiftlint-action, mtgto/swift-format-action | Lint/format actions |

## Topic: Licensing

| Source | Used for |
|--------|----------|
| github.com/tisfeng/Easydict/blob/dev/LICENSE + api.github.com/repos/tisfeng/Easydict/license | Easydict = GPL-3.0 |
| github.com/tisfeng/SelectedTextKit/blob/main/LICENSE + /Package.swift + api license | SelectedTextKit = MIT, swift-tools 5.9, macOS 11 |
| tisfeng/AXSwift/LICENSE, jordanbaird/KeySender/LICENSE | Transitive deps MIT |
| github.com/sparkle-project/Sparkle/blob/2.x/LICENSE | MIT core + external BSD/zlib/MIT components |
| opensource.org/license/mit | MIT grant + attribution-only obligation |
| gnu.org/licenses/gpl-3.0.en.html, /quick-guide-gplv3.html | GPL-3.0 whole-program copyleft (§5) |
| apache.org/licenses/GPL-compatibility.html, /licenses/LICENSE-2.0 | Apache-2.0 one-way compat + §3 patent grant |
| mozilla.org/en-US/MPL/2.0/, /FAQ/ | MPL-2.0 file-level copyleft |

## Verification & caveats

**All topic claims confirmed**, but the following rest on weaker ground or remain open. Treat them
as engineering lore pending re-verification, not settled fact:

- **structure:** No exemplar validates a "thin `.xcodeproj` app target + local SPM packages"
  pattern — the SelectTTS local-SPM deviation is unvalidated by this sample. Stats' second
  "application" target (LaunchAtLogin helper) is *inferred from productName*. Whether Ice ships no
  test target is unconfirmed. Two trivial imprecisions corrected in the digest (Maccy = 41 `.lproj`
  not "~45"; Stats' Memory framework folder = `Modules/RAM`).
- **menubar:** 13/14 confirmed; the deployment trade-off is a synthesis. Open: whether the macOS
  Tahoe (26) `openSettings` breakage (June 2025) was later fixed; FluidMenuBarExtra's exact min
  macOS; whether macOS 14/15 fixed window-style fade-out/highlight natively. Minor caveat: the
  MenuBarExtraAccess "very strict... no custom UI" wording is not in the current README (only the
  first-party-API sentence is verbatim).
- **libs:** All confirmed; no remaining open questions. Nuances: LaunchAtLogin-Modern's README
  doesn't literally name `SMAppService`; KeychainAccess "Swift 5.1+" is approximate.
- **dist (most caveats):**
  - The same-Team-ID Apple Events exemption is true but **forum thread 108526 does NOT contain it**;
    Apple's canonical entitlement page is JS-rendered.
  - The cited "Hammerspoon-Info.plist" is the Info.plist, **not** the entitlements file (entitlements
    verified via the theevilbit writeup).
  - **"No `com.apple.security.accessibility` entitlement" rests on absence-of-evidence**
    (Hammerspoon + Eclectic Light), not an explicit Apple statement; jano.dev's counter-claim exists
    and is a likely misconception.
  - The CI "feed key via stdin" approach is real (#2308) but the co-cited SparkleReleaseTest writes
    the key to a file.
  - Open: TN3147 vs practice on stapling the `.app` *and* the DMG; current `notarytool` auth
    recommendation; no single canonical end-to-end workflow (assembled from multiple repos).
- **license:** All 10 confirmed; engineering reading, **not legal advice**. The "SelectedTextKit was
  extracted from GPL Easydict" line is provenance, not a license fact (tisfeng owns both). Re-verify
  SPDX at integration time (branches: Easydict `dev`, SelectedTextKit/AXSwift/KeySender `main`,
  Sparkle `2.x`, KeychainAccess `master`). Reproduce Sparkle's external-license notices verbatim.
