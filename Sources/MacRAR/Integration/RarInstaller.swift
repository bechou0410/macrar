import Foundation

/// Copies a user-supplied `rar` binary into the app's managed location.
public enum RarInstaller {
    public enum InstallError: LocalizedError {
        case notExecutable
        case wrongBinary
        case copyFailed(String)
        public var errorDescription: String? {
            switch self {
            case .notExecutable:    "The selected file is not executable."
            case .wrongBinary:      "The selected file does not look like the RAR CLI tool."
            case .copyFailed(let s): "Copy failed: \(s)"
            }
        }
    }

    public static var managedPath: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/MacRAR/bin/rar")
    }

    public static func install(from src: URL) throws {
        let attrs = (try? FileManager.default.attributesOfItem(atPath: src.path)) ?? [:]
        let perms = (attrs[.posixPermissions] as? Int) ?? 0
        guard perms & 0o100 != 0 else { throw InstallError.notExecutable }

        // Validate by spawning with no args and checking banner contains "RAR"
        let process = Process()
        process.executableURL = src
        process.arguments = []
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        let banner = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard banner.contains("RAR") else { throw InstallError.wrongBinary }

        try FileManager.default.createDirectory(
            at: managedPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: managedPath.path) {
            try FileManager.default.removeItem(at: managedPath)
        }
        do {
            try FileManager.default.copyItem(at: src, to: managedPath)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: managedPath.path
            )
        } catch {
            throw InstallError.copyFailed(error.localizedDescription)
        }
    }
}
