# Shared settings and helpers for the release scripts. Sourced, not run.
#
# Every setting can be overridden from the environment (the defaults are what a release uses).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Common Name of the self-signed code-signing certificate.
IDENTITY_NAME="${SELECTTTS_SIGNING_IDENTITY:-SelectTTS Self-Signed}"
# The identity lives in its own keychain, kept off the keychain search list so other apps never
# see it or ask to unlock it. codesign is pointed at it explicitly with --keychain.
SIGNING_KEYCHAIN="${SELECTTTS_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/selecttts-signing.keychain-db}"
# That keychain's random password is stored in the login keychain under this service name.
KEYCHAIN_PASSWORD_SERVICE="${SELECTTTS_KEYCHAIN_PASSWORD_SERVICE:-selecttts-signing-keychain}"
# SHA-1 of the release certificate (public, committed). Releases must be signed with exactly
# this certificate: it is what keeps users' Accessibility grant valid across updates.
CERT_FINGERPRINT_FILE="${SELECTTTS_CERT_FINGERPRINT_FILE:-$REPO_ROOT/packaging/signing/certificate-sha1.txt}"
# Certificate lifetime. The designated requirement pins the certificate itself, so replacing it
# (e.g. on expiry) makes every user re-grant Accessibility once — hence the long lifetime.
CERT_DAYS=7305 # 20 years

die() {
    echo "error: $*" >&2
    exit 1
}

warn() {
    echo "warning: $*" >&2
}

keychain_password() {
    security find-generic-password -s "$KEYCHAIN_PASSWORD_SERVICE" -a "$USER" -w 2>/dev/null ||
        die "no '$KEYCHAIN_PASSWORD_SERVICE' password in the login keychain — was the identity created on this Mac? (scripts/release/signing-identity.sh import)"
}

require_signing_keychain() {
    [[ -f "$SIGNING_KEYCHAIN" ]] ||
        die "no signing keychain at $SIGNING_KEYCHAIN — run scripts/release/signing-identity.sh create (first time) or import (new Mac)"
}

unlock_signing_keychain() {
    require_signing_keychain
    security unlock-keychain -p "$(keychain_password)" "$SIGNING_KEYCHAIN"
}

# SHA-1 (uppercase hex) of the identity named $IDENTITY_NAME in the signing keychain. The
# certificate is self-signed and so untrusted; `find-identity` without -v still lists it, and
# codesign signs with it fine.
identity_sha1() {
    security find-identity -p codesigning "$SIGNING_KEYCHAIN" |
        awk -v name="\"$IDENTITY_NAME\"" 'index($0, name) { print $2; exit }'
}

expected_sha1() {
    [[ -f "$CERT_FINGERPRINT_FILE" ]] || die "missing $CERT_FINGERPRINT_FILE"
    tr -d '[:space:]' <"$CERT_FINGERPRINT_FILE"
}

lowercase() {
    tr '[:upper:]' '[:lower:]'
}
