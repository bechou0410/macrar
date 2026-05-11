import Foundation

/// Streamed progress events. Subscribers (UI) bind to these for live updates.
public enum ProgressEvent: Sendable, Equatable {
    /// Operation has started. `totalFiles` known only when listing precedes extraction.
    case started(totalFiles: Int?)
    /// New file began processing.
    case fileStarted(name: String)
    /// Per-file percentage update (0–100).
    case fileProgress(name: String, percent: Double)
    /// File done (either OK or FAILED captured in `success`).
    case fileCompleted(name: String, success: Bool)
    /// Overall archive progress (0.0–1.0).
    case overallProgress(fraction: Double)
    /// Non-fatal warning surfaced by rar/unrar.
    case warning(String)
    /// Terminal event with final result.
    case finished(RarResult)
}
