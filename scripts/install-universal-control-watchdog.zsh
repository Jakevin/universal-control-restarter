#!/bin/zsh
set -euo pipefail

LABEL="com.local.universal-control-watchdog"
SCRIPT_DIR="${0:A:h}"
BASE_DIR="${SCRIPT_DIR:h}"
RUNTIME_DIR="$HOME/Library/Application Support/UniversalControlWatchdog"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$RUNTIME_DIR/logs"
chmod +x "$BASE_DIR/scripts/universal-control-watchdog.zsh"
cp "$BASE_DIR/scripts/universal-control-watchdog.zsh" "$RUNTIME_DIR/universal-control-watchdog.zsh"
chmod +x "$RUNTIME_DIR/universal-control-watchdog.zsh"

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
    <string>/bin/zsh</string>
    <string>$RUNTIME_DIR/universal-control-watchdog.zsh</string>
  </array>

  <key>StartInterval</key>
  <integer>60</integer>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$RUNTIME_DIR/logs/universal-control-watchdog.stdout.log</string>

  <key>StandardErrorPath</key>
  <string>$RUNTIME_DIR/logs/universal-control-watchdog.stderr.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "$PLIST_DST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Installed and started $LABEL"
echo "Log: $RUNTIME_DIR/logs/universal-control-watchdog.log"
