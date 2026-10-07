# SelectTTS

Open-source, native macOS menu-bar app that **captures selected text from (almost) any app**,
**routes it to pluggable text modules**, and **speaks it** via a choice of providers — cloud
(OpenAI, Groq, ElevenLabs, …), custom OpenAI-compatible / local TTS servers (Kokoro-FastAPI,
AllTalk, Speaches, LocalAI), or the built-in **offline system voice** (zero config, no key).

Text-to-speech is the flagship module; the router is module-agnostic, so future modules
(translate, summarize, "send to an LLM with prompt X") plug in by implementing one protocol.

> **Status:** in development. The pure cores in [`Packages/SelectTTSKit`](Packages/SelectTTSKit)
> build and unit-test headlessly; the SwiftUI menu-bar app (`.xcodeproj`) is built in Xcode.
> Contributors and coding agents: start with [`AGENTS.md`](AGENTS.md).

## Install

```sh
brew install --cask jakobmusik/tap/selecttts
```

Or download the DMG from [Releases](https://github.com/jakobmusik/SelectTTS/releases) and drag
SelectTTS to Applications. Requires macOS 14 or later.

SelectTTS isn't notarized by Apple (it's signed with the project's own certificate), so the DMG
needs a one-time **Open Anyway** in System Settings ▸ Privacy & Security; the Homebrew cask handles
that for you. Then allow SelectTTS under System Settings ▸ Privacy & Security ▸ **Accessibility** so
it can read your selection (that permission survives updates), and record a hotkey in SelectTTS
Settings ▸ Shortcuts. Maintainers: see [`scripts/release/README.md`](scripts/release/README.md).

## Repository layout

```
ref/                            # research notes behind the design (capture, TTS APIs, macOS practices)
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

The app target depends on the cores plus remote SPM packages (SelectedTextKit, KeyboardShortcuts)
and injects remote-backed implementations through the protocols above, so the cores stay
Apple-SDK-only and `swift test` needs no network.

## Building & testing the cores

```sh
cd Packages/SelectTTSKit
swift build
swift test
```

Requires the Swift 6.x toolchain (Command Line Tools is enough for the cores). The full app needs
Xcode (macOS 14 deployment target).

## Building the app

The Xcode project is committed; `App/` is a synchronized folder, so there is no generation step:

```sh
open SelectTTS.xcodeproj
```

The project pins `DEVELOPMENT_TEAM` to a Personal Team so builds are signed with a stable
Apple Development identity (an ad-hoc signature would lose the Accessibility grant on every
rebuild); change it to your own Team ID if you clone this. Then build & run the `SelectTTS` scheme.
The app launches as a menu-bar item (no Dock icon).

## License

[MIT](LICENSE). SelectTTS depends on the MIT-licensed
[SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) (and its MIT deps AXSwift/KeySender);
it does **not** copy code from the GPL-3.0 Easydict repo. Bundled third-party notices live in
[`NOTICES.md`](NOTICES.md).
