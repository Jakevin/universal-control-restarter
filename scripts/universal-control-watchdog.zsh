#!/bin/zsh
set -u

BASE_DIR="$HOME/Library/Application Support/UniversalControlWatchdog"
LOG_DIR="$BASE_DIR/logs"
STATE_FILE="$LOG_DIR/universal-control-watchdog.state"
WATCHDOG_LOG="$LOG_DIR/universal-control-watchdog.log"
LOCK_DIR="/tmp/universal-control-watchdog.lock"
COOLDOWN_SECONDS=300

mkdir -p "$LOG_DIR"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S %z"
}

log_msg() {
  printf "%s %s\n" "$(timestamp)" "$*" >> "$WATCHDOG_LOG"
}

cleanup() {
  rmdir "$LOCK_DIR" 2>/dev/null || true
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap cleanup EXIT

now="$(date +%s)"
last_restart=0
if [[ -r "$STATE_FILE" ]]; then
  last_restart="$(cat "$STATE_FILE" 2>/dev/null || printf "0")"
fi

missing=()
for proc in UniversalControl sharingd rapportd SidecarRelay useractivityd bluetoothd; do
  if ! pgrep -x "$proc" >/dev/null 2>&1; then
    missing+=("$proc")
  fi
done

predicate='process == "UniversalControl" OR process == "rapportd" OR process == "sharingd" OR eventMessage CONTAINS[c] "AWDLStateDump" OR eventMessage CONTAINS[c] "CLink" OR eventMessage CONTAINS[c] "RemoteDisplay"'
recent_log="$(log show --last 2m --style compact --predicate "$predicate" 2>/dev/null | tail -220)"

bad_patterns=()
has_recent_connection=0
if printf "%s" "$recent_log" | grep -Eq 'UniversalControl.*Connected|UniversalControl.*ACCEPTED|clink:[1-9]'; then
  has_recent_connection=1
fi

if (( has_recent_connection == 0 )) && printf "%s" "$recent_log" | grep -Eq 'clink:0|rdlink:0|no data connection|AWDL enabled with no data connection'; then
  bad_patterns+=("awdl_no_data_connection")
fi
if (( has_recent_connection == 0 )) && printf "%s" "$recent_log" | grep -Eq 'Endpoint state changed: .*: Unreachable|Reachable -> Unreachable|Lost AWDL device'; then
  bad_patterns+=("rapport_endpoint_lost")
fi

if (( ${#missing[@]} == 0 && ${#bad_patterns[@]} == 0 )); then
  exit 0
fi

age=$(( now - last_restart ))
if (( age < COOLDOWN_SECONDS )); then
  log_msg "detected issue but skipped restart during cooldown (${age}s/${COOLDOWN_SECONDS}s): missing=${missing[*]:-none} patterns=${bad_patterns[*]:-none}"
  exit 0
fi

log_msg "restarting continuity services: missing=${missing[*]:-none} patterns=${bad_patterns[*]:-none}"
killall UniversalControl sharingd rapportd SidecarRelay useractivityd 2>/dev/null || true
sleep 3

for proc in UniversalControl sharingd rapportd SidecarRelay useractivityd bluetoothd; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    log_msg "process ok: $proc"
  else
    log_msg "process still missing: $proc"
  fi
done

date +%s > "$STATE_FILE"
