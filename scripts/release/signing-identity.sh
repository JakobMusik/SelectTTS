#!/usr/bin/env bash
# Manage the self-signed code-signing identity that release builds are signed with.
#
# Why self-signed: releases ship without an Apple Developer ID for now (scripts/release/README.md).
# macOS ties the Accessibility grant to the app's designated requirement. An ad-hoc signature
# changes on every build and silently voids the grant; a signature from this one long-lived
# certificate keeps the same requirement (`certificate leaf = H"<sha1>"`) across releases, so
# users grant Accessibility once. Gatekeeper still rejects the app (the certificate is not from
# Apple) — the Homebrew cask clears the quarantine flag, DMG users click "Open Anyway".
#
#   signing-identity.sh create        make the identity (once per project, ever)
#   signing-identity.sh show          print the identity and the requirement releases will carry
#   signing-identity.sh export FILE   write a passphrase-protected .p12 backup (asks for a passphrase)
#   signing-identity.sh import FILE   restore the identity from a .p12 backup (e.g. on a new Mac)
set -euo pipefail
source "$(dirname "$0")/common.sh"

# Creates the signing keychain, imports the .p12 into it, and stores the keychain's password in
# the login keychain.
import_p12() {
    local p12="$1" p12_password="$2" kc_password
    kc_password="$(/usr/bin/openssl rand -hex 24)"

    security create-keychain -p "$kc_password" "$SIGNING_KEYCHAIN"
    security set-keychain-settings "$SIGNING_KEYCHAIN" # no auto-lock; releases unlock it anyway
    security unlock-keychain -p "$kc_password" "$SIGNING_KEYCHAIN"
    if ! security import "$p12" -k "$SIGNING_KEYCHAIN" -P "$p12_password" \
        -T /usr/bin/codesign -T /usr/bin/security >/dev/null; then
        security delete-keychain "$SIGNING_KEYCHAIN"
        die "could not import $p12 (wrong passphrase?)"
    fi
    # Let codesign and security use the key without a GUI "allow access" prompt.
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kc_password" \
        "$SIGNING_KEYCHAIN" >/dev/null
    security add-generic-password -U -s "$KEYCHAIN_PASSWORD_SERVICE" -a "$USER" \
        -l "SelectTTS release signing keychain" -w "$kc_password"
}

cmd_create() {
    [[ ! -e "$SIGNING_KEYCHAIN" ]] ||
        die "$SIGNING_KEYCHAIN already exists — refusing to replace the identity (see 'show')"
    [[ ! -e "$CERT_FINGERPRINT_FILE" ]] ||
        die "$CERT_FINGERPRINT_FILE exists, so this project already has a release identity. A new one would make every user re-grant Accessibility; restore the backup with 'import' instead."

    local tmp
    tmp="$(mktemp -d)"
    # Expanded now: the local is gone by the time the EXIT trap runs. Removes the plaintext key.
    trap "rm -rf '$tmp'" EXIT
    cat >"$tmp/cert.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = ext
prompt = no
[ dn ]
CN = $IDENTITY_NAME
[ ext ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
subjectKeyIdentifier = hash
EOF
    # /usr/bin/openssl is LibreSSL, whose .p12 encryption `security import` understands (OpenSSL 3's
    # default PBKDF2/AES .p12 needs -legacy).
    /usr/bin/openssl req -x509 -newkey rsa:3072 -nodes -sha256 -days "$CERT_DAYS" \
        -config "$tmp/cert.cnf" -keyout "$tmp/key.pem" -out "$tmp/cert.pem" 2>/dev/null
    local p12_password
    p12_password="$(/usr/bin/openssl rand -hex 24)"
    /usr/bin/openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" \
        -name "$IDENTITY_NAME" -out "$tmp/identity.p12" -passout "pass:$p12_password"

    import_p12 "$tmp/identity.p12" "$p12_password"

    local sha1
    sha1="$(identity_sha1)"
    [[ -n "$sha1" ]] || die "identity '$IDENTITY_NAME' not found after import"
    mkdir -p "$(dirname "$CERT_FINGERPRINT_FILE")"
    echo "$sha1" >"$CERT_FINGERPRINT_FILE"

    echo "Created '$IDENTITY_NAME' in $SIGNING_KEYCHAIN"
    echo "Wrote its fingerprint to ${CERT_FINGERPRINT_FILE#"$REPO_ROOT/"} (commit this file)."
    echo
    echo "Back it up now — losing it means every user re-grants Accessibility once:"
    echo "  scripts/release/signing-identity.sh export ~/Desktop/selecttts-signing.p12"
    echo "then keep the .p12 and its passphrase in your password manager and delete the file."
    echo
    cmd_show
}

cmd_show() {
    require_signing_keychain
    local sha1
    sha1="$(identity_sha1)"
    [[ -n "$sha1" ]] || die "identity '$IDENTITY_NAME' not found in $SIGNING_KEYCHAIN"
    echo "Identity:    $IDENTITY_NAME"
    echo "SHA-1:       $sha1"
    echo "Keychain:    $SIGNING_KEYCHAIN"
    if [[ -f "$CERT_FINGERPRINT_FILE" && "$(expected_sha1)" != "$sha1" ]]; then
        warn "this identity does NOT match ${CERT_FINGERPRINT_FILE#"$REPO_ROOT/"} ($(expected_sha1))"
    fi
    echo "Releases carry: designated => identifier \"com.selecttts.app\" and certificate leaf = H\"$(lowercase <<<"$sha1")\""
}

cmd_export() {
    local out="${1:-}"
    [[ -n "$out" ]] || die "usage: signing-identity.sh export FILE.p12"
    [[ ! -e "$out" ]] || die "$out already exists"
    unlock_signing_keychain

    local pass pass2
    read -r -s -p "Passphrase for the backup: " pass
    echo
    read -r -s -p "Repeat it: " pass2
    echo
    [[ -n "$pass" && "$pass" == "$pass2" ]] || die "the passphrases are empty or differ"

    (umask 077 && security export -k "$SIGNING_KEYCHAIN" -t identities -f pkcs12 -P "$pass" -o "$out")
    echo "Wrote $out — store it and the passphrase in your password manager, then delete the file."
}

cmd_import() {
    local p12="${1:-}"
    [[ -n "$p12" && -f "$p12" ]] || die "usage: signing-identity.sh import FILE.p12"
    [[ ! -e "$SIGNING_KEYCHAIN" ]] || die "$SIGNING_KEYCHAIN already exists"

    local pass
    read -r -s -p "Backup passphrase: " pass
    echo
    import_p12 "$p12" "$pass"
    cmd_show
}

case "${1:-}" in
    create) cmd_create ;;
    show) cmd_show ;;
    export) cmd_export "${2:-}" ;;
    import) cmd_import "${2:-}" ;;
    *)
        sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
        exit 64
        ;;
esac
