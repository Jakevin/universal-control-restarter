#!/bin/zsh
set -euo pipefail

LABEL="com.local.universal-control-restarter-menubar"
SCRIPT_DIR="${0:A:h}"
BASE_DIR="${SCRIPT_DIR:h}"
APP_DIR="$HOME/Applications/Universal Control Restarter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
RUNTIME_DIR="$HOME/Library/Application Support/UniversalControlWatchdog"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$HOME/Library/LaunchAgents" "$RUNTIME_DIR/logs"

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

cat > "$PLIST_DST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>$MACOS_DIR/UniversalControlRestarter</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <false/>

  <key>StandardOutPath</key>
  <string>$RUNTIME_DIR/logs/menubar.stdout.log</string>

  <key>StandardErrorPath</key>
  <string>$RUNTIME_DIR/logs/menubar.stderr.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST_DST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed and started $LABEL"
echo "App: $APP_DIR"
