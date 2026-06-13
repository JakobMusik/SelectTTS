import Foundation

public typealias ProviderID = String

/// The TTS provider contract. One protocol; the OpenAI-compatible adapter, ElevenLabs, and the
/// offline system voice all conform (decision D3). The signature is streaming-first: a buffered
/// provider simply yields one terminal chunk.
public protocol SpeechProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }

    /// May hit the network (cloud/local servers) or be static (system voice).
    func availableVoices() async throws -> [Voice]

    /// Produce audio for `request`. Chunks are delivered in order; the stream finishes after the
    /// final chunk (or throws on error).
    func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error>
}

/// Errors common to provider adapters.
public enum SpeechProviderError: Error, Equatable, Sendable {
    case missingAPIKey
    case invalidBaseURL
    case inputTooLong(limit: Int)
    case httpStatus(Int, body: String?)
    case emptyResponse
    case unsupported(String)
}
