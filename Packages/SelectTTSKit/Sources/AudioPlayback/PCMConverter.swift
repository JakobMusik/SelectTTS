import Foundation

/// Pure conversions for the streaming PCM path. The playback engine is float-only / non-interleaved
/// (Int16 or interleaved buffers crash AVAudioEngine — `ref/tts-api-structures/04-…`), so incoming
/// 16-bit signed LE PCM is converted to `Float32` in `[-1, 1)`.
public enum PCMConverter {

    /// Convert little-endian signed 16-bit samples to normalized `Float`. An odd trailing byte
    /// (incomplete sample) is ignored — use `PCMByteAccumulator` to carry it across chunks.
    public static func int16LEtoFloat32(_ data: Data) -> [Float] {
        let sampleCount = data.count / 2
        guard sampleCount > 0 else { return [] }
        let bytes = [UInt8](data)
        var out = [Float](repeating: 0, count: sampleCount)
        for i in 0..<sampleCount {
            let lo = UInt16(bytes[2 * i])
            let hi = UInt16(bytes[2 * i + 1])
            let sample = Int16(bitPattern: lo | (hi << 8))
            out[i] = Float(sample) / 32768.0
        }
        return out
    }
}

/// Accumulates raw PCM bytes across streamed chunks, emitting only complete 16-bit samples and
/// carrying a trailing odd byte forward (a 16-bit sample can split across HTTP chunk boundaries —
/// `ref/tts-api-structures/04-…`).
public final class PCMByteAccumulator {
    private var spare: UInt8?

    public init() {}

    /// Append `data` and return all complete `Float32` samples now available.
    public func append(_ data: Data) -> [Float] {
        var buffer = Data()
        if let spare { buffer.append(spare); self.spare = nil }
        buffer.append(data)

        let usableCount = buffer.count - (buffer.count % 2)
        if buffer.count % 2 == 1 {
            spare = buffer.last
        }
        guard usableCount > 0 else { return [] }
        return PCMConverter.int16LEtoFloat32(buffer.prefix(usableCount))
    }

    /// Drop any carried byte (call when a stream ends).
    public func reset() {
        spare = nil
    }

    public var hasPendingByte: Bool { spare != nil }
}
