import Foundation
import SpeechCore
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Progressive PCM player built on `AVAudioEngine` + `AVAudioPlayerNode` (decision D5 / §7.2):
/// converts incoming 16-bit LE PCM to `Float32` `AVAudioPCMBuffer`s and `scheduleBuffer`s them as
/// bytes arrive, for low time-to-first-audio. WAV chunks are de-headered before conversion. This
/// type is exercised live in the app; the conversion math it relies on is unit-tested
/// (`PCMConverter`, `WAVHeaderParser`).
public final class StreamingAudioPlayer: AudioSink, @unchecked Sendable {
    #if canImport(AVFoundation)
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let accumulator = PCMByteAccumulator()
    private let lock = NSLock()

    /// Format of the buffers we schedule; established from the first chunk's declared format.
    private var streamFormat: PCMStreamFormat?
    private var renderFormat: AVAudioFormat?
    private var sawWAVHeader = false
    private var started = false

    public init() {}

    public func enqueue(_ chunk: AudioChunk) async throws {
        // The body does no awaiting; run it under a synchronous critical section so the lock is not
        // held across a suspension point (Swift 6-clean).
        try enqueueLocked(chunk)
    }

    public func finish() async {
        // Buffered audio drains via the scheduled completion callbacks.
    }

    public func stop() async {
        stopLocked()
    }

    private func enqueueLocked(_ chunk: AudioChunk) throws {
        lock.lock(); defer { lock.unlock() }

        var pcmData = chunk.data
        var format = chunk.pcmFormat

        // Container WAV: parse the header once, then treat the remainder as raw PCM.
        if format == nil, !sawWAVHeader, let header = try? WAVHeaderParser.parse(chunk.data) {
            sawWAVHeader = true
            format = header.pcmFormat
            let end = header.dataLength > 0
                ? min(header.dataOffset + header.dataLength, chunk.data.count)
                : chunk.data.count
            if header.dataOffset <= end {
                pcmData = chunk.data.subdata(in: header.dataOffset..<end)
            }
        }

        let effective = format ?? streamFormat ?? .openAIpcm
        if streamFormat == nil { try start(with: effective) }

        let floats = accumulator.append(pcmData)
        guard !floats.isEmpty, let renderFormat else { return }
        guard let buffer = Self.makeBuffer(floats: floats, format: renderFormat) else { return }

        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in }
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func stopLocked() {
        lock.lock(); defer { lock.unlock() }
        playerNode.stop()
        engine.stop()
        accumulator.reset()
        started = false
        streamFormat = nil
        sawWAVHeader = false
    }

    private func start(with format: PCMStreamFormat) throws {
        streamFormat = format
        guard let avFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: AVAudioChannelCount(max(1, format.channels)),
            interleaved: false
        ) else { return }
        renderFormat = avFormat

        engine.attach(playerNode)
        // Connecting the node at the source rate lets the main mixer resample to hardware.
        engine.connect(playerNode, to: engine.mainMixerNode, format: avFormat)
        if !started {
            try engine.start()
            started = true
        }
    }

    private static func makeBuffer(floats: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(floats.count / Int(format.channelCount))
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channelData = buffer.floatChannelData
        else { return nil }
        buffer.frameLength = frames
        // Mono fast-path; multi-channel would de-interleave here.
        let channels = Int(format.channelCount)
        for frame in 0..<Int(frames) {
            for ch in 0..<channels {
                channelData[ch][frame] = floats[frame * channels + ch]
            }
        }
        return buffer
    }
    #else
    public init() {}
    public func enqueue(_ chunk: AudioChunk) async throws {}
    public func finish() async {}
    public func stop() async {}
    #endif
}
