import Foundation

/// A voice's saved `voice_settings` (`GET {root}/v1/voices/{id}/settings`).
///
/// Used to send a speed override without disturbing the rest: the API fills any field missing from
/// (or null in) a request's `voice_settings` with its default rather than the voice's saved value.
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
