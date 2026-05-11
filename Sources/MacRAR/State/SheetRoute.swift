import Foundation

/// Discriminated routes for app-level sheets.
public enum SheetRoute: Identifiable, Equatable {
    case extract(sessionID: ArchiveSession.ID)
    case create(prefilledSources: [URL])
    case progress(operationID: UUID)
    case passwordPrompt(sessionID: ArchiveSession.ID)
    case commentEditor(sessionID: ArchiveSession.ID)
    case recoveryRecord(sessionID: ArchiveSession.ID)
    case renameEntry(sessionID: ArchiveSession.ID, entryPath: String)
    case lockConfirm(sessionID: ArchiveSession.ID)
    case deleteConfirm(sessionID: ArchiveSession.ID, entries: [String])
    case sfxToggle(sessionID: ArchiveSession.ID, makeSFX: Bool)
    case rarAutoInstall
    case error(message: String)

    public var id: String {
        switch self {
        case .extract(let id):                "extract-\(id)"
        case .create:                         "create"
        case .progress(let id):               "progress-\(id)"
        case .passwordPrompt(let id):         "password-\(id)"
        case .commentEditor(let id):          "comment-\(id)"
        case .recoveryRecord(let id):         "rr-\(id)"
        case .renameEntry(let id, let p):     "rename-\(id)-\(p)"
        case .lockConfirm(let id):            "lock-\(id)"
        case .deleteConfirm(let id, let es):  "delete-\(id)-\(es.count)"
        case .sfxToggle(let id, let m):       "sfx-\(id)-\(m)"
        case .rarAutoInstall:                 "rar-auto-install"
        case .error(let msg):                 "error-\(msg.hashValue)"
        }
    }
}
