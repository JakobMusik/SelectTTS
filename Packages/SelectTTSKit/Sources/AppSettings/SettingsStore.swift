import Foundation

/// Persists provider profiles + the active selection. The app uses `UserDefaultsSettingsStore`;
/// tests use the in-memory one. (Non-secret prefs only — secrets go to `SecretStore`.)
public protocol SettingsStore: AnyObject, Sendable {
    func loadProviderConfigs() -> [ProviderConfig]
    func saveProviderConfigs(_ configs: [ProviderConfig])
    func loadActiveProviderID() -> String?
    func saveActiveProviderID(_ id: String?)
}

extension SettingsStore {
    /// Convenience: the active profile, or the system default when nothing is selected/persisted.
    public func activeConfig() -> ProviderConfig {
        let configs = loadProviderConfigs()
        if let id = loadActiveProviderID(), let match = configs.first(where: { $0.id == id }) {
            return match
        }
        return configs.first ?? .systemDefault
    }
}

/// Hermetic in-memory store for tests/previews.
public final class InMemorySettingsStore: SettingsStore, @unchecked Sendable {
    private var configs: [ProviderConfig]
    private var activeID: String?
    private let lock = NSLock()

    public init(configs: [ProviderConfig] = [.systemDefault], activeID: String? = "system") {
        self.configs = configs
        self.activeID = activeID
    }

    public func loadProviderConfigs() -> [ProviderConfig] {
        lock.lock(); defer { lock.unlock() }
        return configs
    }

    public func saveProviderConfigs(_ configs: [ProviderConfig]) {
        lock.lock(); defer { lock.unlock() }
        self.configs = configs
    }

    public func loadActiveProviderID() -> String? {
        lock.lock(); defer { lock.unlock() }
        return activeID
    }

    public func saveActiveProviderID(_ id: String?) {
        lock.lock(); defer { lock.unlock() }
        activeID = id
    }
}

/// `UserDefaults`-backed store (JSON-encoded), the one the app uses. Plain `UserDefaults` rather than
/// a typed-defaults library keeps the core free of remote dependencies.
public final class UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let configsKey = "selecttts.providerConfigs"
    private let activeKey = "selecttts.activeProviderID"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadProviderConfigs() -> [ProviderConfig] {
        guard let data = defaults.data(forKey: configsKey),
              let decoded = try? JSONDecoder().decode([ProviderConfig].self, from: data)
        else { return [.systemDefault] }
        return decoded
    }

    public func saveProviderConfigs(_ configs: [ProviderConfig]) {
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: configsKey)
        }
    }

    public func loadActiveProviderID() -> String? {
        defaults.string(forKey: activeKey)
    }

    public func saveActiveProviderID(_ id: String?) {
        defaults.set(id, forKey: activeKey)
    }
}
