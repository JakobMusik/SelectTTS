#!/usr/bin/env bash
# Lint the repository with pinned SwiftFormat and SwiftLint versions — the same ones CI runs.
#
#   scripts/lint.sh          # report findings; exits non-zero if there are any
#   scripts/lint.sh --fix    # autocorrect what SwiftLint can, then format with SwiftFormat
#
# Homebrew and the CI runner images ship whatever version is current, and a different version
# reports different findings. So the release binaries are downloaded from GitHub, checked against
# the SHA-256s below, and cached in .build/tools. To upgrade a tool, change its version and the
# SHA-256 of its release zip (`shasum -a 256 swiftformat.zip`).
set -euo pipefail

SWIFTFORMAT_VERSION="0.64.6"
SWIFTFORMAT_SHA256="70e6b2057647fb1c54d620ebbb6649274de56534c57f91f67461a129ebaaba3e"
SWIFTLINT_VERSION="0.65.1"
SWIFTLINT_SHA256="c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$REPO_ROOT/.build/tools"
SWIFTFORMAT="$TOOLS/swiftformat-$SWIFTFORMAT_VERSION/swiftformat"
SWIFTLINT="$TOOLS/swiftlint-$SWIFTLINT_VERSION/swiftlint"

DOWNLOAD=""
trap 'if [[ -n "$DOWNLOAD" ]]; then rm -rf "$DOWNLOAD"; fi' EXIT

# fetch PATH URL SHA256: downloads the zip, verifies it and installs its binary (named like PATH's
# last component) at PATH, unless PATH is already there.
fetch() {
    local binary="$1" url="$2" sha256="$3"
    [[ -x "$binary" ]] && return
    local name
    name="$(basename "$binary")"
    echo "==> Downloading $url"
    mkdir -p "$TOOLS"
    DOWNLOAD="$(mktemp -d "$TOOLS/.download.XXXXXX")"
    curl -fsSL --retry 3 -o "$DOWNLOAD/tool.zip" "$url"
    if ! echo "$sha256  $DOWNLOAD/tool.zip" | shasum -a 256 -c --status; then
        echo "error: $url doesn't match its pinned SHA-256" >&2
        exit 1
    fi
    unzip -q "$DOWNLOAD/tool.zip" "$name" -d "$DOWNLOAD"
    mkdir -p "$(dirname "$binary")"
    mv "$DOWNLOAD/$name" "$binary"
    rm -rf "$DOWNLOAD"
    DOWNLOAD=""
}

fetch "$SWIFTFORMAT" \
    "https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/swiftformat.zip" \
    "$SWIFTFORMAT_SHA256"
fetch "$SWIFTLINT" \
    "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/portable_swiftlint.zip" \
    "$SWIFTLINT_SHA256"

cd "$REPO_ROOT"
case "${1:-}" in
    "")
        status=0
        echo "==> SwiftFormat $SWIFTFORMAT_VERSION (lint mode)"
        "$SWIFTFORMAT" --lint . || status=1
        echo "==> SwiftLint $SWIFTLINT_VERSION"
        "$SWIFTLINT" lint --quiet || status=1
        exit "$status"
        ;;
    --fix)
        "$SWIFTLINT" lint --fix --quiet
        "$SWIFTFORMAT" .
        ;;
    *)
        echo "usage: scripts/lint.sh [--fix]" >&2
        exit 2
        ;;
esac
