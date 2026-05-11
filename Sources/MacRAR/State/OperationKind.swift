import Foundation
import RarKit

/// Discriminated kind of a long-running archive operation. Used by `OperationTracker`.
public enum OperationKind: Sendable, Equatable {
    case extract(destination: URL, options: ExtractOptions)
    case create(sources: [URL], destination: URL, options: CreateOptions)
    case test
    case repair(outputDir: URL)
    case list
    case lock
    case addComment(String)
    case removeComment
    case convertSFX
    case removeSFX
    case addRecoveryRecord(percent: Int)
    case rename(from: String, to: String)
    case delete(entries: [String])
    case addFiles(sources: [URL])

    public var displayName: String {
        switch self {
        case .extract:            "Extracting"
        case .create:             "Creating archive"
        case .test:               "Testing"
        case .repair:             "Repairing"
        case .list:               "Listing"
        case .lock:               "Locking"
        case .addComment:         "Writing comment"
        case .removeComment:      "Removing comment"
        case .convertSFX:         "Converting to SFX"
        case .removeSFX:          "Removing SFX wrapper"
        case .addRecoveryRecord:  "Adding recovery record"
        case .rename:             "Renaming entry"
        case .delete:             "Deleting entries"
        case .addFiles:           "Adding files"
        }
    }

    public var iconSystemName: String {
        switch self {
        case .extract:            "arrow.down.doc"
        case .create:             "plus.rectangle.on.folder"
        case .test:               "checkmark.shield"
        case .repair:             "wrench.adjustable"
        case .list:               "list.bullet"
        case .lock:               "lock.fill"
        case .addComment, .removeComment: "text.bubble"
        case .convertSFX, .removeSFX:     "shippingbox"
        case .addRecoveryRecord:  "lifepreserver"
        case .rename:             "pencil"
        case .delete:             "trash"
        case .addFiles:           "plus.circle"
        }
    }
}
