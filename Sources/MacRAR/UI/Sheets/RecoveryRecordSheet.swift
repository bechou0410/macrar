import SwiftUI
import RarKit

struct RecoveryRecordSheet: View {
    let session: ArchiveSession
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var percent: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lifepreserver").foregroundStyle(.tint).font(.title2)
                Text("Add Recovery Record").font(.headline)
                Spacer()
            }
            Text("Adds redundant data so unrar can repair corruption. Larger = stronger but bigger file.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Text("Size").frame(width: 40, alignment: .leading)
                Slider(value: Binding(get: { Double(percent) },
                                       set: { percent = Int($0) }), in: 1...10, step: 1)
                Text("\(percent)%").font(.caption.monospaced()).frame(width: 40, alignment: .trailing)
            }

            Text("Estimated archive growth: ~\(percent)%")
                .font(.caption).foregroundStyle(.secondary)

            if !model.runner.rarAvailable { RarInstallBanner() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.runner.rarAvailable)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func apply() {
        let cmd = RarCommand(
            tool: .rar,
            action: .addRecoveryRecord(percent: percent),
            archive: session.archive.url,
            switches: [.assumeYes]
        )
        model.startOperation(
            kind: .addRecoveryRecord(percent: percent),
            archive: session.archive,
            command: cmd
        )
        dismiss()
    }
}
