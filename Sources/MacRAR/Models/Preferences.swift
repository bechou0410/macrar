import Foundation

/// User-tunable preferences. Persisted via `PreferencesStore` (UserDefaults).
public struct Preferences: Codable, Sendable, Equatable {
    public var defaultExtractDestination: ExtractDestinationMode = .ask
    public var defaultCompressionLevel: Int = 3
    public var liquidGlassMode: LiquidGlassMode = .auto
    public var firstLaunchHandled: Bool = false
    public var rarInstallReminder: RarInstallReminder = .ask
    public var checkForUpdatesOnLaunch: Bool = true

    public enum ExtractDestinationMode: String, Codable, Sendable, CaseIterable, Identifiable {
        case ask
        case sameAsArchive
        case downloads
        case desktop
        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .ask:           "Ask each time"
            case .sameAsArchive: "Next to archive"
            case .downloads:     "Downloads"
            case .desktop:       "Desktop"
            }
        }
    }

    public enum LiquidGlassMode: String, Codable, Sendable, CaseIterable, Identifiable {
        case auto, alwaysOn, alwaysOff
        public var id: String { rawValue }
    }

    public enum RarInstallReminder: String, Codable, Sendable {
        case ask, neverAgain
    }

    public init() {}
    public static let `default` = Preferences()
}
