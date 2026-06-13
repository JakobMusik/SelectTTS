#!/usr/bin/env bash
# Smoke-test the SelectTTSKit cores using only the Swift compiler (no Xcode / no SwiftPM driver).
#
# Useful where the full SwiftPM toolchain is unavailable (e.g. Command Line Tools only): it emits
# each module in dependency order with `swiftc`, which type-checks the whole graph. For real unit
# tests run `swift test` in Packages/SelectTTSKit (needs Xcode / a working SwiftPM).
set -euo pipefail

cd "$(dirname "$0")/../Packages/SelectTTSKit"

SDK="$(xcrun --show-sdk-path)"
TARGET="arm64-apple-macosx13.0"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

emit() {
  local name="$1"; shift
  swiftc -wmo -parse-as-library -target "$TARGET" -sdk "$SDK" -I "$BUILD" \
    -module-name "$name" \
    -emit-module -emit-module-path "$BUILD/$name.swiftmodule" \
    -emit-object -o "$BUILD/$name.o" \
    "$@"
  echo "  ✓ $name"
}

echo "Type-checking SelectTTSKit cores with swiftc:"
emit SpeechCore       Sources/SpeechCore/*.swift
emit TextRouting      Sources/TextRouting/*.swift
emit SelectionCapture Sources/SelectionCapture/*.swift
emit Providers        Sources/Providers/*.swift
emit AudioPlayback    Sources/AudioPlayback/*.swift
emit AppSettings      Sources/AppSettings/*.swift
emit TTSModule        Sources/TTSModule/*.swift
echo "All cores compile."
