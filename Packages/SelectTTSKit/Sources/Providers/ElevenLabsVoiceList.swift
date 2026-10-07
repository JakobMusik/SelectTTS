import Foundation
import SpeechCore

/// Decodes the JSON returned by ElevenLabs `GET {root}/v2/voices` into `[Voice]`.
///
/// The endpoint returns `{ "voices": [ { "voice_id", "name", "labels": { "gender", "language", … },
/// "verified_languages": [ { "language", "locale", … } ] } ], "has_more", "next_page_token" }`.
/// Voice ids (not names) are what `SpeechRequest.voice` carries, so `Voice.id` = the
/// `voice_id`. Unknown/missing fields degrade gracefully rather than failing the whole decode. The
/// legacy `/v1/voices` shape (no pagination fields) decodes too.
public enum ElevenLabsVoiceList {

    /// One page of the catalog plus the cursor for the next one.
    public struct Page: Sendable {
        public let voices: [Voice]
        public let hasMore: Bool
        public let nextPageToken: String?
    }

    /// Caveat attached to voices copied from the shared Voice Library: ElevenLabs rejects them for
    /// free plans with 402 `paid_plan_required` ("Free users cannot use library voices via the API").
    public static let libraryVoiceNote = "Library voice — needs a paid plan"

    public static func decode(_ data: Data) throws -> [Voice] {
        try decodePage(data).voices
    }

    public static func decodePage(_ data: Data) throws -> Page {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let voices = response.voices.map { raw in
            Voice(
                id: raw.voiceID,
                name: raw.name?.isEmpty == false ? raw.name! : raw.voiceID,
                language: language(of: raw),
                quality: nil,
                gender: mapGender(raw.labels?["gender"]),
                note: raw.sharingStatus == "copied" ? libraryVoiceNote : nil
            )
        }
        return Page(
            voices: voices,
            hasMore: response.hasMore ?? false,
            nextPageToken: response.nextPageToken
        )
    }

    /// Prefer a verified BCP-47 locale (`en-GB`), then the `language` label (`en`). The `accent`
    /// label ("american", "british") is not a language tag, so it is never used here.
    private static func language(of raw: RawVoice) -> String? {
        let verified = raw.verifiedLanguages ?? []
        return verified.lazy.compactMap(\.locale).first(where: { !$0.isEmpty })
            ?? raw.labels?["language"]
            ?? verified.first?.language
    }

    private static func mapGender(_ value: String?) -> VoiceGender? {
        switch value?.lowercased() {
        case "male": .male
        case "female": .female
        case .some: .unspecified
        case nil: nil
        }
    }

    private struct Response: Decodable {
        let voices: [RawVoice]
        let hasMore: Bool?
        let nextPageToken: String?

        enum CodingKeys: String, CodingKey {
            case voices
            case hasMore = "has_more"
            case nextPageToken = "next_page_token"
        }
    }

    private struct RawVoice: Decodable {
        let voiceID: String
        let name: String?
        let labels: [String: String]?
        let verifiedLanguages: [VerifiedLanguage]?
        /// `sharing.status` — `"copied"` marks a voice added from the shared Voice Library.
        let sharingStatus: String?

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case name
            case labels
            case verifiedLanguages = "verified_languages"
            case sharing
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            voiceID = try container.decode(String.self, forKey: .voiceID)
            // Optional metadata is decoded leniently: one odd voice must not drop the whole catalog.
            name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? nil
            labels = ((try? container.decodeIfPresent([String: String?].self, forKey: .labels)) ?? nil)?
                .compactMapValues { $0 }
            verifiedLanguages = (try? container.decodeIfPresent(
                [VerifiedLanguage].self, forKey: .verifiedLanguages
            )) ?? nil
            sharingStatus = ((try? container.decodeIfPresent(Sharing.self, forKey: .sharing)) ?? nil)?.status
        }
    }

    private struct Sharing: Decodable {
        let status: String?
    }

    private struct VerifiedLanguage: Decodable {
        let language: String?
        let locale: String?
    }
}
