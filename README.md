# SelectTTS

Open-source, native macOS menu-bar app that **captures selected text from (almost) any app**,
**routes it to pluggable text modules**, and **speaks it** via a choice of providers — cloud
(OpenAI, Groq, ElevenLabs, …), custom OpenAI-compatible / local TTS servers (Kokoro-FastAPI,
AllTalk, Speaches, LocalAI), or the built-in **offline system voice** (zero config, no key).

Text-to-speech is the flagship module; the router is module-agnostic, so future modules
(translate, summarize, "send to an LLM with prompt X") plug in by implementing one protocol.

> **Status:** Research + planning complete (see [`docs/implementation-plan.md`](docs/implementation-plan.md)
> and [`ref/`](ref/)). Implementation in progress — the pure cores in
> [`Packages/SelectTTSKit`](Packages/SelectTTSKit) build and unit-test headlessly; the SwiftUI
> menu-bar app shell (`.xcodeproj`) is built in Xcode.

## Repository layout

```
docs/implementation-plan.md     # the load-bearing plan (architecture, decisions D1–D11, milestones)
ref/                            # adversarially-verified research backing every decision
Packages/SelectTTSKit/          # pure, UI-free, headless-testable cores (one target per module)
  Sources/
    SpeechCore/                 # SpeechProvider protocol, SpeechRequest, AudioChunk, SentenceChunker
    TextRouting/                # TextInput, TextModule, TextRouter, ModuleRegistry
    SelectionCapture/           # SelectionCapturing protocol + native Accessibility reader
    Providers/                  # OpenAICompatibleProvider, ElevenLabsProvider, SystemSpeechProvider
    AudioPlayback/              # streaming PCM playback math (Int16↔Float32, WAV parsing)
    AppSettings/                # ProviderConfig (Codable), Keychain/secret store, settings store
    TTSModule/                  # the flagship module: chunk → synthesize → play
  Tests/                        # XCTest unit tests for the pure logic
```

The app target depends on the cores plus remote SPM packages (SelectedTextKit, KeyboardShortcuts,
Defaults, LaunchAtLogin-Modern, Sparkle) and injects their implementations through the protocols
above (decisions D6/D10/D11).

## Building & testing the cores

```sh
cd Packages/SelectTTSKit
swift build
swift test
```

Requires the Swift 6.x toolchain (Command Line Tools is enough for the cores). The full app needs
Xcode (macOS 14 deployment target).

## Building the app

The Xcode project is generated from [`project.yml`](project.yml) with
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (decision D12):

```sh
brew install xcodegen      # one-time
xcodegen generate          # writes SelectTTS.xcodeproj (gitignored)
open SelectTTS.xcodeproj
```

In Xcode, set your Development Team under **Signing & Capabilities**, then build & run the
`SelectTTS` scheme. The app launches as a menu-bar item (no Dock icon). The current build is
increment 1: a menu-bar shell with a **Speak Sample** action that runs text through the offline
system voice. Selection capture (global hotkey), provider profiles, and auto-update land in
subsequent increments — see [`docs/implementation-plan.md`](docs/implementation-plan.md) §13 and
`.planning/task_plan.md`.

## License

[MIT](LICENSE). SelectTTS depends on the MIT-licensed
[SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) (and its MIT deps AXSwift/KeySender);
it does **not** copy code from the GPL-3.0 Easydict repo. Bundled third-party notices live in
[`NOTICES.md`](NOTICES.md).
