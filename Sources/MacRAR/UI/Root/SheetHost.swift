import SwiftUI
import RarKit

/// View modifier that routes `AppModel.activeSheet` to the right sheet UI.
struct SheetHost: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        @Bindable var model = model
        content
            // Bind to `presentedSheet` (UUID-keyed wrapper) so each invocation
            // gets a fresh identity — prevents stale-view crashes when the
            // same route case is re-presented after dismissal.
            .sheet(item: $model.presentedSheet) { presented in
                switch presented.route {
                case .extract(let id):
                    if let session = model.sessions.first(where: { $0.id == id }) {
                        ExtractSheet(session: session)
                            .environment(model)
                    }
                case .create(let urls):
                    CreateSheet(prefilledSources: urls)
                        .environment(model)
                case .progress(let opID):
                    if let tracker = model.operations.first(where: { $0.id == opID }) {
                        ProgressSheet(tracker: tracker)
                    }
                case .passwordPrompt(let sid):
                    if let session = model.sessions.first(where: { $0.id == sid }) {
                        PasswordPromptSheet(
                            archiveName: session.archive.url.lastPathComponent,
                            onSubmit: { _ in model.activeSheet = nil },
                            onCancel: { model.activeSheet = nil }
                        )
                    }
                case .commentEditor(let sid):
                    if let s = model.sessions.first(where: { $0.id == sid }) {
                        CommentEditorSheet(session: s).environment(model)
                    }
                case .recoveryRecord(let sid):
                    if let s = model.sessions.first(where: { $0.id == sid }) {
                        RecoveryRecordSheet(session: s).environment(model)
                    }
                case .renameEntry(let sid, let path):
                    if let s = model.sessions.first(where: { $0.id == sid }) {
                        RenameEntrySheet(session: s, entryPath: path).environment(model)
                    }
                case .lockConfirm(let sid):
                    if let s = model.sessions.first(where: { $0.id == sid }) {
                        LockConfirmationSheet(session: s).environment(model)
                    }
                case .deleteConfirm(let sid, let entries):
                    if let s = model.sessions.first(where: { $0.id == sid }) {
                        DeleteEntriesConfirmation(session: s, entries: entries).environment(model)
                    }
                case .sfxToggle(let sid, let makeSFX):
                    if let s = model.sessions.first(where: { $0.id == sid }) {
                        SFXConfirmationSheet(session: s, makeSFX: makeSFX).environment(model)
                    }
                case .rarAutoInstall:
                    RarAutoInstallSheet(detector: model.statusDetector)
                        .environment(model)
                case .error(let msg):
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.largeTitle).foregroundStyle(.red)
                        Text(msg)
                        Button("OK") { model.activeSheet = nil }
                    }
                    .padding(20)
                    .frame(width: 360)
                }
            }
    }
}

extension View {
    func appSheetHost() -> some View {
        modifier(SheetHost())
    }
}
