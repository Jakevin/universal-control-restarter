#!/bin/zsh
set -euo pipefail

LABEL="com.local.universal-control-restarter-menubar"
PLIST_DST="$HOME/Library/LaunchAgents/$LABEL.plist"

launchctl bootout "gui/$(id -u)" "$PLIST_DST" 2>/dev/null || true
rm -f "$PLIST_DST"
pkill -x UniversalControlRestarter 2>/dev/null || true

echo "Uninstalled $LABEL"
