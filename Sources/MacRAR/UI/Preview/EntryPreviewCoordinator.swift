import Cocoa
import QuickLook
import QuickLookUI
import RarKit

/// Coordinates QLPreviewPanel for archive entries.
///
/// Flow: caller calls `preview(entries:from:)` → we extract each entry to a
/// shared temp dir via the bundled unrar / system unzip / tar (mirroring
/// ArchiveExtractor's format dispatch), then present the global QL panel.
final class EntryPreviewCoordinator: NSObject, @unchecked Sendable {
    @MainActor static let shared = EntryPreviewCoordinator()

    nonisolated(unsafe) private var previewURLs: [URL] = []
    nonisolated(unsafe) private var tempDir: URL?

    @MainActor
    func preview(entries: [ArchiveEntry], from archive: URL, runner: RarRunner) {
        guard !entries.isEmpty else { return }
        Task {
            do {
                let urls = try await extractForPreview(entries: entries, archive: archive, runner: runner)
                await MainActor.run {
                    self.previewURLs = urls
                    self.show()
                }
            } catch {
                NSLog("Preview extraction failed: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func show() {
        let panel = QLPreviewPanel.shared()
        panel?.dataSource = self
        panel?.delegate = self
        panel?.makeKeyAndOrderFront(nil)
        panel?.reloadData()
    }

    // MARK: - Extraction

    private func extractForPreview(
        entries: [ArchiveEntry],
        archive: URL,
        runner: RarRunner
    ) async throws -> [URL] {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacRAR-Preview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Mark old temp dir for cleanup
        if let prev = tempDir { try? FileManager.default.removeItem(at: prev) }
        tempDir = dir

        let format = ArchiveFormat.detect(from: archive)
        let names = entries.map(\.path)
        switch format {
        case .rar, .sfx:
            // Bundled unrar can selectively extract by listing filenames.
            let cmd = RarCommand(
                tool: .unrar,
                action: .extract(keepPaths: true),
                archive: archive,
                files: names,
                switches: [.assumeYes, .overwriteAll],
                workingDirectory: dir
            )
            _ = try await runner.run(cmd)
        case .zip:
            try runSystemTool("/usr/bin/unzip", ["-o", archive.path, "-d", dir.path] + names)
        case .tar, .tarGz, .tarBz2:
            try runSystemTool("/usr/bin/tar", ["-xf", archive.path, "-C", dir.path] + names)
        default:
            throw NSError(domain: "MacRAR", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Preview not supported for \(format.rawValue)"
            ])
        }

        return entries.map { dir.appendingPathComponent($0.path) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func runSystemTool(_ path: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        try p.run()
        p.waitUntilExit()
    }
}

extension EntryPreviewCoordinator: QLPreviewPanelDataSource {
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURLs.count
    }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURLs[index] as NSURL
    }
}

extension EntryPreviewCoordinator: QLPreviewPanelDelegate {}
