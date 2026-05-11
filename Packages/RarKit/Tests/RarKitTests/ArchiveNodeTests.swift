import Testing
import Foundation
@testable import RarKit

@Suite("ArchiveNode tree builder")
struct ArchiveNodeTests {
    func entry(_ path: String, dir: Bool = false) -> ArchiveEntry {
        ArchiveEntry(
            path: path, name: (path as NSString).lastPathComponent,
            uncompressedSize: 10, compressedSize: 5,
            modified: nil, isDirectory: dir
        )
    }

    @Test("flat list builds flat children")
    func flatList() {
        let tree = ArchiveNode.build(from: [entry("a.txt"), entry("b.txt"), entry("c.txt")])
        let kids = tree.children ?? []
        #expect(kids.count == 3)
        #expect(kids.map(\.name) == ["a.txt", "b.txt", "c.txt"])
    }

    @Test("nested paths group into directories")
    func nested() {
        let entries = [
            entry("docs/intro.md"),
            entry("docs/api/list.md"),
            entry("docs/api/get.md"),
            entry("readme.txt"),
        ]
        let tree = ArchiveNode.build(from: entries)
        let kids = tree.children ?? []
        // Directories first, then files
        #expect(kids.count == 2)
        #expect(kids[0].name == "docs")
        #expect(kids[1].name == "readme.txt")
        let docs = kids[0].children ?? []
        #expect(docs.contains(where: { $0.name == "api" }))
        #expect(docs.contains(where: { $0.name == "intro.md" }))
        let api = docs.first(where: { $0.name == "api" })?.children ?? []
        #expect(api.map(\.name).sorted() == ["get.md", "list.md"])
    }
}
