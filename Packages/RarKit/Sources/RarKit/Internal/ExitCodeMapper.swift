import Foundation

/// Maps a rar/unrar exit code to a `RarResult` or throws a typed `RarError`.
/// Based on WinRAR docs + RAR 7.22 empirical behavior.
enum ExitCodeMapper {
    static func mapToResult(
        exitCode: Int32,
        stdout: String,
        stderr: String
    ) throws -> RarResult {
        switch exitCode {
        case 0:
            return RarResult(status: .success, stdout: stdout, stderr: stderr, exitCode: 0)
        case 1:
            return RarResult(status: .warning, stdout: stdout, stderr: stderr, exitCode: 1)
        case 2:
            throw RarError.corruptedArchive(stdout: stderr.isEmpty ? stdout : stderr)
        case 3:
            throw RarError.crcError
        case 4:
            throw RarError.lockedArchive
        case 5:
            throw RarError.writeError(stderr.isEmpty ? "disk full or permission denied" : stderr)
        case 6:
            throw RarError.openError(stderr.isEmpty ? "file not found" : stderr)
        case 7:
            throw RarError.userError(stderr.isEmpty ? "invalid arguments" : stderr)
        case 8:
            throw RarError.memoryError
        case 9:
            throw RarError.userError("file create error: \(stderr)")
        case 10:
            throw RarError.openError("no files matched")
        case 11:
            throw RarError.userError("wrong password")
        case 12:
            throw RarError.userError("read error: \(stderr)")
        case 255, -2: // 255 from Process exit, -2 sometimes from SIGINT
            throw RarError.userCancelled
        default:
            throw RarError.unknown(exitCode: exitCode, stderr: stderr)
        }
    }
}
