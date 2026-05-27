import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let runtimeLog = NSString(string: "~/Library/Application Support/UniversalControlWatchdog/logs/universal-control-watchdog.log").expandingTildeInPath

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "arrow.clockwise.circle", accessibilityDescription: "Restart Universal Control")
            } else {
                button.title = "UC"
            }
            button.toolTip = "Universal Control Restarter"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Restart Universal Control", action: #selector(restartUniversalControl), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Run Watchdog Check", action: #selector(runWatchdog), keyEquivalent: "w"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Watchdog Log", action: #selector(openWatchdogLog), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Open Log Folder", action: #selector(openLogFolder), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    @objc private func restartUniversalControl() {
        setIconBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let output = self.runShell("""
            killall UniversalControl sharingd rapportd SidecarRelay useractivityd 2>/dev/null || true
            sleep 3
            pgrep -x UniversalControl >/dev/null && pgrep -x sharingd >/dev/null && pgrep -x rapportd >/dev/null
            """)

            DispatchQueue.main.async {
                self.setIconBusy(false)
                if output.status == 0 {
                    self.notify(title: "Universal Control restarted", body: "Continuity services were restarted.")
                } else {
                    self.notify(title: "Restart finished with warnings", body: "One or more services did not report healthy yet.")
                }
            }
        }
    }

    @objc private func runWatchdog() {
        setIconBusy(true)
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSString(string: "~/Library/Application Support/UniversalControlWatchdog/universal-control-watchdog.zsh").expandingTildeInPath
            let output = self.runShell("/bin/zsh \(Self.shellQuote(script))")

            DispatchQueue.main.async {
                self.setIconBusy(false)
                if output.status == 0 {
                    self.notify(title: "Watchdog check complete", body: "No launch errors were reported.")
                } else {
                    self.notify(title: "Watchdog check failed", body: "Exit code \(output.status).")
                }
            }
        }
    }

    @objc private func openWatchdogLog() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: runtimeLog) {
            fm.createFile(atPath: runtimeLog, contents: nil)
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: runtimeLog))
    }

    @objc private func openLogFolder() {
        NSWorkspace.shared.open(URL(fileURLWithPath: (runtimeLog as NSString).deletingLastPathComponent))
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setIconBusy(_ busy: Bool) {
        guard let button = statusItem.button else { return }
        if #available(macOS 11.0, *) {
            button.image = NSImage(systemSymbolName: busy ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise.circle", accessibilityDescription: "Restart Universal Control")
        } else {
            button.title = busy ? "..." : "UC"
        }
    }

    private func notify(title: String, body: String) {
        let script = "display notification \(Self.appleScriptQuote(body)) with title \(Self.appleScriptQuote(title))"
        _ = runProcess("/usr/bin/osascript", ["-e", script])
    }

    private func runShell(_ command: String) -> (status: Int32, output: String) {
        runProcess("/bin/zsh", ["-lc", command])
    }

    private func runProcess(_ launchPath: String, _ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return (process.terminationStatus, String(data: data, encoding: .utf8) ?? "")
        } catch {
            return (127, error.localizedDescription)
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
