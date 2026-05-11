import Foundation
import AppKit

/// Runs once on first launch to perform the same setup that `Install.command`
/// used to do — eliminating the need for any manual user step beyond the
/// initial "right-click → Open" Gatekeeper bypass.
///
/// Tasks performed:
///   1. Strip our own `com.apple.quarantine` xattr (we're past Gatekeeper if running).
///   2. Force-register with Launch Services so file associations work everywhere.
///   3. Refresh `pbs` and pre-enable our Services menu items in `NSServicesStatus`.
///
/// Subsequent launches detect the sentinel UserDefault and skip.
@MainActor
enum FirstRunBootstrapper {
    private static let bootstrapKey = "MacRARBootstrapDone-v2"
    private static let bundleID = "com.bechou.winrar"

    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: bootstrapKey) else { return }

        Task.detached(priority: .background) {
            await performBootstrap()
            await MainActor.run {
                UserDefaults.standard.set(true, forKey: bootstrapKey)
            }
        }
    }

    /// Force-rerun, e.g. from "Repair Setup" menu item.
    static func forceRun() {
        UserDefaults.standard.removeObject(forKey: bootstrapKey)
        runIfNeeded()
    }

    private static func performBootstrap() async {
        let appPath = Bundle.main.bundleURL.path

        // 1. Strip our own quarantine flag (we're past Gatekeeper at this point).
        runTool("/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", appPath])

        // 2. Re-register with Launch Services. Makes file associations + Services
        //    discoverable without the user opening System Settings.
        let lsregister = "/System/Library/Frameworks/CoreServices.framework"
                      + "/Frameworks/LaunchServices.framework/Support/lsregister"
        runTool(lsregister, args: ["-f", "-R", "-trusted", appPath])

        // 3. Refresh Services + enable our entries in pbs.
        runTool("/System/Library/CoreServices/pbs", args: ["-update"])
        try? await Task.sleep(for: .milliseconds(500))

        enableOurServicesInPbsPlist()

        // 4. Restart pbs + Finder so the Services menu picks up changes immediately.
        runTool("/usr/bin/killall", args: ["pbs"])
        runTool("/usr/bin/killall", args: ["Finder"])
    }

    /// Adds our two services to `~/Library/Preferences/pbs.plist`'s
    /// `NSServicesStatus` dict with `enabled_context_menu` + `enabled_services_menu`
    /// both set, so the user doesn't have to enable them in System Settings.
    private static func enableOurServicesInPbsPlist() {
        let entries: [(label: String, selector: String)] = [
            ("Compress with MacRAR…", "compressService"),
            ("Extract with MacRAR",    "extractService"),
        ]
        for entry in entries {
            let key = "\(bundleID) - \(entry.label) - \(entry.selector)"
            // Use `defaults` CLI to avoid touching plist files directly; respects
            // pbs's running state and serialization format.
            runTool("/usr/bin/defaults", args: [
                "write", "pbs", "NSServicesStatus",
                "-dict-add", key,
                "{\"enabled_context_menu\" = 1; \"enabled_services_menu\" = 1;}"
            ])
        }
    }

    @discardableResult
    private static func runTool(_ path: String, args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        do {
            try p.run()
            p.waitUntilExit()
            return p.terminationStatus
        } catch {
            return -1
        }
    }
}
