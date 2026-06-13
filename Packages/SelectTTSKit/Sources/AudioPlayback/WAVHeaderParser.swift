import Foundation
import SpeechCore

/// Parsed RIFF/WAVE header. The `data` chunk is **not always at byte 44** — extra chunks (`LIST`,
/// `fact`, …) can precede it, so we locate it by scanning chunk ids (`ref/tts-api-structures/04-…`).
public struct WAVHeader: Equatable, Sendable {
    public let sampleRate: Double
    public let channels: Int
    public let bitsPerSample: Int
    public let isFloat: Bool
    /// Byte offset where PCM samples begin.
    public let dataOffset: Int
    /// Declared length of the data chunk (may be unreliable / 0 for streamed WAV).
    public let dataLength: Int

    public var pcmFormat: PCMStreamFormat {
        PCMStreamFormat(
            sampleRate: sampleRate, channels: channels,
            bitsPerSample: bitsPerSample, isFloat: isFloat
        )
    }
}

public enum WAVParseError: Error, Equatable, Sendable {
    case tooShort
    case notRIFF
    case notWAVE
    case missingFmtChunk
    case missingDataChunk
}

/// Minimal canonical-WAV parser sufficient for the formats our providers return.
public enum WAVHeaderParser {

    public static func parse(_ data: Data) throws -> WAVHeader {
        let b = [UInt8](data)
        guard b.count >= 12 else { throw WAVParseError.tooShort }
        guard tag(b, 0) == "RIFF" else { throw WAVParseError.notRIFF }
        guard tag(b, 8) == "WAVE" else { throw WAVParseError.notWAVE }

        var offset = 12
        var fmt: (sampleRate: Double, channels: Int, bits: Int, isFloat: Bool)?
        var dataChunk: (offset: Int, length: Int)?

        while offset + 8 <= b.count {
            let id = tag(b, offset)
            let size = Int(readUInt32LE(b, offset + 4))
            let payload = offset + 8

            if id == "fmt " && payload + 16 <= b.count {
                let audioFormat = readUInt16LE(b, payload)          // 1 = PCM, 3 = IEEE float
                let channels = Int(readUInt16LE(b, payload + 2))
                let sampleRate = Double(readUInt32LE(b, payload + 4))
                let bits = Int(readUInt16LE(b, payload + 14))
                fmt = (sampleRate, channels, bits, audioFormat == 3)
            } else if id == "data" {
                dataChunk = (payload, size)
                break // samples follow; stop scanning
            }

            // Chunks are word-aligned: odd sizes are padded with one byte.
            offset = payload + size + (size % 2)
        }

        guard let fmt else { throw WAVParseError.missingFmtChunk }
        guard let dataChunk else { throw WAVParseError.missingDataChunk }

        return WAVHeader(
            sampleRate: fmt.sampleRate,
            channels: fmt.channels,
            bitsPerSample: fmt.bits,
            isFloat: fmt.isFloat,
            dataOffset: dataChunk.offset,
            dataLength: dataChunk.length
        )
    }

    // MARK: - Little-endian readers

    private static func tag(_ b: [UInt8], _ at: Int) -> String {
        guard at + 4 <= b.count else { return "" }
        return String(bytes: b[at..<at + 4], encoding: .ascii) ?? ""
    }

    private static func readUInt16LE(_ b: [UInt8], _ at: Int) -> UInt16 {
        UInt16(b[at]) | (UInt16(b[at + 1]) << 8)
    }

    private static func readUInt32LE(_ b: [UInt8], _ at: Int) -> UInt32 {
        UInt32(b[at]) | (UInt32(b[at + 1]) << 8) | (UInt32(b[at + 2]) << 16) | (UInt32(b[at + 3]) << 24)
    }
}
