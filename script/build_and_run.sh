#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-run}"
case "$MODE" in run|--build-only|--verify|--debug|--logs|--telemetry) ;; *) echo "Usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2;; esac
if [[ "$(uname -s)" != Darwin ]]; then echo "The SwiftUI app requires macOS 14+ and a Swift 6 toolchain. The core can be tested here with swift test." >&2; exit 1; fi
cd "$ROOT"
APP_NAME="Purrtion"
BUNDLE_ID="local.purrtion.calculator"
APP="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP/Contents"
CONFIG="${CONFIGURATION:-debug}"
if [[ "$CONFIG" != debug && "$CONFIG" != release ]]; then echo "CONFIGURATION must be debug or release" >&2; exit 2; fi
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
./script/sync_shared.sh
swift build -c "$CONFIG" --product "$APP_NAME"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
chmod +x "$CONTENTS/MacOS/$APP_NAME"
RESOURCE_BUNDLE="$BIN_DIR/Purrtion_PurrtionCore.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then echo "Missing SwiftPM resource bundle: $RESOURCE_BUNDLE" >&2; exit 1; fi
cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"
ICON="$ROOT/brand/Purrtion.icns"
if [[ ! -f "$ICON" ]]; then echo "Missing app icon: $ICON" >&2; exit 1; fi
cp "$ICON" "$CONTENTS/Resources/Purrtion.icns"
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$APP_NAME</string>
<key>CFBundleDisplayName</key><string>$APP_NAME</string>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIconFile</key><string>Purrtion</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
/usr/bin/plutil -lint "$CONTENTS/Info.plist"
# Local development signature only; not a Developer ID or notarized distribution.
/usr/bin/codesign --force --sign - --timestamp=none "$APP"
echo "Built $APP"
case "$MODE" in
  --build-only) ;;
  --debug) /usr/bin/lldb -- "$CONTENTS/MacOS/$APP_NAME" ;;
  --verify) /usr/bin/open -n "$APP"; sleep 2; pgrep -x "$APP_NAME" >/dev/null; echo "Purrtion process is running." ;;
  --logs|--telemetry) /usr/bin/open -n "$APP"; /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\"" ;;
  run) /usr/bin/open -n "$APP" ;;
esac
