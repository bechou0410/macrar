import SwiftUI
import AppKit

struct DestinationPicker: View {
    @Binding var selection: URL

    var body: some View {
        HStack {
            Text(selection.path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Choose…", action: pick)
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = selection
        if panel.runModal() == .OK, let url = panel.url {
            selection = url
        }
    }
}
