import Foundation

/// Converts raw rar/unrar stdout lines into typed `ProgressEvent`s.
/// Stateful — tracks total file count + current file index for overall progress.
///
/// Uses plain string ops (no regex) to keep parser deterministic and avoid
/// Swift 6 strict-concurrency issues with `Regex<…>` not being Sendable.
struct RarOutputParser {
    private var buffer = ProgressBuffer()
    private(set) var totalFiles: Int?
    private(set) var filesCompleted: Int = 0
    private(set) var currentFile: String = ""
    private(set) var currentFilePercent: Double = 0

    mutating func feed(_ chunk: Data) -> [ProgressEvent] {
        var events: [ProgressEvent] = []
        for line in buffer.feed(chunk) {
            events.append(contentsOf: handle(line))
        }
        return events
    }

    mutating func flush() -> [ProgressEvent] {
        var events: [ProgressEvent] = []
        for line in buffer.flush() {
            events.append(contentsOf: handle(line))
        }
        return events
    }

    private mutating func handle(_ line: ProgressBuffer.Line) -> [ProgressEvent] {
        switch line {
        case .update(let raw):
            // Mid-stream `\r` update: typically "  42%" or "Extracting foo.txt   42%".
            // Try to pull a trailing percentage.
            if let pct = trailingPercent(raw) {
                currentFilePercent = pct
                if !currentFile.isEmpty {
                    return [.fileProgress(name: currentFile, percent: pct), overallEvent()]
                }
            }
            return []

        case .committed(let raw):
            let text = raw.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { return [] }
            var events: [ProgressEvent] = []

            // "Extracting <name>"  | "Creating <name>" | "Adding <name>" | "Testing <name>" | "Updating <name>"
            if let name = filenameAfterPrefix(text) {
                if name != currentFile {
                    if !currentFile.isEmpty {
                        events.append(.fileCompleted(name: currentFile, success: true))
                        filesCompleted += 1
                    }
                    currentFile = name
                    currentFilePercent = 0
                    events.append(.fileStarted(name: name))
                }
            }

            // Trailing "OK" / "FAILED"
            if !currentFile.isEmpty {
                if text.hasSuffix(" OK") || text == "OK" {
                    events.append(.fileCompleted(name: currentFile, success: true))
                    filesCompleted += 1
                    currentFile = ""
                    currentFilePercent = 0
                } else if text.hasSuffix(" FAILED") || text == "FAILED" {
                    events.append(.fileCompleted(name: currentFile, success: false))
                    filesCompleted += 1
                    currentFile = ""
                    currentFilePercent = 0
                }
            }

            if text.contains("All OK") {
                events.append(.overallProgress(fraction: 1.0))
            }

            return events
        }
    }

    // MARK: - Parsing helpers

    /// Returns the percentage if the line ends with a "<N>%" token.
    private func trailingPercent(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix("%") else { return nil }
        let body = trimmed.dropLast()
        // Walk backward through digits
        var i = body.endIndex
        var digits = ""
        while i > body.startIndex {
            let prev = body.index(before: i)
            let c = body[prev]
            if c.isNumber {
                digits.insert(c, at: digits.startIndex)
                i = prev
            } else {
                break
            }
        }
        guard let n = Double(digits), n >= 0, n <= 100 else { return nil }
        return n
    }

    private static let actionPrefixes = ["Extracting ", "Creating ", "Adding ", "Updating ", "Testing "]

    /// If a line starts with an action verb, returns the filename portion (trimming trailing % / OK / FAILED markers).
    private func filenameAfterPrefix(_ line: String) -> String? {
        for prefix in Self.actionPrefixes {
            guard line.hasPrefix(prefix) else { continue }
            var rest = String(line.dropFirst(prefix.count))
            // Strip trailing "  <N>%" / "OK" / "FAILED" / whitespace
            for tail in [" OK", " FAILED"] {
                if rest.hasSuffix(tail) {
                    rest = String(rest.dropLast(tail.count))
                }
            }
            if rest.hasSuffix("%") {
                // remove "  <N>%" trailing percent
                var idx = rest.endIndex
                idx = rest.index(before: idx) // drop %
                while idx > rest.startIndex, rest[rest.index(before: idx)].isNumber {
                    idx = rest.index(before: idx)
                }
                while idx > rest.startIndex, rest[rest.index(before: idx)].isWhitespace {
                    idx = rest.index(before: idx)
                }
                rest = String(rest[..<idx])
            }
            let name = rest.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    private func overallEvent() -> ProgressEvent {
        if let total = totalFiles, total > 0 {
            let frac = (Double(filesCompleted) + currentFilePercent / 100.0) / Double(total)
            return .overallProgress(fraction: min(1.0, max(0, frac)))
        }
        return .overallProgress(fraction: currentFilePercent / 100.0)
    }
}
