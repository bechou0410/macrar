import Foundation

/// Top-level async API for invoking rar/unrar.
///
/// Two entry points:
///   - `run(_:)` — convenience for blocking ops (list, test, version). Returns final result.
///   - `runWithProgress(_:)` — returns an `Operation` exposing an `AsyncThrowingStream<ProgressEvent>`
///     for long-running ops with live UI updates and cancel support.
public actor RarRunner {
    private let binaries: BinaryLocator

    public init(binaries: BinaryLocator) {
        self.binaries = binaries
    }

    public nonisolated var rarAvailable: Bool { binaries.rarAvailable }
    public nonisolated var rarURL: URL? { binaries.rarURL }
    public nonisolated var unrarURL: URL { binaries.unrarURL }

    /// Run a command and collect the full output. Use for short-lived ops.
    public func run(_ command: RarCommand) async throws -> RarResult {
        let executable = try resolveExecutable(for: command.tool)
        let argv = ArgvBuilder.build(command)

        let process = RarProcess(
            executable: executable,
            arguments: argv,
            workingDirectory: command.workingDirectory
        )
        let streams = try process.launch()

        async let stdoutData: Data = collect(streams.stdout)
        async let stderrData: Data = collect(streams.stderr)
        let exit = await streams.waitForExit()
        let stdout = String(data: await stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: await stderrData, encoding: .utf8) ?? ""

        return try ExitCodeMapper.mapToResult(exitCode: exit, stdout: stdout, stderr: stderr)
    }

    /// Run a command and stream progress events. Caller may cancel via the returned `Operation`.
    public nonisolated func runWithProgress(_ command: RarCommand) -> Operation {
        let id = UUID()
        let (events, continuation) = AsyncThrowingStream<ProgressEvent, Error>.makeStream()

        let task = Task<Void, Never> {
            do {
                let executable = try await self.resolveExecutable(for: command.tool)
                let argv = ArgvBuilder.build(command)
                let process = RarProcess(
                    executable: executable,
                    arguments: argv,
                    workingDirectory: command.workingDirectory
                )
                let streams = try process.launch()

                // stderr capture for diagnostics; emit warnings live.
                let stderrTask = Task {
                    var collected = Data()
                    for await chunk in streams.stderr {
                        collected.append(chunk)
                        if let s = String(data: chunk, encoding: .utf8),
                           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            continuation.yield(.warning(s.trimmingCharacters(in: .whitespacesAndNewlines)))
                        }
                    }
                    return collected
                }

                // Stream stdout through the parser.
                var parser = RarOutputParser()
                var stdoutCollected = Data()
                for await chunk in streams.stdout {
                    stdoutCollected.append(chunk)
                    if Task.isCancelled {
                        streams.terminate()
                        continuation.finish(throwing: RarError.userCancelled)
                        return
                    }
                    for event in parser.feed(chunk) {
                        continuation.yield(event)
                    }
                }
                for event in parser.flush() {
                    continuation.yield(event)
                }

                let exit = await streams.waitForExit()
                let stderr = String(data: await stderrTask.value, encoding: .utf8) ?? ""
                let stdout = String(data: stdoutCollected, encoding: .utf8) ?? ""

                let result = try ExitCodeMapper.mapToResult(exitCode: exit, stdout: stdout, stderr: stderr)
                continuation.yield(.finished(result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
        }

        return Operation(id: id, events: events, cancel: { task.cancel() })
    }

    public struct Operation: Sendable {
        public let id: UUID
        public let events: AsyncThrowingStream<ProgressEvent, Error>
        private let _cancel: @Sendable () -> Void

        public init(id: UUID, events: AsyncThrowingStream<ProgressEvent, Error>, cancel: @escaping @Sendable () -> Void) {
            self.id = id
            self.events = events
            self._cancel = cancel
        }

        public func cancel() { _cancel() }
    }

    // MARK: - Internals

    private func resolveExecutable(for tool: RarCommand.Tool) throws -> URL {
        switch tool {
        case .unrar: return binaries.unrarURL
        case .rar:
            guard let rar = binaries.rarURL else { throw RarError.rarMissing }
            return rar
        }
    }

    private func collect(_ stream: AsyncStream<Data>) async -> Data {
        var out = Data()
        for await chunk in stream { out.append(chunk) }
        return out
    }
}
