import Foundation
import SpeechCore

/// Maps a SelectTTS `AudioFormat` to an ElevenLabs `output_format` query token, plus the PCM layout
/// to tag the returned `AudioChunk`s with (nil for compressed tokens).
///
/// ElevenLabs has no WAV output, so both *streamable* SelectTTS formats (`.wav`/`.pcm`) request
/// headerless `pcm_24000` — signed 16-bit LE, 24 kHz, mono, exactly `PCMStreamFormat.openAIpcm`.
/// Tagging chunks with that layout makes `StreamingAudioPlayer` play them progressively instead of
/// trying (and failing) to decode an MP3 byte stream. Compressed
/// tokens are still valid ElevenLabs requests but can't feed the streaming player (pcm == nil), so
/// `ElevenLabsProvider.synthesize` refuses them rather than play the bytes as noise.
public enum ElevenLabsOutputFormat {

    /// `(query token, PCM layout for returned chunks)`. The layout is non-nil only for tokens that
    /// produce headerless linear PCM the streaming player can consume directly.
    public static func resolve(_ format: AudioFormat) -> (token: String, pcm: PCMStreamFormat?) {
        switch format {
        case .wav, .pcm:
            // ElevenLabs emits no container; pcm_24000 == openAIpcm (24 kHz / 16-bit / signed LE / mono).
            ("pcm_24000", .openAIpcm)
        case .opus:
            ("opus_48000_128", nil)
        case .mp3, .aac, .flac, .m4a:
            // ElevenLabs offers no AAC/FLAC/M4A; fall back to its default-bitrate MP3.
            ("mp3_44100_128", nil)
        }
    }
}
