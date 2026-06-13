# Sources & Verification — TTS API Structures

## Pass 1 — deep-research wf_f3b87c38-9fe (2026-06-12)

Pipeline: 5 search angles → 26 sources fetched → 126 claims extracted → top 25 adversarially
verified (3 votes each, 2/3 refutes kill) → **22 confirmed, 3 killed** → 10 merged findings.
108 agent calls.

### Verified-claim sources (primary unless noted)

| Source | Angle | Used for |
|--------|-------|----------|
| developers.openai.com/api/docs/api-reference/audio/createSpeech | OpenAI spec | Full request/response schema (01) |
| developers.openai.com/api/docs/guides/text-to-speech | OpenAI spec | Voices, formats, streaming guidance (01) |
| developers.openai.com/api/docs/guides/audio | OpenAI spec | Streaming modes (01) |
| github.com/remsky/Kokoro-FastAPI | Local servers | Kokoro section (02) |
| docs.openwebui.com …/Kokoro-FastAPI-integration | Local servers | Corroboration for Kokoro drop-in usage |
| github.com/erew123/alltalk_tts wiki (OpenAI-compatible endpoint) + tts_server.py source | Local servers | AllTalk section (02) — limits verified in code |
| github.com/matatonic/openedai-speech (+releases) | Local servers | Legacy/archived status (02) |
| speaches.ai/usage/text-to-speech + github.com/speaches-ai/speaches src/routers/speech.py | Local servers | Speaches section (02) — body verified in code |
| elevenlabs.io/docs/api-reference/text-to-speech/convert | Provider matrix | ElevenLabs shape (03) |
| elevenlabs.io/docs/api-reference/authentication | Provider matrix | xi-api-key auth (03) |

### Fetched but no surviving verified claims in pass 1 (now resolved by pass 2)

The following were fetched in pass 1 but produced no surviving verified claims at the time. **Pass
2 (2026-06-13) re-investigated each area against primary sources and they are now citable** — see
the Pass-2 source table below:

- lmstudio-ai/lmstudio-bug-tracker issues #1715, #1205 (forum) — LM Studio TTS status
- console.groq.com/docs/text-to-speech; learn.microsoft.com Azure TTS REST; Google
  `text/synthesize` reference — other-provider shapes
- dev.to/syedharisali/medium streaming-audio blogs, community.openai.com streaming thread,
  github.com/dimitris-c/AudioStreaming, Apple dev forums 124807 — macOS playback
- developer.apple.com AVSpeechSynthesizer / AVSpeechSynthesisVoice / voice-quality /
  pitchMultiplier docs, Apple forums 689461 — system TTS

### Refuted / unresolved claims — do not state as fact

| Claim | Vote | Consequence |
|-------|------|-------------|
| Kokoro-FastAPI supports mp3/wav/opus/flac/m4a/pcm response formats | pass 1 **0-3 refuted** → **pass 2 CONFIRMED** | **Upgraded**: pass 2 re-verified the full mp3/wav/opus/flac/m4a/pcm list 3-0 against the Kokoro-FastAPI README + deepwiki |
| openedai-speech is a usable drop-in local backend | **0-3 refuted** | It's archived (Jan 2026); legacy only |
| Speaches lacks opus/aac formats | pass 1 **1-2 unresolved** → **pass 2 CONFIRMED** | **Resolved**: Speaches supports mp3 (default) + wav only; **opus and aac NOT supported** (speaches.ai docs) |

### Community-sourced caveats (not primary-doc-verified)

- gpt-4o-mini-tts reportedly ignores `speed` in practice (OpenAI community forum reports).

### Time-sensitivity notes

- OpenAI model/voice lists churn; gpt-4o-mini-tts-2025-03-20 shuts down 2026-07-23.
- Kokoro-FastAPI latency figures are self-reported; project recommends pinning release tags.
- AllTalk's OpenAI endpoint exists only on V2/`alltalkbeta`.
- Speaches no-auth is default config, not guaranteed.

## Pass 2 — gap-fill deep-research wf_011ff0d2-367 (2026-06-13)

Closed the four ⏳ gaps left by pass 1. Four research angles (**localtts, cloudtts, playback,
systts**), each adversarially verified (3 votes/claim, 2/3 refutes kill). **Results: localtts 9/9
confirmed, cloudtts 5/5 core claims confirmed, playback 11/11 confirmed, systts all
structural/API claims confirmed — zero refuted.** Written into
`04-macos-playback-and-system-tts.md` (new) and the previously-pending sections of
`02-local-openai-compatible-servers.md` and `03-elevenlabs-and-other-providers.md`.

### Pass-2 verified-claim sources (primary unless noted)

