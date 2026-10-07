import Foundation

/// The handful of things that genuinely vary across OpenAI-compatible backends. Lives in config
/// (data, not code) so new/updated backends need no code change.
public struct ProviderCapabilities: Sendable, Equatable, Codable {
    /// `instructions` field accepted (OpenAI gpt-4o-mini-tts only).
    public var supportsInstructions: Bool
    /// `stream_format: sse` accepted (OpenAI non-tts-1/-hd only).
    public var supportsSSE: Bool
    /// Whether `speed` is actually honored (reliable on tts-1/-hd; ignored by gpt-4o-mini-tts;
    /// enforced by AllTalk/Kokoro).
    public var speedHonored: Bool
    /// Max characters per request (OpenAI & AllTalk cap at 4096; others effectively unbounded).
    public var maxInputCharacters: Int
    public var defaultFormat: AudioFormat

    public init(
        supportsInstructions: Bool = false,
        supportsSSE: Bool = false,
        speedHonored: Bool = true,
        maxInputCharacters: Int = 4096,
        defaultFormat: AudioFormat = .wav
    ) {
        self.supportsInstructions = supportsInstructions
        self.supportsSSE = supportsSSE
        self.speedHonored = speedHonored
        self.maxInputCharacters = maxInputCharacters
        self.defaultFormat = defaultFormat
    }

    /// OpenAI cloud, gpt-4o-mini-tts family (instructions + SSE; speed unreliable).
    public static let openAI = ProviderCapabilities(
        supportsInstructions: true, supportsSSE: true, speedHonored: false,
        maxInputCharacters: 4096, defaultFormat: .wav
    )
    /// OpenAI tts-1 / tts-1-hd (speed honored; no instructions/SSE).
    public static let openAITTS1 = ProviderCapabilities(
        supportsInstructions: false, supportsSSE: false, speedHonored: true,
        maxInputCharacters: 4096, defaultFormat: .wav
    )
    /// Kokoro-FastAPI (speed honored; large input; blendable `af_*` voices).
    public static let kokoro = ProviderCapabilities(
        supportsInstructions: false, supportsSSE: false, speedHonored: true,
        maxInputCharacters: 100_000, defaultFormat: .wav
    )
    /// AllTalk V2 (speed 0.25–4.0 enforced; input ≤ 4096).
    public static let allTalk = ProviderCapabilities(
        supportsInstructions: false, supportsSSE: false, speedHonored: true,
        maxInputCharacters: 4096, defaultFormat: .wav
    )
    /// Generic local OpenAI-compatible TTS server.
    public static let localGeneric = ProviderCapabilities(
        supportsInstructions: false, supportsSSE: false, speedHonored: true,
        maxInputCharacters: 100_000, defaultFormat: .wav
    )
}
