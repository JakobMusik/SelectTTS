import Foundation
import SpeechCore
import TextRouting

/// The flagship `TextModule`: speak the captured text. Owns the long-text chunker and drives the
/// active provider + audio sink. Depends only on abstractions (`SpeechProvider`, `AudioSink`,
/// `TextModule`); the app injects concrete instances, so this whole flow is unit-testable with fakes.
public final class TTSModule: TextModule, @unchecked Sendable {
    public let id: ModuleID = "tts"
    public let displayName: String = "Text to Speech"
    public var isEnabled: Bool

    /// Resolves the currently-active provider at call time (config can change between invocations).
    private let providerProvider: @Sendable () -> SpeechProvider
    /// Where audio goes (the streaming player in production).
    private let sink: AudioSink
    /// Builds a `SpeechRequest` for one text chunk using the active profile's voice/model/format.
    private let makeRequest: @Sendable (String) -> SpeechRequest
    private let maxCharacters: Int

    public init(
        isEnabled: Bool = true,
        maxCharacters: Int = SentenceChunker.defaultMaxCharacters,
        sink: AudioSink,
        provider: @escaping @Sendable () -> SpeechProvider,
        makeRequest: @escaping @Sendable (String) -> SpeechRequest
    ) {
        self.isEnabled = isEnabled
        self.maxCharacters = maxCharacters
        self.sink = sink
        self.providerProvider = provider
        self.makeRequest = makeRequest
    }

    public func canHandle(_ input: TextInput) -> Bool {
        !input.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func perform(_ input: TextInput) async throws {
        let chunks = SentenceChunker.chunk(input.text, maxCharacters: maxCharacters)
        guard !chunks.isEmpty else { return }

        let provider = providerProvider()
        do {
            for chunk in chunks {
                try Task.checkCancellation()
                let request = makeRequest(chunk)
                for try await audio in provider.synthesize(request) {
                    // Stop means stop: never hand the sink audio after cancellation (it would
                    // restart playback the user just silenced).
                    try Task.checkCancellation()
                    try await sink.enqueue(audio)
                }
            }
            try Task.checkCancellation()
            // Returns once the audio has actually played (or the sink was stopped).
            await sink.finish()
        } catch {
            await sink.stop()
            throw error
        }
    }
}
