import SwiftUI
import RarKit

struct BrowserToolbar: ToolbarContent {
    let session: ArchiveSession
    @Binding var showInspector: Bool
    var onExtract: () -> Void
    var onAdd: () -> Void
    var onTest: () -> Void
    var onRepair: () -> Void
    var onPreview: () -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: onExtract) {
                Label("Extract", systemImage: "arrow.down.doc")
            }
            .primaryActionStyle()

            Button(action: onAdd) {
                Label("New…", systemImage: "plus.rectangle.on.folder")
            }
            .secondaryActionStyle()

            Button(action: onPreview) {
                Label("Preview", systemImage: "eye")
            }
            .secondaryActionStyle()
            .disabled(session.selectedEntryIDs.isEmpty)
            .keyboardShortcut("y", modifiers: [.command])

            Button(action: onTest) {
                Label("Test", systemImage: "checkmark.shield")
            }
            .secondaryActionStyle()

            Button(action: onRepair) {
                Label("Repair", systemImage: "wrench.adjustable")
            }
            .secondaryActionStyle()
        }
        ToolbarItem(placement: .automatic) {
            Menu {
                MoreActionsMenu(session: session)
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        ToolbarItem(placement: .automatic) {
            Button { showInspector.toggle() } label: {
                Image(systemName: "sidebar.right")
            }
            .help("Toggle Inspector")
        }
    }
}

struct MoreActionsMenu: View {
    let session: ArchiveSession
    @Environment(AppModel.self) private var model

    var body: some View {
        Button("Edit Comment…") {
            model.activeSheet = .commentEditor(sessionID: session.id)
        }
        Button("Add Recovery Record…") {
            model.activeSheet = .recoveryRecord(sessionID: session.id)
        }
        Divider()
        Button("Convert to SFX…") {
            model.activeSheet = .sfxToggle(sessionID: session.id, makeSFX: true)
        }
        Button("Remove SFX Wrapper…") {
            model.activeSheet = .sfxToggle(sessionID: session.id, makeSFX: false)
        }
        Divider()
        Button("Lock Archive…") {
            model.activeSheet = .lockConfirm(sessionID: session.id)
        }
        .disabled(session.archive.isLocked)
        if !session.selectedEntryIDs.isEmpty {
            Divider()
            Button("Rename Selected Entry…") {
                if let path = session.selectedEntryIDs.first {
                    model.activeSheet = .renameEntry(sessionID: session.id, entryPath: path)
                }
            }
            .disabled(session.selectedEntryIDs.count != 1)
            Button("Delete Selected Entries…", role: .destructive) {
                let entries = Array(session.selectedEntryIDs)
                model.activeSheet = .deleteConfirm(sessionID: session.id, entries: entries)
            }
        }
    }
}
