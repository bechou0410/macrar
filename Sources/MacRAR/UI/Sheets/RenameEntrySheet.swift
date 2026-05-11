import SwiftUI
import RarKit

struct RenameEntrySheet: View {
    let session: ArchiveSession
    let entryPath: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String

    init(session: ArchiveSession, entryPath: String) {
        self.session = session
        self.entryPath = entryPath
        _newName = State(initialValue: (entryPath as NSString).lastPathComponent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "pencil").foregroundStyle(.tint)
                Text("Rename entry").font(.headline)
                Spacer()
            }
            Text("Current: \(entryPath)").font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)

            TextField("New name", text: $newName)
                .textFieldStyle(.roundedBorder)

            if !model.runner.rarAvailable { RarInstallBanner() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Rename") { rename() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.isEmpty || newName.contains("/") || !model.runner.rarAvailable)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func rename() {
        // Replace the last path component, preserving any parent dirs.
        let parent = (entryPath as NSString).deletingLastPathComponent
        let target = parent.isEmpty ? newName : "\(parent)/\(newName)"
        let cmd = RarCommand(
            tool: .rar,
            action: .rename(from: entryPath, to: target),
            archive: session.archive.url,
            switches: [.assumeYes]
        )
        model.startOperation(
            kind: .rename(from: entryPath, to: target),
            archive: session.archive,
            command: cmd
        )
        dismiss()
    }
}
