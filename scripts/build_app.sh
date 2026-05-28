#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Manual/CamBar.app"
FRAMEWORK_SRC="$ROOT_DIR/Pods/VLCKit/VLCKit.xcframework/macos-arm64_x86_64/VLCKit.framework"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"

if [[ ! -d "$ROOT_DIR/Pods/VLCKit" ]]; then
  (cd "$ROOT_DIR" && pod install)
fi

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Frameworks"

xcrun swiftc \
  -target arm64-apple-macos13.0 \
  -sdk "$SDK_PATH" \
  -F "$ROOT_DIR/Pods/VLCKit/VLCKit.xcframework/macos-arm64_x86_64" \
  -framework AppKit \
  -framework Security \
  -framework VLCKit \
  "$ROOT_DIR"/CamBar/Sources/*.swift \
  -o "$APP_DIR/Contents/MacOS/CamBar"

cp "$ROOT_DIR/CamBar/Sources/Info.plist" "$APP_DIR/Contents/Info.plist"
ditto "$FRAMEWORK_SRC" "$APP_DIR/Contents/Frameworks/VLCKit.framework"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
