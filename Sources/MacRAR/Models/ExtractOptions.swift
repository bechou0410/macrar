import Foundation

/// User-controlled options for an extract operation.
public struct ExtractOptions: Sendable, Equatable {
    public var keepPaths: Bool = true
    public var overwrite: OverwriteMode = .ask
    public var password: String? = nil
    public var includePatterns: [String] = []
    public var excludePatterns: [String] = []
    public var openInFinderWhenDone: Bool = true

    public enum OverwriteMode: String, Sendable, CaseIterable, Identifiable {
        case ask, always, never, renameOld, renameNew
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .ask:        "Ask each time"
            case .always:     "Always overwrite"
            case .never:      "Never overwrite"
            case .renameOld:  "Rename existing"
            case .renameNew:  "Rename new"
            }
        }
    }

    public init() {}
}
