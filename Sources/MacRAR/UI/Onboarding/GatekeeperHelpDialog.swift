import SwiftUI
import AppKit

struct GatekeeperHelpDialog: View {
    @Environment(\.dismiss) private var dismiss
    private let command = "xattr -dr com.apple.quarantine /Applications/MacRAR.app"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint).font(.title2)
                Text("First-run setup").font(.headline)
                Spacer()
            }

            Text("MacRAR uses ad-hoc code signing instead of a paid Apple Developer ID. If macOS blocked launching the app, run this in Terminal once:")
                .font(.callout)

            HStack {
                Text(command)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy to clipboard")
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))

            Text("Or: right-click MacRAR.app in Applications → Open → Open again.")
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("OK") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 500)
    }
}
