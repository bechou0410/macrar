import Foundation

/// Dispatches archive listing to the right backend based on file format:
///   - `.rar` / `.sfx`  → bundled `unrar`
///   - `.zip`            → system `/usr/bin/unzip`
///   - `.tar*` / `.gz` (tar-compressed) → system `/usr/bin/tar`
///   - other formats throw `RarError.userError`
public struct ArchiveLister: Sendable {
    public let bundledUnrar: URL?

    public init(bundledUnrar: URL?) {
        self.bundledUnrar = bundledUnrar
    }

    public func list(_ archive: URL, password: String? = nil) async throws -> [ArchiveEntry] {
        let format = ArchiveFormat.detect(from: archive)
        switch format {
        case .rar, .sfx:
            guard let unrar = bundledUnrar else { throw RarError.unrarMissing }
            return try await listRar(archive, password: password, unrar: unrar)
        case .zip:
            return try await listZip(archive, password: password)
        case .tar, .tarGz, .tarBz2:
            return try await listTar(archive)
        case .gz, .bz2:
            // Single-file gzip/bzip2 — synthesize a single entry from the wrapper filename.
            let name = archive.deletingPathExtension().lastPathComponent
            let size = (try? FileManager.default.attributesOfItem(atPath: archive.path)[.size] as? Int64) ?? 0
            return [ArchiveEntry(
                path: name, name: name,
                uncompressedSize: size, compressedSize: size,
                modified: nil
            )]
        case .sevenZip, .iso, .unknown:
            throw RarError.userError("Listing not supported for \(format.rawValue) archives")
        }
    }

    // MARK: - RAR (via bundled unrar)

    private func listRar(_ archive: URL, password: String?, unrar: URL) async throws -> [ArchiveEntry] {
        let runner = RarRunner(binaries: .custom(unrarURL: unrar))
        let result = try await runner.run(.list(archive: archive, password: password))
        return RarListOutputToEntries.parse(result.stdout)
    }

    // MARK: - ZIP (via /usr/bin/unzip)

    private func listZip(_ archive: URL, password: String?) async throws -> [ArchiveEntry] {
        let unzip = URL(fileURLWithPath: "/usr/bin/unzip")
        var args = ["-l", archive.path]
        if let p = password { args.insert(contentsOf: ["-P", p], at: 0) }
        let (stdout, exit) = try runSystemTool(unzip, args: args)
        guard exit == 0 else {
            throw RarError.openError("unzip exited \(exit)")
        }
        return ZipListParser.parse(stdout)
    }

    // MARK: - TAR (via /usr/bin/tar)

    private func listTar(_ archive: URL) async throws -> [ArchiveEntry] {
        let tar = URL(fileURLWithPath: "/usr/bin/tar")
        // -tvf auto-detects compression on modern macOS (libarchive)
        let (stdout, exit) = try runSystemTool(tar, args: ["-tvf", archive.path])
        guard exit == 0 else {
            throw RarError.openError("tar exited \(exit)")
        }
        return TarListParser.parse(stdout)
    }

    // MARK: - Helpers

    private func runSystemTool(_ executable: URL, args: [String]) throws -> (String, Int32) {
        let p = Process()
        p.executableURL = executable
        p.arguments = args
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        try p.run()
        p.waitUntilExit()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "", p.terminationStatus)
    }
}
