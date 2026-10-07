import Foundation

public typealias ProviderID = String

/// The TTS provider contract. One protocol; the OpenAI-compatible adapter, ElevenLabs, and the
/// offline system voice all conform. The signature is streaming-first: a buffered
/// provider simply yields one terminal chunk.
public protocol SpeechProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }

    /// May hit the network (cloud/local servers) or be static (system voice).
    func availableVoices() async throws -> [Voice]

    /// Models the provider can synthesize with, when it publishes a catalog (ElevenLabs does);
    /// empty means "no catalog — the model is free text". Defaults to empty.
    func availableModels() async throws -> [SpeechModel]

    /// Produce audio for `request`. Chunks are delivered in order; the stream finishes after the
    /// final chunk (or throws on error).
    func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error>
}

extension SpeechProvider {
    public func availableModels() async throws -> [SpeechModel] { [] }
}

/// Errors common to provider adapters.
public enum SpeechProviderError: Error, Equatable, Sendable {
    case missingAPIKey
    /// The profile names no voice (a provider whose voice is required, e.g. ElevenLabs' path id).
    case missingVoice
    case invalidBaseURL
    case inputTooLong(limit: Int)
    /// A non-2xx response. `body` carries the server's error message when one could be extracted.
    case httpStatus(Int, body: String?)
    case emptyResponse
    case unsupported(String)
}

/// Human-readable text for status lines (the app interpolates errors with `"\(error)"`).
extension SpeechProviderError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .missingAPIKey: return "No API key set for this profile"
        case .missingVoice: return "No voice set for this profile"
        case .invalidBaseURL: return "Invalid base URL"
        case .inputTooLong(let limit): return "Text exceeds the provider's \(limit)-character limit"
        case .httpStatus(let code, let body):
            guard let body, !body.isEmpty else { return "HTTP \(code)" }
            return "HTTP \(code): \(body)"
        case .emptyResponse: return "The provider returned no audio"
        case .unsupported(let what): return "Unsupported: \(what)"
        }
    }
}
