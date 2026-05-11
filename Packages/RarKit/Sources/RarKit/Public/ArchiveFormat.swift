import Foundation

/// Archive container format detected from file extension or magic bytes.
public enum ArchiveFormat: String, Sendable, CaseIterable, Hashable {
    case rar = "RAR"
    case zip = "ZIP"
    case sevenZip = "7Z"
    case tar = "TAR"
    case tarGz = "TAR.GZ"
    case tarBz2 = "TAR.BZ2"
    case gz = "GZ"
    case bz2 = "BZ2"
    case iso = "ISO"
    case sfx = "SFX"
    case unknown = "Unknown"

    /// Whether the bundled `unrar` can list/extract this format.
    public var unrarCanRead: Bool {
        switch self {
        case .rar, .sfx: return true
        default: return false  // unrar only handles RAR family natively
        }
    }

    /// Whether external `rar` can create archives of this format.
    public var canCreate: Bool {
        self == .rar  // rar binary creates RAR only
    }

    /// Detect format from URL path extension.
    public static func detect(from url: URL) -> ArchiveFormat {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz")   { return .tarGz }
        if name.hasSuffix(".tar.bz2") || name.hasSuffix(".tbz") { return .tarBz2 }
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "rar":  return .rar
        case "zip":  return .zip
        case "7z":   return .sevenZip
        case "tar":  return .tar
        case "gz":   return .gz
        case "bz2":  return .bz2
        case "iso":  return .iso
        case "exe":  return .sfx
        default:     return .unknown
        }
    }
}
