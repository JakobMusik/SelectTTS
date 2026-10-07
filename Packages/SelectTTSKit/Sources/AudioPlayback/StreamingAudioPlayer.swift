import Foundation
import SpeechCore
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Progressive PCM player built on `AVAudioEngine` + `AVAudioPlayerNode`:
/// converts incoming 16-bit LE PCM to `Float32` `AVAudioPCMBuffer`s and `scheduleBuffer`s them as
/// bytes arrive, for low time-to-first-audio. WAV chunks are de-headered before conversion. This
/// type is exercised live in the app; the conversion math it relies on is unit-tested
/// (`PCMConverter`, `WAVHeaderParser`).
///
/// Playback tracking: every scheduled buffer is counted until AVFoundation reports it played, so
/// `finish()` can wait for the utterance to actually end. `stop()` bumps a generation number so
/// completion callbacks from discarded buffers are ignored, and resumes any `finish()` waiters.
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

    /// Buffers scheduled but not yet played back (current generation only).
    private var pendingBuffers = 0
    /// Incremented by `stop()`; callbacks from earlier generations are stale.
    private var generation = 0
    /// `finish()` callers waiting for `pendingBuffers` to reach zero.
    private var drainWaiters: [CheckedContinuation<Void, Never>] = []
    /// Completion callbacks hop here before taking `lock`, so `playerNode.stop()` (which may invoke
    /// them synchronously) can be called while holding the lock without deadlocking.
    private let callbackQueue = DispatchQueue(label: "com.selecttts.player.callbacks")
    private var configurationObserver: NSObjectProtocol?

    public init() {
        // An output-device change (headphones unplugged, …) stops the engine without playing the
        // remaining buffers; treat it as a stop so nothing waits forever.
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            self?.stopLocked()
        }
    }

    deinit {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
    }

    public func enqueue(_ chunk: AudioChunk) async throws {
        // The body does no awaiting; run it under a synchronous critical section so the lock is not
        // held across a suspension point (Swift 6-clean).
        try enqueueLocked(chunk)
    }

    /// Waits until every scheduled buffer has been played back (or `stop()` discarded them).
    public func finish() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if pendingBuffers == 0 {
                lock.unlock()
                continuation.resume()
            } else {
                drainWaiters.append(continuation)
                lock.unlock()
            }
        }
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

        let bufferGeneration = generation
        pendingBuffers += 1
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            self?.callbackQueue.async { self?.bufferPlayed(generation: bufferGeneration) }
        }
        if !playerNode.isPlaying { playerNode.play() }
    }

    private func bufferPlayed(generation bufferGeneration: Int) {
        lock.lock()
        guard bufferGeneration == generation else { lock.unlock(); return }
        pendingBuffers = max(0, pendingBuffers - 1)
        var waiters: [CheckedContinuation<Void, Never>] = []
        if pendingBuffers == 0 { swap(&waiters, &drainWaiters) }
        lock.unlock()
        waiters.forEach { $0.resume() }
    }

    private func stopLocked() {
        lock.lock()
        generation += 1
        pendingBuffers = 0
        var waiters: [CheckedContinuation<Void, Never>] = []
        swap(&waiters, &drainWaiters)
        if playerNode.engine != nil { playerNode.stop() }
        if engine.isRunning { engine.stop() }
        accumulator.reset()
        started = false
        streamFormat = nil
        sawWAVHeader = false
        lock.unlock()
        waiters.forEach { $0.resume() }
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

        if playerNode.engine == nil { engine.attach(playerNode) }
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
    public func enqueue(_: AudioChunk) async throws {}
    public func finish() async {}
    public func stop() async {}
    #endif
}
