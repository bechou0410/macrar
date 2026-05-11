import Foundation

/// User-controlled options for creating a new archive.
public struct CreateOptions: Sendable, Equatable {
    public var compressionLevel: Int = 3           // 0–5 (-m0..-m5)
    public var dictionarySize: DictionarySize = .mb16
    public var solidArchive: Bool = false           // -s
    public var recoveryRecordPercent: Int = 0       // 0 = disabled; 1–10 → -rr<N>p
    public var volumeSizeBytes: Int64? = nil        // nil = single-volume; else -v<n>b
    public var password: String = ""
    public var encryptHeaders: Bool = false         // -hp instead of -p
    public var sfx: Bool = false                    // -sfx
    public var multiThreaded: Int = ProcessInfo.processInfo.activeProcessorCount
    public var comment: String = ""

    public init() {}

    public var passwordOrNil: String? { password.isEmpty ? nil : password }
    public var recoveryRecordOrNil: Int? { recoveryRecordPercent > 0 ? recoveryRecordPercent : nil }

    public enum DictionarySize: Int, Sendable, CaseIterable, Identifiable {
        case mb1 = 1, mb4 = 4, mb16 = 16, mb64 = 64, mb256 = 256, mb1024 = 1024
        public var id: Int { rawValue }
        public var label: String { "\(rawValue) MB" }
    }
}
