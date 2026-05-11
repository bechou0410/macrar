import Foundation

/// Parses the columnar output of `/usr/bin/unzip -l <archive>` into `[ArchiveEntry]`.
///
/// Format:
/// ```
/// Archive:  test.zip
///   Length      Date    Time    Name
/// ---------  ---------- -----   ----
///        12  2026-05-11 14:38   hello.txt
///        12  2026-05-11 14:38   second.txt
/// ---------                     -------
///        24                     2 files
/// ```
public enum ZipListParser {
    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy-MM-dd HH:mm",   // ISO-style
            "MM-dd-yyyy HH:mm",   // macOS unzip with en_US locale
            "dd-MM-yyyy HH:mm",   // some other locales
        ]
        return formats.map { fmt in
            let f = DateFormatter()
            f.dateFormat = fmt
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            return f
        }
    }()

    private static func parseDate(_ s: String) -> Date? {
        for f in dateFormatters {
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    public static func parse(_ stdout: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        var inListing = false
        for raw in stdout.components(separatedBy: .newlines) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("---") {
                inListing.toggle()
                continue
            }
            guard inListing else { continue }
            if let entry = parseRow(raw) {
                entries.append(entry)
            }
        }
        return entries
    }

    private static func parseRow(_ raw: String) -> ArchiveEntry? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard tokens.count >= 4 else { return nil }
        guard let size = Int64(tokens[0]) else { return nil }
        let dateStr = "\(tokens[1]) \(tokens[2])"
        let name = tokens.dropFirst(3).joined(separator: " ")
        let isDirectory = name.hasSuffix("/")
        let lastComponent = name.split(separator: "/").last.map(String.init) ?? name
        return ArchiveEntry(
            path: name,
            name: lastComponent,
            uncompressedSize: size,
            compressedSize: size,
            modified: parseDate(dateStr),
            crc32: "",
            attributes: "",
            isDirectory: isDirectory,
            isEncrypted: false
        )
    }
}
