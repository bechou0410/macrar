import Testing
@testable import RarKit

@Suite("ExitCodeMapper")
struct ExitCodeMapperTests {
    @Test("success") func success() throws {
        let r = try ExitCodeMapper.mapToResult(exitCode: 0, stdout: "All OK", stderr: "")
        #expect(r.status == .success)
    }

    @Test("warning") func warning() throws {
        let r = try ExitCodeMapper.mapToResult(exitCode: 1, stdout: "x", stderr: "minor")
        #expect(r.status == .warning)
    }

    @Test("corrupted") func corrupted() {
        #expect(throws: RarError.self) {
            try ExitCodeMapper.mapToResult(exitCode: 2, stdout: "", stderr: "bad")
        }
    }

    @Test("wrong password") func wrongPassword() {
        #expect(throws: RarError.userError("wrong password")) {
            try ExitCodeMapper.mapToResult(exitCode: 11, stdout: "", stderr: "")
        }
    }

    @Test("user cancelled (255)") func cancelled() {
        #expect(throws: RarError.userCancelled) {
            try ExitCodeMapper.mapToResult(exitCode: 255, stdout: "", stderr: "")
        }
    }

    @Test("memory error") func memoryError() {
        #expect(throws: RarError.memoryError) {
            try ExitCodeMapper.mapToResult(exitCode: 8, stdout: "", stderr: "")
        }
    }
}
