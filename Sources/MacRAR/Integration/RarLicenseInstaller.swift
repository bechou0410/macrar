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

    // MARK: - Inspection

    /// Parsed info from a rarreg.key file.
    public struct LicenseInfo: Sendable, Equatable {
        public let owner: String
        public let licenseType: String
        public let uid: String
        /// Best-effort decode of the first 4 bytes of UID as a UNIX timestamp.
        /// Nil when the value is implausible (outside 2000-01-01…now+1y).
        public let purchaseDate: Date?
    }

    /// Returns parsed info from whichever known key location has a file.
    public static func readInstalledInfo() -> LicenseInfo? {
        for path in searchPaths {
            if let info = try? read(from: path) { return info }
        }
        return nil
    }

    /// Parse a rarreg.key file. Throws `InstallError.invalidFile` on bad header.
    public static func read(from url: URL) throws -> LicenseInfo {
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .ascii) ?? ""
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard lines.first == "RAR registration data" else {
            throw InstallError.invalidFile
        }

        let owner = lines.dropFirst().first(where: { !$0.isEmpty }) ?? ""
        // License type is the second non-empty line after the header.
        let nonHeader = lines.dropFirst().filter { !$0.isEmpty }
        let licenseType = nonHeader.count > 1 ? nonHeader[1] : ""

        // UID line: `UID=<hex>`
        let uidLine = lines.first(where: { $0.hasPrefix("UID=") }) ?? ""
        let uid = String(uidLine.dropFirst(4))

        return LicenseInfo(
            owner: owner,
            licenseType: licenseType,
            uid: uid,
            purchaseDate: decodeUIDTimestamp(uid)
        )
    }

    /// Decode the first 4 hex bytes of the UID as a UNIX timestamp.
    /// Returns nil if the result is outside the plausibility window —
    /// avoids misleading users when the UID encoding format isn't a timestamp.
    private static func decodeUIDTimestamp(_ uid: String) -> Date? {
        guard uid.count >= 8 else { return nil }
        let hexPrefix = String(uid.prefix(8))
        guard let seconds = UInt32(hexPrefix, radix: 16) else { return nil }
        let date = Date(timeIntervalSince1970: TimeInterval(seconds))
        // Plausibility: between RAR's commercial era (~2000) and now + 1 year.
        let lower = Date(timeIntervalSince1970: 946_684_800) // 2000-01-01
        let upper = Date().addingTimeInterval(365 * 86400)
        guard date >= lower && date <= upper else { return nil }
        return date
    }
}
