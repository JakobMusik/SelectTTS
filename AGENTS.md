# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project purpose

**SelectTTS** is an open-source, native macOS **menu-bar app** that captures the user's selected
text from (almost) any app, **routes it to pluggable text modules**, and **speaks it aloud**.
Text-to-speech is the flagship module — the router is module-agnostic, so other text-consuming
features (translate, summarize, "send to an LLM with prompt X") plug in by implementing one
protocol. The design mirrors Easydict's *capture → route → services* skeleton, with TTS as the
first-class service.

It speaks through pluggable providers: bring-your-own-key **OpenAI** (and OpenAI-compatible
backends such as Groq), **Google Gemini**, and **locally-served custom endpoints** (Kokoro-FastAPI,
AllTalk, Speaches, LocalAI, …), plus a built-in **offline system voice** (`AVSpeechSynthesizer`)
that needs no key or network. The app runs **unsandboxed + notarized** (direct download / Homebrew),
not the Mac App Store, because selection capture needs Accessibility + Apple Events that the sandbox
forbids.

## Sources of truth

These carry the *why* behind the code — read them before non-trivial work:

- `docs/implementation-plan.md` — architecture, **numbered decisions D1–D12**, and milestones (§13).
- `ref/` — adversarially-verified research backing each decision (capture techniques, TTS provider
  API shapes, macOS app practices). Cite these rather than re-deriving.
- `.planning/` — live task state and the **TODO list** (TODOs are tracked here, *not* in code — the
  SwiftLint `todo` rule is intentionally disabled).

## Commands

Two build surfaces. **The pure cores build and test headlessly without Xcode or network; the app needs Xcode.**

```sh
# Cores (Packages/SelectTTSKit) — hermetic, Apple-SDK-only, no network:
cd Packages/SelectTTSKit
swift build
swift test
swift test --filter ProvidersTests                       # one test target
swift test --filter SpeechCoreTests.SentenceChunkerTests  # one class/case (regex match)

# Type-check the cores without SwiftPM/Xcode (Command Line Tools only):
./scripts/typecheck-cores.sh

# App — the .xcodeproj is GENERATED from project.yml (XcodeGen) and gitignored; never hand-edit it:
brew install xcodegen          # one-time
xcodegen generate              # writes SelectTTS.xcodeproj
open SelectTTS.xcodeproj        # set Development Team in Signing & Capabilities, then run
xcodebuild -project SelectTTS.xcodeproj -scheme SelectTTS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build   # headless app build (as CI does)

# Lint/format (informational, non-gating until M5; run before committing):
swiftformat --lint .
swiftlint lint --quiet
```

CI (`.github/workflows/ci.yml`, `macos-14`) runs three jobs: `swift test` on the cores, an
XcodeGen + `xcodebuild` app build with signing disabled, and a non-gating lint pass.

## Architecture

### Two layers, one hard rule

The codebase is split to keep domain logic testable in isolation:

1. **`Packages/SelectTTSKit/`** — the pure, UI-free cores, one SPM target per module. **It depends
   on nothing but the Apple SDK** (decision D11), which is *why* `swift test` is hermetic and fast.
   The cores define **protocols** for everything external: `SelectionCapturing`, `SpeechProvider`,
   `AudioSink`, `SettingsStore`, `SecretStore`, `TextModule`.
2. **`App/`** — the thin SwiftUI menu-bar shell. It owns the UI and supplies the **concrete,
   remote/SDK-backed implementations** of those protocols (e.g. `SelectedTextKitCapturer`,
   `KeychainSecretStore`, `UserDefaultsSettingsStore`, `StreamingAudioPlayer`, the concrete
   providers) and injects them.

**The rule: never add a remote SPM dependency to `SelectTTSKit`.** Remote deps (SelectedTextKit,
KeyboardShortcuts, …) live only in the app target and reach the cores through the protocols above.
Tests inject in-memory doubles (`InMemorySettingsStore`, `StubSelectionCapturer`, etc.).

### Composition

`App/AppEnvironment.swift` (`@MainActor ObservableObject`) is the **runtime composition root**: at
`init` it instantiates the concrete implementations and wires the graph, then drives `@Published`
UI state. The `AppCore` target provides the headless *wiring helpers* it calls —
`CaptureSpeakCoordinator` (capture→route), `TTSPipeline.makeModule` (builds the TTS module), and
`ProviderFactory` (config → provider). DI is one-time at startup; there is no dynamic wiring after.

Module dependency graph (enforced by per-target deps in `Package.swift`):
```
SpeechCore · TextRouting · SelectionCapture        (leaf: protocols + value types, no inter-deps)
        ↑              ↑
Providers · AudioPlayback · AppSettings   →  on SpeechCore
        ↑
TTSModule   →  on SpeechCore + TextRouting
        ↑
AppCore     →  on all of the above  (composition helpers)
```

### The speak pipeline (end to end)

trigger (global hotkey via **KeyboardShortcuts**, or a menu action)
→ `CaptureSpeakCoordinator.captureAndRoute` calls the injected `SelectionCapturing`
→ wraps the result as `TextInput { text, sourceApp, trigger, date }`
→ `TextRouter.route` validates against `RoutingPolicy` (min/max length) and dispatches to every
   enabled `TextModule` in `ModuleRegistry` whose `canHandle` passes
→ `TTSModule.perform` splits text with `SentenceChunker` (≤ the provider's `maxInputCharacters`,
   default 4096), and per chunk builds a `SpeechRequest` and calls the **active** provider
