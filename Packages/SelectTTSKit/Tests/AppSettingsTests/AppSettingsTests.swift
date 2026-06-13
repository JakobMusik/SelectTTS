import XCTest
@testable import AppSettings
import SpeechCore

final class ProviderConfigTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let config = ProviderConfig(
            kind: .openAICompatible,
            name: "OpenAI",
            baseURLString: "https://api.openai.com/v1",
            apiKeyKeychainRef: "ref-openai",
            model: "gpt-4o-mini-tts",
            voice: "marin",
            format: .pcm,
            speed: 1.25,
            capabilities: .openAI
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ProviderConfig.self, from: data)
        XCTAssertEqual(config, decoded)
        XCTAssertEqual(decoded.baseURL, URL(string: "https://api.openai.com/v1"))
    }

    func testSystemDefaultIsKeyless() {
        XCTAssertEqual(ProviderConfig.systemDefault.kind, .system)
        XCTAssertNil(ProviderConfig.systemDefault.apiKeyKeychainRef)
        XCTAssertNil(ProviderConfig.systemDefault.baseURL)
    }
}

final class InMemorySecretStoreTests: XCTestCase {

    func testSetGetDelete() throws {
        let store = InMemorySecretStore()
        XCTAssertNil(try store.secret(for: "ref"))
        try store.set("sk-123", for: "ref")
        XCTAssertEqual(try store.secret(for: "ref"), "sk-123")
        try store.delete("ref")
        XCTAssertNil(try store.secret(for: "ref"))
    }
}

final class SettingsStoreTests: XCTestCase {

    func testActiveConfigResolvesSelectedID() {
        let openAI = ProviderConfig(id: "openai", kind: .openAICompatible, name: "OpenAI")
        let store = InMemorySettingsStore(configs: [.systemDefault, openAI], activeID: "openai")
        XCTAssertEqual(store.activeConfig().id, "openai")
    }

    func testActiveConfigFallsBackToFirstThenSystem() {
        let store = InMemorySettingsStore(configs: [.systemDefault], activeID: nil)
        XCTAssertEqual(store.activeConfig().id, "system")

        let empty = InMemorySettingsStore(configs: [], activeID: nil)
        XCTAssertEqual(empty.activeConfig().kind, .system) // .systemDefault fallback
    }

    func testSaveAndLoad() {
        let store = InMemorySettingsStore()
        let configs = [ProviderConfig(id: "x", kind: .elevenLabs, name: "EL")]
        store.saveProviderConfigs(configs)
        store.saveActiveProviderID("x")
        XCTAssertEqual(store.loadProviderConfigs().map(\.id), ["x"])
        XCTAssertEqual(store.loadActiveProviderID(), "x")
    }
}
