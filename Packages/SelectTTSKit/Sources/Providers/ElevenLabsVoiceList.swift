import Foundation
import SpeechCore

/// Decodes the JSON returned by ElevenLabs `GET {baseURL}/voices` into `[Voice]`.
///
/// The endpoint returns `{ "voices": [ { "voice_id", "name", "labels": { "gender", "language", … } } ] }`.
/// Voice ids (not names) are what `SpeechRequest.voice` carries (decision D4), so `Voice.id` = the
/// `voice_id`. Unknown/missing fields degrade gracefully rather than failing the whole decode.
public enum ElevenLabsVoiceList {

    public static func decode(_ data: Data) throws -> [Voice] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return response.voices.map { raw in
            Voice(
                id: raw.voiceID,
                name: raw.name?.isEmpty == false ? raw.name! : raw.voiceID,
                language: raw.labels?["language"] ?? raw.labels?["accent"],
                quality: nil,
                gender: mapGender(raw.labels?["gender"])
            )
        }
    }

    private static func mapGender(_ value: String?) -> VoiceGender? {
        switch value?.lowercased() {
        case "male": return .male
        case "female": return .female
        case .some: return .unspecified
        case nil: return nil
        }
    }

    private struct Response: Decodable {
        let voices: [RawVoice]
    }

    private struct RawVoice: Decodable {
        let voiceID: String
        let name: String?
        let labels: [String: String]?

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case name
            case labels
        }
    }
}
