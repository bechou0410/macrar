import Foundation

/// Hierarchical wrapper around `ArchiveEntry` for `SwiftUI.OutlineGroup` rendering.
/// A node either holds an `ArchiveEntry` (file) or is a synthetic directory grouping children.
public struct ArchiveNode: Identifiable, Hashable, Sendable {
    public let id: String                   // full path; unique
    public let name: String
    public let entry: ArchiveEntry?         // nil → synthetic directory node
    public var children: [ArchiveNode]?     // nil → leaf

    public init(id: String, name: String, entry: ArchiveEntry? = nil, children: [ArchiveNode]? = nil) {
        self.id = id
        self.name = name
        self.entry = entry
        self.children = children
    }

    public var isDirectory: Bool {
        children != nil || (entry?.isDirectory ?? false)
    }

    /// Build a tree from a flat list of entries. Sorts directories first, then files; alphabetical.
    public static func build(from entries: [ArchiveEntry]) -> ArchiveNode {
        var root = MutableNode(name: "", path: "")
        for entry in entries {
            let parts = entry.path.split(separator: "/").map(String.init)
            guard !parts.isEmpty else { continue }
            root.insert(entry: entry, pathComponents: parts[...], pathPrefix: "")
        }
        return root.toImmutable()
    }
}

private final class MutableNode {
    let name: String
    let path: String
    var entry: ArchiveEntry?
    var children: [String: MutableNode] = [:]

    init(name: String, path: String, entry: ArchiveEntry? = nil) {
        self.name = name
        self.path = path
        self.entry = entry
    }

    func insert(entry: ArchiveEntry, pathComponents: ArraySlice<String>, pathPrefix: String) {
        guard let head = pathComponents.first else { return }
        let newPrefix = pathPrefix.isEmpty ? head : "\(pathPrefix)/\(head)"
        if pathComponents.count == 1 {
            // Leaf — direct child of self
            let child = MutableNode(name: head, path: newPrefix, entry: entry)
            children[head] = child
        } else {
            let child = children[head] ?? MutableNode(name: head, path: newPrefix)
            child.insert(entry: entry, pathComponents: pathComponents.dropFirst(), pathPrefix: newPrefix)
            children[head] = child
        }
    }

    func toImmutable() -> ArchiveNode {
        let sortedKids = children.values.sorted { a, b in
            let aDir = a.entry?.isDirectory ?? !a.children.isEmpty
            let bDir = b.entry?.isDirectory ?? !b.children.isEmpty
            if aDir != bDir { return aDir }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
        let kids = sortedKids.map { $0.toImmutable() }
        return ArchiveNode(
            id: path.isEmpty ? "/" : path,
            name: name,
            entry: entry,
            children: kids.isEmpty ? (entry == nil ? [] : nil) : kids
        )
    }
}
