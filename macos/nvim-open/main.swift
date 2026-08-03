// nvim-open opens files in nvim from outside the terminal: Finder, or something
// you just downloaded.
//
// It is one binary wearing two hats:
//
//   1. A CLI: `nvim-open file...` handles the paths in argv and exits. No
//      NSApplication is started on this path, so it stays cheap.
//   2. The executable inside "Open in Neovim.app". macOS only hands files to
//      .app bundles, and it delivers them as an Apple Event
//      (kAEOpenDocuments) - never as argv. Measured: a bundled binary that
//      merely reads argv sees argc=0. Receiving that event is why this is
//      Swift/AppKit rather than the Go used elsewhere in this repo; doing it
//      here rather than in an AppleScript applet that shells out saves ~154ms
//      of OSA runtime and one process hop.
//
// Files land in a new tmux window in the session last used, since that is where
// the rest of the work lives and a tmux window is resurrect-able.

import AppKit
import Foundation

let version = "1.0"

let usage = """
nvim-open - open files in nvim from Finder or the shell

Usage:
  nvim-open <file>...   open the files as tabs in a new tmux window
  nvim-open --full <file>...
                        use the full Neovim config instead of the peek profile
  nvim-open --help
  nvim-open --version

Also the executable inside ~/Applications/Open in Neovim.app, which is what
lets Finder and browsers hand files over. Point extensions at it with
macos/scripts/register-file-handlers.sh.
"""

// MARK: - Opening

enum Profile: String {
    // A peek at a file does not need LSP, treesitter or completion. Measured:
    // 30ms for a bare config against ~150ms for the full one.
    case peek
    case full

    var appName: String? { self == .peek ? "peek" : nil }
}

struct Opener {
    let profile: Profile

    func open(paths: [String]) {
        let files = existing(paths)
        let targets = files.isEmpty ? [homeDirectory()] : files

        if let session = activeTmuxSession() {
            newTmuxWindow(session: session, files: targets)
        } else {
            launchGhostty(files: targets)
        }

        // Without this the file opens behind whatever you clicked from.
        _ = run("/usr/bin/open", ["-a", "Ghostty"])
    }

    /// Drops paths for files that have since moved, so one stale entry in a
    /// multi-file selection cannot stop the rest from opening.
    private func existing(_ paths: [String]) -> [String] {
        paths
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    private func homeDirectory() -> String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// The session last looked at is the one a new window should appear in.
    /// Resolved explicitly rather than letting tmux default to "current
    /// session", which is ambiguous when invoked with no attached client.
    private func activeTmuxSession() -> String? {
        guard let out = run("/opt/homebrew/bin/tmux",
                            ["list-sessions", "-F", "#{session_last_attached} #{session_name}"]),
              !out.isEmpty else { return nil }

        var best: (stamp: Int, name: String)?
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let stamp = Int(parts[0]) else { continue }
            let name = String(parts[1])
            if best == nil || stamp > best!.stamp {
                best = (stamp, name)
            }
        }
        return best?.name
    }

