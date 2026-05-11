import Testing
import Foundation
@testable import RarKit

@Suite("RarListOutputToEntries")
struct RarListOutputToEntriesTests {
    @Test("parses sample unrar `l` output")
    func parsesSample() {
        let sample = """
        Archive: test.rar
        Details: RAR 5

         Attributes       Size     Date    Time   Name
        ----------- ----------  ---------- -----  ----
         -rw-r--r--         12  2026-05-11 14:38  hello.txt
         -rw-r--r--         12  2026-05-11 14:38  second.txt
        ----------- ----------  ---------- -----  ----
                            24                    2
        """
        let entries = RarListOutputToEntries.parse(sample)
        #expect(entries.count == 2)
        #expect(entries.first?.name == "hello.txt")
        #expect(entries.first?.uncompressedSize == 12)
        #expect(entries.last?.name == "second.txt")
    }

    @Test("empty/header-only stdout yields no entries")
    func emptyInput() {
        #expect(RarListOutputToEntries.parse("").isEmpty)
        #expect(RarListOutputToEntries.parse("Archive: foo.rar").isEmpty)
    }
}
