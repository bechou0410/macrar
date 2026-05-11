import Foundation

/// Spawns a rar/unrar process with async streaming output.
/// Implementation uses Foundation `Process` + Pipe; wraps stdout/stderr as `AsyncStream<Data>`.
struct RarProcess {
    let executable: URL
    let arguments: [String]
    let workingDirectory: URL?

    struct Streams {
        let stdout: AsyncStream<Data>
        let stderr: AsyncStream<Data>
        /// Awaits process exit. Returns termination code (signed; SIGTERM gives 15, etc.)
        let waitForExit: @Sendable () async -> Int32
        /// Send SIGTERM to the child.
        let terminate: @Sendable () -> Void
    }

    /// Launches the process. Throws if executable doesn't exist or fails to start.
    func launch() throws -> Streams {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        if let cwd = workingDirectory {
            process.currentDirectoryURL = cwd
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        // No interactive stdin — rar prompts via tty; we feed passwords via -p<pwd>.
        process.standardInput = FileHandle.nullDevice

        let stdoutStream = makeStream(handle: stdoutPipe.fileHandleForReading)
        let stderrStream = makeStream(handle: stderrPipe.fileHandleForReading)

        try process.run()

        let waitForExit: @Sendable () async -> Int32 = {
            await withCheckedContinuation { continuation in
                let queue = DispatchQueue.global(qos: .userInitiated)
                queue.async {
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                }
            }
        }

        let terminate: @Sendable () -> Void = {
            if process.isRunning {
                process.terminate()
            }
        }

        return Streams(
            stdout: stdoutStream,
            stderr: stderrStream,
            waitForExit: waitForExit,
            terminate: terminate
        )
    }

    private func makeStream(handle: FileHandle) -> AsyncStream<Data> {
        AsyncStream { continuation in
            handle.readabilityHandler = { fh in
                let data = fh.availableData
                if data.isEmpty {
                    fh.readabilityHandler = nil
                    continuation.finish()
                } else {
                    continuation.yield(data)
                }
            }
            continuation.onTermination = { _ in
                handle.readabilityHandler = nil
            }
        }
    }
}
