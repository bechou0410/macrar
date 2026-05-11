import SwiftUI
import RarKit

struct CommentEditorSheet: View {
    let session: ArchiveSession
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var comment: String = ""
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if isLoading {
                ProgressView("Loading current comment…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(40)
            } else {
                TextEditor(text: $comment)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
            }
            Divider()
            footer
        }
        .frame(width: 560, height: 400)
        .task { await loadCurrent() }
    }

    private var header: some View {
        HStack {
            Image(systemName: "text.bubble.fill").foregroundStyle(.tint)
            Text("Archive Comment").font(.headline)
            Spacer()
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            if !model.runner.rarAvailable {
                Label("rar required to save", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || !model.runner.rarAvailable)
        }
        .padding(12)
    }

    private func loadCurrent() async {
        defer { isLoading = false }
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("macrar-comment-\(UUID().uuidString).txt")
        let cmd = RarCommand(
            tool: .unrar,
            action: .readComment,
            archive: session.archive.url,
            switches: [.assumeYes]
        )
        do {
            let result = try await model.runner.run(cmd)
            // unrar `cw` writes the comment to stdout (without -o). Capture it.
            comment = result.stdout
        } catch {
            // No comment present = error in some versions; just leave empty.
            comment = ""
        }
        _ = tmp
    }

    private func save() {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("macrar-comment-\(UUID().uuidString).txt")
        try? comment.write(to: tmp, atomically: true, encoding: .utf8)
        let cmd = RarCommand(
            tool: .rar,
            action: .writeComment(filePath: tmp.path),
            archive: session.archive.url,
            switches: [.assumeYes]
        )
        model.startOperation(
            kind: .addComment(comment),
            archive: session.archive,
            command: cmd
        )
        dismiss()
    }
}
