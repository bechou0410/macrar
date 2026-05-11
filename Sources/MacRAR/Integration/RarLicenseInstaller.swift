import Foundation

/// Installs a user-supplied `rarreg.key` to where RAR 7.x for macOS looks
/// for it: `~/.config/rar/rarreg.key` (XDG_CONFIG_HOME convention).
///
/// Older RAR versions used `~/.rar/rarreg.key` so we still check + clean
/// that legacy location for backwards compatibility.
public enum RarLicenseInstaller {
    public enum InstallError: LocalizedError {
        case invalidFile
        public var errorDescription: String? { "The selected file is not a valid rarreg.key." }
    }

    /// All paths RAR 7.x may read keys from. Order matters: first is canonical.
    public static var searchPaths: [URL] {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return [
            home.appendingPathComponent(".config/rar/rarreg.key"), // RAR 7.x default
            home.appendingPathComponent(".rar/rarreg.key"),         // RAR 6.x legacy
        ]
    }

    /// Canonical install location (used by `install`).
    public static var installLocation: URL { searchPaths[0] }

    /// True if a key is present at ANY known location.
    public static func isInstalled() -> Bool {
        searchPaths.contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    public static func install(from src: URL) throws {
        let raw = try Data(contentsOf: src)
        let text = String(data: raw, encoding: .ascii) ?? ""
        guard text.hasPrefix("RAR registration data") else { throw InstallError.invalidFile }

        // Strip CRLF — Windows-origin keys get rejected by the macOS rar
        // parser if line terminators aren't LF-only.
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")
        let data = Data(normalised.utf8)

        // Write to the canonical RAR 7.x location.
        let dest = installLocation
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: dest, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: dest.path
        )

        // Also clear any stale legacy key at ~/.rar/rarreg.key so the user
        // doesn't end up with two divergent keys.
        for legacy in searchPaths.dropFirst() {
            try? FileManager.default.removeItem(at: legacy)
        }
    }

    /// Removes the key from EVERY known location — fixes the "Remove License
    /// doesn't actually remove it" bug where MacRAR only cleared one path
    /// but RAR continued reading from another.
    public static func uninstall() throws {
        var lastError: Error?
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                do {
                    try FileManager.default.removeItem(at: path)
                } catch {
                    lastError = error
                }
            }
        }
        if let error = lastError { throw error }
    }
}
