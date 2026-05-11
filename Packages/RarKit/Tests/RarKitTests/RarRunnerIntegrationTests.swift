import Testing
import Foundation
@testable import RarKit

@Suite("RarRunner Integration — bundled unrar")
struct RarRunnerIntegrationTests {
    /// Path to bundled unrar — climbs up from CWD looking for project markers.
    static let bundledUnrar: URL? = {
        let fm = FileManager.default
        var dir = URL(fileURLWithPath: fm.currentDirectoryPath)
        for _ in 0..<6 {
            for sub in [
                "build/Release/MacRAR.app/Contents/Helpers/MacOS/unrar",
                "Vendor/unrar/universal/unrar",
                "Vendor/unrar/arm64/unrar",
            ] {
                let candidate = dir.appendingPathComponent(sub)
                if fm.isExecutableFile(atPath: candidate.path) {
                    return candidate.standardized
                }
            }
            dir.deleteLastPathComponent()
        }
        return nil
    }()

    @Test("listing a real archive succeeds")
    func listRealArchive() async throws {
        guard let unrar = Self.bundledUnrar else {
            Issue.record("Bundled unrar not found — run `make build` first to populate build/Release/")
            return
        }

        // Build a tiny archive using whatever rar is around (test env may not have it; skip otherwise).
        let rarBin = BinaryLocator.locateRar() ?? URL(fileURLWithPath: "/Users/chou/Downloads/rar 2/_private/rar")
        guard FileManager.default.isExecutableFile(atPath: rarBin.path) else {
            Issue.record("No `rar` available to build fixture archive — skipping")
            return
        }

        let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rarkit-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let txt = tmpDir.appendingPathComponent("hello.txt")
        try "hello world".write(to: txt, atomically: true, encoding: .utf8)

        let archive = tmpDir.appendingPathComponent("test.rar")

        // Build archive using the local rar binary directly (bypass RarKit since this is fixture setup).
        let create = Process()
        create.executableURL = rarBin
        create.arguments = ["a", "-y", archive.path, txt.path]
        create.currentDirectoryURL = tmpDir
        create.standardOutput = Pipe()
        create.standardError = Pipe()
        try create.run()
        create.waitUntilExit()
        #expect(create.terminationStatus == 0)
        #expect(FileManager.default.fileExists(atPath: archive.path))

        // Now use RarKit to list the archive via bundled unrar.
        let runner = RarRunner(binaries: .custom(unrarURL: unrar))
        let result = try await runner.run(.list(archive: archive))

        #expect(result.status == .success)
        #expect(result.stdout.contains("hello.txt"))
    }

    @Test("rarMissing thrown when create requested without rar in PATH")
    func rarMissingError() async throws {
        guard let unrar = Self.bundledUnrar else {
            Issue.record("Bundled unrar not found")
            return
        }
        let runner = RarRunner(binaries: .custom(unrarURL: unrar, rarURL: nil))

        await #expect(throws: RarError.rarMissing) {
            try await runner.run(.create(
                archive: URL(fileURLWithPath: "/tmp/x.rar"),
                sources: [URL(fileURLWithPath: "/tmp/x.txt")]
            ))
        }
    }
}
