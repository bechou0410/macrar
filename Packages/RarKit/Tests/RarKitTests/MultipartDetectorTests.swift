import Testing
import Foundation
@testable import RarKit

@Suite("MultipartDetector")
struct MultipartDetectorTests {
    @Test("single .rar reports not multipart")
    func single() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("foo.rar")
        try Data().write(to: url)
        let r = MultipartDetector.detect(url)
        #expect(!r.isMultipart)
        #expect(r.firstVolume == url)
        #expect(r.parts == [url])
    }

    @Test("partNN.rar resolves to part01.rar")
    func modernParts() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let part1 = dir.appendingPathComponent("foo.part01.rar")
        let part2 = dir.appendingPathComponent("foo.part02.rar")
        let part3 = dir.appendingPathComponent("foo.part03.rar")
        for u in [part1, part2, part3] { try Data().write(to: u) }
        let r = MultipartDetector.detect(part2)
        #expect(r.isMultipart)
        #expect(r.firstVolume == part1)
        #expect(r.parts.count == 3)
    }

    @Test("legacy .r00/.r01 siblings of .rar")
    func legacyParts() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let main = dir.appendingPathComponent("foo.rar")
        let r00  = dir.appendingPathComponent("foo.r00")
        let r01  = dir.appendingPathComponent("foo.r01")
        for u in [main, r00, r01] { try Data().write(to: u) }
        let r = MultipartDetector.detect(r00)
        #expect(r.isMultipart)
        #expect(r.firstVolume == main)
        #expect(r.parts.count == 3)
    }

    private func makeTempDir() throws -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("rarkit-mp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
