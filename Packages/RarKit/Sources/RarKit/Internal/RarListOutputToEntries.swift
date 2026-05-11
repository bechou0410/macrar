import Foundation

/// Parses the columnar output of `unrar l <archive>` into `[ArchiveEntry]`.
///
/// Format (RAR 7.x):
/// ```
/// Archive: test.rar
/// Details: RAR 5
///
///  Attributes       Size     Date    Time   Name
/// ----------- ----------  ---------- -----  ----
///  -rw-r--r--         12  2026-05-11 14:38  hello.txt
/// ----------- ----------  ---------- -----  ----
///                     24                    2
/// ```
public enum RarListOutputToEntries {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    public static func parse(_ stdout: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var insideListing = false
        for rawLine in stdout.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .init(charactersIn: " "))
            if line.hasPrefix("---") {
                insideListing.toggle()
                continue
            }
            guard insideListing else { continue }
            if line.isEmpty { continue }
            // Skip total-line at end (no attributes prefix)
            if let entry = parseRow(rawLine) {
                entries.append(entry)
            }
        }
        return entries
    }

    /// Splits a row preserving the trailing name (which may contain spaces).
    /// Layout: `<attr 11ch>  <size>  <date>  <time>  <name…>`
    private static func parseRow(_ raw: String) -> ArchiveEntry? {
        let trimmed = raw.trimmingCharacters(in: .init(charactersIn: " "))
        guard let firstChar = trimmed.first,
              "*.dlABCDEFGHIJKLMNOPQRSTUVWXYZ-".contains(firstChar) else { return nil }

        // Pull columns by greedy whitespace split for the first 5 tokens, then rejoin tail as name.
        let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard tokens.count >= 5 else { return nil }
        let attrs = String(tokens[0])
        guard let size = Int64(tokens[1]) else { return nil }
        let dateStr = "\(tokens[2]) \(tokens[3])"
        let nameTokens = tokens.dropFirst(4)
        let name = nameTokens.joined(separator: " ")

        let modified = dateFormatter.date(from: dateStr)
        let isDirectory = attrs.first == "d" || attrs.contains(where: { $0 == "D" })
        let isEncrypted = raw.contains("*")  // unrar marks encrypted files with leading * in listing

        let lastComponent = name.split(separator: "/").last.map(String.init) ?? name

        return ArchiveEntry(
            path: name,
            name: lastComponent,
            uncompressedSize: size,
            compressedSize: size,                // `l` doesn't include compressed; `lt` does
            modified: modified,
            crc32: "",
            attributes: attrs,
            isDirectory: isDirectory,
            isEncrypted: isEncrypted
        )
    }
}
