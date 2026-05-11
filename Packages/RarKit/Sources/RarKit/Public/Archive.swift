import Foundation

/// Metadata about an archive container (sum of entries).
public struct Archive: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let url: URL                     // first volume URL if multipart
    public let format: ArchiveFormat
    public let isMultipart: Bool
    public let parts: [URL]                 // ordered volumes (single-volume = [url])
    public let isHeaderEncrypted: Bool      // true → password needed even to list
    public let isLocked: Bool               // `k` command applied; cannot modify
    public let hasRecoveryRecord: Bool
    public let entryCount: Int
    public let totalUncompressedBytes: Int64
    public let totalCompressedBytes: Int64

    public init(
        id: UUID = UUID(),
        url: URL,
        format: ArchiveFormat,
        isMultipart: Bool = false,
        parts: [URL] = [],
        isHeaderEncrypted: Bool = false,
        isLocked: Bool = false,
        hasRecoveryRecord: Bool = false,
        entryCount: Int = 0,
        totalUncompressedBytes: Int64 = 0,
        totalCompressedBytes: Int64 = 0
    ) {
        self.id = id
        self.url = url
        self.format = format
        self.isMultipart = isMultipart
        self.parts = parts.isEmpty ? [url] : parts
        self.isHeaderEncrypted = isHeaderEncrypted
        self.isLocked = isLocked
        self.hasRecoveryRecord = hasRecoveryRecord
        self.entryCount = entryCount
        self.totalUncompressedBytes = totalUncompressedBytes
        self.totalCompressedBytes = totalCompressedBytes
    }

    public var compressionRatio: Double {
        guard totalUncompressedBytes > 0 else { return 0 }
        let ratio = 1.0 - Double(totalCompressedBytes) / Double(totalUncompressedBytes)
        return max(0, min(1, ratio))
    }
}
