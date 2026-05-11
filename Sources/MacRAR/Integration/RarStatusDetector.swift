import Foundation
import Observation
import RarKit

/// Observable wrapper that detects whether `rar` is installed and its license state.
@MainActor
@Observable
public final class RarStatusDetector {
    public enum LicenseState: Equatable, Sendable {
        case trial
        case registered(owner: String)
        case unknown
        case notInstalled
    }

    public private(set) var binaryPath: URL?
    public private(set) var version: String?
    public private(set) var licenseState: LicenseState = .notInstalled
    public private(set) var lastDetectedAt: Date?

    public init() {}

    public func detect(using runner: RarRunner) async {
        // Re-scan PATH so newly installed rar (post-launch) is picked up.
        guard let rarURL = BinaryLocator.locateRar() ?? runner.rarURL else {
            binaryPath = nil
            version = nil
            licenseState = .notInstalled
            lastDetectedAt = .now
            return
        }
        binaryPath = rarURL

        // Run `rar` with no args — prints banner with version + license state.
        let process = Process()
        process.executableURL = rarURL
        process.arguments = []
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let text = String(data: data, encoding: .utf8) ?? ""
            self.version = extractVersion(text)
            self.licenseState = detectLicense(text)
        } catch {
            self.version = nil
            self.licenseState = .unknown
        }
        lastDetectedAt = .now
    }

    private func extractVersion(_ banner: String) -> String? {
        // Line 0: "RAR 7.22   Copyright (c) ..."
        guard let firstLine = banner.split(separator: "\n").first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "RAR" else { return nil }
        return String(parts[1])
    }

    private func detectLicense(_ banner: String) -> LicenseState {
        let lines = banner.split(separator: "\n").map { String($0) }
        if lines.contains(where: { $0.contains("Trial version") }) {
            return .trial
        }
        for line in lines {
            if line.lowercased().contains("registered to") {
                let parts = line.components(separatedBy: ":")
                if parts.count >= 2 {
                    return .registered(owner: parts[1].trimmingCharacters(in: .whitespaces))
                }
            }
        }
        return .unknown
    }
}

