import Foundation
import SpeechCore

/// One adapter for OpenAI cloud + Groq + every verified local OpenAI-compatible TTS server
/// (Kokoro-FastAPI, AllTalk, Speaches, LocalAI), since they all accept OpenAI's request body.
/// Configured per profile with `baseURL` + key + capabilities. Streams the response body over
/// chunked transfer: for `response_format: pcm` chunks carry `PCMStreamFormat.openAIpcm`; for `wav`
/// the header is parsed downstream by the player.
public struct OpenAICompatibleProvider: SpeechProvider {
    public let id: ProviderID
    public let displayName: String

    private let baseURL: URL
    private let apiKey: String
    private let capabilities: ProviderCapabilities
    private let staticVoices: [Voice]
    private let session: URLSession
    private let builder = OpenAISpeechRequestBuilder()

    public init(
        id: ProviderID,
        displayName: String,
        baseURL: URL,
        apiKey: String,
        capabilities: ProviderCapabilities = .openAI,
        staticVoices: [Voice] = [],
        session: URLSession = .shared
    ) {
        self.id = id
        self.displayName = displayName
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.capabilities = capabilities
        self.staticVoices = staticVoices
        self.session = session
    }

    public func availableVoices() async throws -> [Voice] {
        // OpenAI-compatible TTS has no universal voice-list endpoint; the profile supplies the
        // catalog. Backends with a known list endpoint can override via a richer adapter later.
        staticVoices
    }

    public func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let urlRequest = try builder.makeRequest(
                        baseURL: baseURL, apiKey: apiKey,
                        request: request, capabilities: capabilities
                    )
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse,
                       !(200..<300).contains(http.statusCode) {
                        throw SpeechProviderError.httpStatus(http.statusCode, body: nil)
                    }

                    let pcmFormat: PCMStreamFormat? = (request.format == .pcm) ? .openAIpcm : nil
                    var buffer = Data()
                    let flushThreshold = 16 * 1024

                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= flushThreshold {
                            continuation.yield(AudioChunk(data: buffer, pcmFormat: pcmFormat))
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(AudioChunk(data: buffer, pcmFormat: pcmFormat))
                    }
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
