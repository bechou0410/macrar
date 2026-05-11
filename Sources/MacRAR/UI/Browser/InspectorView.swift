import SwiftUI
import RarKit

struct InspectorView: View {
    let session: ArchiveSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(session.archive.url.lastPathComponent)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.middle)

            archiveDetails

            if let entry = selectedEntry {
                Divider()
                entryDetails(entry)
            }

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 240)
        .liquidGlass()
    }

    private var selectedEntry: ArchiveEntry? {
        guard let first = session.selectedEntryIDs.first else { return nil }
        return session.entries.first { $0.id == first }
    }

    @ViewBuilder
    private var archiveDetails: some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Format", session.archive.format.rawValue)
            row("Entries", "\(session.archive.entryCount)")
            row("Size", FormattingHelpers.bytes(session.archive.totalUncompressedBytes))
            row("Packed", FormattingHelpers.bytes(session.archive.totalCompressedBytes))
            row("Ratio", FormattingHelpers.percent(session.archive.compressionRatio))
            if session.archive.isMultipart {
                row("Volumes", "\(session.archive.parts.count)")
            }
            if session.archive.isLocked {
                Label("Locked", systemImage: "lock.fill").foregroundStyle(.orange)
            }
            if session.archive.hasRecoveryRecord {
                Label("Recovery record", systemImage: "lifepreserver").foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func entryDetails(_ entry: ArchiveEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.path).font(.subheadline.bold()).lineLimit(2).truncationMode(.middle)
            row("Size", FormattingHelpers.bytes(entry.uncompressedSize))
            row("Packed", FormattingHelpers.bytes(entry.compressedSize))
            row("Ratio", FormattingHelpers.percent(entry.compressionRatio))
            row("Modified", FormattingHelpers.date(entry.modified))
            if !entry.crc32.isEmpty { row("CRC32", entry.crc32) }
            if !entry.attributes.isEmpty {
                row("Attributes", entry.attributes)
                    .font(.system(.caption, design: .monospaced))
            }
            if entry.isEncrypted {
                Label("Encrypted", systemImage: "lock").foregroundStyle(.orange).font(.caption)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary).font(.caption)
            Spacer()
            Text(value).font(.caption.monospacedDigit())
        }
    }
}
