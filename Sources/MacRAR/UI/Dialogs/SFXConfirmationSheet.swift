import SwiftUI
import RarKit

struct SFXConfirmationSheet: View {
    let session: ArchiveSession
    let makeSFX: Bool        // true = convert to SFX, false = strip SFX wrapper
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "shippingbox").foregroundStyle(.tint).font(.title2)
                Text(makeSFX ? "Convert to SFX?" : "Remove SFX wrapper?").font(.headline)
                Spacer()
            }

            if makeSFX {
                Text("Wraps the archive in a Windows .exe self-extractor using the bundled default SFX module. The resulting file is a Windows executable — useful for cross-platform distribution.")
                    .font(.callout)
                Label("SFX archives run on Windows, not macOS.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Removes the SFX (Windows executable) wrapper, leaving a plain .rar archive.")
                    .font(.callout)
            }

            if !model.runner.rarAvailable { RarInstallBanner() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(makeSFX ? "Convert" : "Remove") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.runner.rarAvailable)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private func apply() {
        let action: RarCommand.Action = makeSFX ? .convertToSFX : .removeSFX
        let kind: OperationKind = makeSFX ? .convertSFX : .removeSFX
        let cmd = RarCommand(
            tool: .rar,
            action: action,
            archive: session.archive.url,
            switches: [.assumeYes]
        )
        model.startOperation(kind: kind, archive: session.archive, command: cmd)
        dismiss()
    }
}