| Source | Angle | Used for |
|--------|-------|----------|
| lmstudio.ai/docs/developer/openai-compat | localtts | LM Studio endpoint list — no `/v1/audio/speech` (02) |
| github.com/lmstudio-ai/lmstudio-bug-tracker/issues/1715 | localtts | LM Studio TTS feature request, OPEN (02) |
| github.com/ollama/ollama/issues/11021 | localtts | Ollama has no native TTS; closed dup of #5424 (02) |
| github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md | localtts | llama.cpp `--talker-model` / `--code2wav-model` flags (02) |
| deepwiki.com/ggml-org/llama.cpp/6.6-text-to-speech-(tts) | localtts | Qwen3-Omni talker TTS corroboration (02) |
| localai.io/features/text-to-audio/ + /model-compatibility/ | localtts | LocalAI `:8080` endpoint, YAML backend model, formats (02) |
| github.com/remsky/Kokoro-FastAPI/blob/master/README.md + deepwiki.com/remsky/Kokoro-FastAPI | localtts | Kokoro formats mp3/wav/opus/flac/m4a/pcm + weighted voice blends (02) — **upgrades the pass-1 refute** |
| speaches.ai/usage/text-to-speech + github.com/speaches-ai/speaches README | localtts | Speaches mp3/wav only, opus/aac NOT supported (02) |
| github.com/erew123/alltalk_tts wiki | localtts | AllTalk port 7851, OpenAI voice names (02) |
| github.com/matatonic/openedai-speech | localtts | Archived legacy sidecar, formats (02) |
| console.groq.com/docs/text-to-speech | cloudtts | Groq OpenAI-shaped, Orpheus models, PlayAI shutdown 2025-12-31 (03) |
| learn.microsoft.com/en-us/azure/ai-services/speech-service/rest-text-to-speech (2026-05-21) | cloudtts | Azure SSML body, `Ocp-Apim-Subscription-Key`, `X-Microsoft-OutputFormat` (03) |
| docs.cloud.google.com/text-to-speech/docs/reference/rest/v1/text/synthesize | cloudtts | Google `text:synthesize`, base64 `audioContent`, OAuth scope (03) |
| developers.deepgram.com/docs/text-to-speech | cloudtts | Deepgram Aura `/v1/speak`, `Authorization: Token`, `?model=`, mpeg (03) |
| developers.openai.com/api/docs/guides/text-to-speech + platform.openai.com/docs/guides/text-to-speech | playback | OpenAI `pcm` = headerless 24 kHz/16-bit/LE/mono; wav/pcm fastest (04) |
| developer.apple.com/documentation/avfaudio/avaudioplayer | playback | AVAudioPlayer needs complete data, no streaming (04) |
| developer.apple.com/documentation/avfaudio/avaudioplayernode | playback | AVAudioEngine push model, `scheduleBuffer` (04) |
| developer.apple.com/documentation/avfaudio/avaudiopcmbuffer | playback | Int16→Float32 buffer recipe, `int16ChannelData` (04) |
| dev.to/joostmbakker/…sub-200ms-time-to-first-audio (StreamTTS) | playback | ~180 ms TTFA build, Float32 non-interleaved, backpressure ~3 s (04) |
| syedharisali.com/articles/streaming-audio-with-avaudioengine/ | playback | AVAudioEngine streaming walkthrough (04) |
| developer.apple.com/forums/thread/747009, /111726, /703410 | playback | Float32 format requirement, mixer auto-resample notes (04) |
| github.com/faiface/beep/issues/2 | playback | WAV header not always 44 bytes — parse `data` chunk (04) |
| github.com/lieff/minimp3 | playback | MP3 frame-boundary / consumed-bytes problem (04) |
| github.com/dimitris-c/AudioStreaming | playback | Compressed-streaming library + supported formats (04) |
| medium.com/@mehsamadi/mastering-avaudioplayernode… | playback | `.dataPlayedBack` vs `.dataRendered` completion types (04) |
| developer.apple.com/documentation/avfaudio/avspeechsynthesizer (+ utterance, voice, voicequality, delegate, write, requestpersonalvoiceauthorization) | systts | AVSpeechSynthesizer availability, ranges, enums, callbacks (04) |
| xybp888/iOS-SDKs …/AVSpeechSynthesis.h | systts | SDK-header verbatim availability + pitch/volume ranges (04) |
| developer.apple.com/videos/play/wwdc2023/10033/ + bendodson.com/weblog/2024/04/03/… | systts | Personal Voice (macOS 14+) flow (04) |
| developer.apple.com/forums/thread/678287, /684419, /731624 | systts | `write()` must-retain + zero-length-buffer convention (forum-only) (04) |

### Pass-2 caveats / still-unverified (flagged in the docs, do NOT state as hard fact)

- Google API-key auth form (`?key=` / `X-goog-api-key`) for `text:synthesize` — **unverified**;
  only the OAuth cloud-platform scope is confirmed.
- Deepgram Bearer/short-lived-JWT auth — **unverified**; only `Authorization: Token` confirmed.
- Groq PlayAI "deprecated 2025-12-23" is the **announcement** date; actual shutdown 2025-12-31.
- Groq HTTP streaming for Orpheus not explicitly documented.
- AVSpeechUtterance numeric rate min/max/default (0.0 / 1.0 / ~0.5) — **not in any primary Apple
  source**; only the three `extern const float` constants are documented.
- `write(_:toBufferCallback:)` zero-length end-of-stream convention + macOS 10.15 bug / macOS 11
  fix — **forum-only**, not in Apple reference docs (the must-retain fact itself is documented).
- No documented entitlement / Info.plist key for Personal Voice on a sandboxed/MAS app
  (absence-of-evidence).
- Int16→Float32 divisor (32768.0 vs 32767.0) — no authoritative Apple prescription.
- Several Apple AVFoundation reference pages are JS-rendered; confirmed via the SDK header +
  mirrors — re-confirm against live Apple pages at implementation time.
- llama.cpp `--talker-model` `/v1/audio/speech` documented on master only; exact first tagged
  release unknown.
