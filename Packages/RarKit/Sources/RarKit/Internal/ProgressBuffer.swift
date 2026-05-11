import Foundation

/// Stateful byte-stream → line-stream parser that handles `\r` (carriage return)
/// progress updates — `rar`/`unrar` use these to overwrite a single status line.
///
/// `feed(_:)` accepts raw bytes; `flush()` finalizes any pending content as a final line.
/// Yields `Line` values:
///   - `.update` for content that was overwritten (mid-progress like " 25%")
///   - `.committed` for content terminated with `\n` (final result like "OK")
struct ProgressBuffer {
    enum Line: Equatable {
        case update(String)
        case committed(String)
    }

    private var buffer: Data = .init()
    private var pendingProgressLine: String?

    mutating func feed(_ chunk: Data) -> [Line] {
        var out: [Line] = []
        for byte in chunk {
            switch byte {
            case 0x0A: // \n — commit current buffer as final line
                let line = decodeAndClear()
                if let progress = pendingProgressLine, !progress.isEmpty {
                    out.append(.update(progress))
                    pendingProgressLine = nil
                }
                out.append(.committed(line))
            case 0x0D: // \r — current buffer is a progress update, will be overwritten
                let line = decodeAndClear()
                if !line.isEmpty {
                    pendingProgressLine = line
                    out.append(.update(line))
                }
            default:
                buffer.append(byte)
            }
        }
        return out
    }

    /// Flush any trailing line that wasn't terminated with `\n`.
    mutating func flush() -> [Line] {
        let line = decodeAndClear()
        guard !line.isEmpty else { return [] }
        return [.committed(line)]
    }

    private mutating func decodeAndClear() -> String {
        defer { buffer.removeAll(keepingCapacity: true) }
        return String(data: buffer, encoding: .utf8) ?? String(decoding: buffer, as: UTF8.self)
    }
}
