import Foundation

/// Resolves paths to bundled `unrar` (required) and external `rar` (optional, user-installed).
///
/// `rar` is NOT bundled (RAR EULA forbids redistribution of the commercial RAR
/// binary inside another software package). Users must install it themselves
/// via `brew install rar` or by downloading from rarlab.com.
public struct BinaryLocator: Sendable, Equatable {
    public let unrarURL: URL
    public let rarURL: URL?

    public init(unrarURL: URL, rarURL: URL?) {
        self.unrarURL = unrarURL
        self.rarURL = rarURL
    }

    public var rarAvailable: Bool { rarURL != nil }

    /// Resolve bundled unrar from the running app bundle's `Contents/Helpers/MacOS/`,
    /// plus rar from common install locations and $PATH.
    public static func resolve(in bundle: Bundle = .main) throws -> BinaryLocator {
        let helpers = bundle.bundleURL
            .appendingPathComponent("Contents/Helpers/MacOS", isDirectory: true)
        let unrar = helpers.appendingPathComponent("unrar")
        guard FileManager.default.isExecutableFile(atPath: unrar.path) else {
            throw RarError.unrarMissing
        }
        return BinaryLocator(unrarURL: unrar, rarURL: locateRar())
    }

    /// For unit tests: build a locator from explicit URLs.
    public static func custom(unrarURL: URL, rarURL: URL? = nil) -> BinaryLocator {
        BinaryLocator(unrarURL: unrarURL, rarURL: rarURL)
    }

    /// Re-run the rar lookup (e.g. after user installs via Homebrew without app restart).
    public func refreshingRar() -> BinaryLocator {
        BinaryLocator(unrarURL: unrarURL, rarURL: Self.locateRar())
    }

    // MARK: - rar lookup

    private static let rarSearchPaths: [String] = [
        "/opt/homebrew/bin/rar",
        "/usr/local/bin/rar",
        "/usr/bin/rar",
        NSHomeDirectory() + "/Library/Application Support/MacRAR/bin/rar",
        NSHomeDirectory() + "/.local/bin/rar",
    ]

    /// Look up `rar` in known install locations + $PATH.
    /// Returns nil when not found — callers should surface `RarError.rarMissing`.
    public static func locateRar() -> URL? {
        let fm = FileManager.default

        for path in rarSearchPaths {
            if fm.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            for dir in pathEnv.split(separator: ":") {
                let candidate = "\(dir)/rar"
                if fm.isExecutableFile(atPath: candidate) {
                    return URL(fileURLWithPath: candidate)
                }
            }
        }

        return nil
    }
}
