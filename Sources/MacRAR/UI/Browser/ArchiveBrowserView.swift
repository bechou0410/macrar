import SwiftUI
import RarKit

struct ArchiveBrowserView: View {
    @Environment(AppModel.self) private var model
    @Bindable var session: ArchiveSession
    @State private var showInspector: Bool = true

    var body: some View {
        HSplitView {
            ArchiveTableView(session: session)
                .frame(minWidth: 500)

            if showInspector {
                InspectorView(session: session)
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 380)
            }
        }
        .navigationTitle(session.archive.url.lastPathComponent)
        .navigationSubtitle("\(session.archive.entryCount) entries · \(FormattingHelpers.bytes(session.archive.totalUncompressedBytes))")
        .searchable(text: $session.search, placement: .toolbar, prompt: "Filter entries")
        .toolbar {
            BrowserToolbar(
                session: session,
                showInspector: $showInspector,
                onExtract: { model.activeSheet = .extract(sessionID: session.id) },
                onAdd:     { model.activeSheet = .create(prefilledSources: []) },
                onTest:    test,
                onRepair:  repair,
                onPreview: preview
            )
        }
        .acceptArchiveDrop { urls in
            Task { await model.openMany(urls: urls) }
        }
    }

    private func test() {
        // Test only works for RAR archives (unrar t). Other formats: surface a warning banner.
        let format = ArchiveFormat.detect(from: session.archive.url)
        guard format == .rar || format == .sfx else {
            model.lastResultBanner = .init(
                kind: .info,
                message: "Test is only supported for RAR archives",
                detailURL: nil
            )
            return
        }
        let cmd = RarCommand.test(archive: session.archive.url)
        model.startOperation(kind: .test, archive: session.archive, command: cmd)
    }

    private func preview() {
        let entries = session.entries.filter { session.selectedEntryIDs.contains($0.id) && !$0.isDirectory }
        guard !entries.isEmpty else { return }
        EntryPreviewCoordinator.shared.preview(
            entries: entries,
            from: session.archive.url,
            runner: model.runner
        )
    }

    private func repair() {
        let dest = session.archive.url.deletingLastPathComponent()
        let cmd = RarCommand(
            tool: .unrar,
            action: .repair,
            archive: session.archive.url,
            switches: [.assumeYes],
            workingDirectory: dest
        )
        model.startOperation(
            kind: .repair(outputDir: dest),
            archive: session.archive,
            command: cmd
        )
    }
}
