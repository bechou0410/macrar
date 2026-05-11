import Testing
@testable import RarKit

@Suite("ZipListParser")
struct ZipListParserTests {
    @Test("parses ISO-date unzip output")
    func parsesISODate() {
        let sample = """
        Archive:  test.zip
          Length      Date    Time    Name
        ---------  ---------- -----   ----
               12  2026-05-11 14:38   hello.txt
               24  2026-05-11 14:38   folder/inner.txt
        ---------                     -------
               36                     2 files
        """
        let entries = ZipListParser.parse(sample)
        #expect(entries.count == 2)
        #expect(entries[0].uncompressedSize == 12)
    }

    @Test("parses US-locale unzip output (MM-dd-yyyy)")
    func parsesUSDate() {
        let sample = """
        Archive:  test.zip
          Length      Date    Time    Name
        ---------  ---------- -----   ----
                6  05-11-2026 15:26   a.txt
                5  05-11-2026 15:26   sub/c.txt
        ---------                     -------
               11                     2 files
        """
        let entries = ZipListParser.parse(sample)
        #expect(entries.count == 2)
        #expect(entries[0].path == "a.txt")
        #expect(entries[1].path == "sub/c.txt")
        #expect(entries[0].modified != nil)
    }
}

@Suite("TarListParser")
struct TarListParserTests {
    @Test("parses BSD tar -tvf output")
    func parsesBsdTar() {
        let sample = """
        -rw-r--r--  0 chou   staff      12 May 11 14:38 hello.txt
        drwxr-xr-x  0 chou   staff       0 May 11 14:38 folder/
        -rw-r--r--  0 chou   staff      24 May 11 14:38 folder/inner.txt
        """
        let entries = TarListParser.parse(sample)
        #expect(entries.count == 3)
        #expect(entries[0].path == "hello.txt")
        #expect(entries[0].uncompressedSize == 12)
        #expect(entries[1].isDirectory)
        #expect(entries[2].path == "folder/inner.txt")
    }
}
