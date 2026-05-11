import SwiftUI
import RarKit

/// Commands are not part of the view hierarchy and don't inherit `@Environment`
/// from the WindowGroup, so we pass the model explicitly from `MacRARApp`.
struct AppCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About MacRAR") {
                openWindow(id: "about")
            }
        }
        CommandGroup(replacing: .newItem) {
            Button("New Archive…") {
                Task { @MainActor in model.activeSheet = .create(prefilledSources: []) }
            }.keyboardShortcut("n")
            Button("Open…") { openFile() }.keyboardShortcut("o")
            Button("Close Archive") { closeFront() }
                .keyboardShortcut("w")
        }
        CommandMenu("Archive") {
            Button("Extract…") {
                Task { @MainActor in
                    if let id = model.selectedSessionID {
                        model.activeSheet = .extract(sessionID: id)
                    }
                }
            }.keyboardShortcut("e")
            Button("Test") {}.keyboardShortcut("t")
            Button("Repair") {}
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            let urls = panel.urls
            Task { @MainActor in await model.openMany(urls: urls) }
        }
    }

    private func closeFront() {
        Task { @MainActor in
            guard let id = model.selectedSessionID else { return }
            model.closeSession(id: id)
        }
    }
}
