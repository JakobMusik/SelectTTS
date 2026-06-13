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
        // `GET {baseURL}/voices`; fall back to any preloaded profile voices if the key is absent or
        // the call fails, so the picker stays usable rather than throwing.
        guard !apiKey.isEmpty else { return staticVoices }
        do {
            let request = try builder.makeVoiceListRequest(baseURL: baseURL, apiKey: apiKey)
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw SpeechProviderError.httpStatus(http.statusCode, body: nil)
            }
            let voices = try ElevenLabsVoiceList.decode(data)
            return voices.isEmpty ? staticVoices : voices
        } catch {
            return staticVoices
        }
    }

    public func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Request headerless PCM for streamable formats so the player can consume the bytes
                    // directly; compressed tokens (pcm == nil) take the non-streaming/decode path.
                    let (token, pcm) = ElevenLabsOutputFormat.resolve(request.format)
                    let urlRequest = try builder.makeRequest(
                        baseURL: baseURL, apiKey: apiKey,
                        voiceID: request.voice, text: request.text, modelID: request.model,
                        outputFormat: token
                    )
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse,
                       !(200..<300).contains(http.statusCode) {
                        throw SpeechProviderError.httpStatus(http.statusCode, body: nil)
                    }
                    var buffer = Data()
                    let flushThreshold = 16 * 1024
                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= flushThreshold {
                            continuation.yield(AudioChunk(data: buffer, pcmFormat: pcm))
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty { continuation.yield(AudioChunk(data: buffer, pcmFormat: pcm)) }
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
