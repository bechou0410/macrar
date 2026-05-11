import Testing
import Foundation
@testable import RarKit

@Suite("ArgvBuilder")
struct ArgvBuilderTests {
    let archive = URL(fileURLWithPath: "/tmp/foo.rar")

    @Test("extract with paths + assumeYes + overwrite=always")
    func extractAlways() {
        let cmd = RarCommand.extract(
            archive: archive,
            to: URL(fileURLWithPath: "/tmp/out"),
            overwrite: .always
        )
        let argv = ArgvBuilder.build(cmd)
        #expect(argv == ["x", "-y", "-o+", "/tmp/foo.rar", "/tmp/out/"])
    }

    @Test("extract flat (no paths)")
    func extractFlat() {
        let cmd = RarCommand.extract(
            archive: archive,
            to: URL(fileURLWithPath: "/tmp/out"),
            keepPaths: false
        )
        let argv = ArgvBuilder.build(cmd)
        #expect(argv.first == "e")
        #expect(argv.last == "/tmp/out/")
    }

    @Test("list technical")
    func listTechnical() {
        let cmd = RarCommand.list(archive: archive, technical: true)
        let argv = ArgvBuilder.build(cmd)
        #expect(argv == ["lt", "-y", "/tmp/foo.rar"])
    }

    @Test("create with compression + solid + recovery + password (uses relative paths)")
    func createFull() {
        let cmd = RarCommand.create(
            archive: archive,
            sources: [URL(fileURLWithPath: "/tmp/file1.txt"), URL(fileURLWithPath: "/tmp/file2.txt")],
            compression: 5,
            solid: true,
            recoveryPercent: 3,
            password: "secret"
        )
        let argv = ArgvBuilder.build(cmd)
        #expect(argv[0] == "a")
        #expect(argv.contains("-m5"))
        #expect(argv.contains("-s"))
        #expect(argv.contains("-rr3p"))
        #expect(argv.contains("-psecret"))
        #expect(argv.contains("/tmp/foo.rar"))
        // Sources stored relative to common parent (/tmp); avoids absolute-path leakage in archive entries.
        #expect(argv.contains("file1.txt"))
        #expect(argv.contains("file2.txt"))
        #expect(cmd.workingDirectory?.path == "/tmp")
    }

    @Test("create with encrypted headers uses -hp")
    func createWithEncryptHeaders() {
        let cmd = RarCommand.create(
            archive: archive,
            sources: [URL(fileURLWithPath: "/tmp/x.txt")],
            password: "secret",
            encryptHeaders: true
        )
        let argv = ArgvBuilder.build(cmd)
        #expect(argv.contains("-hpsecret"))
        #expect(!argv.contains("-psecret"))
    }

    @Test("test command")
    func testCommand() {
        let cmd = RarCommand.test(archive: archive)
        let argv = ArgvBuilder.build(cmd)
        #expect(argv == ["t", "-y", "/tmp/foo.rar"])
    }
}
