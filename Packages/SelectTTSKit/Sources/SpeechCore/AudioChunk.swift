import Foundation

/// One piece of synthesized audio flowing from a provider to the playback layer.
///
/// Providers that stream yield many chunks as bytes arrive; buffered providers (and
/// `SystemSpeechProvider`'s baseline path) yield a single terminal chunk.
public struct AudioChunk: Sendable {
    /// Raw bytes. Interpretation depends on `pcmFormat`:
    /// - non-nil → linear PCM samples laid out per `pcmFormat` (headerless).
    /// - nil → container-encoded bytes (e.g. a WAV stream whose header must be parsed, or a
    ///   compressed format) for the buffered/decode path.
    public let data: Data
    public let pcmFormat: PCMStreamFormat?
    /// True for the final chunk of a synthesis (may carry empty `data`).
    public let isFinal: Bool

    public init(data: Data, pcmFormat: PCMStreamFormat? = nil, isFinal: Bool = false) {
        self.data = data
        self.pcmFormat = pcmFormat
        self.isFinal = isFinal
    }

    /// A zero-length terminal sentinel.
    public static let terminal = AudioChunk(data: Data(), pcmFormat: nil, isFinal: true)
}
