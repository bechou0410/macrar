import Foundation

/// JSON-file-backed persistence for the recents list.
/// Stored at `~/Library/Application Support/MacRAR/recents.json`.
@MainActor
public final class RecentsStore {
    public static let maxEntries = 30
    private let fileURL: URL

    public init(fileURL: URL? = nil) {
        if let url = fileURL {
            self.fileURL = url
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("MacRAR", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            self.fileURL = dir.appendingPathComponent("recents.json")
        }
    }

    public func load() -> [RecentArchive] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? JSONDecoder().decode([RecentArchive].self, from: data)
        else { return [] }
        // Drop entries whose files have disappeared.
        return items.filter { FileManager.default.fileExists(atPath: $0.url.path) }
    }

    public func save(_ items: [RecentArchive]) {
        let bounded = Array(items.prefix(Self.maxEntries))
        guard let data = try? JSONEncoder().encode(bounded) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Insert/promote `archive` to the front of the list. Returns the new ordered list.
    public func promote(_ archive: RecentArchive, in existing: [RecentArchive]) -> [RecentArchive] {
        var list = existing.filter { $0.url != archive.url }
        list.insert(archive, at: 0)
        return Array(list.prefix(Self.maxEntries))
    }
}
