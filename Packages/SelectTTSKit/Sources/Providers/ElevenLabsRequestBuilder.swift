import Foundation
import SpeechCore

/// Pure builder for the ElevenLabs HTTP requests — note the voice id is in the **path** and auth is
/// the `xi-api-key` header (not Bearer), so it needs its own adapter, not the OpenAI-compatible one.
///
/// `baseURL` is the API **root** (no version segment): speech lives under `/v1`, the voice catalog
/// under `/v2`. The data-residency hosts (`https://api.us.elevenlabs.io`,
/// `https://api.eu.residency.elevenlabs.io`, …) work the same way, and a trailing `/v1` or `/v2` is
/// tolerated so older profiles that stored `https://api.elevenlabs.io/v1` keep working.
public struct ElevenLabsRequestBuilder: Sendable {

    public static let defaultBaseURL = URL(string: "https://api.elevenlabs.io")!
    public static let defaultModelID = "eleven_multilingual_v2"
    /// A premade voice every account can use (the one ElevenLabs' own examples use: "George").
    public static let defaultVoiceID = "JBFqnCBsd6RMkjVDRZzb"
    /// `voice_settings.speed` bounds — the API rejects anything outside with 400 `invalid_voice_settings`.
    public static let speedRange: ClosedRange<Double> = 0.7...1.2
    /// `GET /v2/voices` maximum page size.
    public static let voicePageSize = 100

    public init() {}

    /// `baseURL` with any trailing `/v1` or `/v2` removed.
    public static func apiRoot(_ baseURL: URL) -> URL {
        var url = baseURL
        if ["v1", "v2"].contains(url.lastPathComponent) {
            url.deleteLastPathComponent()
        }
        return url
    }

    /// The `voice_settings.speed` to send for a requested speed — clamped to `speedRange` — or nil at
    /// 1.0, where no `voice_settings` is sent and the voice's saved settings (incl. its speed) apply.
    public static func speedOverride(for speed: Double) -> Double? {
        let clamped = min(max(speed, speedRange.lowerBound), speedRange.upperBound)
        return abs(clamped - 1.0) > 0.001 ? clamped : nil
    }

    /// `POST {root}/v1/text-to-speech/{voiceID}/stream` — the streaming variant, which answers with
    /// chunked audio as it is generated (the non-`/stream` endpoint buffers the whole clip first).
    ///
    /// A non-1.0 `speed` is sent as `voice_settings` = `storedVoiceSettings` with `speed` replaced. The
    /// API fills every field missing from (or null in) `voice_settings` with its *default*, not the
    /// voice's saved value (verified 2026-10-07), so a speed-only object would reset a tuned voice's
    /// stability/similarity/style. Without stored settings it falls back to speed only.
    public func makeRequest(
        baseURL: URL = defaultBaseURL,
        apiKey: String,
        voiceID: String,
        text: String,
        modelID: String? = nil,
        outputFormat: String? = nil,
        speed: Double = 1.0,
        storedVoiceSettings: ElevenLabsVoiceSettings? = nil
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw SpeechProviderError.missingAPIKey }
        let voiceID = voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceID.isEmpty else { throw SpeechProviderError.missingVoice }

        var url = Self.apiRoot(baseURL)
            .appendingPathComponent("v1")
            .appendingPathComponent("text-to-speech")
            .appendingPathComponent(voiceID)
            .appendingPathComponent("stream")
        if let outputFormat {
            url = Self.adding([URLQueryItem(name: "output_format", value: outputFormat)], to: url)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let model = modelID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var body: [String: Any] = [
            "text": text,
            "model_id": model.isEmpty ? Self.defaultModelID : model,
        ]
        if let speedOverride = Self.speedOverride(for: speed) {
            var settings = storedVoiceSettings ?? ElevenLabsVoiceSettings()
            settings.speed = speedOverride
            body["voice_settings"] = settings.jsonObject
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return urlRequest
    }

    /// `GET {root}/v1/voices/{voiceID}/settings` — the voice's saved settings (auth via `xi-api-key`).
    public func makeVoiceSettingsRequest(
        baseURL: URL = defaultBaseURL,
        apiKey: String,
        voiceID: String
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw SpeechProviderError.missingAPIKey }
        let voiceID = voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceID.isEmpty else { throw SpeechProviderError.missingVoice }
        var urlRequest = URLRequest(url: Self.apiRoot(baseURL)
            .appendingPathComponent("v1")
            .appendingPathComponent("voices")
            .appendingPathComponent(voiceID)
            .appendingPathComponent("settings"))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        return urlRequest
    }

    /// `GET {root}/v1/models` — every model, including speech-to-speech ones (filtered on decode).
    public func makeModelListRequest(
        baseURL: URL = defaultBaseURL,
        apiKey: String
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw SpeechProviderError.missingAPIKey }
        var urlRequest = URLRequest(url: Self.apiRoot(baseURL)
            .appendingPathComponent("v1")
            .appendingPathComponent("models"))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        return urlRequest
    }

    /// `GET {root}/v2/voices?page_size=100[&next_page_token=…]` — the current catalog endpoint
    /// (`/v1/voices` is legacy). Paginated: pass the previous page's `next_page_token` to continue.
    public func makeVoiceListRequest(
        baseURL: URL = defaultBaseURL,
        apiKey: String,
        pageToken: String? = nil
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else { throw SpeechProviderError.missingAPIKey }
        var query = [URLQueryItem(name: "page_size", value: String(Self.voicePageSize))]
        if let pageToken, !pageToken.isEmpty {
            query.append(URLQueryItem(name: "next_page_token", value: pageToken))
        }
        let url = Self.adding(
            query,
            to: Self.apiRoot(baseURL)
                .appendingPathComponent("v2")
                .appendingPathComponent("voices")
        )
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        return urlRequest
    }

    private static func adding(_ items: [URLQueryItem], to url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.queryItems = (components.queryItems ?? []) + items
        return components.url ?? url
    }
}
