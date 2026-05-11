import Cocoa
import QuickLookUI
import SwiftUI
import RarKit

/// Quick Look preview controller: lists archive entries using the bundled unrar
/// resolved from the parent app's `Contents/Helpers/MacOS/unrar`.
final class PreviewViewController: NSViewController, QLPreviewingController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 420))
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let archive = (try? await listArchive(url: url)) ?? .placeholder(url: url)
        await MainActor.run {
            let hosting = NSHostingController(rootView: QuickLookArchivePreview(archive: archive))
            self.view.subviews.forEach { $0.removeFromSuperview() }
            self.addChild(hosting)
            hosting.view.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(hosting.view)
            NSLayoutConstraint.activate([
                hosting.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                hosting.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                hosting.view.topAnchor.constraint(equalTo: self.view.topAnchor),
                hosting.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            ])
        }
    }

    private func listArchive(url: URL) async throws -> ArchivePreviewData {
        let unrar = try? resolveBundledUnrar()
        let lister = ArchiveLister(bundledUnrar: unrar)
        let entries = try await lister.list(url)
        return ArchivePreviewData(
            url: url,
            entries: entries,
            format: ArchiveFormat.detect(from: url)
        )
    }

    /// Climb from the extension's bundle to the host app's Helpers/MacOS/unrar.
    /// Extension is at: ParentApp.app/Contents/PlugIns/QuickLookExtension.appex
    /// → ../../../Contents/Helpers/MacOS/unrar
    private func resolveBundledUnrar() throws -> URL {
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // Contents
            .deletingLastPathComponent()  // ParentApp.app/..
        // Note: deletingLastPathComponent thrice removes the bundle dir + Contents + PlugIns,
        // landing us in the dir containing ParentApp.app. We need ParentApp.app/Contents/Helpers/MacOS/unrar.
        let appBundle = Bundle.main.bundleURL
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // Contents
        let unrar = appBundle.appendingPathComponent("Helpers/MacOS/unrar")
        guard FileManager.default.isExecutableFile(atPath: unrar.path) else {
            throw NSError(domain: "MacRARQuickLook", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Bundled unrar not found at \(unrar.path)"
            ])
        }
        _ = app
        return unrar
    }
}

struct ArchivePreviewData: Sendable {
    let url: URL
    let entries: [ArchiveEntry]
    let format: ArchiveFormat

    var totalBytes: Int64 {
        entries.reduce(0) { $0 + $1.uncompressedSize }
    }

    static func placeholder(url: URL) -> ArchivePreviewData {
        .init(url: url, entries: [], format: ArchiveFormat.detect(from: url))
    }
}

struct QuickLookArchivePreview: View {
    let archive: ArchivePreviewData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if archive.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "lock.doc").font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("Cannot preview archive contents")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Text("Archive may be password-protected or unsupported")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List {
                    ForEach(archive.entries.prefix(200)) { entry in
                        HStack {
                            Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                                .foregroundStyle(entry.isDirectory ? .blue : .secondary)
                            Text(entry.path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(byteFormat(entry.uncompressedSize))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    if archive.entries.count > 200 {
                        Text("… and \(archive.entries.count - 200) more")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "archivebox.fill")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text(archive.url.lastPathComponent).font(.headline)
                Text("\(archive.format.rawValue) · \(archive.entries.count) entries · \(byteFormat(archive.totalBytes))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }

    private func byteFormat(_ n: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: n)
    }
}
