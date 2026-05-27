import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let runtimeDir = NSString(string: "~/Library/Application Support/UniversalControlWatchdog").expandingTildeInPath
    private lazy var runtimeLog = "\(runtimeDir)/logs/universal-control-watchdog.log"
    private lazy var runtimeWatchdog = "\(runtimeDir)/universal-control-watchdog.zsh"
    private let watchdogLabel = "com.local.universal-control-watchdog"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installBundledWatchdog(showNotification: false)

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
        menu.addItem(NSMenuItem(title: "Install/Repair Watchdog", action: #selector(installWatchdogFromMenu), keyEquivalent: "i"))
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
            let output = self.runShell("/bin/zsh \(Self.shellQuote(self.runtimeWatchdog))")

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

    @objc private func installWatchdogFromMenu() {
        installBundledWatchdog(showNotification: true)
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

    private func installBundledWatchdog(showNotification: Bool) {
        DispatchQueue.global(qos: .utility).async {
            let result = self.installBundledWatchdogSync()
            if showNotification {
                DispatchQueue.main.async {
                    if result.status == 0 {
                        self.notify(title: "Watchdog installed", body: "Background monitoring is active.")
                    } else {
                        self.notify(title: "Watchdog install failed", body: result.output.isEmpty ? "Exit code \(result.status)." : result.output)
                    }
                }
            }
        }
    }

    private func installBundledWatchdogSync() -> (status: Int32, output: String) {
        guard let bundledScript = Bundle.main.url(forResource: "universal-control-watchdog", withExtension: "zsh") else {
            return (2, "Bundled watchdog script is missing.")
        }

        let fm = FileManager.default
        let logsDir = "\(runtimeDir)/logs"
        let launchAgentsDir = NSString(string: "~/Library/LaunchAgents").expandingTildeInPath
        let plistPath = "\(launchAgentsDir)/\(watchdogLabel).plist"

        do {
            try fm.createDirectory(atPath: logsDir, withIntermediateDirectories: true)
            try fm.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)

            if fm.fileExists(atPath: runtimeWatchdog) {
                try fm.removeItem(atPath: runtimeWatchdog)
            }
            try fm.copyItem(at: bundledScript, to: URL(fileURLWithPath: runtimeWatchdog))
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: runtimeWatchdog)

            let plist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
              "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>Label</key>
              <string>\(watchdogLabel)</string>
              <key>ProgramArguments</key>
              <array>
                <string>/bin/zsh</string>
                <string>\(Self.xmlEscape(runtimeWatchdog))</string>
              </array>
              <key>StartInterval</key>
              <integer>60</integer>
              <key>RunAtLoad</key>
              <true/>
              <key>StandardOutPath</key>
              <string>\(Self.xmlEscape(logsDir))/universal-control-watchdog.stdout.log</string>
              <key>StandardErrorPath</key>
              <string>\(Self.xmlEscape(logsDir))/universal-control-watchdog.stderr.log</string>
            </dict>
            </plist>
            """
            try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)

            _ = runProcess("/bin/launchctl", ["bootout", "gui/\(getuid())", plistPath])
            let bootstrap = runProcess("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistPath])
            if bootstrap.status != 0 && !bootstrap.output.contains("already bootstrapped") {
                return bootstrap
            }
            _ = runProcess("/bin/launchctl", ["enable", "gui/\(getuid())/\(watchdogLabel)"])
            return runProcess("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/\(watchdogLabel)"])
        } catch {
            return (1, error.localizedDescription)
        }
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

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
