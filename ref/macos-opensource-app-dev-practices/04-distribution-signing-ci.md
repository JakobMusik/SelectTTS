# Distribution, Signing & CI

The modern pipeline for a **notarized, directly-distributed (non-App-Store)** open-source macOS app
that uses Accessibility + Apple Events: Developer ID signing + hardened runtime →
`notarytool submit --wait` → `stapler` → signed/notarized DMG → GitHub Releases → Homebrew cask →
Sparkle appcast (EdDSA), all driven from GitHub Actions.

> Deep-research pass on **2026-06-13** (workflow **wf_011ff0d2-367**, research →
> adversarial-verify). 20/20 claims confirmed against primary or strong secondary sources, most
> quoted near-verbatim. **Reliability: High overall.** Several verifier caveats are recorded
> honestly below (and in [`sources.md`](./sources.md)) — notably that the "no
> `com.apple.security.accessibility` entitlement" conclusion rests on **absence of evidence**.

## Entitlements: the critical nuance (confirmed, with caveats)

This is the part most worth getting right for SelectTTS.

| Capability | Entitlement / Info.plist key | Required? |
|------------|------------------------------|-----------|
| **Accessibility API as a client** (`AXUIElement`, `AXIsProcessTrusted`) | none | **No code-signing entitlement.** Gated solely by TCC consent (System Settings > Privacy & Security > Accessibility) |
| **Sending Apple Events to *other* apps** from a hardened, non-sandboxed app | `com.apple.security.automation.apple-events` **AND** `NSAppleEventsUsageDescription` | **Yes** — *unless* only sending to self or same-Team-ID processes |

