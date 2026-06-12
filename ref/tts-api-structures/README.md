# TTS API Structures — Reference

Research reference for **SelectTTS**: what TTS HTTP APIs look like across cloud BYOK providers and
local OpenAI-compatible servers, and what that implies for the provider abstraction.

> Compiled via a multi-source, adversarially-verified deep-research pass on **2026-06-12**
> (26 sources fetched, 25 claims verified → 22 confirmed, 3 killed). A targeted follow-up pass
> covers the gap areas (LM Studio, Azure/Google/Groq, macOS playback, AVSpeechSynthesizer); see
> [`sources.md`](./sources.md) for provenance and per-claim verification status.

## Documents

| File | Contents |
|------|----------|
| [`01-openai-speech-api.md`](./01-openai-speech-api.md) | OpenAI `POST /v1/audio/speech` exact schema: models, voices, formats, speed, instructions, streaming modes, limits. |
| [`02-local-openai-compatible-servers.md`](./02-local-openai-compatible-servers.md) | Kokoro-FastAPI, AllTalk V2, Speaches, openedai-speech (legacy), LM Studio status. |
| [`03-elevenlabs-and-other-providers.md`](./03-elevenlabs-and-other-providers.md) | ElevenLabs API shape (custom adapter required); Azure / Google / Groq PlayAI adapter assessments. |
| [`04-macos-playback-and-system-tts.md`](./04-macos-playback-and-system-tts.md) | AVAudioPlayer vs AVAudioEngine streaming, WAV/PCM handling, MP3 chunk pitfalls, AVSpeechSynthesizer system-voice fallback. |
| [`sources.md`](./sources.md) | Annotated bibliography + verification stats + refuted claims. |

## TL;DR

**OpenAI's `POST /v1/audio/speech` is the de-facto standard.** The same
`{model, input, voice, response_format, speed}` body is accepted — verified against docs *and
server source code* — by:

| Backend | Base URL (default) | Verified | Notes |
|---------|-------------------|:---:|-------|
| OpenAI cloud | `https://api.openai.com/v1` | ✅ 3-0 | 13 model-dependent voices, 4096-char input cap |
| Kokoro-FastAPI | `http://localhost:8880/v1` | ✅ 3-0 | model `"kokoro"`, blendable `af_*+af_*` voices, active |
| AllTalk V2 | `http://localhost:7851/v1` | ✅ 3-0 | model ignored; six classic OpenAI voice names, remappable |
| Speaches | `http://localhost:8000/v1` | ✅ 3-0 | extra `sample_rate` field; SDKs need a dummy key |
| openedai-speech | — | ✅ 3-0 | **archived Jan 2026 — legacy only** |

**ElevenLabs is *not* OpenAI-shaped** (voice id in the URL path, `xi-api-key` header, separate
voice-listing endpoint) → it gets its own adapter.

## Provider-abstraction implication (synthesis of verified claims)

One **`OpenAICompatibleProvider`** with a configurable base URL + per-backend *capability
metadata* covers OpenAI and all live local servers. The metadata that genuinely varies:

1. **Voice catalog** — OpenAI's 13 model-dependent names vs Kokoro's `af_*` (+blends) vs
   AllTalk's fixed six. Don't hard-code a voice list; make it per-provider-config.
2. **Model handling** — meaningful at OpenAI; literal `"kokoro"` at Kokoro; required-but-ignored
   at AllTalk. A free-text model field per config is correct.
3. **Feature flags** — `instructions` and `stream_format: "sse"` exist only on OpenAI
   gpt-4o-mini-tts; no local server verified to support them.
4. **Auth** — real key (OpenAI) vs any non-empty dummy string (local servers; OpenAI SDKs refuse
   empty keys).

**Lowest-common-denominator streaming path:** request `wav` (or `pcm` + client-side header
handling) over plain HTTP chunked transfer — supported by OpenAI on all models and the verified
local servers, and avoids MP3 chunk-boundary decoding entirely.

Separate adapters: `ElevenLabsProvider` (verified shape) and, per follow-up research,
Azure/Google if ever wanted. System `AVSpeechSynthesizer` is the offline zero-config default
(see `04-…`).
