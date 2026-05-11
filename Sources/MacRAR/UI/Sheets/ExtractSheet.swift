import SwiftUI
import RarKit

struct ExtractSheet: View {
    let session: ArchiveSession
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var destination: URL
    @State private var options = ExtractOptions()
    @State private var password = ""

    init(session: ArchiveSession) {
        self.session = session
        let dl = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let nameStem = session.archive.url.deletingPathExtension().lastPathComponent
        _destination = State(initialValue: dl.appendingPathComponent(nameStem, isDirectory: true))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            form
            Divider()
            footer
        }
        .frame(width: 520)
        .frame(minHeight: 380)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Extract Archive").font(.title3.bold())
                Spacer()
            }
            Text(session.archive.url.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
    }

    private var form: some View {
        Form {
            Section("Destination") {
                DestinationPicker(selection: $destination)
                Toggle("Reveal in Finder when done", isOn: $options.openInFinderWhenDone)
            }
            Section("Options") {
                Toggle("Preserve folder structure", isOn: $options.keepPaths)
                Picker("If files exist", selection: $options.overwrite) {
                    ForEach(ExtractOptions.OverwriteMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
            }
            if session.archive.isHeaderEncrypted {
                Section("Password") {
                    SecureField("Required to extract", text: $password)
                }
            } else {
                Section("Password (optional)") {
                    SecureField("Only if entries are encrypted", text: $password)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Extract") { start() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func start() {
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        options.password = password.isEmpty ? nil : password
        let mode: ArchiveExtractor.OverwriteMode = switch options.overwrite {
        case .ask:        .ask
        case .always:     .always
        case .never:      .never
        case .renameOld:  .always       // closest match — only rar supports rename-old
        case .renameNew:  .renameNew
        }
        let extractor = ArchiveExtractor(runner: model.runner)
        let op = extractor.extract(
            archive: session.archive.url,
            to: destination,
            password: options.password,
            overwrite: mode
        )
        model.startOperation(
            kind: .extract(destination: destination, options: options),
            archive: session.archive,
            operation: op
        )
        dismiss()
    }
}
