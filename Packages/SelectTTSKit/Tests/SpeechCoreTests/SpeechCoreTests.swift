@testable import SpeechCore
import XCTest

final class SentenceChunkerTests: XCTestCase {

    func testShortTextIsOneChunk() {
        let chunks = SentenceChunker.chunk("Hello world.", maxCharacters: 100)
        XCTAssertEqual(chunks, ["Hello world."])
    }

    func testEmptyAndWhitespaceYieldNothing() {
        XCTAssertEqual(SentenceChunker.chunk("", maxCharacters: 100), [])
        XCTAssertEqual(SentenceChunker.chunk("   \n\t ", maxCharacters: 100), [])
    }

    func testLongTextSplitsWithinLimitAndPreservesWords() {
        let sentence = "The quick brown fox jumps over the lazy dog. "
        let text = String(repeating: sentence, count: 50) // ~2250 chars
        let limit = 200
        let chunks = SentenceChunker.chunk(text, maxCharacters: limit)

        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, limit, "chunk exceeded limit: \(chunk.count)")
            XCTAssertFalse(chunk.isEmpty)
        }
        // No words were dropped (token multiset preserved).
        let original = text.split(separator: " ").filter { !$0.isEmpty }.count
        let recombined = chunks.joined(separator: " ").split(separator: " ").filter { !$0.isEmpty }.count
        XCTAssertEqual(original, recombined)
    }

    func testOversizedUnbreakableRunIsHardSplit() {
        let run = String(repeating: "a", count: 1000) // single token, no spaces
        let limit = 256
        let chunks = SentenceChunker.chunk(run, maxCharacters: limit)
        XCTAssertEqual(chunks.count, 4) // 256*3 + 232
        for chunk in chunks { XCTAssertLessThanOrEqual(chunk.count, limit) }
        XCTAssertEqual(chunks.joined().count, 1000)
    }
}

final class SpeechCoreTypeTests: XCTestCase {

    func testStreamableFormats() {
        XCTAssertTrue(AudioFormat.wav.isStreamable)
        XCTAssertTrue(AudioFormat.pcm.isStreamable)
        XCTAssertFalse(AudioFormat.mp3.isStreamable)
        XCTAssertFalse(AudioFormat.opus.isStreamable)
    }

    func testSpeechRequestClampsSpeed() {
        XCTAssertEqual(SpeechRequest(text: "x", voice: "v", speed: 99).speed, 4.0)
        XCTAssertEqual(SpeechRequest(text: "x", voice: "v", speed: -5).speed, 0.25)
        XCTAssertEqual(SpeechRequest(text: "x", voice: "v", speed: 1.5).speed, 1.5)
    }

    func testCapabilityPresets() {
        XCTAssertEqual(ProviderCapabilities.openAI.maxInputCharacters, 4096)
        XCTAssertFalse(ProviderCapabilities.openAI.speedHonored) // gpt-4o-mini-tts ignores speed
        XCTAssertTrue(ProviderCapabilities.openAITTS1.speedHonored)
        XCTAssertGreaterThan(ProviderCapabilities.kokoro.maxInputCharacters, 4096)
    }

    func testOpenAIpcmFormatConstants() {
        XCTAssertEqual(PCMStreamFormat.openAIpcm.sampleRate, 24_000)
        XCTAssertEqual(PCMStreamFormat.openAIpcm.bitsPerSample, 16)
        XCTAssertEqual(PCMStreamFormat.openAIpcm.bytesPerFrame, 2)
        XCTAssertFalse(PCMStreamFormat.openAIpcm.isFloat)
    }
}
