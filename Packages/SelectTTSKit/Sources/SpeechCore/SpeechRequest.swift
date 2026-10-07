import Foundation

/// A single synthesis request. `voice`/`model` are free text — the active provider profile defines
/// the catalog. `speed` is clamped to the OpenAI-documented 0.25...4.0 range; whether
/// a backend honors it is a per-profile capability flag.
public struct SpeechRequest: Sendable, Equatable {
    public let text: String
    public let voice: String
    public let model: String?
    public let format: AudioFormat
    public let speed: Double

    public static let minSpeed = 0.25
    public static let maxSpeed = 4.0

    public init(
        text: String,
        voice: String,
        model: String? = nil,
        format: AudioFormat = .wav,
        speed: Double = 1.0
    ) {
        self.text = text
        self.voice = voice
        self.model = model
        self.format = format
        self.speed = Swift.min(Swift.max(speed, SpeechRequest.minSpeed), SpeechRequest.maxSpeed)
    }
}
