import SwiftUI
import RarKit

struct ArchiveTableView: View {
    @Bindable var session: ArchiveSession
    @Environment(AppModel.self) private var model

    var body: some View {
        Table(of: ArchiveEntry.self, selection: $session.selectedEntryIDs) {
            TableColumn("Name") { entry in
                HStack {
                    Image(systemName: entry.isDirectory ? "folder.fill" : "doc")
                        .foregroundStyle(entry.isDirectory ? Color.blue : Color.secondary)
                    Text(entry.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if entry.isEncrypted {
                        Image(systemName: "lock.fill").foregroundStyle(.orange).font(.caption)
                    }
                }
            }
            TableColumn("Size") { entry in
                Text(FormattingHelpers.bytes(entry.uncompressedSize))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)
            TableColumn("Packed") { entry in
                Text(FormattingHelpers.bytes(entry.compressedSize))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 100)
            TableColumn("Ratio") { entry in
                Text(FormattingHelpers.percent(entry.compressionRatio))
                    .foregroundStyle(.secondary)
            }
            .width(min: 60, ideal: 70)
            TableColumn("Modified") { entry in
                Text(FormattingHelpers.date(entry.modified))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .width(min: 120, ideal: 160)
        } rows: {
            ForEach(session.filteredEntries) { entry in
                TableRow(entry)
                    .contextMenu {
                        if !entry.isDirectory {
                            Button("Quick Look") { previewEntry(entry) }
                                .keyboardShortcut(.space, modifiers: [])
                            Divider()
                        }
                        Button("Rename…") {
                            model.activeSheet = .renameEntry(sessionID: session.id, entryPath: entry.path)
                        }
                        .disabled(!model.runner.rarAvailable)
                        Button("Delete from Archive", role: .destructive) {
                            model.activeSheet = .deleteConfirm(sessionID: session.id, entries: [entry.path])
                        }
                        .disabled(!model.runner.rarAvailable)
                    }
            }
        }
        .alternatingRowBackgrounds()
        .onKeyPress(.space) {
            previewSelected()
            return .handled
        }
    }

    private func previewSelected() {
        let entries = session.entries.filter { session.selectedEntryIDs.contains($0.id) && !$0.isDirectory }
        guard !entries.isEmpty else { return }
        EntryPreviewCoordinator.shared.preview(
            entries: entries,
            from: session.archive.url,
            runner: model.runner
        )
    }

    private func previewEntry(_ entry: ArchiveEntry) {
        EntryPreviewCoordinator.shared.preview(
            entries: [entry],
            from: session.archive.url,
            runner: model.runner
        )
    }
}
