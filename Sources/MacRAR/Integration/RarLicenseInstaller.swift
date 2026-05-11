import Foundation

/// Installs a user-supplied `rarreg.key` to `~/.rar/rarreg.key` (where `rar` looks for it).
public enum RarLicenseInstaller {
    public enum InstallError: LocalizedError {
        case invalidFile
        public var errorDescription: String? { "The selected file is not a valid rarreg.key." }
    }

    public static var installLocation: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".rar/rarreg.key")
    }

    public static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: installLocation.path)
    }

    public static func install(from src: URL) throws {
        let raw = try Data(contentsOf: src)
        let text = String(data: raw, encoding: .ascii) ?? ""
        guard text.hasPrefix("RAR registration data") else { throw InstallError.invalidFile }

        // Normalise line endings to LF — keys often originate from Windows
        // (CRLF) but the macOS `rar` binary's key parser requires LF-only.
        // Without this, valid keys may be rejected and the trial banner persists.
        let normalised = text.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")
        let data = Data(normalised.utf8)

        try FileManager.default.createDirectory(
            at: installLocation.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: installLocation, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: installLocation.path
        )
    }

    public static func uninstall() throws {
        if FileManager.default.fileExists(atPath: installLocation.path) {
            try FileManager.default.removeItem(at: installLocation)
        }
    }
}
