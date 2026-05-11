import Foundation
import Observation
import Darwin

/// Downloads the RAR CLI directly from RARLAB and installs the `rar` binary
/// into `~/Library/Application Support/MacRAR/bin/rar`.
///
/// Legal note: RARLAB's EULA permits redistribution of the unmodified RAR
/// installation package, but forbids bundling inside another software package.
/// This installer fetches the original archive from rarlab.com at runtime —
/// the user is the recipient of RARLAB's distribution, the app is the courier.
@MainActor
@Observable
public final class RarAutoInstaller {
    public enum Phase: Sendable, Equatable {
        case idle
        case downloading(received: Int64, total: Int64?)
        case extracting
        case installing
        case done
        case failed(message: String)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var lastDownloadURL: URL?

    public init() {}

    public var isRunning: Bool {
        switch phase {
        case .idle, .done, .failed: return false
        default: return true
        }
    }

    /// Runs the full download → extract → install pipeline. Caller may await.
    public func install() async {
        guard !isRunning else { return }
        do {
            let url = downloadURL()
            lastDownloadURL = url
            let archive = try await download(from: url)
            phase = .extracting
            let extracted = try extractTarball(at: archive)
            phase = .installing
            try copyRarBinary(from: extracted)
            phase = .done
        } catch let err as CancellationError {
            _ = err
            phase = .failed(message: "Cancelled")
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    /// Picks the RARLAB tarball URL matching the host architecture.
    /// RARLAB uses `rarmacos-arm-NNN.tar.gz` and `rarmacos-x64-NNN.tar.gz`.
    public func downloadURL() -> URL {
        let arch = hostArchitecture()
        let file = (arch == "arm64") ? "rarmacos-arm-722.tar.gz" : "rarmacos-x64-722.tar.gz"
        return URL(string: "https://www.rarlab.com/rar/\(file)")!
    }

    private func hostArchitecture() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &buf, &size, nil, 0)
        let s = String(cString: buf)
        return s.hasPrefix("arm") ? "arm64" : "x86_64"
    }

    // MARK: - Pipeline steps

    private func download(from url: URL) async throws -> URL {
        phase = .downloading(received: 0, total: nil)

        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        let total = response.expectedContentLength
        let dest = FileManager.default.temporaryDirectory
            .appendingPathComponent("macrar-rar-\(UUID().uuidString).tar.gz")
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: dest) else {
            throw NSError(domain: "MacRARAutoInstaller", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create temp file"
            ])
        }
        defer { try? handle.close() }

        var received: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                received += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                phase = .downloading(received: received, total: total > 0 ? total : nil)
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            received += Int64(buffer.count)
            phase = .downloading(received: received, total: total > 0 ? total : nil)
        }
        return dest
    }

    private func extractTarball(at tarball: URL) throws -> URL {
        let workDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("macrar-rar-extract-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", tarball.path, "-C", workDir.path]
        let err = Pipe()
        tar.standardError = err
        try tar.run()
        tar.waitUntilExit()
        guard tar.terminationStatus == 0 else {
            let stderr = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "MacRARAutoInstaller", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "tar exited \(tar.terminationStatus): \(stderr)"
            ])
        }
        // Cleanup tarball
        try? FileManager.default.removeItem(at: tarball)
        return workDir
    }

    private func copyRarBinary(from extractedRoot: URL) throws {
        // RARLAB layout: <root>/rar/rar (and unrar, license, etc.)
        let candidates = [
            extractedRoot.appendingPathComponent("rar/rar"),
            extractedRoot.appendingPathComponent("rar"),
        ]
        guard let src = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) else {
            throw NSError(domain: "MacRARAutoInstaller", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Extracted archive did not contain a rar binary"
            ])
        }

        let dest = RarInstaller.managedPath
        try FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: src, to: dest)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: dest.path
        )

        // Cleanup work dir
        try? FileManager.default.removeItem(at: extractedRoot)
    }
}

public extension RarAutoInstaller.Phase {
    var progressFraction: Double? {
        if case .downloading(let received, let total?) = self, total > 0 {
            return Double(received) / Double(total)
        }
        return nil
    }

    var displayMessage: String {
        switch self {
        case .idle: return "Ready"
        case .downloading(let r, let t):
            if let t {
                return "Downloading \(ByteCountFormatter.string(fromByteCount: r, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: t, countStyle: .file))"
            }
            return "Downloading \(ByteCountFormatter.string(fromByteCount: r, countStyle: .file))"
        case .extracting: return "Extracting archive…"
        case .installing: return "Installing rar binary…"
        case .done: return "Installed successfully"
        case .failed(let m): return m
        }
    }
}
