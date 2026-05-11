import Testing
import Foundation
@testable import RarKit

@Suite("RarCommand.create — relative paths")
struct RarCreateRelativePathsTests {
    @Test("single file uses its parent dir as cwd + bare name")
    func singleFile() {
        let cmd = RarCommand.create(
            archive: URL(fileURLWithPath: "/tmp/out.rar"),
            sources: [URL(fileURLWithPath: "/Users/chou/Downloads/oc.jpg")]
        )
        #expect(cmd.workingDirectory?.path == "/Users/chou/Downloads")
        #expect(cmd.files == ["oc.jpg"])
    }

    @Test("multiple files in same folder → cwd = that folder")
    func sameFolder() {
        let cmd = RarCommand.create(
            archive: URL(fileURLWithPath: "/tmp/out.rar"),
            sources: [
                URL(fileURLWithPath: "/Users/chou/Pics/a.jpg"),
                URL(fileURLWithPath: "/Users/chou/Pics/b.jpg"),
            ]
        )
        #expect(cmd.workingDirectory?.path == "/Users/chou/Pics")
        #expect(cmd.files == ["a.jpg", "b.jpg"])
    }

    @Test("files in sibling folders → cwd = common ancestor")
    func siblingFolders() {
        let cmd = RarCommand.create(
            archive: URL(fileURLWithPath: "/tmp/out.rar"),
            sources: [
                URL(fileURLWithPath: "/Users/chou/Pics/a.jpg"),
                URL(fileURLWithPath: "/Users/chou/Docs/b.txt"),
            ]
        )
        #expect(cmd.workingDirectory?.path == "/Users/chou")
        #expect(cmd.files.sorted() == ["Docs/b.txt", "Pics/a.jpg"])
    }

    @Test("argv emitted by builder uses relative names + cwd")
    func argvCorrect() {
        let cmd = RarCommand.create(
            archive: URL(fileURLWithPath: "/tmp/out.rar"),
            sources: [URL(fileURLWithPath: "/Users/chou/Downloads/oc.jpg")]
        )
        let argv = ArgvBuilder.build(cmd)
        #expect(argv.first == "a")
        #expect(argv.contains("/tmp/out.rar"))
        #expect(argv.contains("oc.jpg"))
        #expect(!argv.contains("/Users/chou/Downloads/oc.jpg"))
    }
}
