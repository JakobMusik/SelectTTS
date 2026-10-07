import AppSettings
import Foundation
import SpeechCore
import TextRouting
import TTSModule

/// Assembles the default TTS pipeline from app state: a `TTSModule` whose active provider is resolved
/// from the current `ProviderConfig` (via `ProviderFactory`) at each call, feeding the supplied sink.
///
/// The app builds this once at startup, passing the streaming `AudioSink` and the settings/secret
/// stores; the module then always speaks through whatever profile is currently active.
public enum TTSPipeline {

    /// Build the TTS module bound to live app state.
    /// - Parameter activeConfig: returns the currently-selected `ProviderConfig` (re-read per call so
    ///   provider/voice changes take effect without rebuilding the module).
    public static func makeModule(
        sink: AudioSink,
        secrets: SecretStore,
        activeConfig: @escaping @Sendable () -> ProviderConfig,
        isEnabled: Bool = true
    ) -> TTSModule {
        TTSModule(
            isEnabled: isEnabled,
            maxCharacters: SentenceChunker.defaultMaxCharacters,
            sink: sink,
            provider: {
                let config = activeConfig()
                // Fall back to the offline system voice if the configured provider can't be built
                // (e.g. a custom endpoint with a missing base URL) so the app always speaks.
                if let provider = try? ProviderFactory.makeProvider(from: config, secrets: secrets) {
                    return provider
                }
                return (try? ProviderFactory.makeProvider(from: .systemDefault, secrets: secrets))
                    ?? SystemSpeechFallback()
            },
            makeRequest: { text in
                ProviderFactory.makeRequest(text: text, config: activeConfig())
            }
        )
    }
}

/// A last-resort empty provider so `makeModule` is non-throwing even in impossible states.
/// (In practice `.systemDefault` always builds; this exists only to keep the closure total.)
private struct SystemSpeechFallback: SpeechProvider {
    let id: ProviderID = "system.fallback"
    let displayName = "System Voice"
    func availableVoices() async throws -> [Voice] { [] }
    func synthesize(_: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