→ `provider.synthesize(request)` returns `AsyncThrowingStream<AudioChunk>`
→ chunks flow into the `AudioSink` (`StreamingAudioPlayer`) for progressive playback.

**The active provider is resolved lazily** — `TTSPipeline` holds an `activeConfig: () -> ProviderConfig`
closure re-read on *every* synthesis, so changing the profile in Settings takes effect on the next
utterance with no rebuild.

### Providers

All providers conform to one `SpeechProvider` protocol (`id`, `displayName`, `availableVoices()`,
`synthesize() -> AsyncThrowingStream<AudioChunk>`). `ProviderFactory` maps `ProviderConfig.kind`
(`.system` / `.openAICompatible` / `.elevenLabs`) to a concrete adapter:

- **`OpenAICompatibleProvider`** — one adapter for OpenAI cloud, Groq, and every local
  OpenAI-compatible TTS server (Kokoro-FastAPI, AllTalk, Speaches, LocalAI), differing only by
  `baseURL` + `ProviderCapabilities` + supplied voice catalog. (Note: **LM Studio and Ollama do not
  serve TTS** — their OpenAI-compatible servers expose chat/completions, not `/v1/audio/speech` — so
  point local TTS profiles at a dedicated TTS server.)
- **`SystemSpeechProvider`** — offline `AVSpeechSynthesizer`, the keyless default.
- **Bespoke adapters** for services whose API is *not* OpenAI-shaped: **ElevenLabs** (voice id in
  URL path, `xi-api-key` header) and **Google Gemini** (base64-audio-in-JSON). Each conforms to
  `SpeechProvider` with its own `ProviderKind` case + `ProviderFactory` branch rather than reusing
  `OpenAICompatibleProvider`.

**Config is data, not code (decision D4):** voice/model/format/speed and `ProviderCapabilities`
(`speedHonored`, `maxInputCharacters`, `supportsInstructions`, `supportsSSE`) all live in
`ProviderConfig`. Adding a new *OpenAI-compatible* backend therefore needs **zero code** — just a
new profile. Voice catalogs are runtime data (`Voice` structs), never hard-coded enums.

### Audio streaming

`StreamingAudioPlayer` (the production `AudioSink`) drives `AVAudioEngine` + `AVAudioPlayerNode`.
Only **`wav` and `pcm` are streamable** (`AudioFormat.isStreamable`); compressed formats
(mp3/opus/aac/flac/m4a) can't be fed arbitrary byte slices and take a non-progressive path — so
providers are asked for `wav`/`pcm` for live playback (decision D5). Per chunk it: parses the WAV
header once if present (`WAVHeaderParser` scans for the `data` chunk — it is **not** always at byte
44), accumulates raw bytes (`PCMByteAccumulator` carries a split 16-bit sample across chunk
boundaries), converts Int16-LE → Float32 (`PCMConverter`, ÷32768), and schedules a non-interleaved
Float32 `AVAudioPCMBuffer` (Int16/interleaved buffers crash the engine). The default PCM layout is
OpenAI's `pcm`: 24 kHz, 16-bit signed LE, mono. Critical sections use `NSLock` with no `await` held
across the lock (Swift 6 data-race safety).

### Settings, secrets, permissions

- `ProviderConfig` (Codable): `{ id, kind, name, baseURL, apiKeyKeychainRef, model, voice, format,
  speed, capabilities }`. Profiles persist via `SettingsStore` → `UserDefaultsSettingsStore`
  (JSON under `selecttts.providerConfigs`; active id under `selecttts.activeProviderID`). The
  `.system` profile is always present and cannot be deleted; `TTSPipeline` falls back to it (and
  then to an empty provider) so the app is always speakable.
- **Secrets never live in the config** — only a Keychain reference string. Keys are stored via
  `SecretStore` → `KeychainSecretStore` (Security framework, service `com.selecttts.apikeys`).
- **No App Sandbox** (D1). Capture uses SelectedTextKit's `.auto` chain (Accessibility → menu-bar
  AXPress → AppleScript → simulated ⌘C). Permissions: **Accessibility** (TCC, no entitlement —
  often needs an app relaunch after granting) and, for the AppleScript browser path, **Automation**
  (needs the `com.apple.security.automation.apple-events` entitlement + `NSAppleEventsUsageDescription`).
  The hotkey uses NSEvent global monitoring → needs Accessibility, **not** Input Monitoring.

## Conventions & gotchas

- **Do not hand-edit `SelectTTS.xcodeproj`** — it's generated and gitignored. Change build settings,
  deployment target (macOS 14), or dependencies in `project.yml`, then `xcodegen generate`.
- **Keep `SelectTTSKit` Apple-SDK-only.** A new external capability is wired as a protocol in the
  cores + a concrete impl in `App/`.
- **Add a text module** = implement `TextModule` + register it in `AppEnvironment` (no dynamic
  loading). **Add a speech provider** = a new `SpeechProvider` conformer + a `ProviderKind` case +
  a `ProviderFactory` branch (a new OpenAI-compatible *backend* needs none of that — just a profile).
- TODOs and task state live in `.planning/`, decisions in `docs/implementation-plan.md` — keep them
  in sync when you change behavior.
- The `Defaults` library is named in comments/plan but **not actually used** — settings use plain
  `UserDefaults` + JSON.

## License

MIT (`LICENSE`). SelectTTS depends on the MIT-licensed SelectedTextKit (and its MIT deps
AXSwift/KeySender); it **must not copy code from the GPL-3.0 Easydict repo**. Third-party notices
live in `NOTICES.md`.
