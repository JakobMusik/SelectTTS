import Foundation

/// A voice offered by a provider. Catalogs vary per backend and churn over time, so a voice is
/// just data (decision D4) — never a hard-coded enum.
public struct Voice: Identifiable, Hashable, Codable, Sendable {
    /// The string passed back to the provider in a `SpeechRequest` (OpenAI name, Kokoro `af_*`,
    /// an `AVSpeechSynthesisVoice.identifier`, an ElevenLabs voice id, …).
    public let id: String
    public let name: String
    /// BCP-47 language tag when known (e.g. `en-US`).
    public let language: String?
    public let quality: VoiceQuality?
    public let gender: VoiceGender?

    public init(
        id: String,
        name: String,
        language: String? = nil,
        quality: VoiceQuality? = nil,
        gender: VoiceGender? = nil
    ) {
        self.id = id
        self.name = name
        self.language = language
        self.quality = quality
        self.gender = gender
    }
}

public enum VoiceQuality: String, Codable, Sendable {
    case `default`
    case enhanced
    case premium
}

public enum VoiceGender: String, Codable, Sendable {
    case male
    case female
    case unspecified
}
