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

    /// Upper bound on `/v2/voices` pages fetched (100 voices each) so a huge workspace can't stall
    /// the picker.
    static let maxVoicePages = 20

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

    /// Pages through `GET {root}/v2/voices`. Throws on a missing key or a failed request (with the
    /// server's message) so the UI can say *why* the list is empty; the voice-id field stays editable.
    public func availableVoices() async throws -> [Voice] {
        var voices: [Voice] = []
        var pageToken: String?
        var pages = 0
        repeat {
            let request = try builder.makeVoiceListRequest(
                baseURL: baseURL, apiKey: apiKey, pageToken: pageToken
            )
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw SpeechProviderError.httpStatus(
                    http.statusCode, body: ElevenLabsErrorMessage.extract(from: data)
                )
            }
            let page = try ElevenLabsVoiceList.decodePage(data)
            voices += page.voices
            pageToken = page.hasMore ? page.nextPageToken : nil
            pages += 1
        } while pageToken != nil && pages < Self.maxVoicePages
        return voices.isEmpty ? staticVoices : voices
    }

    public func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Request headerless PCM so the player can consume the bytes directly. Compressed
                    // tokens can't be fed to the streaming player (it would play MP3/Opus bytes as raw
                    // PCM — noise), so refuse them up front instead of spending credits (D5).
                    let (token, pcm) = ElevenLabsOutputFormat.resolve(request.format)
                    guard let pcm else {
                        throw SpeechProviderError.unsupported(
                            "ElevenLabs \(request.format.rawValue.uppercased()) output can't be played "
                                + "yet — choose PCM or WAV"
                        )
                    }
                    let urlRequest = try builder.makeRequest(
                        baseURL: baseURL, apiKey: apiKey,
                        voiceID: request.voice, text: request.text, modelID: request.model,
                        outputFormat: token, speed: request.speed
                    )
                    let (bytes, response) = try await session.bytes(for: urlRequest)
                    if let http = response as? HTTPURLResponse,
                       !(200..<300).contains(http.statusCode) {
                        throw SpeechProviderError.httpStatus(
                            http.statusCode, body: await Self.errorMessage(from: bytes)
                        )
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

    /// Reads (a bounded prefix of) an error response body and extracts its message.
    private static func errorMessage(from bytes: URLSession.AsyncBytes) async -> String? {
        var data = Data()
        do {
            for try await byte in bytes {
                data.append(byte)
                if data.count >= 64 * 1024 { break }
            }
        } catch {
            // Keep whatever arrived; the status code alone is still reported.
        }
        return ElevenLabsErrorMessage.extract(from: data)
    }
}