- Using the Accessibility API as a client requires **no** code-signing entitlement; there is **no
  documented `com.apple.security.accessibility` hardened-runtime entitlement**.
  **Honest caveat:** this conclusion is **absence-of-evidence** (Hammerspoon's actual entitlements
  + Eclectic Light), not an explicit Apple statement. jano.dev's 2025 claim that such an entitlement
  *is* required is uncorroborated and likely a misconception; `NSAccessibilityUsageDescription` is
  also not a standard Info.plist key.
  Sources:
  [Hammerspoon-Info.plist](https://github.com/Hammerspoon/hammerspoon/blob/master/Hammerspoon/Hammerspoon-Info.plist),
  [eclecticlight.co/2021/01/07/notarization-the-hardened-runtime](https://eclecticlight.co/2021/01/07/notarization-the-hardened-runtime/),
  jano.dev (counter-claim).
- The same-Team-ID Apple Events exemption is true and multiply-corroborated, **but the specific
  cited forum thread 108526 does NOT actually contain it**, and Apple's canonical entitlement page
  is JS-rendered.
  Sources:
  [lapcatsoftware.com/articles/hardened-runtime-sandboxing.html](https://lapcatsoftware.com/articles/hardened-runtime-sandboxing.html),
  Hammerspoon-Info.plist,
  [developer.apple.com/forums/thread/108526](https://developer.apple.com/forums/thread/108526).
- **Documented hardened-runtime entitlements** are the `com.apple.security.cs.*` exceptions:
  `allow-jit`, `allow-unsigned-executable-memory`, `allow-dyld-environment-variables`,
  `disable-library-validation`, `disable-executable-page-protection`, `debugger`; plus
  `get-task-allow` and `app-sandbox`; plus resource/automation keys (`device.*`,
  `personal-information.*`, `automation.apple-events`). A minimal accessibility + apple-events app
  needs **none of the `cs.*` exceptions** unless it embeds plugins/JIT. (Hammerspoon additionally
  declares `device.audio-input`, `device.camera`,
  `personal-information.addressbook/calendars/location/photos-library`.)
  **Caveat:** the cited "Hammerspoon-Info.plist" URL is the Info.plist, not the entitlements file
  (entitlements verified via the theevilbit writeup).

## Signing: Developer ID + hardened runtime (confirmed)

- Non-MAS apps use a **Developer ID Application** certificate (the $99/yr program). The app **must
  enable hardened runtime** to be notarizable.
- Sign **bottom-up** (helpers/frameworks first, then the `.app`):
  `codesign -f -s $ID -o runtime`.
- All embedded **Sparkle** components (Sparkle.framework, Autoupdate, Updater.app, the
  Downloader/Installer XPC services) must be Developer ID-signed or notarization fails — set
  Sparkle.framework to **"Embed & Sign"**. The EdDSA appcast signature is **separate from and
  additional to** Developer ID code signing.
- Sources:
  [rsms gist](https://gist.github.com/rsms/929c9c2fec231f0cf843a1a746a416f5),
  [developer.apple.com/developer-id](https://developer.apple.com/developer-id/),
  [steipete/CodexBar RELEASING.md](https://github.com/steipete/CodexBar/blob/main/docs/RELEASING.md),
  [sparkle-project.org/documentation](https://sparkle-project.org/documentation/).

## Notarization with notarytool (confirmed)

- **altool notarization is deprecated.** Apple's notary service stopped accepting altool /
  Xcode-13-or-earlier uploads on **November 1, 2023**; use **`notarytool`** (or Xcode 14+). altool
  still works for other tasks (e.g. App Store uploads).
  Sources:
  [developer.apple.com/news/?id=y5mjxqmn](https://developer.apple.com/news/?id=y5mjxqmn),
  [/news/upcoming-requirements/?id=11012023a](https://developer.apple.com/news/upcoming-requirements/?id=11012023a).
- `notarytool` subcommands: **submit, info, log, history, store-credentials, wait**.
  `submit --wait` uploads and blocks until done (no polling). Auth options: App Store Connect API
  key (`-k`/`-d`); Apple ID + Team ID + app-specific `--password`; or a saved
  `--keychain-profile`/`-p` (created via `store-credentials`). It does **NOT** staple — that is a
  separate `xcrun stapler staple`.
  [keith.github.io/xcode-man-pages/notarytool.1.html](https://keith.github.io/xcode-man-pages/notarytool.1.html)
- **End-to-end flow:**
  1. `ditto -c -k --keepParent App.app App.zip` (a Finder zip will not do)
  2. `xcrun notarytool submit App.zip --keychain-profile <name> --wait`
  3. optional: `notarytool log <id> output.json`
  4. `xcrun stapler staple App.app`
  5. verify: `spctl -a -vvv -t install`

  Stapling is recommended for **offline** Gatekeeper validation; **staple Error 65 = the
  notarization request itself failed**.
  Sources: rsms gist, notarytool man page.

## Packaging: DMG preferred (confirmed)

- The **DMG** is the preferred direct-distribution vehicle: it can be code-signed and itself
  notarized + stapled; copying the app to `/Applications` avoids Gatekeeper **app translocation**. A
  downloaded **zip is unconditionally quarantined** → triggers translocation/sandboxing.
- Typical order: sign + notarize + staple the `.app`, build the DMG, then notarize + staple the DMG
  too (e.g. `xcrun notarytool submit ... --wait dist/Franz.dmg`;
  `xcrun stapler staple dist/Franz.dmg`).
- **create-dmg** (`brew install create-dmg`): `create-dmg [options] <output.dmg> <source_folder>`;
  options include `--volname`, `--volicon`, `--background`, `--window-pos`, `--window-size`,
  `--icon`, `--app-drop-link` (the `/Applications` symlink), `--codesign <identity>`, `--encrypt`.
- Sources: rsms gist,
  [defn.io/2023/09/22/distributing-mac-apps-with-github-actions](https://defn.io/2023/09/22/distributing-mac-apps-with-github-actions/),
  [github.com/create-dmg/create-dmg](https://github.com/create-dmg/create-dmg).

## Homebrew cask (confirmed)

- A cask is a Ruby DSL with stanzas: `version`, `sha256` (`shasum -a 256` or `:no_check`), `url`,
  `name`, `desc` (< 80 chars), `homepage`, `app` (installs the `.app` to `/Applications`),
  `livecheck` (a Sparkle strategy exists in `brew livecheck`), `zap`. New casks are submitted as a
  PR to `Homebrew/homebrew-cask`; the `sha256` must match the released artifact.
- **Cask updates are NOT automatic** even with a Sparkle livecheck strategy — each version needs a
  PR. Maintainers commonly run `brew bump-cask-pr` from a release Action (or
  `dawidd6/action-homebrew-bump-package`).
- Sources:
  [docs.brew.sh/Cask-Cookbook](https://docs.brew.sh/Cask-Cookbook),
  [Homebrew/homebrew-cask CONTRIBUTING](https://github.com/Homebrew/homebrew-cask/blob/main/CONTRIBUTING.md),
  [docs.brew.sh/How-To-Open-a-Homebrew-Pull-Request](https://docs.brew.sh/How-To-Open-a-Homebrew-Pull-Request),
  [Homebrew discussions #3808](https://github.com/orgs/Homebrew/discussions/3808),
  [action-homebrew-bump-cask](https://github.com/marketplace/actions/homebrew-bump-cask).

## Sparkle appcast + EdDSA (confirmed)

- Sparkle in-app updates use an **EdDSA (ed25519)** key. Run `generate_keys` once (private key →
  login Keychain + public key); put the public key in `Info.plist` **`SUPublicEDKey`** (base64
  string); set **`SUFeedURL`** to the hosted `appcast.xml` URL.
- `generate_appcast` archives the app (`.dmg`/`.zip`/`.tar.*`/`.aar`), generates EdDSA signatures,
  and writes a signed `appcast.xml` with `<item>` entries (version, `sparkle:edSignature`, length,
  download URL). **CI: feed the private key via stdin** —
  `echo "$PRIVATE_SPARKLE_KEY" | ./generate_appcast --ed-key-file -` — and store the key as a
  GitHub secret. `sign_update` signs a single archive manually (outputs
  `sparkle:edSignature="..." length="..."`).
  **Caveat:** the stdin approach is real (Sparkle discussion #2308), but the co-cited
  SparkleReleaseTest workflow actually writes the key to a file.
- Serve `appcast.xml` + archives over **HTTPS**; common open-source hosting = GitHub Releases
  (archives) + GitHub Pages (appcast), with `SUFeedURL` = e.g.
  `https://<user>.github.io/<repo>/appcast.xml`.
- Sources:
  [sparkle-project.org/documentation](https://sparkle-project.org/documentation/),
  [/documentation/publishing](https://sparkle-project.org/documentation/publishing/),
  [Sparkle discussion #2308](https://github.com/sparkle-project/Sparkle/discussions/2308),
  [SparkleReleaseTest release.yml](https://github.com/AlexPerathoner/SparkleReleaseTest/blob/master/.github/workflows/release.yml),
  [medium.com/@alex.pera automating Sparkle releases](https://medium.com/@alex.pera/automating-xcode-sparkle-releases-with-github-actions-bd14f3ca92aa).

## GitHub Actions: cert import + build (confirmed)

Exact macOS-runner certificate-import sequence:

```
security create-keychain -p <pwd> $RUNNER_TEMP/app-signing.keychain-db
security set-keychain-settings -lut 21600 <keychain>
security unlock-keychain -p <pwd> <keychain>
security import <cert.p12> -P <p12-pwd> -A -t cert -f pkcs12 -k <keychain>
security set-key-partition-list -S apple-tool:,apple: -k <pwd> <keychain>
security list-keychain -d user -s <keychain>
# cleanup:
security delete-keychain $RUNNER_TEMP/app-signing.keychain-db
```

The `.p12` is base64-decoded from a secret.
Sources:
[docs.github.com — installing an Apple certificate on macOS runners](https://docs.github.com/en/actions/use-cases-and-examples/deploying/installing-an-apple-certificate-on-macos-runners-for-xcode-development),
SparkleReleaseTest release.yml.

Typical release build:

```
xcodebuild clean archive -project X.xcodeproj -scheme X -archivePath X.xcarchive
xcodebuild -exportArchive -archivePath X.xcarchive \
  -exportOptionsPlist ExportOptions.plist -exportPath dist   # Developer ID export method
```

…then sign / notarize / staple / package. Sources: defn.io, SparkleReleaseTest release.yml.

### Required GitHub Actions secrets (confirmed)

base64 Developer ID `.p12`, the `.p12` password, a temp-keychain password, the Apple ID (or App
Store Connect API key id/issuer/key), an app-specific password, the Team ID, and the Sparkle EdDSA
private key — e.g. `PROD_MACOS_CERTIFICATE`, `..._CERTIFICATE_NAME`, `..._CERTIFICATE_PWD`,
`..._NOTARIZATION_APPLE_ID`, `..._NOTARIZATION_PWD`, `..._NOTARIZATION_TEAM_ID`, `..._CI_KEYCHAIN_PWD`,
`PRIVATE_SPARKLE_KEY`.
Sources:
[federicoterzi.com — automatic code signing and notarization](https://federicoterzi.com/blog/automatic-code-signing-and-notarization-for-macos-apps-using-github-actions/),
Sparkle discussion #2308.

## CI: lint, format, tests (confirmed)

- **SwiftLint** via `norio-nomura/action-swiftlint` (Ice uses `@3.2.1` with `--strict` on
  ubuntu-latest) or `cirruslabs/swiftlint-action`.
- **swift-format** via `xcrun swift-format lint --recursive --strict .` or
  `mtgto/swift-format-action`.
- **Tests** via `xcodebuild test`.
- Final artifacts to GitHub Releases (e.g. `softprops/action-gh-release@v1`), attaching the
  notarized/stapled **DMG** and/or a **ditto zip**
  (`ditto -c -k --sequesterRsrc --keepParent X.app X.zip`, used as the Sparkle enclosure) —
  referenced by both the cask `url` and the appcast enclosure.
- Sources:
  [Ice lint.yml](https://github.com/jordanbaird/Ice/blob/main/.github/workflows/lint.yml),
  cirruslabs/swiftlint-action, mtgto/swift-format-action, docs.brew.sh/Cask-Cookbook,
  SparkleReleaseTest release.yml.

## Open questions / verifier caveats (honest)

- Apple's canonical hardened-runtime / apple-events / "configuring the hardened runtime" pages are
  **JS-rendered**; entitlement names were corroborated via secondary sources + Hammerspoon —
  confirm against live Apple docs.
- The **jano.dev** `com.apple.security.accessibility` + `NSAccessibilityUsageDescription` claim is
  likely a misconception, but **no explicit Apple "no entitlement required" statement was found** —
  the conclusion is absence-of-evidence.
- Whether stapling the `.app` *before* building the DMG **and also** notarizing+stapling the DMG is
  strictly necessary, vs only notarizing the DMG (practice varies) — verify against TN3147 /
  "Customizing the notarization workflow".
- Exact current `notarytool` auth recommendation (API key vs Apple-ID + app-specific password) —
  confirm against the latest `xcrun notarytool --help`.
- **No single canonical end-to-end workflow** does Developer ID + notarytool + create-dmg +
  generate_appcast + Homebrew bump in one file; this was assembled from SparkleReleaseTest,
  CodexBar, defn.io/Franz, and Ice.

## Implications for SelectTTS

- **Ship Developer ID + hardened runtime, direct-distributed (non-MAS)** — the only viable path for
  a selection-grabber (consistent with the Phase 1 selected-text-capture findings).
- **Entitlements to declare:** if SelectTTS only reads selected text via the Accessibility API as a
  client, it needs **no `com.apple.security.accessibility` entitlement** — just the runtime TCC
  grant. **If** it scripts other apps (e.g. AppleScript to browsers for selection capture), it must
  add **`com.apple.security.automation.apple-events`** + an **`NSAppleEventsUsageDescription`**
  string. Treat the "no accessibility entitlement" point as well-supported but absence-of-evidence;
  confirm at integration time.
- **Pipeline:** `notarytool submit --wait` → `xcrun stapler staple` → notarized DMG via create-dmg
  → GitHub Releases → Homebrew cask (with a `brew bump-cask-pr` step) → Sparkle appcast on GitHub
  Pages.
- **Wire up the GitHub Actions secrets** listed above, and remember to **Embed & Sign** Sparkle's
  framework + helpers or notarization will fail.
