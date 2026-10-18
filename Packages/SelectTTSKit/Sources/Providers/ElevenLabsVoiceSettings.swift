import Foundation
import SpeechCore

/// A voice's saved `voice_settings` (`GET {root}/v1/voices/{id}/settings`).
///
/// Used to send overrides (speed, a profile's `VoiceSettings`) without disturbing the rest: the API
/// fills any field missing from (or null in) a request's `voice_settings` with its default rather
/// than the voice's saved value.
public struct ElevenLabsVoiceSettings: Codable, Equatable, Sendable {
    public var stability: Double?
    public var similarityBoost: Double?
    public var style: Double?
    public var useSpeakerBoost: Bool?
    public var speed: Double?

    public init(
        stability: Double? = nil,
        similarityBoost: Double? = nil,
        style: Double? = nil,
        useSpeakerBoost: Bool? = nil,
        speed: Double? = nil
    ) {
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style
        self.useSpeakerBoost = useSpeakerBoost
        self.speed = speed
    }

    /// What the API uses for a field that isn't sent (`GET /v1/voices/settings/default`, 2026-10-18).
    public static let apiDefaults = ElevenLabsVoiceSettings(
        stability: 0.5, similarityBoost: 0.75, style: 0, useSpeakerBoost: true, speed: 1.0
    )

    /// These settings with every non-nil field of `overrides` (clamped to 0...1) replacing its own.
    public func applying(_ overrides: VoiceSettings) -> ElevenLabsVoiceSettings {
        var merged = self
        if let stability = overrides.stability { merged.stability = VoiceSettings.clamped(stability) }
        if let similarity = overrides.similarity { merged.similarityBoost = VoiceSettings.clamped(similarity) }
        if let style = overrides.style { merged.style = VoiceSettings.clamped(style) }
        if let speakerBoost = overrides.speakerBoost { merged.useSpeakerBoost = speakerBoost }
        return merged
    }

    /// The four tunable fields as a profile's `VoiceSettings`, with API defaults for missing ones.
    public var asVoiceSettings: VoiceSettings {
        let defaults = Self.apiDefaults
        return VoiceSettings(
            stability: stability ?? defaults.stability,
            similarity: similarityBoost ?? defaults.similarityBoost,
            style: style ?? defaults.style,
            speakerBoost: useSpeakerBoost ?? defaults.useSpeakerBoost
        )
    }

    enum CodingKeys: String, CodingKey {
        case stability
        case similarityBoost = "similarity_boost"
        case style
        case useSpeakerBoost = "use_speaker_boost"
        case speed
    }

    /// The non-nil fields as a `JSONSerialization`-ready object.
    var jsonObject: [String: Any] {
        var object: [String: Any] = [:]
        if let stability { object[CodingKeys.stability.rawValue] = stability }
        if let similarityBoost { object[CodingKeys.similarityBoost.rawValue] = similarityBoost }
        if let style { object[CodingKeys.style.rawValue] = style }
        if let useSpeakerBoost { object[CodingKeys.useSpeakerBoost.rawValue] = useSpeakerBoost }
        if let speed { object[CodingKeys.speed.rawValue] = speed }
        return object
    }
}
