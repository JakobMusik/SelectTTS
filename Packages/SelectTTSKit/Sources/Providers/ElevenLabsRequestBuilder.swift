import Foundation
import SpeechCore

/// Pure builder for ElevenLabs `POST {baseURL}/text-to-speech/{voiceID}` — note the voice id is in
/// the **path** and auth is the `xi-api-key` header (not Bearer), so it needs its own adapter, not
/// the OpenAI-compatible one (decision D3).
public struct ElevenLabsRequestBuilder: Sendable {

    public static let defaultBaseURL = URL(string: "https://api.elevenlabs.io/v1")!
    public static let defaultModelID = "eleven_multilingual_v2"

    public init() {}

    public func makeRequest(
        baseURL: URL = defaultBaseURL,
        apiKey: String,
        voiceID: String,
        text: String,
        modelID: String? = nil,
        outputFormat: String? = nil
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw SpeechProviderError.missingAPIKey }

        var url = baseURL
            .appendingPathComponent("text-to-speech")
            .appendingPathComponent(voiceID)
        if let outputFormat,
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = [URLQueryItem(name: "output_format", value: outputFormat)]
            url = components.url ?? url
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": modelID ?? Self.defaultModelID,
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return urlRequest
    }

    /// `GET {baseURL}/voices` — the catalog endpoint (auth via `xi-api-key`, decoded by
    /// `ElevenLabsVoiceList`).
    public func makeVoiceListRequest(
        baseURL: URL = defaultBaseURL,
        apiKey: String
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw SpeechProviderError.missingAPIKey }
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("voices"))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        return urlRequest
    }
}
