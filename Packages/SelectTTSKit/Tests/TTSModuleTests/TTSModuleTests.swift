import XCTest
@testable import TTSModule
import SpeechCore
import TextRouting

private struct BoomError: Error {}

/// Records the requests it received and yields a fixed number of chunks (or throws).
private final class FakeProvider: SpeechProvider, @unchecked Sendable {
    let id: ProviderID = "fake"
    let displayName = "Fake"
    let chunksPerRequest: Int
    let error: Error?
    private let lock = NSLock()
    private(set) var requests: [SpeechRequest] = []

    init(chunksPerRequest: Int = 2, error: Error? = nil) {
        self.chunksPerRequest = chunksPerRequest
        self.error = error
    }

    func availableVoices() async throws -> [Voice] { [] }

    func synthesize(_ request: SpeechRequest) -> AsyncThrowingStream<AudioChunk, Error> {
        lock.lock(); requests.append(request); lock.unlock()
        let n = chunksPerRequest
        let err = error
        return AsyncThrowingStream { continuation in
            if let err { continuation.finish(throwing: err); return }
            for i in 0..<n { continuation.yield(AudioChunk(data: Data([UInt8(i % 256)]))) }
            continuation.yield(.terminal)
            continuation.finish()
        }
    }

    var requestCount: Int { lock.lock(); defer { lock.unlock() }; return requests.count }
    var requestedTexts: [String] { lock.lock(); defer { lock.unlock() }; return requests.map(\.text) }
}

private final class RecordingSink: AudioSink, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var enqueued = 0
    private(set) var finishCount = 0
    private(set) var stopCount = 0

    func enqueue(_ chunk: AudioChunk) async throws { lock.lock(); enqueued += 1; lock.unlock() }
    func finish() async { lock.lock(); finishCount += 1; lock.unlock() }
    func stop() async { lock.lock(); stopCount += 1; lock.unlock() }

    var snapshot: (enqueued: Int, finish: Int, stop: Int) {
        lock.lock(); defer { lock.unlock() }
        return (enqueued, finishCount, stopCount)
    }
}

final class TTSModuleTests: XCTestCase {

    private func makeModule(
        provider: FakeProvider, sink: RecordingSink, maxCharacters: Int = 4096
    ) -> TTSModule {
        TTSModule(
            maxCharacters: maxCharacters,
            sink: sink,
            provider: { provider },
            makeRequest: { SpeechRequest(text: $0, voice: "v") }
        )
    }

    func testSpeaksShortTextAsOneRequest() async throws {
        let provider = FakeProvider(chunksPerRequest: 3) // 3 + terminal
        let sink = RecordingSink()
        let module = makeModule(provider: provider, sink: sink)

        try await module.perform(TextInput(text: "Hello world."))

        XCTAssertEqual(provider.requestCount, 1)
        let snap = sink.snapshot
        XCTAssertEqual(snap.enqueued, 4) // 3 audio + terminal
        XCTAssertEqual(snap.finish, 1)
        XCTAssertEqual(snap.stop, 0)
    }

    func testChunksLongTextIntoMultipleRequests() async throws {
        let provider = FakeProvider(chunksPerRequest: 1)
        let sink = RecordingSink()
        let module = makeModule(provider: provider, sink: sink, maxCharacters: 40)

        let text = String(repeating: "This is a sentence. ", count: 10) // ~200 chars
        try await module.perform(TextInput(text: text))

        XCTAssertGreaterThan(provider.requestCount, 1)
        // Every requested chunk respects the limit.
        for t in provider.requestedTexts { XCTAssertLessThanOrEqual(t.count, 40) }
        XCTAssertEqual(sink.snapshot.finish, 1)
    }

    func testEmptyTextIsNoOp() async throws {
        let provider = FakeProvider()
        let sink = RecordingSink()
        let module = makeModule(provider: provider, sink: sink)

        XCTAssertFalse(module.canHandle(TextInput(text: "   ")))
        try await module.perform(TextInput(text: "   "))
        XCTAssertEqual(provider.requestCount, 0)
        XCTAssertEqual(sink.snapshot.enqueued, 0)
    }

    func testProviderErrorStopsSinkAndRethrows() async {
        let provider = FakeProvider(error: BoomError())
        let sink = RecordingSink()
        let module = makeModule(provider: provider, sink: sink)

        do {
            try await module.perform(TextInput(text: "Hello."))
            XCTFail("expected error")
        } catch {
            XCTAssertTrue(error is BoomError)
        }
        XCTAssertEqual(sink.snapshot.stop, 1)
        XCTAssertEqual(sink.snapshot.finish, 0)
    }
}
