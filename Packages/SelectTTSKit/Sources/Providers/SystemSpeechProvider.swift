import Foundation
import SpeechCore
#if canImport(AVFoundation)
import AVFoundation
#endif

/// The offline, zero-config default: `AVSpeechSynthesizer`, on-device, no API key, so
/// the app speaks out of the box. Renders to PCM via `write(_:toBufferCallback:)` and yields the
/// samples as `AudioChunk`s so the same playback path serves cloud and system voices.
public final class SystemSpeechProvider: NSObject, SpeechProvider, @unchecked Sendable {
    public let id: ProviderID = "system"
    public let displayName: String = "System Voice (offline)"

    #if canImport(AVFoundation)
    /// Must be strongly retained while writing/speaking.
    private let synthesizer = AVSpeechSynthesizer()
    #endif

    override public init() { super.init() }

    public func availableVoices() async throws -> [Voice] {
        #if canImport(AVFoundation)
        return AVSpeechSynthesisVoice.speechVoices().map { v in
            Voice(
                id: v.identifier,
                name: v.name,
                language: v.language,
                quality: Self.mapQuality(v.quality),
                gender: Self.mapGender(v.gender)
            )
        }
        #else
        return []
        #endif
    }

    public func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
        #if canImport(AVFoundation)
        return AsyncThrowingStream { continuation in
            let utterance = AVSpeechUtterance(string: request.text)
            if let voice = AVSpeechSynthesisVoice(identifier: request.voice) {
                utterance.voice = voice
            }
            utterance.rate = Self.mapRate(request.speed)

            // Stop rendering when the consumer goes away (e.g. the user stopped playback).
            continuation.onTermination = { [self] termination in
                if case .cancelled = termination { synthesizer.stopSpeaking(at: .immediate) }
            }

            self.synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 else {
                    continuation.yield(.terminal)
                    continuation.finish()
                    return
                }
                if let chunk = Self.makeChunk(from: pcm) {
                    continuation.yield(chunk)
                }
            }
        }
        #else
        return AsyncThrowingStream { $0.finish(throwing: SpeechProviderError.unsupported("AVFoundation")) }
        #endif
    }

    #if canImport(AVFoundation)
    /// Convert a synthesized buffer (Int16 or Float32, channel 0) to 16-bit LE PCM bytes.
    static func makeChunk(from buffer: AVAudioPCMBuffer) -> AudioChunk? {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return nil }

        var samples = [Int16](repeating: 0, count: frames)
        if let int16 = buffer.int16ChannelData {
            let channel = int16[0]
            for f in 0..<frames { samples[f] = channel[f] }
        } else if let float = buffer.floatChannelData {
            let channel = float[0]
            for f in 0..<frames {
                let clamped = Swift.max(-1.0, Swift.min(1.0, channel[f]))
                samples[f] = Int16(clamped * 32767.0)
            }
        } else {
            return nil
        }

        var data = Data(capacity: frames * 2)
        for sample in samples {
            let u = UInt16(bitPattern: sample)
            data.append(UInt8(u & 0x00ff))
            data.append(UInt8(u >> 8))
        }
        let format = PCMStreamFormat(
            sampleRate: buffer.format.sampleRate, channels: 1, bitsPerSample: 16, isFloat: false
        )
        return AudioChunk(data: data, pcmFormat: format)
    }

    static func mapRate(_ speed: Double) -> Float {
        let scaled = AVSpeechUtteranceDefaultSpeechRate * Float(speed)
        return Swift.min(Swift.max(scaled, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
    }

    static func mapQuality(_ q: AVSpeechSynthesisVoiceQuality) -> VoiceQuality {
        switch q {
        case .enhanced: .enhanced
        case .premium: .premium
        default: .default
        }
    }

    static func mapGender(_ g: AVSpeechSynthesisVoiceGender) -> VoiceGender {
        switch g {
        case .male: .male
        case .female: .female
        default: .unspecified
        }
    }
    #endif
}
