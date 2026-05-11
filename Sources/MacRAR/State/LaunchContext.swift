import Foundation

/// How the app was launched. Drives whether the full browser window is shown
/// (`normal`) or just a single operation sheet on top of a hidden window
/// (`compress` / `extract`) for Services-menu / drag-onto-dock invocations.
public enum LaunchContext: Equatable, Sendable {
    case normal
    case compress(sources: [URL])
    case extract(archives: [URL])

    public var isHeadless: Bool {
        switch self {
        case .normal: return false
        default:      return true
        }
    }
}
