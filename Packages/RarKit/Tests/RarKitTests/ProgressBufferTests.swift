import Testing
import Foundation
@testable import RarKit

@Suite("ProgressBuffer")
struct ProgressBufferTests {
    @Test("single line terminated by newline")
    func singleLine() {
        var buf = ProgressBuffer()
        let lines = buf.feed(Data("hello\n".utf8))
        #expect(lines == [.committed("hello")])
    }

    @Test("multiple lines in one chunk")
    func multipleLines() {
        var buf = ProgressBuffer()
        let lines = buf.feed(Data("foo\nbar\nbaz\n".utf8))
        #expect(lines == [.committed("foo"), .committed("bar"), .committed("baz")])
    }

    @Test("carriage return emits update then next chunk overwrites")
    func carriageReturn() {
        var buf = ProgressBuffer()
        let lines1 = buf.feed(Data("  5%\r".utf8))
        let lines2 = buf.feed(Data(" 10%\r".utf8))
        let lines3 = buf.feed(Data(" OK\n".utf8))
        #expect(lines1 == [.update("  5%")])
        #expect(lines2 == [.update(" 10%")])
        // lines3: pending progress is flushed THEN the committed line ends with "OK"
        #expect(lines3.count >= 1)
        #expect(lines3.last == .committed(" OK"))
    }

    @Test("flush yields trailing line without newline")
    func flushTrailing() {
        var buf = ProgressBuffer()
        _ = buf.feed(Data("partial".utf8))
        let lines = buf.flush()
        #expect(lines == [.committed("partial")])
    }

    @Test("empty flush yields nothing")
    func emptyFlush() {
        var buf = ProgressBuffer()
        let lines = buf.flush()
        #expect(lines == [])
    }
}
