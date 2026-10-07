import Foundation
#if canImport(Security)
import Security
#endif

/// Stores BYOK API keys. The app stores only a *reference* in `ProviderConfig`; the secret itself
/// lives here (Keychain in production). A small hand-rolled wrapper is preferred over the
/// effectively-unmaintained KeychainAccess library.
public protocol SecretStore: AnyObject, Sendable {
    func set(_ secret: String, for reference: String) throws
    func secret(for reference: String) throws -> String?
    func delete(_ reference: String) throws
}

public enum SecretStoreError: Error, Equatable, Sendable {
    case encodingFailed
    case unexpectedStatus(Int32)
}

/// Hermetic in-memory store for tests/previews.
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var storage: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func set(_ secret: String, for reference: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[reference] = secret
    }

    public func secret(for reference: String) throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return storage[reference]
    }

    public func delete(_ reference: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[reference] = nil
    }
}

#if canImport(Security)
/// Keychain-backed store (generic password items, keyed by `reference` as the account).
public final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    public init(service: String = "com.selecttts.apikeys") {
        self.service = service
    }

    private func query(for reference: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: reference,
        ]
    }

    public func set(_ secret: String, for reference: String) throws {
        guard let data = secret.data(using: .utf8) else { throw SecretStoreError.encodingFailed }
        SecItemDelete(query(for: reference) as CFDictionary)
        var attributes = query(for: reference)
        attributes[kSecValueData as String] = data
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecretStoreError.unexpectedStatus(status) }
    }

    public func secret(for reference: String) throws -> String? {
        var query = query(for: reference)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecretStoreError.unexpectedStatus(status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func delete(_ reference: String) throws {
        let status = SecItemDelete(query(for: reference) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecretStoreError.unexpectedStatus(status)
        }
    }
}
#endif
