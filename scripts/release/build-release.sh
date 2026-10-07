#!/usr/bin/env bash
# Build, sign and package a release: dist/SelectTTS-<version>.dmg, and point the Homebrew cask
# (packaging/homebrew/selecttts.rb) at it. Publishing is a separate, manual step (scripts/release/README.md).
#
#   scripts/release/build-release.sh 0.1.0
#
# The app is built unsigned, then signed with the self-signed release identity
# (scripts/release/signing-identity.sh) with the hardened runtime and App/SelectTTS.entitlements.
# The script stops if the result would not carry the committed designated requirement, because a
# different requirement silently voids every user's Accessibility grant.
#
# If a tap checkout exists at $SELECTTTS_TAP_DIR (default: ../homebrew-tap next to this repo), the
# updated cask is copied to its Casks/ directory too.
set -euo pipefail
source "$(dirname "$0")/common.sh"

VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: build-release.sh X.Y.Z"

APP_NAME="SelectTTS"
DERIVED="$REPO_ROOT/build/release"
STAGE="$DERIVED/dmg-root"
APP="$STAGE/$APP_NAME.app"
DIST="$REPO_ROOT/dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
CASK="$REPO_ROOT/packaging/homebrew/selecttts.rb"
TAP_DIR="${SELECTTTS_TAP_DIR:-$REPO_ROOT/../homebrew-tap}"
ENTITLEMENTS="$REPO_ROOT/App/SelectTTS.entitlements"
BUILD_NUMBER="$(git -C "$REPO_ROOT" rev-list --count HEAD)"

[[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]] ||
    warn "the working tree has uncommitted changes; this build won't match a commit"

# 1. Check the signing identity before spending time on a build.
unlock_signing_keychain
SHA1="$(identity_sha1)"
EXPECTED="$(expected_sha1)"
[[ -n "$SHA1" ]] || die "identity '$IDENTITY_NAME' not found in $SIGNING_KEYCHAIN"
[[ "$SHA1" == "$EXPECTED" ]] ||
    die "the signing identity ($SHA1) is not the project's release certificate ($EXPECTED) — import the backup instead of creating a new identity"

# 2. Build unsigned (signing happens below, with our identity, not the Xcode team's).
BUILD_LOG="$DERIVED/xcodebuild.log"
echo "==> Building $APP_NAME $VERSION ($BUILD_NUMBER), log: ${BUILD_LOG#"$REPO_ROOT/"}"
mkdir -p "$DERIVED"
if ! xcodebuild \
    -project "$REPO_ROOT/SelectTTS.xcodeproj" -scheme SelectTTS -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$DERIVED" \
    -disableAutomaticPackageResolution \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGNING_ALLOWED=NO \
    clean build >"$BUILD_LOG" 2>&1; then
    tail -40 "$BUILD_LOG" >&2
    die "xcodebuild failed (full log: $BUILD_LOG)"
fi

rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$DERIVED/Build/Products/Release/$APP_NAME.app" "$APP"

# 3. Sign. Nested code (frameworks, XPC services, helpers — e.g. once Sparkle is added) must be
#    signed inside-out before the app; there is none today, so refuse rather than sign it wrongly.
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$APP/Contents/Info.plist")"
NESTED="$(find "$APP/Contents" -type f ! -path "$APP/Contents/MacOS/$EXECUTABLE" -print0 |
    xargs -0 file | grep 'Mach-O' || true)"
[[ -z "$NESTED" ]] || die "nested code found; extend the signing step to sign it first:
$NESTED"

echo "==> Signing with '$IDENTITY_NAME' ($SHA1)"
codesign --force --options runtime --timestamp=none \
    --entitlements "$ENTITLEMENTS" \
    --keychain "$SIGNING_KEYCHAIN" --sign "$SHA1" \
    "$APP"

codesign --verify --strict --deep "$APP"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Contents/Info.plist")"
DR="$(codesign -d -r- "$APP" 2>&1 | sed -n 's/^designated => //p')"
WANT_DR="identifier \"$BUNDLE_ID\" and certificate leaf = H\"$(lowercase <<<"$SHA1")\""
[[ "$DR" == "$WANT_DR" ]] || die "unexpected designated requirement:
  got:  $DR
  want: $WANT_DR"
# Captured first: piping codesign into `grep -q` under pipefail fails whenever grep exits early.
SIGNATURE_INFO="$(codesign -d --verbose=2 "$APP" 2>&1)"
ENTITLEMENTS_SIGNED="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)"
[[ "$SIGNATURE_INFO" == *"flags=0x10000(runtime)"* ]] || die "the hardened runtime flag is missing"
[[ "$ENTITLEMENTS_SIGNED" != *"get-task-allow"* ]] ||
    die "the release carries get-task-allow (a debug entitlement)"

# 4. Package: a compressed DMG with the app and an /Applications link to drag it onto.
echo "==> Packaging $DMG"
ln -s /Applications "$STAGE/Applications"
mkdir -p "$DIST"
rm -f "$DMG"
hdiutil create -quiet -volname "$APP_NAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG"
hdiutil verify -quiet "$DMG"
SHA256="$(shasum -a 256 "$DMG" | awk '{ print $1 }')"

# 5. Point the cask at this release.
sed -i '' -E \
    -e "s/^  version \".*\"$/  version \"$VERSION\"/" \
    -e "s/^  sha256 .*$/  sha256 \"$SHA256\"/" \
    "$CASK"
grep -q "^  version \"$VERSION\"$" "$CASK" && grep -q "^  sha256 \"$SHA256\"$" "$CASK" ||
    die "could not update $CASK"
if [[ -d "$TAP_DIR/.git" ]]; then
    mkdir -p "$TAP_DIR/Casks"
    cp "$CASK" "$TAP_DIR/Casks/selecttts.rb"
    TAP_NOTE="copied to $TAP_DIR/Casks/selecttts.rb"
else
    TAP_NOTE="no tap checkout at $TAP_DIR, so it was not copied"
fi

cat <<EOF

Built ${DMG#"$REPO_ROOT/"}
  version     $VERSION (build $BUILD_NUMBER)
  sha256      $SHA256
  requirement $DR
Updated ${CASK#"$REPO_ROOT/"} ($TAP_NOTE).

Publish (scripts/release/README.md):
  git commit -am "Release $VERSION" && git tag v$VERSION && git push origin main v$VERSION
  gh release create v$VERSION "$DMG" --title "$APP_NAME $VERSION" --generate-notes
  then commit + push the cask in the tap repo.
EOF
