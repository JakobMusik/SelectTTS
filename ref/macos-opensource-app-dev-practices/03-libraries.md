# Libraries — Swift Stack for a macOS Menu-Bar Utility

The conventional Swift dependency stack for a macOS 13+ menu-bar utility, with license, version,
minimum-OS, and hardened-runtime / Mac App Store (MAS) notes for each.

> Deep-research pass on **2026-06-13** (workflow **wf_011ff0d2-367**, research →
> adversarial-verify). All 7 claims confirmed against primary sources (official GitHub
> READMEs/releases, sparkle-project.org docs + LICENSE, Apple developer docs/forums). Two minor
> nuances (neither refutes): LaunchAtLogin-Modern's README doesn't literally name `SMAppService`
> though it uses it; KeychainAccess "Swift 5.1+" is approximate (README advertises broader Swift).
> Both original Sparkle open questions were resolved. **Reliability: High.**

## At-a-glance

| Library | Latest version | License | Min macOS | Purpose | Hardened-runtime / MAS notes |
|---------|---------------|---------|-----------|---------|------------------------------|
| [sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | **2.4.0** (2025-09-18) | MIT | 10.15+ | Global keyboard shortcuts; SwiftUI `Recorder` + Cocoa `RecorderCocoa` | "Fully sandboxed and MAS compatible"; uses some non-replaceable Carbon hotkey APIs internally; fine under hardened runtime / notarization |
| [sindresorhus/Defaults](https://github.com/sindresorhus/Defaults) | **9.0.8** (2026-03-26) | MIT | 11+ | Type-safe `UserDefaults` wrapper (typed keys, SwiftUI property wrapper, Codable, observation) | No entitlement / notarization / MAS conflicts |
| [sindresorhus/LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | **1.1.0** (2023-12-21, still latest in 2026) | MIT | 13+ | Launch at login; `LaunchAtLogin.isEnabled` + SwiftUI `LaunchAtLogin.Toggle()` | Sandbox/MAS-compatible; backed by `SMAppService` on macOS 13+. MAS rule: launch-at-login only by explicit user action, never on by default |
| [sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle) | **2.9.3** (2026-06-08) | MIT core + others (below) | 10.13+ | Secure auto-updater for non-MAS apps | Works with Developer ID / hardened runtime / notarization; **MAS-incompatible** (below) |
| [kishikawakatsumi/KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | **4.2.2** (2021-03-01 — none since → effectively unmaintained) | MIT | 10.9+ | Subscript-style Keychain wrapper (e.g. BYOK API keys) | Works under hardened runtime / sandbox / MAS; cross-app sharing needs `keychain-access-groups` entitlement |

## SMAppService (Apple, ServiceManagement) — confirmed

`SMAppService` was introduced in **macOS 13 Ventura** and replaces the deprecated
`SMLoginItemSetEnabled` and `SMJobBless`. It manages login items / agents / daemons via
`register()` / `unregister()` (underlying `registerAndReturnError()` /
`unregisterAndReturnError()`). Accessors: `SMAppService.mainApp`, `loginItem(identifier:)`,
`agent(plistName:)`, `daemon(plistName:)`. The user approves in **System Settings > Login Items**.
LaunchAtLogin-Modern is backed by this on macOS 13+ (though the README does not name it).
Sources:
[developer.apple.com/documentation/servicemanagement/smappservice](https://developer.apple.com/documentation/servicemanagement/smappservice),
[theevilbit.github.io/posts/smappservice](https://theevilbit.github.io/posts/smappservice/).

## Sparkle 2.x detail — confirmed

- **Component licenses:** MIT for the core; bundled **bsdiff/bspatch + `SUSignatureVerifier` under
  BSD-2-Clause**; **Ed25519 under a zlib-style license**. Min OS **macOS 10.13+**; SPM.
- **Sandboxing:** Sparkle 2 supports sandboxing; Sparkle 1 does not.
- **Update mechanism:** the appcast is an RSS feed at `Info.plist` key `SUFeedURL`, compared
  against the app's `CFBundleVersion`; updates are verified with **EdDSA ed25519 + Apple code
  signing**.
- **Tools:** `generate_keys` (private key stored in Keychain, base64 public key goes in `Info.plist`
  `SUPublicEDKey`), `sign_update`, `generate_appcast` (produces the appcast + delta updates).
- Sources:
  [github.com/sparkle-project/Sparkle](https://github.com/sparkle-project/Sparkle),
  [sparkle-project.org/documentation](https://sparkle-project.org/documentation/).

### Sparkle + Mac App Store: incompatible (confirmed)

Sparkle works with **Developer ID / hardened runtime / notarization** but is **MAS-incompatible**
(the App Store forbids third-party self-update). Sandboxed Sparkle requires `Info.plist`
`SUEnableInstallerLauncherService = YES` plus
`com.apple.security.temporary-exception.mach-lookup.global-name` entitlements (with `-spks` /
`-spki` names) — **disallowed on MAS**. Common pattern: a **separate non-MAS target**.
Sources:
[sparkle-project.org/documentation/sandboxing](https://sparkle-project.org/documentation/sandboxing/),
[avanderlee.com/xcode/sparkle-distribution-apps-in-and-out-of-the-mac-app-store](https://www.avanderlee.com/xcode/sparkle-distribution-apps-in-and-out-of-the-mac-app-store/).

## KeychainAccess detail — confirmed

MIT, subscript-style Keychain wrapper; latest **v4.2.2 (2021-03-01)** — none since, so it is
**effectively unmaintained**. macOS 10.9+, Swift 5.1+ (approximate). Works under hardened runtime /
sandbox / MAS (cross-app sharing needs the `keychain-access-groups` entitlement). Alternatives:
Apple Keychain Services directly (`SecItemAdd` / `SecItemCopyMatching`) or Square **Valet**.
**Storing BYOK API keys in the Keychain poses no hardened-runtime / notarization / MAS conflict.**
[github.com/kishikawakatsumi/KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess)

## Open questions

None remaining — both original open questions were resolved (Sparkle 2.9.3 min OS = macOS 10.13+;
LaunchAtLogin-Modern v1.1.0 remains the latest release).

## Implications for SelectTTS

- **Adopt the sindresorhus stack:** Defaults for typed settings, KeyboardShortcuts for the global
  hotkey, LaunchAtLogin-Modern (SMAppService-backed) for the login-item toggle — all MIT,
  sandbox/MAS-friendly, and zero hardened-runtime friction.
- **Use Sparkle 2.x** for in-app updates given SelectTTS ships **non-MAS / Developer ID** (see
  [`04-…`](./04-distribution-signing-ci.md)). The MAS incompatibility is a non-issue for the chosen
  distribution path; remember to embed-and-sign Sparkle's components.
- **Store BYOK provider API keys in the Keychain.** KeychainAccess is convenient but
  **unmaintained since 2021** — weigh it against using Apple Keychain Services directly or Valet.
  Either way there is no entitlement/notarization conflict for single-app key storage.
- **macOS 14 target** comfortably satisfies every library's minimum OS.
