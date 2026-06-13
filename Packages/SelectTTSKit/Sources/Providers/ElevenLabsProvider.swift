import Foundation
import SpeechCore

/// ElevenLabs adapter (separate from OpenAI-compatible — voice id in path, `xi-api-key` auth).
/// `SpeechRequest.voice` carries the ElevenLabs voice id; `model` carries the `model_id`.
public struct ElevenLabsProvider: SpeechProvider {
    public let id: ProviderID
    public let displayName: String

    private let baseURL: URL
    private let apiKey: String
    private let staticVoices: [Voice]
    private let session: URLSession
    private let builder = ElevenLabsRequestBuilder()

    public init(
        id: ProviderID = "elevenlabs",
        displayName: String = "ElevenLabs",
        baseURL: URL = ElevenLabsRequestBuilder.defaultBaseURL,
        apiKey: String,
        staticVoices: [Voice] = [],
        session: URLSession = .shared
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.staticVoices = staticVoices
        self.session = session
    }

    public func availableVoices() async throws -> [Voice] {
        // Voices come from a separate `GET /v1/voices` endpoint; wired in M4. Profiles can preload.
        staticVoices
    }

    public func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try builder.makeRequest(
                        baseURL: baseURL, apiKey: apiKey,
                        voiceID: request.voice, text: request.text, modelID: request.model
                    )
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse,
                       !(200..<300).contains(http.statusCode) {
                        throw SpeechProviderError.httpStatus(http.statusCode, body: nil)
                    }
                    // ElevenLabs returns compressed audio by default; carry raw bytes (decode path).
                    var buffer = Data()
                    let flushThreshold = 16 * 1024
                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= flushThreshold {
                            continuation.yield(AudioChunk(data: buffer))
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty { continuation.yield(AudioChunk(data: buffer)) }
                    continuation.yield(.terminal)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
