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
        let data = try Data(contentsOf: src)
        let text = String(data: data, encoding: .ascii) ?? ""
        guard text.hasPrefix("RAR registration data") else { throw InstallError.invalidFile }
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
