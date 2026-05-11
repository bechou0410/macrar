import Foundation

/// Errors surfaced by RarKit. Map directly to UI alerts.
public enum RarError: Error, Sendable, Equatable {
    /// Bundled `unrar` binary missing from the app bundle (should never happen in shipped builds).
    case unrarMissing
    /// `rar` binary not found in $PATH / common install locations; user must install separately.
    case rarMissing
    /// Archive data corrupted or unreadable.
    case corruptedArchive(stdout: String)
    /// CRC mismatch during unpacking.
    case crcError
    /// Archive is locked (rar `k` command applied); modifications refused.
    case lockedArchive
    /// Disk full or write permission denied.
    case writeError(String)
    /// Source file not found or permission denied.
    case openError(String)
    /// Bad CLI arguments / unsupported operation.
    case userError(String)
    /// Process out of memory.
    case memoryError
    /// User cancelled (SIGTERM via cancel button).
    case userCancelled
    /// Unknown exit code; raw stderr captured for diagnostics.
    case unknown(exitCode: Int32, stderr: String)
}

extension RarError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unrarMissing:           "Bundled unrar binary is missing."
        case .rarMissing:             "The RAR CLI tool is not installed. Install it via Homebrew (brew install rar) or from rarlab.com."
        case .corruptedArchive:       "The archive is corrupted or unreadable."
        case .crcError:               "Checksum verification failed during extraction."
        case .lockedArchive:          "The archive is locked and cannot be modified."
        case .writeError(let s):      "Write failed: \(s)"
        case .openError(let s):       "Could not open file: \(s)"
        case .userError(let s):       "Operation failed: \(s)"
        case .memoryError:            "Not enough memory to complete the operation."
        case .userCancelled:          "Operation cancelled."
        case .unknown(let code, _):   "Unknown error (exit code \(code))."
        }
    }
}
