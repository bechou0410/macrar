import Foundation
import Observation
import RarKit

/// Root @Observable app state. SwiftUI views bind here; AppModel orchestrates RarKit calls.
@MainActor
@Observable
public final class AppModel {
    public var sessions: [ArchiveSession] = []
    public var selectedSessionID: ArchiveSession.ID?
    public var recents: [RecentArchive] = []
    public var preferences: Preferences = .default
    public var operations: [OperationTracker] = []
    public var lastError: String?
    /// The current sheet route, or nil if none is presented.
    ///
    /// Every assignment bumps `_sheetVersion` so SwiftUI's `.sheet(item:)`
    /// sees a fresh identity even when re-presenting the same route case
    /// (eg user opens CreateSheet, presses Esc, opens CreateSheet again).
    /// Without this, SwiftUI reuses stale view state and can crash on rapid
    /// dismiss-then-present cycles.
    public var activeSheet: SheetRoute? {
        didSet { if activeSheet != nil { _sheetVersion = UUID() } }
    }
    /// Per-presentation token. Read by `presentedSheet`.
    private var _sheetVersion: UUID = UUID()

    /// Identifiable wrapper that SheetHost binds for `.sheet(item:)`.
    public var presentedSheet: PresentedSheet? {
        get { activeSheet.map { PresentedSheet(id: _sheetVersion, route: $0) } }
        set { activeSheet = newValue?.route }
    }

    public struct PresentedSheet: Identifiable, Equatable {
        public let id: UUID
        public let route: SheetRoute
        public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    }

    public var lastResultBanner: ResultBanner?
    /// Set by AppDelegate when launched via Services / Apple Events; drives headless UI.
    public var launchContext: LaunchContext = .normal

    public struct ResultBanner: Identifiable, Equatable {
        public let id = UUID()
        public let kind: Kind
        public let message: String
        public let detailURL: URL?

        public enum Kind: Sendable, Equatable { case success, failure, info }
    }

    public let runner: RarRunner
    public let statusDetector = RarStatusDetector()
    private let recentsStore: RecentsStore
    private let preferencesStore: PreferencesStore

    public init(
        runner: RarRunner,
        recentsStore: RecentsStore = RecentsStore(),
        preferencesStore: PreferencesStore = PreferencesStore()
    ) {
        self.runner = runner
        self.recentsStore = recentsStore
        self.preferencesStore = preferencesStore
        self.preferences = preferencesStore.load()
        self.recents = recentsStore.load()
        Task { @MainActor in await statusDetector.detect(using: runner) }
    }

    // MARK: - Sessions

    public var selectedSession: ArchiveSession? {
        guard let id = selectedSessionID else { return nil }
        return sessions.first { $0.id == id }
    }

    public func closeSession(id: ArchiveSession.ID) {
        sessions.removeAll { $0.id == id }
        if selectedSessionID == id {
            selectedSessionID = sessions.first?.id
        }
    }

    // MARK: - Open archive

