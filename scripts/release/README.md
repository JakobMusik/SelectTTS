# Releasing SelectTTS

SelectTTS is distributed outside the Mac App Store, because the App Store sandbox rules out reading
other apps' selections. For now there is **no Apple Developer ID**: releases are signed with the
project's own self-signed certificate, published on GitHub Releases, and installed through the
project's own Homebrew tap. Moving to a Developer ID later is described at the end.

## How it works

- **Signature.** Release builds are signed with the certificate **SelectTTS Self-Signed** (its SHA-1
  is committed in [`packaging/signing/certificate-sha1.txt`](../../packaging/signing/certificate-sha1.txt)),
  with the hardened runtime and [`App/SelectTTS.entitlements`](../../App/SelectTTS.entitlements).
- **Why self-signed rather than unsigned.** macOS records the Accessibility grant against the app's
  *designated requirement*. Releases carry
  `identifier "com.selecttts.app" and certificate leaf = H"<sha1>"`, which stays the same as long as
  the same certificate signs every release, so users grant Accessibility once and it survives
  updates. An ad-hoc signature changes on every build and silently voids the grant.
- **Gatekeeper.** The certificate is not issued by Apple and the app is not notarized, so Gatekeeper
  refuses a *quarantined* copy. The Homebrew cask removes the quarantine attribute after install;
  people who download the DMG click **Open Anyway** once. macOS still verifies the signature itself.
- **Why our own tap.** The official `homebrew/cask` tap has disabled casks that fail Gatekeeper
  since September 2026, and it only accepts notable projects (225 stars, or 90 forks/watchers, for a
  self-submission). A tap (`jakobmusik/homebrew-tap`) has neither requirement.

## Where the signing identity lives

| What | Where |
|------|-------|
| Certificate + private key | `~/Library/Keychains/selecttts-signing.keychain-db`, a separate keychain kept off the keychain search list, so other apps never see it or ask to unlock it |
| That keychain's password | login keychain, item `selecttts-signing-keychain` (random; the scripts read it, you never need it) |
| Certificate fingerprint (public) | `packaging/signing/certificate-sha1.txt` (committed) |

The identity was created on 2026-10-07 and is valid for 20 years.

**Back it up** outside the repository, never inside it:

```sh
scripts/release/signing-identity.sh export ../backups/selecttts-signing.p12
```

It asks for a passphrase. Keep the `.p12` and the passphrase somewhere safe. On a new Mac, restore it
with `scripts/release/signing-identity.sh import FILE.p12`.
`scripts/release/signing-identity.sh show` prints the identity and the requirement releases carry.

Never create a second identity for the project. `create` refuses once the fingerprint file exists.
If the key is lost for good: delete the fingerprint file, run `create`, and say in the release notes
that everyone must re-grant Accessibility once (remove and re-add SelectTTS in the list).

## One-time: the GitHub repositories

The cask assumes `github.com/jakobmusik/SelectTTS` and `github.com/jakobmusik/homebrew-tap`. If you
use other names, change `url` and `homepage` in
[`packaging/homebrew/selecttts.rb`](../../packaging/homebrew/selecttts.rb).

```sh
gh repo create jakobmusik/SelectTTS --public --source . --push
gh repo create jakobmusik/homebrew-tap --public --description "Homebrew tap for SelectTTS"
git clone https://github.com/jakobmusik/homebrew-tap ../homebrew-tap
```

A tap is a plain repository with the cask at `Casks/selecttts.rb`. With the checkout at
`../homebrew-tap`, the release script copies the cask into it automatically (override the location
with `SELECTTTS_TAP_DIR`).

## Each release

1. Build, sign and package from a clean, committed tree:

   ```sh
   scripts/release/build-release.sh 0.2.0
   ```

   This builds the Release configuration unsigned (version `0.2.0`, build number = commit count),
   signs it, verifies the signature, hardened runtime, entitlements and designated requirement,
   writes `dist/SelectTTS-0.2.0.dmg`, and updates `version` and `sha256` in the cask (and the copy in
   `../homebrew-tap`). It stops if the signature would not match the committed fingerprint.

2. Publish the app:

   ```sh
   git commit -am "Release 0.2.0"
   git tag v0.2.0
   git push origin main v0.2.0
   gh release create v0.2.0 dist/SelectTTS-0.2.0.dmg --title "SelectTTS 0.2.0" --generate-notes
   ```

   Upload exactly the DMG that was built: DMGs are not byte-reproducible, so a rebuild changes the
   sha256 and the cask must be updated again.

3. Publish the cask:

   ```sh
   cd ../homebrew-tap
   git commit -am "selecttts 0.2.0"
   git push
   ```

4. Check it the way users get it: `brew update && brew upgrade --cask selecttts`, or a fresh
   `brew install --cask jakobmusik/tap/selecttts`.

## What users do

- **Homebrew:** `brew install --cask jakobmusik/tap/selecttts`. Homebrew trusts the cask on that
  first fully qualified install. Then allow SelectTTS under System Settings ▸ Privacy & Security ▸
  Accessibility and relaunch it. Updates: `brew upgrade --cask selecttts`.
- **DMG:** drag SelectTTS to Applications and open it. macOS says it can't verify the app; open
  System Settings ▸ Privacy & Security and click **Open Anyway** (since macOS 15, Control-click ▸
  Open no longer bypasses this). Or run `xattr -dr com.apple.quarantine /Applications/SelectTTS.app`.

There is no in-app updater yet; the Accessibility grant survives updates either way.

## Gotchas

- **Your own Mac:** Xcode builds are signed with your Apple Development identity, releases with the
  self-signed one. They share the bundle id but not the designated requirement, so switching between
  an Xcode build and an installed release leaves the Accessibility toggle on but not working. Remove
  SelectTTS from the list and add it again, or run `tccutil reset Accessibility com.selecttts.app`.
- **Nested code.** The script refuses to sign an app that contains frameworks, helpers or XPC
  services, which must be signed inside-out first. Adding an updater such as Sparkle means extending
  the signing step.
- **No timestamp.** Signatures are made with `--timestamp=none`.

## Moving to a Developer ID later

1. Join the Apple Developer Program (USD 99/year) and create a **Developer ID Application**
   certificate.
2. Sign with it (`codesign --options runtime --timestamp`), zip the app with
   `ditto -c -k --keepParent`, notarize with `xcrun notarytool submit --wait`, run
   `xcrun stapler staple` on the app, build the DMG, and drop the quarantine step from the cask.
3. Once the repository is notable enough, submit the cask to `homebrew/cask`.

The first Developer ID release changes the designated requirement (it becomes Team ID-based), so
every user re-grants Accessibility once; say so in its release notes. The fingerprint check in
`build-release.sh` has to change with it. If the membership later lapses, notarized releases keep
working; only new releases can't be notarized until it is renewed.
