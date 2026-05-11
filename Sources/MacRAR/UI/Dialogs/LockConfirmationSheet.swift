import SwiftUI
import RarKit

struct LockConfirmationSheet: View {
    let session: ArchiveSession
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var typed: String = ""
    private let confirmation = "LOCK"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "lock.fill").foregroundStyle(.orange).font(.title2)
                Text("Lock archive?").font(.headline)
                Spacer()
            }

            Text("Locking is permanent. A locked archive cannot be modified, repackaged, or have its SFX wrapper changed.")
                .font(.callout)
            Text("Type \"\(confirmation)\" to confirm.")
                .font(.caption).foregroundStyle(.secondary)

            TextField(confirmation, text: $typed)
                .textFieldStyle(.roundedBorder)

            if !model.runner.rarAvailable { RarInstallBanner() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Lock", role: .destructive) { apply() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(typed != confirmation || !model.runner.rarAvailable)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func apply() {
        let cmd = RarCommand(
            tool: .rar,
            action: .lock,
            archive: session.archive.url,
            switches: [.assumeYes]
        )
        model.startOperation(kind: .lock, archive: session.archive, command: cmd)
        dismiss()
    }
}