    public func open(url: URL) async {
        let resolved = MultipartDetector.detect(url)
        let format = ArchiveFormat.detect(from: resolved.firstVolume)

        do {
            let lister = ArchiveLister(bundledUnrar: runner.unrarURL)
            let entries = try await lister.list(resolved.firstVolume)
            let archive = Archive(
                url: resolved.firstVolume,
                format: format,
                isMultipart: resolved.isMultipart,
                parts: resolved.parts,
                entryCount: entries.count,
                totalUncompressedBytes: entries.reduce(0) { $0 + $1.uncompressedSize },
                totalCompressedBytes: entries.reduce(0) { $0 + $1.compressedSize }
            )

            let session = ArchiveSession(archive: archive, entries: entries)
            sessions.append(session)
            selectedSessionID = session.id

            let recent = RecentArchive(
                url: archive.url,
                entryCount: archive.entryCount,
                totalBytes: archive.totalUncompressedBytes
            )
            recents = recentsStore.promote(recent, in: recents)
            recentsStore.save(recents)
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func openMany(urls: [URL]) async {
        for url in urls {
            await open(url: url)
        }
    }

    // MARK: - Operations

    /// Start a tracked operation; appends to `operations`, consumes events in background.
    /// Auto-shows the progress sheet and posts a result banner on completion.
    @discardableResult
    public func startOperation(
        kind: OperationKind,
        archive: Archive?,
        command: RarCommand,
        autoShowProgress: Bool = true,
        onComplete: (@MainActor (OperationTracker) -> Void)? = nil
    ) -> OperationTracker {
        startOperation(
            kind: kind,
            archive: archive,
            operation: runner.runWithProgress(command),
            autoShowProgress: autoShowProgress,
            onComplete: onComplete
        )
    }

    /// Overload that takes a pre-built operation — used for non-RAR formats
    /// via `ArchiveExtractor` where the operation source isn't `RarRunner`.
    @discardableResult
    public func startOperation(
        kind: OperationKind,
        archive: Archive?,
        operation op: RarRunner.Operation,
        autoShowProgress: Bool = true,
        onComplete: (@MainActor (OperationTracker) -> Void)? = nil
    ) -> OperationTracker {
        let tracker = OperationTracker(kind: kind, archive: archive, operation: op)
        operations.append(tracker)
        if autoShowProgress {
            activeSheet = .progress(operationID: tracker.id)
        }
        Task { @MainActor in
            await tracker.consume()
            // Auto-dismiss progress sheet
            if case .progress(let id) = activeSheet, id == tracker.id {
                activeSheet = nil
            }
            // Post result banner
            switch tracker.status {
            case .succeeded:
                lastResultBanner = .init(kind: .success,
                                         message: "\(kind.displayName) finished in \(tracker.elapsedFormatted)",
                                         detailURL: extractedDestination(for: kind))
            case .failed(let msg):
                lastResultBanner = .init(kind: .failure, message: msg, detailURL: nil)
            case .cancelled:
                lastResultBanner = .init(kind: .info, message: "Cancelled", detailURL: nil)
            case .running:
                break
            }
            onComplete?(tracker)
            // Refresh listing if the archive was mutated
            if shouldRefreshAfter(kind), let arch = archive,
               let session = sessions.first(where: { $0.archive.url == arch.url }) {
                await refresh(session)
            }
        }
        return tracker
    }

    private func extractedDestination(for kind: OperationKind) -> URL? {
        if case .extract(let dest, _) = kind { return dest }
        return nil
    }

    private func shouldRefreshAfter(_ kind: OperationKind) -> Bool {
        switch kind {
        case .extract, .test, .list, .repair: return false
        default: return true
        }
    }

    /// Re-list an existing session's archive.
    public func refresh(_ session: ArchiveSession) async {
        do {
            let lister = ArchiveLister(bundledUnrar: runner.unrarURL)
            let entries = try await lister.list(session.archive.url)
            session.replace(entries: entries)
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Preferences

    public func savePreferences() {
        preferencesStore.save(preferences)
    }

    // MARK: - Service intents (from right-click Services menu)

    /// Triggered by Finder Services menu: "Compress with MacRAR…". Shows just
    /// the New Archive sheet without bringing up the main browser window.
    public func handleServiceCompress(sources: [URL]) {
        launchContext = .compress(sources: sources)
        activeSheet = .create(prefilledSources: sources)
    }

    /// Triggered by Finder Services menu: "Extract with MacRAR". For each
    /// archive, dispatches the right tool (unrar for RAR / SFX, ArchiveExtractor
    /// for ZIP / TAR / etc.). Shows progress + password prompt only; no browser.
    public func handleServiceExtract(archives: [URL]) {
        launchContext = .extract(archives: archives)
        Task { @MainActor in
            for archive in archives {
                await quickExtract(archive)
            }
        }
    }

    /// Extract `archive` to its parent folder (next to the archive), routing
    /// through ArchiveExtractor so all supported formats work.
    public func quickExtract(_ archive: URL) async {
        let resolved = MultipartDetector.detect(archive).firstVolume
        let destination = resolved.deletingLastPathComponent()
            .appendingPathComponent(resolved.deletingPathExtension().lastPathComponent)
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let extractor = ArchiveExtractor(runner: runner)
        let op = extractor.extract(archive: resolved, to: destination, overwrite: .always)
        var opts = ExtractOptions()
        opts.openInFinderWhenDone = true
        startOperation(
            kind: .extract(destination: destination, options: opts),
            archive: nil,
            operation: op
        )
    }
}
