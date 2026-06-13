# Menu-Bar UI & Settings

macOS menu-bar app UI patterns: `MenuBarExtra` and its limits, the wrappers that paper over them,
when apps fall back to raw `NSStatusItem`, hiding the Dock icon with `LSUIElement`, the SwiftUI
`Settings` scene and the macOS-14 `SettingsLink`/`openSettings` gate, and the floating `NSPanel`
recipe for transient UI.

> Deep-research pass on **2026-06-13** (workflow **wf_011ff0d2-367**, research →
> adversarial-verify). 13/14 claims confirmed against strong primary sources (Apple doc JSON
> endpoints, GitHub raw READMEs/`Package.swift`, a cited author blog); the 14th is a synthesis
> that follows from confirmed facts. Three minor caveats (none falsify the claims) are flagged
> inline. **Reliability: High.**

## MenuBarExtra — the native scene (confirmed)

- `MenuBarExtra` is a **Scene**, available **macOS 13.0+**. Apple's abstract: "A scene that renders
  itself as a persistent control in the system menu bar." It can back a full main-window app or a
  menu-bar-only utility.
  [developer.apple.com/documentation/swiftui/menubarextra](https://developer.apple.com/documentation/swiftui/menubarextra)
- Two styles set via `menuBarExtraStyle`, all macOS 13.0+:

  | Style value | Type | Behavior |
  |-------------|------|----------|
  | `menu` | `PullDownMenuBarExtraStyle` | Pull-down menu — **text / buttons / dividers only** |
  | `window` | `WindowMenuBarExtraStyle` | Popover-like; **arbitrary SwiftUI**, dynamic or fixed size |
  | `automatic` (default) | `AutomaticMenuBarExtraStyle` | — |

  [developer.apple.com/documentation/swiftui/menubarextrastyle](https://developer.apple.com/documentation/swiftui/menubarextrastyle)
- The `menu` style is limited to text/buttons/dividers: **custom button styles are ignored and
  images are not rendered**. The `window` style allows arbitrary SwiftUI with dynamic or fixed
  sizing.
  Sources:
  [nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/),
  [medium.com/better-programming/create-menu-bar-apps-for-macos-ventura-or-higher](https://medium.com/better-programming/create-menu-bar-apps-for-macos-ventura-or-higher-4c05a5b28e31).
  **Caveat:** the menu-style limits are stated by the Better Programming source, not the
  nilcoalescing one.

## What MenuBarExtra cannot do (confirmed)

- **No first-party API** to get/set the menu's presentation state, disable the extra, or access the
  underlying `NSStatusItem` / popup `NSWindow`. This is verbatim in the MenuBarExtraAccess README,
  noted "still as of Xcode 26"; the button itself is limited to text/image.
  [github.com/orchetect/MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess)
  **Caveat:** the README's "very strict... image+text... no custom UI" wording quoted in some
  notes is **not** in the current README — only the first-party-API sentence is verbatim.
- The `window` style **lacks fade-out on dismissal, lacks a persisted button highlight, and resizes
  poorly**. `FluidMenuBarExtra` adds animated resizing, persisted highlight, and a smooth fade-out.
  [github.com/lfroms/fluid-menu-bar-extra](https://github.com/lfroms/fluid-menu-bar-extra/blob/main/README.md)

## Wrappers

| Wrapper | Adds |
|---------|------|
| [FluidMenuBarExtra](https://github.com/lfroms/fluid-menu-bar-extra) | Animated resizing, persisted button highlight, smooth fade-out for the window style |
| [MenuBarExtraAccess](https://github.com/orchetect/MenuBarExtraAccess) | Access to presentation state and the underlying `NSStatusItem` / popup window that the first-party API withholds |

## When apps use raw NSStatusItem instead (confirmed)

Apps still use AppKit `NSStatusItem` directly for: **dynamic-width buttons, multiple click targets,
colors beyond template images, direct status-item access, and pre-macOS-13 support** (MenuBarExtra
requires Ventura). **Ice** is the in-survey example — it manages `NSStatusItem` in AppKit and does
not use MenuBarExtra at all.

Sources:
[polpiella.dev/a-menu-bar-only-macos-app-using-appkit](https://www.polpiella.dev/a-menu-bar-only-macos-app-using-appkit/),
[multi.app/blog/pushing-the-limits-nsstatusitem](https://multi.app/blog/pushing-the-limits-nsstatusitem).

## Hiding the Dock icon — LSUIElement (confirmed)

- `LSUIElement = true` in `Info.plist` hides the Dock icon and the main menu bar (the
  `NSStatusItem` still shows). Xcode's label for the key is **"Application is Agent (UIElement)"**.
  Sources:
  [cocoadev.github.io/LSUIElement](https://cocoadev.github.io/LSUIElement/),
  hints.macworld.com.
- Apple's `MenuBarExtra` docs **explicitly recommend `LSUIElement = true`** to hide the app from
  the Dock and app switcher. A menu-bar-only app is **auto-terminated if the user removes its
  extra**.
  [developer.apple.com/documentation/swiftui/menubarextra](https://developer.apple.com/documentation/swiftui/menubarextra)

## Settings scene + the macOS-14 gate (confirmed)

- The SwiftUI **`Settings` scene (macOS 11.0)** auto-wires the Settings menu item + Cmd-comma and
  shows/hides the view on selection; it replaces the AppKit `NSWindowController` preferences
  pattern and is often paired with `AppStorage`.
  [developer.apple.com/documentation/swiftui/settings](https://developer.apple.com/documentation/swiftui/settings)
- **sindresorhus/Settings** (formerly Preferences): AppKit `SettingsPane` + SwiftUI
  `Settings.Pane` (macOS 10.15+); titles the window "Settings" on macOS 13+;
  `Package.swift` declares `swift-tools-version:5.8`, `.macOS(.v10_13)`.
  [github.com/sindresorhus/Settings](https://github.com/sindresorhus/Settings)
- **Opening Settings from a SwiftUI menu-bar app is unreliable.** `SettingsLink` and `openSettings`
  are **both macOS 14.0+**. An accessory app with no Dock icon **cannot make a window key**; the
  real fix uses a hidden context window plus toggling `NSApplication` activation policy between
  `.accessory` and `.regular`. As of **June 17 2025**, `openSettings` worked on macOS 15 but was
  **broken on macOS Tahoe (26)**.
  Sources:
  [steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items/),
  [/swiftui/settingslink](https://developer.apple.com/documentation/swiftui/settingslink),
  [/swiftui/environmentvalues/opensettings](https://developer.apple.com/documentation/swiftui/environmentvalues/opensettings).
  **Caveat:** one note conflates which of two sources states capabilities vs version-compatibility.

## Floating NSPanel for transient UI (confirmed)

SwiftUI has **no native floating-panel scene**. Transient floating UI = an `NSPanel` with the
`nonactivatingPanel` style mask (Apple: "a panel ... that does not activate the owning app") + a
floating window level, hosting SwiftUI via `NSHostingView`.
Sources:
[/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel](https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel),
[cindori.com/developer/floating-panel](https://cindori.com/developer/floating-panel).

The Cindori recipe (an `NSPanel` subclass):

- `styleMask = [.nonactivatingPanel, .titled, .resizable, .closable, .fullSizeContentView]`
- `isFloatingPanel = true`
- `level = .floating`
- `collectionBehavior.insert(.fullScreenAuxiliary)`
- `hidesOnDeactivate = true`
- `titlebarAppearsTransparent = true`
- `isMovableByWindowBackground = true`
- `titleVisibility = .hidden`
- `contentView = NSHostingView(rootView:)`

[cindori.com/developer/floating-panel](https://cindori.com/developer/floating-panel)

## Deployment trade-off (synthesis — follows from the above)

macOS 13 is the floor for `MenuBarExtra` but **lacks** `SettingsLink`/`openSettings` (both macOS
14). Targeting 13 forces more AppKit glue to open Settings; targeting **14+ unlocks the
first-party Settings-opening APIs** (still with the menu-bar quirks above).
Sources: the MenuBarExtra + SettingsLink + openSettings docs.

## Open questions (honest caveats)

- Whether the macOS Tahoe (26) `openSettings` breakage (June 2025) was fixed in a later macOS 26 /
  SwiftUI update.
- Exact named shipping apps using raw `NSStatusItem` (Bartender, iStat Menus, Ice) beyond
  Multi.app's own documented usage.
- FluidMenuBarExtra's exact minimum macOS deployment target (README does not state; at least 13).
- Whether macOS 14/15 fixed the window-style fade-out/highlight issues natively, or whether the
  wrappers remain necessary.

## Implications for SelectTTS

- **Target macOS 14** so `SettingsLink`/`openSettings` are available first-party — this removes the
  activation-policy gymnastics required at the macOS-13 floor.
- **Choose the menu-bar surface by need:** if SelectTTS needs only a simple dropdown, `MenuBarExtra`
  with the `window` style (wrap with FluidMenuBarExtra if the fade-out/highlight rough edges show);
  if it needs a custom panel, custom click handling, or direct status-item control, follow the
  **Ice pattern** — manage `NSStatusItem` from the AppDelegate.
- **Set `LSUIElement = true`** ("Application is Agent") to run as a menu-bar-only agent, and be
  aware the app is auto-terminated if the user removes its extra.
- **For any transient floating control** (e.g. a reader/progress popover not anchored to the menu
  bar), use the Cindori `nonactivatingPanel` `NSPanel` + `NSHostingView` recipe rather than
  expecting a SwiftUI scene.
