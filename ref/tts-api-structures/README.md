# TTS API Structures — Reference

Research reference for **SelectTTS**: what TTS HTTP APIs look like across cloud BYOK providers and
local OpenAI-compatible servers, and what that implies for the provider abstraction.

> Compiled via a multi-source, adversarially-verified deep-research **pass 1** on **2026-06-12**
> (26 sources fetched, 25 claims verified → 22 confirmed, 3 killed), then completed by a
> **pass-2 gap-fill** on **2026-06-13** (wf_011ff0d2-367) covering the four gap areas — LM Studio /
> Ollama TTS status, Groq/Azure/Google/Deepgram cloud shapes, macOS AVFoundation playback, and
> AVSpeechSynthesizer. **All ⏳ gaps are now filled.** See [`sources.md`](./sources.md) for
> provenance and per-claim verification status.

## Documents

| File | Contents |
|------|----------|
| [`01-openai-speech-api.md`](./01-openai-speech-api.md) | OpenAI `POST /v1/audio/speech` exact schema: models, voices, formats, speed, instructions, streaming modes, limits. |
| [`02-local-openai-compatible-servers.md`](./02-local-openai-compatible-servers.md) | Kokoro-FastAPI, AllTalk V2, Speaches, LocalAI, llama.cpp+Qwen3-Omni, openedai-speech (legacy); LM Studio / Ollama definitively have no TTS. |
| [`03-elevenlabs-and-other-providers.md`](./03-elevenlabs-and-other-providers.md) | ElevenLabs API shape (custom adapter); Groq (OpenAI-shaped preset), Azure / Google / Deepgram bespoke-adapter shapes; adapter-fit table. |
| [`04-macos-playback-and-system-tts.md`](./04-macos-playback-and-system-tts.md) | AVAudioPlayer vs AVAudioEngine streaming, Int16→Float32 PCM buffer recipe, WAV/PCM handling, MP3 chunk pitfalls, AVSpeechSynthesizer system-voice provider. |
| [`sources.md`](./sources.md) | Annotated bibliography + verification stats + refuted claims. |

## TL;DR

**OpenAI's `POST /v1/audio/speech` is the de-facto standard.** The same
`{model, input, voice, response_format, speed}` body is accepted — verified against docs *and
server source code* — by:

| Backend | Base URL (default) | Verified | Notes |
|---------|-------------------|:---:|-------|
| OpenAI cloud | `https://api.openai.com/v1` | ✅ 3-0 | 13 model-dependent voices, 4096-char input cap |
| **Groq cloud** | `https://api.groq.com/openai/v1` | ✅ 3-0 (pass 2) | OpenAI-shaped → just a preset profile; Orpheus models (PlayAI shut down 2025-12-31) |
| Kokoro-FastAPI | `http://localhost:8880/v1` | ✅ 3-0 | model `"kokoro"`, blendable `af_*+af_*` voices; formats now confirmed mp3/wav/opus/flac/m4a/pcm |
| AllTalk V2 | `http://localhost:7851/v1` | ✅ 3-0 | model ignored; six classic OpenAI voice names, remappable |
| Speaches | `http://localhost:8000/v1` | ✅ 3-0 | extra `sample_rate` field; SDKs need a dummy key; mp3/wav only |
| LocalAI | `http://localhost:8080/v1` | ✅ 3-0 (pass 2) | model from a YAML backend file; wav/mp3/aac/flac/opus |
| llama.cpp+Qwen3-Omni | `http://localhost:8080/v1` | ✅ 3-0 (pass 2) | TTS **only** with `--talker-model` + `--code2wav-model` |
| openedai-speech | — | ✅ 3-0 | **archived Jan 2026 — legacy only** |
| **LM Studio / Ollama** | — | ✅ 3-0 (pass 2) | ❌ **NO `/v1/audio/speech`** — pair with a dedicated TTS sidecar |

**ElevenLabs is *not* OpenAI-shaped** (voice id in the URL path, `xi-api-key` header, separate
voice-listing endpoint) → it gets its own adapter. **Groq *is* OpenAI-shaped** (reuse the adapter,
swap the base URL). **LM Studio and Ollama have no TTS endpoint at all** — point TTS profiles at a
dedicated TTS server, and reserve LM Studio/Ollama for future LLM text-modules via
`/v1/chat/completions`.

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

Separate adapters: `ElevenLabsProvider` (verified shape) and — per pass-2 research — bespoke
**Azure** (SSML body + `X-Microsoft-OutputFormat` header), **Google** (JSON in, **base64 audio in
JSON** out), and **Deepgram Aura** (text-field JSON + `?model=` query param, binary mpeg) if ever
wanted; **Groq** needs none (it's an OpenAI-shaped preset). System `AVSpeechSynthesizer` is the
offline zero-config default provider (see [`04-…`](./04-macos-playback-and-system-tts.md)) — and its
companion is the AVAudioEngine + AVAudioPlayerNode playback path that makes D5's `wav`/`pcm`
streaming work.
