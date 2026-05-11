import Foundation
import Observation
import RarKit

/// Live UI-bound state for a single in-flight `RarRunner` operation.
@MainActor
@Observable
public final class OperationTracker: Identifiable {
    public enum Status: Sendable, Equatable {
        case running
        case succeeded
        case failed(message: String)
        case cancelled
    }

    public let id: UUID
    public let kind: OperationKind
    public let archive: Archive?
    public var startedAt: Date = .now
    public var finishedAt: Date?
    public var progress: Double = 0
    public var currentFile: String = ""
    public var status: Status = .running
    public var warnings: [String] = []
    public var lastResult: RarResult?

    private let operation: RarRunner.Operation

    public init(kind: OperationKind, archive: Archive?, operation: RarRunner.Operation) {
        self.id = operation.id
        self.kind = kind
        self.archive = archive
        self.operation = operation
    }

    public func cancel() {
        guard status == .running else { return }
        operation.cancel()
        status = .cancelled
        finishedAt = .now
    }

    /// Spawn a detached Task that consumes events into this tracker. Returns when finished.
    public func consume() async {
        do {
            for try await event in operation.events {
                apply(event)
            }
        } catch let err as RarError {
            status = .failed(message: err.localizedDescription)
            finishedAt = .now
        } catch {
            status = .failed(message: error.localizedDescription)
            finishedAt = .now
        }
    }

    private func apply(_ event: ProgressEvent) {
        switch event {
        case .started:
            startedAt = .now
        case .fileStarted(let name):
            currentFile = name
        case .fileProgress:
            break // overallProgress drives the bar
        case .fileCompleted:
            break
        case .overallProgress(let fraction):
            progress = fraction
        case .warning(let msg):
            warnings.append(msg)
        case .finished(let result):
            lastResult = result
            progress = 1.0
            status = result.status == .success ? .succeeded : .succeeded
            finishedAt = .now
        }
    }

    public var elapsedFormatted: String {
        let end = finishedAt ?? .now
        let secs = end.timeIntervalSince(startedAt)
        if secs < 1 { return "<1s" }
        if secs < 60 { return String(format: "%.0fs", secs) }
        let m = Int(secs / 60), s = Int(secs.truncatingRemainder(dividingBy: 60))
        return "\(m)m \(s)s"
    }
}
