import Foundation

/// Audio container/encoding requested from a provider and returned in the response body.
///
/// For *streaming* playback SelectTTS requests `.wav` or `.pcm` (decision D5): both can be played
/// progressively without aligning to compressed frame boundaries. Compressed formats are supported
/// for download/save but not for the low-latency streaming path.
public enum AudioFormat: String, Codable, Sendable, CaseIterable {
    case wav
    case pcm
    case mp3
    case opus
    case aac
    case flac
    case m4a

    /// Whether this format can be fed to the progressive (chunked) playback path.
    /// PCM/WAV are linear and splittable on 2-byte sample boundaries; compressed formats are not
    /// (a decoder must align to whole frames — see `ref/tts-api-structures/04-…`).
    public var isStreamable: Bool {
        switch self {
        case .wav, .pcm: return true
        case .mp3, .opus, .aac, .flac, .m4a: return false
        }
    }

    /// The value sent as OpenAI's `response_format` field.
    public var responseFormatValue: String { rawValue }

    public var fileExtension: String { rawValue }

    public var mimeType: String {
        switch self {
        case .wav: return "audio/wav"
        case .pcm: return "audio/pcm"
        case .mp3: return "audio/mpeg"
        case .opus: return "audio/opus"
        case .aac: return "audio/aac"
        case .flac: return "audio/flac"
        case .m4a: return "audio/mp4"
        }
    }
}

/// Describes the layout of raw linear-PCM bytes carried in an `AudioChunk`.
///
/// The progressive playback engine is float-only / non-interleaved (Int16 or interleaved buffers
/// crash AVAudioEngine), so the player converts using this descriptor.
public struct PCMStreamFormat: Sendable, Hashable, Codable {
    public var sampleRate: Double
    public var channels: Int
    public var bitsPerSample: Int
    public var isFloat: Bool
    public var isInterleaved: Bool
    public var isBigEndian: Bool

    public init(
        sampleRate: Double,
        channels: Int,
        bitsPerSample: Int,
        isFloat: Bool,
        isInterleaved: Bool = false,
        isBigEndian: Bool = false
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.isFloat = isFloat
        self.isInterleaved = isInterleaved
        self.isBigEndian = isBigEndian
    }

    /// OpenAI `response_format: pcm` → headerless 24 kHz, 16-bit signed LE, mono.
    public static let openAIpcm = PCMStreamFormat(
        sampleRate: 24_000, channels: 1, bitsPerSample: 16, isFloat: false
    )

    public var bytesPerSample: Int { bitsPerSample / 8 }
    public var bytesPerFrame: Int { bytesPerSample * channels }
}
