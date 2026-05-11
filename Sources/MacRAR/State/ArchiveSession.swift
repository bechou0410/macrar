import Foundation
import Observation
import RarKit

/// Live state for one opened archive: metadata, entries, current selection + filter.
@MainActor
@Observable
public final class ArchiveSession: Identifiable {
    public let id = UUID()
    public let archive: Archive
    public var entries: [ArchiveEntry] = []
    public var tree: ArchiveNode = ArchiveNode(id: "/", name: "", children: [])
    public var selectedEntryIDs: Set<ArchiveEntry.ID> = []
    public var search: String = ""
    public var sortKey: SortKey = .name
    public var ascending: Bool = true

    public init(archive: Archive, entries: [ArchiveEntry]) {
        self.archive = archive
        self.replace(entries: entries)
    }

    public func replace(entries: [ArchiveEntry]) {
        self.entries = entries
        self.tree = ArchiveNode.build(from: entries)
    }

    public var filteredEntries: [ArchiveEntry] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        let base = needle.isEmpty
            ? entries
            : entries.filter { $0.path.lowercased().contains(needle) }
        return base.sorted(by: comparator)
    }

    private var comparator: (ArchiveEntry, ArchiveEntry) -> Bool {
        let asc = ascending
        switch sortKey {
        case .name:
            return { asc ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                         : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .size:
            return { asc ? $0.uncompressedSize < $1.uncompressedSize
                         : $0.uncompressedSize > $1.uncompressedSize }
        case .compressed:
            return { asc ? $0.compressedSize < $1.compressedSize
                         : $0.compressedSize > $1.compressedSize }
        case .ratio:
            return { asc ? $0.compressionRatio < $1.compressionRatio
                         : $0.compressionRatio > $1.compressionRatio }
        case .modified:
            return { lhs, rhs in
                let l = lhs.modified ?? .distantPast, r = rhs.modified ?? .distantPast
                return asc ? l < r : l > r
            }
        }
    }

    public enum SortKey: String, Sendable, CaseIterable, Identifiable {
        case name, size, compressed, ratio, modified
        public var id: String { rawValue }
    }
}
