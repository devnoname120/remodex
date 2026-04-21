#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/CodexMobile/CodexMobile.xcodeproj}"
SCHEME="${SCHEME:-CodexMobile}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build/unsigned-ipa}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$OUTPUT_DIR/$SCHEME.xcarchive}"
IPA_NAME="${IPA_NAME:-remodex-unsigned-release.ipa}"
IPA_PATH="$OUTPUT_DIR/$IPA_NAME"
BUILD_LOG_PATH="${BUILD_LOG_PATH:-$OUTPUT_DIR/xcodebuild.log}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=iOS" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  2>&1 | tee "$BUILD_LOG_PATH"

APP_PATH="$(find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$APP_PATH" ]]; then
  echo "Unable to locate an .app bundle in $ARCHIVE_PATH" >&2
  exit 1
fi

PAYLOAD_ROOT="$(mktemp -d "$OUTPUT_DIR/payload.XXXXXX")"
trap 'rm -rf "$PAYLOAD_ROOT"' EXIT

mkdir -p "$PAYLOAD_ROOT/Payload"
ditto "$APP_PATH" "$PAYLOAD_ROOT/Payload/$(basename "$APP_PATH")"
ditto -c -k --sequesterRsrc --keepParent "$PAYLOAD_ROOT/Payload" "$IPA_PATH"

echo "Unsigned IPA created at $IPA_PATH"
