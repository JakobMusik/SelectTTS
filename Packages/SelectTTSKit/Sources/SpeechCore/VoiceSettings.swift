import Foundation

/// Per-profile overrides for how a voice delivers text (ElevenLabs' "voice settings"). Every field is
/// optional: nil keeps the voice's own saved value. Values are 0...1; providers without these
/// controls ignore them.
public struct VoiceSettings: Codable, Equatable, Sendable {
    /// Low = creative (broader emotional range, varies between takes); high = stable but flatter.
    public var stability: Double?
    /// How closely the output sticks to the original voice.
    public var similarity: Double?
    /// Style exaggeration of the voice (0 = none).
    public var style: Double?
    /// Boosts similarity to the original speaker, at some latency cost.
    public var speakerBoost: Bool?

    public static let range: ClosedRange<Double> = 0...1

    public init(
        stability: Double? = nil,
        similarity: Double? = nil,
        style: Double? = nil,
        speakerBoost: Bool? = nil
    ) {
        self.stability = stability
        self.similarity = similarity
        self.style = style
        self.speakerBoost = speakerBoost
    }

    /// No field overridden.
    public var isEmpty: Bool {
        stability == nil && similarity == nil && style == nil && speakerBoost == nil
    }

    /// Every field overridden, so none of the voice's saved values is needed.
    public var isComplete: Bool {
        stability != nil && similarity != nil && style != nil && speakerBoost != nil
    }

    /// `value` clamped to `range`.
    public static func clamped(_ value: Double) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
