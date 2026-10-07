import Foundation

/// Where synthesized audio goes. The streaming player (AudioPlayback) is the production sink; tests
/// and "render to file" use other sinks. Keeping this in SpeechCore lets `TTSModule` depend only on
/// the abstraction, not on AVFoundation.
public protocol AudioSink: Sendable {
    /// Append one chunk of audio. May apply backpressure (suspend) when buffered audio is large.
    func enqueue(_ chunk: AudioChunk) async throws
    /// Signal that no more chunks will arrive for the current utterance. Returns once the enqueued
    /// audio has finished playing (or `stop()` discarded it), so callers know playback is over.
    func finish() async
    /// Stop immediately and discard any buffered audio.
    func stop() async
}
