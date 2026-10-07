import Foundation
import SpeechCore

/// Which adapter a profile drives.
public enum ProviderKind: String, Codable, Sendable, CaseIterable {
    case openAICompatible
    case elevenLabs
    case system
}

/// A named, user-created provider profile (e.g. "OpenAI", "My Kokoro box", "ElevenLabs"). Config is
/// **data, not code**: voices/models/formats are free text, because catalogs vary per backend and
/// churn. Secrets are never stored here — only a Keychain reference.
public struct ProviderConfig: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var kind: ProviderKind
    public var name: String
    /// Required for `.openAICompatible`; nil for `.system`. `.elevenLabs` may override its default.
    public var baseURLString: String?
    /// Keychain account reference for the API key; nil for keyless backends (`.system`, local servers).
    public var apiKeyKeychainRef: String?
    public var model: String?
    public var voice: String?
    public var format: AudioFormat
    public var speed: Double
    public var capabilities: ProviderCapabilities

    public init(
        id: String = UUID().uuidString,
        kind: ProviderKind,
        name: String,
        baseURLString: String? = nil,
        apiKeyKeychainRef: String? = nil,
        model: String? = nil,
        voice: String? = nil,
        format: AudioFormat = .wav,
        speed: Double = 1.0,
        capabilities: ProviderCapabilities = .openAI
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.baseURLString = baseURLString
        self.apiKeyKeychainRef = apiKeyKeychainRef
        self.model = model
        self.voice = voice
        self.format = format
        self.speed = speed
        self.capabilities = capabilities
    }

    public var baseURL: URL? {
        baseURLString.flatMap(URL.init(string:))
    }

    /// The zero-config offline default profile, present on first launch.
    public static let systemDefault = ProviderConfig(
        id: "system",
        kind: .system,
        name: "System Voice (offline)",
        format: .wav,
        capabilities: ProviderCapabilities(speedHonored: true, maxInputCharacters: 100_000)
    )
}
