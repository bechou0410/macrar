import Foundation

/// Parses the verbose output of `/usr/bin/tar -tvf <archive>` into `[ArchiveEntry]`.
///
/// Format (BSD tar on macOS):
/// ```
/// -rw-r--r--  0 chou   staff    12 May 11 14:38 hello.txt
/// drwxr-xr-x  0 chou   staff     0 May 11 14:38 folder/
/// ```
public enum TarListParser {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        // BSD tar emits "MMM d HH:mm" for current year, "MMM d  yyyy" for older
        f.dateFormat = "MMM d HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    private static let oldDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public static func parse(_ stdout: String) -> [ArchiveEntry] {
        var entries: [ArchiveEntry] = []
        for raw in stdout.components(separatedBy: .newlines) {
            if let entry = parseRow(raw) {
                entries.append(entry)
            }
        }
        return entries
    }

    private static func parseRow(_ raw: String) -> ArchiveEntry? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }
        let tokens = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard tokens.count >= 8 else { return nil }
        // Layout: perms links owner group size MonDay TimeOrYear name(+)
        let perms = String(tokens[0])
        guard !perms.isEmpty, "-dlsbcp".contains(perms.first!) else { return nil }
        guard let size = Int64(tokens[4]) else { return nil }
        let month = String(tokens[5])
        let day   = String(tokens[6])
        let timeOrYear = String(tokens[7])
        let dateStr1 = "\(month) \(day) \(timeOrYear)"
        let modified = dateFormatter.date(from: dateStr1) ?? oldDateFormatter.date(from: dateStr1)
        let name = tokens.dropFirst(8).joined(separator: " ")
        let cleanName = name.hasSuffix("/") ? String(name.dropLast()) : name
        let lastComponent = cleanName.split(separator: "/").last.map(String.init) ?? cleanName
        return ArchiveEntry(
            path: cleanName,
            name: lastComponent,
            uncompressedSize: size,
            compressedSize: size,
            modified: modified,
            crc32: "",
            attributes: perms,
            isDirectory: perms.first == "d" || name.hasSuffix("/"),
            isEncrypted: false
        )
    }
}
