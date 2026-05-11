import Foundation

/// Dispatches archive extraction to the right backend based on format:
///   - `.rar` / `.sfx`  → bundled `unrar x`
///   - `.zip`            → system `/usr/bin/unzip`
///   - `.tar*`           → system `/usr/bin/tar -xf`
///
/// Returns the same `RarRunner.Operation` type used elsewhere so UI can bind
/// uniformly to progress events + cancellation.
public struct ArchiveExtractor: Sendable {
    public let runner: RarRunner

    public init(runner: RarRunner) {
        self.runner = runner
    }

    public enum OverwriteMode: Sendable {
        case ask, always, never, renameNew

        var unzipFlag: String {
            switch self {
            case .always:    return "-o"  // overwrite without prompt
            case .never:     return "-n"  // never overwrite
            case .renameNew: return "-o"  // unzip can't rename; closest is overwrite
            case .ask:       return "-n"  // default to never; UI surfaces conflicts
            }
        }
    }

    /// Extract `archive` into `destination`. Returns an `Operation` whose
    /// `events` stream emits progress + finally `.finished`.
    public func extract(
        archive: URL,
        to destination: URL,
        password: String? = nil,
        overwrite: OverwriteMode = .always
    ) -> RarRunner.Operation {
        let format = ArchiveFormat.detect(from: archive)
        switch format {
        case .rar, .sfx:
            let rarOverwrite: RarCommand.Overwrite = switch overwrite {
            case .ask:       .ask
            case .always:    .always
            case .never:     .never
            case .renameNew: .renameNew
            }
            return runner.runWithProgress(
                .extract(archive: archive, to: destination,
                         keepPaths: true,
                         overwrite: rarOverwrite,
                         password: password)
            )
        case .zip:
            return zipOperation(archive: archive, destination: destination,
                                password: password, overwrite: overwrite)
        case .tar, .tarGz, .tarBz2:
            return tarOperation(archive: archive, destination: destination)
        default:
            return immediateError(.userError("Extraction not supported for \(format.rawValue)"))
        }
    }

    // MARK: - ZIP

    private func zipOperation(
        archive: URL,
        destination: URL,
        password: String?,
        overwrite: OverwriteMode
    ) -> RarRunner.Operation {
        var args: [String] = []
        if let p = password { args.append(contentsOf: ["-P", p]) }
        args.append(overwrite.unzipFlag)
        args.append(archive.path)
        args.append(contentsOf: ["-d", destination.path])
        return spawnAndStream(
            executable: URL(fileURLWithPath: "/usr/bin/unzip"),
            arguments: args,
            destination: destination,
            parseFileLine: parseUnzipLine
        )
    }

    /// `  inflating: foo.txt` / `  extracting: foo.txt` / `   creating: dir/`
    private func parseUnzipLine(_ line: String) -> String? {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        let prefixes = ["inflating:", "extracting:", "creating:", "linking:"]
        for p in prefixes {
            if stripped.hasPrefix(p) {
                return stripped.dropFirst(p.count).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - TAR

    private func tarOperation(archive: URL, destination: URL) -> RarRunner.Operation {
        // tar auto-detects compression on macOS (libarchive). -v emits each name to stderr.
        let args = ["-xvf", archive.path, "-C", destination.path]
        return spawnAndStream(
            executable: URL(fileURLWithPath: "/usr/bin/tar"),
            arguments: args,
            destination: destination,
            parseFileLine: parseTarLine,
            progressOnStderr: true
        )
    }

    /// BSD tar prints `x filename` on extract; GNU prints just `filename`.
    private func parseTarLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        if trimmed.hasPrefix("x ") { return String(trimmed.dropFirst(2)) }
        return trimmed
    }

    // MARK: - Shared spawn pipeline

    private func spawnAndStream(
        executable: URL,
        arguments: [String],
        destination: URL,
        parseFileLine: @Sendable @escaping (String) -> String?,
        progressOnStderr: Bool = false
    ) -> RarRunner.Operation {
        let id = UUID()
        let (events, continuation) = AsyncThrowingStream<ProgressEvent, Error>.makeStream()

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = destination

        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        // Make sure dest exists
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let task = Task<Void, Never> {
            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
                return
            }
            continuation.yield(.started(totalFiles: nil))

            let progressHandle = progressOnStderr
                ? errPipe.fileHandleForReading
                : outPipe.fileHandleForReading
            let warningHandle = progressOnStderr
                ? outPipe.fileHandleForReading
                : errPipe.fileHandleForReading

            // Stream the line-emitting pipe
            async let drainProgress: Void = streamLines(handle: progressHandle) { line in
                if let name = parseFileLine(line) {
                    continuation.yield(.fileStarted(name: name))
                    continuation.yield(.fileCompleted(name: name, success: true))
                }
            }
            // Drain the other side for stderr warnings
            async let drainWarn: Void = streamLines(handle: warningHandle) { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    continuation.yield(.warning(trimmed))
                }
            }
            _ = await (drainProgress, drainWarn)

            process.waitUntilExit()
            let code = process.terminationStatus
            do {
                let result = try ExitCodeMapper.mapToResult(exitCode: code, stdout: "", stderr: "")
                continuation.yield(.finished(result))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }

        continuation.onTermination = { _ in
            task.cancel()
            if process.isRunning { process.terminate() }
        }

        return RarRunner.Operation(
            id: id,
            events: events,
            cancel: {
                task.cancel()
                if process.isRunning { process.terminate() }
            }
        )
    }

    private func streamLines(
        handle: FileHandle,
        onLine: @Sendable @escaping (String) -> Void
    ) async {
        var buffer = Data()
        while true {
            let chunk: Data = await Task.detached {
                handle.availableData
            }.value
            if chunk.isEmpty { break }
            buffer.append(chunk)
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = String(data: buffer[..<nl], encoding: .utf8) ?? ""
                buffer.removeSubrange(...nl)
                onLine(line)
            }
        }
        if !buffer.isEmpty,
           let line = String(data: buffer, encoding: .utf8) {
            onLine(line)
        }
    }

    // MARK: - Immediate-error helper

    private func immediateError(_ error: RarError) -> RarRunner.Operation {
        let (events, cont) = AsyncThrowingStream<ProgressEvent, Error>.makeStream()
        cont.finish(throwing: error)
        return RarRunner.Operation(id: UUID(), events: events, cancel: {})
    }
}
