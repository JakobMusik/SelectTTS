@testable import AudioPlayback
import SpeechCore
import XCTest

final class PCMConverterTests: XCTestCase {

    func testInt16LEtoFloat32() {
        // 0x0000 = 0, 0x0001 (LE -> 256) , 0xFFFF (LE -> -1), 0x0080 (LE -> 32768? no) ...
        // bytes [lo, hi]: [0,0]=0, [0,1]=256, [255,255]=-1, [0,128]=-32768
        let data = Data([0x00, 0x00, 0x00, 0x01, 0xFF, 0xFF, 0x00, 0x80])
        let floats = PCMConverter.int16LEtoFloat32(data)
        XCTAssertEqual(floats.count, 4)
        XCTAssertEqual(floats[0], 0.0, accuracy: 1e-6)
        XCTAssertEqual(floats[1], 256.0 / 32768.0, accuracy: 1e-6)
        XCTAssertEqual(floats[2], -1.0 / 32768.0, accuracy: 1e-6)
        XCTAssertEqual(floats[3], -1.0, accuracy: 1e-6) // -32768/32768
    }

    func testOddByteIsIgnoredInDirectConversion() {
        let floats = PCMConverter.int16LEtoFloat32(Data([0x00, 0x01, 0x7F])) // 1.5 samples
        XCTAssertEqual(floats.count, 1)
    }

    func testAccumulatorCarriesSampleAcrossChunkBoundary() {
        let acc = PCMByteAccumulator()
        // First chunk ends mid-sample (odd length).
        let first = acc.append(Data([0x00])) // half a sample
        XCTAssertTrue(first.isEmpty)
        XCTAssertTrue(acc.hasPendingByte)
        // Second chunk: completes the first sample (0x0100 = 256), one full sample (0x0200 = 512),
        // and a trailing odd byte (0x03) that must be carried forward.
        // Combined buffer = [0x00, 0x01, 0x00, 0x02, 0x03] = 5 bytes -> 2 samples + 1 leftover.
        let second = acc.append(Data([0x01, 0x00, 0x02, 0x03]))
        XCTAssertEqual(second.count, 2)
        XCTAssertEqual(second[0], 256.0 / 32768.0, accuracy: 1e-6)
        XCTAssertEqual(second[1], 512.0 / 32768.0, accuracy: 1e-6)
        XCTAssertTrue(acc.hasPendingByte) // trailing 0x03 carried
    }
}

final class WAVHeaderParserTests: XCTestCase {

    func testParsesCanonicalHeader() throws {
        let wav = makeWAV(sampleRate: 24_000, channels: 1, bits: 16, sampleBytes: 8)
        let header = try WAVHeaderParser.parse(wav)
        XCTAssertEqual(header.sampleRate, 24_000)
        XCTAssertEqual(header.channels, 1)
        XCTAssertEqual(header.bitsPerSample, 16)
        XCTAssertFalse(header.isFloat)
        XCTAssertEqual(header.dataOffset, 44) // canonical
        XCTAssertEqual(header.dataLength, 8)
    }

    func testDataChunkIsNotAlwaysAt44() throws {
        // Insert a LIST chunk before "data" — proves we scan, not hardcode 44.
        let extra = chunk(id: "LIST", payload: Array("INFOxxxx".utf8))
        let wav = makeWAV(sampleRate: 16_000, channels: 1, bits: 16, sampleBytes: 4, extraChunksBeforeData: extra)
        let header = try WAVHeaderParser.parse(wav)
        XCTAssertEqual(header.sampleRate, 16_000)
        XCTAssertGreaterThan(header.dataOffset, 44)
    }

    func testRejectsNonRIFF() {
        XCTAssertThrowsError(try WAVHeaderParser.parse(Data(repeating: 0, count: 64))) { error in
            XCTAssertEqual(error as? WAVParseError, .notRIFF)
        }
    }

    // MARK: - WAV byte builders

    private func makeWAV(
        sampleRate: UInt32, channels: UInt16, bits: UInt16, sampleBytes: Int,
        extraChunksBeforeData: [UInt8] = []
    ) -> Data {
        var fmt: [UInt8] = []
        fmt += le16(1) // audioFormat = PCM
        fmt += le16(channels)
        fmt += le32(sampleRate)
        fmt += le32(sampleRate * UInt32(channels) * UInt32(bits / 8)) // byteRate
        fmt += le16(channels * (bits / 8)) // blockAlign
        fmt += le16(bits)
        let fmtChunk = chunk(id: "fmt ", payload: fmt)
        let dataChunk = chunk(id: "data", payload: [UInt8](repeating: 0, count: sampleBytes))

        var body: [UInt8] = Array("WAVE".utf8)
        body += fmtChunk
        body += extraChunksBeforeData
        body += dataChunk

        var riff: [UInt8] = Array("RIFF".utf8)
        riff += le32(UInt32(body.count))
        riff += body
        return Data(riff)
    }

    private func chunk(id: String, payload: [UInt8]) -> [UInt8] {
        var out = Array(id.utf8)
        out += le32(UInt32(payload.count))
        out += payload
        if payload.count % 2 == 1 { out += [0] } // word alignment padding
        return out
    }

    private func le16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xff), UInt8(v >> 8)] }
    private func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)]
    }
}