    private func newTmuxWindow(session: String, files: [String]) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: files[0], isDirectory: &isDirectory)
        // Start in the file's directory so relative paths and :Explore behave.
        let cwd = isDirectory.boolValue ? files[0] : (files[0] as NSString).deletingLastPathComponent

        // "=name:" and not plain "name": a bare target is read as a window
        // index when the session is named numerically, so with a session called
        // "0" this created a window AT index 0 and then failed with "index 0 in
        // use" on every later open. The "=" forbids prefix-matching a different
        // session, the ":" says session rather than window.
        //
        // No -d: creating the window also selects it, which is the point.
        _ = run("/opt/homebrew/bin/tmux",
                ["new-window", "-t", "=\(session):", "-c", cwd,
                 "-n", windowName(files: files), shellCommand(files: files)])
    }

    /// The window name is the file you are looking at, since "nvim" says nothing
    /// when three of these are open. `allow-rename off` in .tmux.conf stops
    /// programs renaming windows later, but a name given at creation sticks.
    private func windowName(files: [String]) -> String {
        var name = (files[0] as NSString).lastPathComponent
        if name.isEmpty {
            name = "nvim"
        }

        // The status line is shared with every other window, so keep it short.
        let limit = 20
        if name.count > limit {
            name = String(name.prefix(limit - 1)) + "…"
        }

        if files.count > 1 {
            name += " +\(files.count - 1)"
        }
        return name
    }

    private func launchGhostty(files: [String]) {
        var args = ["-na", "Ghostty.app", "--args", "-e"]
        args.append(contentsOf: nvimArgv(files: files))
        _ = run("/usr/bin/open", args)
    }

    private func nvimArgv(files: [String]) -> [String] {
        var argv: [String] = []
        if let appName = profile.appName {
            // env, because tmux and `open -e` both take a command, not a shell.
            argv += ["/usr/bin/env", "NVIM_APPNAME=\(appName)"]
        }
        // Tabs rather than a window each: a multi-file selection should not
        // bury the rest of the session.
        argv += ["nvim", "-p", "--"]
        argv += files
        return argv
    }

    /// tmux runs its command through `sh -c`, so the parts need quoting.
    private func shellCommand(files: [String]) -> String {
        nvimArgv(files: files).map(quote).joined(separator: " ")
    }

    private func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Process helpers

/// Runs a command and returns its trimmed stdout, or nil if it could not run or
/// exited non-zero.
@discardableResult
func run(_ launchPath: String, _ arguments: [String]) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice

    // Launched from LaunchServices, PATH is the bare minimum
    // (/usr/bin:/bin:/usr/sbin:/sbin) and neither nvim nor tmux would be found.
    var env = ProcessInfo.processInfo.environment
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:"
        + (env["PATH"] ?? "/usr/bin:/bin")
    process.environment = env

    do {
        try process.run()
    } catch {
        notify("could not run \(launchPath): \(error.localizedDescription)")
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }

    return String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Started from Finder there is no terminal to print to, so a silent failure
/// would just look like a broken double-click.
func notify(_ message: String) {
    let script = "display notification \"\(message)\" with title \"nvim-open\""
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    try? process.run()
    process.waitUntilExit()
}

// MARK: - Apple Event mode

/// Only used when running inside the .app bundle: waits for the open event,
/// handles it, and quits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let opener: Opener
    private var handled = false

    init(opener: Opener) {
        self.opener = opener
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        handled = true
        opener.open(paths: filenames)
        sender.reply(toOpenOrPrint: .success)
        exit(0)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launched with no document (Spotlight, or a stray double-click on the
        // app itself). The event, if any, arrives right after launch, so give it
        // a moment before falling back to a bare editor.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.handled else { return }
            self.opener.open(paths: [])
            exit(0)
        }
    }
}

// MARK: - Entry point

var arguments = Array(CommandLine.arguments.dropFirst())
var profile = Profile.peek

if arguments.first == "--help" || arguments.first == "-h" {
    print(usage)
    exit(0)
}
if arguments.first == "--version" {
    print("nvim-open \(version)")
    exit(0)
}
if let index = arguments.firstIndex(of: "--full") {
    profile = .full
    arguments.remove(at: index)
}
if let bad = arguments.first(where: { $0.hasPrefix("--") }) {
    FileHandle.standardError.write("nvim-open: unknown option: \(bad)\n".data(using: .utf8)!)
    exit(1)
}

let opener = Opener(profile: profile)

if arguments.isEmpty && Bundle.main.bundleIdentifier == "com.tktk2o.open-in-neovim" {
    // Bundle with no argv: the paths are coming as an Apple Event.
    let app = NSApplication.shared
    let delegate = AppDelegate(opener: opener)
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
} else {
    opener.open(paths: arguments)
}
