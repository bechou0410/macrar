import Foundation

/// UserDefaults-backed persistence for `Preferences`.
@MainActor
public final class PreferencesStore {
    private let defaultsKey = "com.bechou.macrar.preferences.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> Preferences {
        guard let data = defaults.data(forKey: defaultsKey),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data)
        else { return .default }
        return prefs
    }

    public func save(_ prefs: Preferences) {
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        defaults.set(data, forKey: defaultsKey)
    }
}
