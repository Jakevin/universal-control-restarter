# Universal Control Restarter

A small macOS utility for recovering flaky Universal Control connections.

It provides two pieces:

- A LaunchAgent watchdog that monitors Universal Control / Continuity symptoms and restarts the relevant local daemons when the connection appears stuck.
- A menu bar button for manually restarting Universal Control services when the pointer starts lagging or stops crossing devices.

This tool is intentionally local-only. It does not collect telemetry, send network requests, or require elevated privileges.

## Requirements

- macOS with Universal Control support
- Xcode command line tooling available through `xcrun swiftc`
- zsh

## Install

For end users, download `Universal-Control-Restarter.zip`, unzip it, move `Universal Control Restarter.app` to `/Applications`, and open it.

On first launch, the app installs or repairs the watchdog LaunchAgent automatically. The circular restart icon appears in the macOS menu bar.

Because this app is not notarized, macOS may show a Gatekeeper warning for downloaded builds. Open it from Finder with right click -> Open the first time.

For source installs, clone the repo, then run:

```zsh
zsh scripts/install-universal-control-watchdog.zsh
zsh scripts/install-universal-control-menubar.zsh
```

The watchdog is installed as:

```text
~/Library/LaunchAgents/com.local.universal-control-watchdog.plist
```

The menu bar app is installed as:

```text
~/Applications/Universal Control Restarter.app
~/Library/LaunchAgents/com.local.universal-control-restarter-menubar.plist
```

Logs are written to:

```text
~/Library/Application Support/UniversalControlWatchdog/logs/
```

## Build a Release App

```zsh
zsh scripts/build-release.zsh
```

This creates:

```text
dist/Universal Control Restarter.app
dist/Universal-Control-Restarter.zip
```

The app bundle includes the watchdog script in `Contents/Resources` and uses ad-hoc signing. It is suitable for local sharing, but not notarized for broad public distribution.

## Usage

After installation, a circular restart icon appears in the macOS menu bar.

Menu actions:

- `Restart Universal Control`: restarts `UniversalControl`, `sharingd`, `rapportd`, `SidecarRelay`, and `useractivityd`.
- `Run Watchdog Check`: runs one watchdog pass immediately.
- `Open Watchdog Log`: opens the watchdog log file.
- `Open Log Folder`: opens the log directory.

You can also trigger the watchdog manually:

```zsh
/bin/zsh "$HOME/Library/Application Support/UniversalControlWatchdog/universal-control-watchdog.zsh"
```

Or force a restart directly:

```zsh
killall UniversalControl sharingd rapportd SidecarRelay useractivityd 2>/dev/null
```

macOS will relaunch those services automatically.

## Watchdog Behavior

The watchdog runs every 60 seconds. It restarts the Continuity services when it sees:

- Missing Universal Control / Continuity daemons
- `clink:0`, `rdlink:0`, or `no data connection` in recent logs
- Rapport endpoint loss such as `Reachable -> Unreachable` or `Lost AWDL device`

It uses a 5 minute cooldown to avoid repeated restarts.

If recent logs show a healthy Universal Control connection, such as `Connected`, `ACCEPTED`, or `clink:[1-9]`, old failure logs are ignored.

## Uninstall

```zsh
zsh scripts/uninstall-universal-control-menubar.zsh
zsh scripts/uninstall-universal-control-watchdog.zsh
```

The uninstall scripts remove LaunchAgents and stop the menu bar process. Runtime logs remain under:

```text
~/Library/Application Support/UniversalControlWatchdog/
```

You can delete that folder manually if you no longer need logs.

## Notes

Universal Control relies on Bluetooth, AWDL, Wi-Fi P2P, Handoff, and local Apple daemons. This tool does not fix router interference, poor Bluetooth signal, iCloud account mismatch, or unsupported devices. It only automates the local restart path that often recovers a stuck or degraded Continuity session.

## License

MIT
