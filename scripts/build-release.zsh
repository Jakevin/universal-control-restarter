#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BASE_DIR="${SCRIPT_DIR:h}"
DIST_DIR="$BASE_DIR/dist"
APP_DIR="$DIST_DIR/Universal Control Restarter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ZIP_PATH="$DIST_DIR/Universal-Control-Restarter.zip"

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

xcrun swiftc "$BASE_DIR/menubar/UniversalControlRestarter.swift" \
  -framework AppKit \
  -o "$MACOS_DIR/UniversalControlRestarter"

cp "$BASE_DIR/scripts/universal-control-watchdog.zsh" "$RESOURCES_DIR/universal-control-watchdog.zsh"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>UniversalControlRestarter</string>
  <key>CFBundleIdentifier</key>
  <string>com.local.universal-control-restarter-menubar</string>
  <key>CFBundleName</key>
  <string>Universal Control Restarter</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/UniversalControlRestarter"
chmod +x "$RESOURCES_DIR/universal-control-watchdog.zsh"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

ditto -c -k --keepParent --norsrc "$APP_DIR" "$ZIP_PATH"

echo "Built $APP_DIR"
echo "Created $ZIP_PATH"
