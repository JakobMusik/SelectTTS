import XCTest
@testable import AppCore
import SpeechCore
import TextRouting
import SelectionCapture
import AppSettings

final class ProviderFactoryTests: XCTestCase {

    func testSystemKindBuildsSystemProvider() throws {
        let provider = try ProviderFactory.makeProvider(from: .systemDefault, secrets: InMemorySecretStore())
        XCTAssertEqual(provider.id, "system")
    }

    func testOpenAICompatibleRequiresBaseURL() {
        let config = ProviderConfig(kind: .openAICompatible, name: "Broken", baseURLString: nil)
        XCTAssertThrowsError(try ProviderFactory.makeProvider(from: config, secrets: InMemorySecretStore())) {
            XCTAssertEqual($0 as? ProviderFactoryError, .missingBaseURL)
        }
    }

    func testOpenAICompatibleResolvesKeyAndIdentity() throws {
        let secrets = InMemorySecretStore()
        try secrets.set("sk-secret", for: "ref-openai")
        let config = ProviderConfig(
            id: "openai-profile", kind: .openAICompatible, name: "OpenAI",
            baseURLString: "https://api.openai.com/v1", apiKeyKeychainRef: "ref-openai",
            model: "tts-1", voice: "marin"
        )
        let provider = try ProviderFactory.makeProvider(from: config, secrets: secrets)
        XCTAssertEqual(provider.id, "openai-profile")
        XCTAssertEqual(provider.displayName, "OpenAI")
    }

    func testElevenLabsKindBuilds() throws {
        let config = ProviderConfig(id: "el", kind: .elevenLabs, name: "ElevenLabs", apiKeyKeychainRef: nil)
        let provider = try ProviderFactory.makeProvider(from: config, secrets: InMemorySecretStore())
        XCTAssertEqual(provider.id, "el")
    }

    func testMakeRequestMapsConfigFields() {
        let config = ProviderConfig(
            kind: .openAICompatible, name: "x", model: "tts-1", voice: "alloy", format: .pcm, speed: 1.5
        )
        let req = ProviderFactory.makeRequest(text: "hello", config: config)
        XCTAssertEqual(req.text, "hello")
        XCTAssertEqual(req.voice, "alloy")
        XCTAssertEqual(req.model, "tts-1")
        XCTAssertEqual(req.format, .pcm)
        XCTAssertEqual(req.speed, 1.5)
    }
}

private final class CountingModule: TextModule, @unchecked Sendable {
    let id: ModuleID = "counter"
    let displayName = "counter"
    var isEnabled = true
    private let lock = NSLock()
    private(set) var lastText: String?
    func canHandle(_ input: TextInput) -> Bool { true }
    func perform(_ input: TextInput) async throws { lock.lock(); lastText = input.text; lock.unlock() }
    var captured: String? { lock.lock(); defer { lock.unlock() }; return lastText }
}

final class CaptureSpeakCoordinatorTests: XCTestCase {

    func testCaptureAndRoutePassesTextThrough() async throws {
        let module = CountingModule()
        let coordinator = CaptureSpeakCoordinator(
            capturer: StubSelectionCapturer(text: "captured selection"),
            router: TextRouter(registry: ModuleRegistry([module]))
        )
        let outcome = try await coordinator.captureAndRoute(trigger: .hotkey)
        XCTAssertEqual(outcome.handledBy, ["counter"])
        XCTAssertEqual(module.captured, "captured selection")
    }

    func testCaptureErrorPropagates() async {
        let coordinator = CaptureSpeakCoordinator(
            capturer: StubSelectionCapturer(result: .failure(.noSelection)),
            router: TextRouter(registry: ModuleRegistry([CountingModule()]))
        )
        do {
            _ = try await coordinator.captureAndRoute(trigger: .hotkey)
            XCTFail("expected capture error")
        } catch {
            XCTAssertEqual(error as? CaptureError, .noSelection)
        }
    }

    func testEmptySelectionIsRejectedByRouter() async {
        let coordinator = CaptureSpeakCoordinator(
            capturer: StubSelectionCapturer(text: "   "),
            router: TextRouter(registry: ModuleRegistry([CountingModule()]))
        )
        do {
            _ = try await coordinator.captureAndRoute(trigger: .menuBar)
            XCTFail("expected rejection")
        } catch {
            XCTAssertEqual(error as? RoutingRejection, .empty)
        }
    }
}
