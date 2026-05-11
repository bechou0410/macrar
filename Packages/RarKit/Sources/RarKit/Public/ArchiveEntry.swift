import Foundation

/// A single file or directory entry within an archive.
public struct ArchiveEntry: Identifiable, Sendable, Hashable {
    public var id: String { path }
    public let path: String                 // forward-slash full path inside archive
    public let name: String                 // last path component
    public let uncompressedSize: Int64
    public let compressedSize: Int64
    public let modified: Date?
    public let crc32: String                // hex string; may be empty
    public let attributes: String           // raw `-rw-r--r--` or `A.....` style
    public let isDirectory: Bool
    public let isEncrypted: Bool

    public init(
        path: String,
        name: String,
        uncompressedSize: Int64,
        compressedSize: Int64,
        modified: Date?,
        crc32: String = "",
        attributes: String = "",
        isDirectory: Bool = false,
        isEncrypted: Bool = false
    ) {
        self.path = path
        self.name = name
        self.uncompressedSize = uncompressedSize
        self.compressedSize = compressedSize
        self.modified = modified
        self.crc32 = crc32
        self.attributes = attributes
        self.isDirectory = isDirectory
        self.isEncrypted = isEncrypted
    }

    /// Compression ratio in [0.0, 1.0]. 0 = stored, near 1 = highly compressed.
    public var compressionRatio: Double {
        guard uncompressedSize > 0 else { return 0 }
        let ratio = 1.0 - Double(compressedSize) / Double(uncompressedSize)
        return max(0, min(1, ratio))
    }
}
