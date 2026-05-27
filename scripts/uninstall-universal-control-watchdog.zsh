#!/bin/zsh
set -euo pipefail

LABEL="com.local.universal-control-watchdog"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"
RUNTIME_DIR="$HOME/Library/Application Support/UniversalControlWatchdog"

launchctl bootout "gui/$(id -u)" "$PLIST_DST" 2>/dev/null || true
rm -f "$PLIST_DST"

echo "Uninstalled $LABEL"
echo "Runtime files remain at $RUNTIME_DIR"
