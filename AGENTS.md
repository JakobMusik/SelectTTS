# SelectTTS — guide for agents and contributors

SelectTTS is a native macOS menu-bar app (macOS 14+). Select text in almost any app, press a
hotkey, and it is read aloud by a provider of your choice: OpenAI or another OpenAI-compatible API
(Groq, or a local TTS server such as Kokoro-FastAPI, AllTalk, Speaches, LocalAI), ElevenLabs, or
the built-in offline system voice. Captured text goes through a small router, so features other
than speech can be added as modules.

## Layout

| Path | What it is |
|------|------------|
| `Packages/SelectTTSKit/` | The UI-free cores: one Swift package, one target per module, with unit tests. **Apple SDK only**, so `swift test` runs without Xcode or network. |
| `App/` | The SwiftUI menu-bar app. The only place remote packages (SelectedTextKit, KeyboardShortcuts) are used. |
| `scripts/release/`, `packaging/` | Release signing, DMG packaging and the Homebrew cask ([`scripts/release/README.md`](scripts/release/README.md)). |

## How a selection gets spoken

1. **Hotkey:** `App/Hotkey/SpeakSelectionShortcut.swift`. There is no default shortcut; the user
   records one in Settings ▸ Shortcuts, and pressing it again stops speaking.
2. **Capture:** `App/Capture/SelectedTextKitCapturer.swift` tries Accessibility, then Edit ▸ Copy,
   then a simulated ⌘C, restoring the clipboard afterwards.
3. **Wiring:** `App/AppEnvironment.swift` builds everything once at launch, using
   `AppCore/CaptureSpeakCoordinator`, `TTSPipeline` and `ProviderFactory`.
4. **Routing:** `TextRouting/TextRouter` hands the text to each enabled `TextModule` in the
   `ModuleRegistry`.
5. **Speech:** `TTSModule` splits the text with `SpeechCore/SentenceChunker` and asks the active
   `SpeechProvider` for audio, chunk by chunk. The active profile is re-read for every utterance.
6. **Providers** (`Providers/`): `OpenAICompatibleProvider`, `ElevenLabsProvider`,
   `SystemSpeechProvider`.
7. **Playback:** `AudioPlayback/StreamingAudioPlayer` plays `wav`/`pcm` as it arrives.
   Compressed formats can't be streamed.

Settings live in `AppSettings/`. Provider profiles (`ProviderConfig`) are stored in UserDefaults;
API keys are stored only in the Keychain, and the profile keeps just a reference to them.

## Build and test

```sh
# Cores: no Xcode, no network
cd Packages/SelectTTSKit
swift build
swift test
swift test --filter ProvidersTests        # one test target

# App, headless (what CI runs)
xcodebuild -project SelectTTS.xcodeproj -scheme SelectTTS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build

# Lint before committing
swiftformat --lint .
swiftlint lint --quiet

# Release: signed DMG in dist/, cask updated (see scripts/release/README.md)
scripts/release/build-release.sh 0.2.0
```

CI (`.github/workflows/ci.yml`) runs the core tests, the headless app build, and a lint pass that
doesn't fail the build.

## Using Xcode (optional)

1. `open SelectTTS.xcodeproj`. Under the SelectTTS target ▸ Signing & Capabilities, choose your own
   team (a free Personal Team works).
2. Run the **SelectTTS** scheme. The app appears in the menu bar, with no Dock icon.
3. Allow it under System Settings ▸ Privacy & Security ▸ **Accessibility**, then relaunch it.
4. `App/` is a synchronized folder: adding, renaming or deleting files there needs no project
   edit. Change build settings, entitlements, Info.plist keys and packages in Xcode; don't
   hand-edit `project.pbxproj`.

Agents with MCP support can build, run and preview through Xcode's MCP bridge
(`xcrun mcpbridge`) while the project is open in Xcode.

## Rules

- **Keep `SelectTTSKit` Apple-SDK-only.** Anything needing a remote package becomes a protocol in
  the cores with its implementation in `App/`. Tests use the in-memory doubles
  (`InMemorySettingsStore`, `StubSelectionCapturer`, …).
- **Keep a stable signing identity.** macOS ties the Accessibility grant to the code signature; an
  ad-hoc signature changes on every build and silently drops the grant. `CODE_SIGNING_ALLOWED=NO`
  builds are for compile checks only.
- **Never replace the release identity** ("SelectTTS Self-Signed", fingerprint in
  `packaging/signing/certificate-sha1.txt`). Users' grants are pinned to it; restore the backup
  instead.
- **Add a text module:** implement `TextModule` and register it in `AppEnvironment`.
- **Add a speech provider:** a new `SpeechProvider`, a `ProviderKind` case, and a `ProviderFactory`
  branch. A new OpenAI-compatible backend needs no code, just a profile. LM Studio and Ollama don't
  serve TTS, so local profiles must point at a TTS server.
- **Add or re-pin a remote package:** copy its license file into `App/Licenses/` and list it in
  `ThirdPartyComponent.all` (`App/Settings/LicensesView.swift`) and `NOTICES.md`. The app shows
  these texts under Settings ▸ About.
- **Capture uses explicit strategies, not `.auto`.** `.auto` gives up when the Accessibility read
  fails, which Electron apps (VS Code, Slack) do.
- **No App Sandbox, no Mac App Store.** Capture needs Accessibility and Apple Events, which the
  sandbox forbids.

## License

MIT ([`LICENSE`](LICENSE)); third-party notices are in [`NOTICES.md`](NOTICES.md). Use the
MIT-licensed SelectedTextKit package; never copy code from Easydict, which is GPL-3.0.
