import Foundation

/// Outcome of a single RAR/UnRAR invocation.
public struct RarResult: Sendable, Equatable {
    public enum Status: Sendable, Equatable { case success, warning }

    public let status: Status
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(status: Status, stdout: String = "", stderr: String = "", exitCode: Int32 = 0) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}
