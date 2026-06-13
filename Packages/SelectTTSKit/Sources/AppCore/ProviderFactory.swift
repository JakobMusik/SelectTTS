import Foundation
import SpeechCore
import AppSettings
import Providers

public enum ProviderFactoryError: Error, Equatable, Sendable {
    case missingBaseURL
}

/// Builds a concrete `SpeechProvider` from a stored `ProviderConfig`, resolving the API key from the
/// `SecretStore` at call time. This is the one place that maps `ProviderKind` → adapter (D3); adding
/// a provider family is a new `case` here plus the adapter.
public enum ProviderFactory {

    public static func makeProvider(
        from config: ProviderConfig,
        secrets: SecretStore,
        session: URLSession = .shared
    ) throws -> SpeechProvider {
        switch config.kind {
        case .system:
            return SystemSpeechProvider()

        case .openAICompatible:
            guard let baseURL = config.baseURL else { throw ProviderFactoryError.missingBaseURL }
            return OpenAICompatibleProvider(
                id: config.id,
                displayName: config.name,
                baseURL: baseURL,
                apiKey: resolveKey(config, secrets),
                capabilities: config.capabilities,
                staticVoices: presetVoices(config),
                session: session
            )

        case .elevenLabs:
            return ElevenLabsProvider(
                id: config.id,
                displayName: config.name,
                baseURL: config.baseURL ?? ElevenLabsRequestBuilder.defaultBaseURL,
                apiKey: resolveKey(config, secrets),
                staticVoices: presetVoices(config),
                session: session
            )
        }
    }

    /// Builds a `SpeechRequest` for one chunk of text using the profile's voice/model/format/speed.
    public static func makeRequest(text: String, config: ProviderConfig) -> SpeechRequest {
        SpeechRequest(
            text: text,
            voice: config.voice ?? "",
            model: config.model,
            format: config.format,
            speed: config.speed
        )
    }

    // MARK: - Helpers

    private static func resolveKey(_ config: ProviderConfig, _ secrets: SecretStore) -> String {
        guard let ref = config.apiKeyKeychainRef else { return "" }
        let stored = try? secrets.secret(for: ref) // String?? — outer = lookup error, inner = absence
        return stored.flatMap { $0 } ?? ""
    }

    private static func presetVoices(_ config: ProviderConfig) -> [Voice] {
        guard let voice = config.voice, !voice.isEmpty else { return [] }
        return [Voice(id: voice, name: voice)]
    }
}
