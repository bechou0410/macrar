import SwiftUI
import RarKit

struct DeleteEntriesConfirmation: View {
    let session: ArchiveSession
    let entries: [String]
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "trash.fill").foregroundStyle(.red).font(.title2)
                Text("Delete \(entries.count) entr\(entries.count == 1 ? "y" : "ies")?")
                    .font(.headline)
                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(entries.prefix(10), id: \.self) { e in
                        Text(e).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                    }
                    if entries.count > 10 {
                        Text("… and \(entries.count - 10) more").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 140)

            Text("This will remove the entries from the archive permanently. The action cannot be undone.")
                .font(.caption).foregroundStyle(.secondary)

            if !model.runner.rarAvailable { RarInstallBanner() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Delete", role: .destructive) { apply() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!model.runner.rarAvailable)
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private func apply() {
        let cmd = RarCommand(
            tool: .rar,
            action: .delete(entries: entries),
            archive: session.archive.url,
            switches: [.assumeYes]
        )
        model.startOperation(
            kind: .delete(entries: entries),
            archive: session.archive,
            command: cmd
        )
        dismiss()
    }
}
