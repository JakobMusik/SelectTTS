import Foundation
import SpeechCore

/// Pure builder for the OpenAI `POST {baseURL}/audio/speech` request. Factored out of the network
/// adapter so the wire format (URL, headers, JSON body) is unit-testable without a server.
///
/// One body shape serves OpenAI cloud, Groq (`https://api.groq.com/openai/v1`), and every verified
/// local TTS server (Kokoro-FastAPI, AllTalk, Speaches, LocalAI) — only `baseURL` + capabilities
/// differ.
public struct OpenAISpeechRequestBuilder: Sendable {

    public init() {}

    /// - Parameter baseURL: e.g. `https://api.openai.com/v1` — `/audio/speech` is appended.
    /// - Parameter apiKey: real key for cloud; local servers ignore it but SDKs require non-empty,
    ///   so an empty key is replaced with a harmless placeholder.
    public func makeRequest(
        baseURL: URL,
        apiKey: String,
        request: SpeechRequest,
        capabilities: ProviderCapabilities
    ) throws -> URLRequest {
        guard request.text.count <= capabilities.maxInputCharacters else {
            throw SpeechProviderError.inputTooLong(limit: capabilities.maxInputCharacters)
        }

        let url = baseURL.appendingPathComponent("audio").appendingPathComponent("speech")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let effectiveKey = apiKey.isEmpty ? "sk-no-key-required" : apiKey
        urlRequest.setValue("Bearer \(effectiveKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model": request.model ?? "",
            "input": request.text,
            "voice": request.voice,
            "response_format": request.format.responseFormatValue,
        ]
        if capabilities.speedHonored {
            body["speed"] = request.speed
        }

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return urlRequest
    }
}
