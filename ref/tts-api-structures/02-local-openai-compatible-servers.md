# Local OpenAI-Compatible TTS Servers

Which local servers expose `POST /v1/audio/speech` with the OpenAI body shape. Pass-1 "verified"
items (Kokoro/AllTalk/Speaches/openedai-speech) were confirmed 3-0 on 2026-06-12 against the
projects' READMEs/wikis and (for AllTalk and Speaches) the actual server source code; the
**pass-2 gap-fill** (wf_011ff0d2-367, **2026-06-13**) added LocalAI, llama.cpp, and the
definitive LM Studio/Ollama answer, and upgraded Kokoro's format list to confirmed.

## Comparison

| Server | Endpoint | Status (2026-06) | Voices | Model field | Verified quirks |
|--------|----------|------------------|--------|-------------|-----------------|
| **Kokoro-FastAPI** | `http://localhost:8880/v1/audio/speech` | ✅ Active (v0.5.0, 2026-06-06) | Kokoro's own names (`af_bella`, `af_sky`, `bf_emma`, `ef_dora`, …), **blendable**: `"af_sky+af_bella"`, weighted `"af_bella(2)+af_sky(1)"` | `"kokoro"` | api_key dummy `"not-needed"`. **Formats CONFIRMED (pass 2): mp3, wav, opus, flac, m4a, pcm** (pass-1 list had been refuted 0-3 — now upgraded). Streaming with adjustable chunk size; <1 s first-token on Apple M3 Pro (self-reported, chunksize 200); smaller chunks → more intonation artifacts; pin release tags |
| **AllTalk V2** | `http://{ip}:7851/v1/audio/speech` | ✅ Active (V2 / `alltalkbeta` branch only) | The six classic OpenAI names (alloy, echo, fable, nova, onyx, shimmer) mapped to local engine voices; remap via `PUT /api/openai-voicemap` | Required **but ignored** (any string) | Limits mirror OpenAI exactly, enforced in code: input ≤ 4096, speed 0.25–4.0. No `instructions` / `stream_format`. |
| **Speaches** | `http://localhost:8000/v1/audio/speech` | ✅ Active | Per loaded model (Kokoro/piper), e.g. voice `af_heart` | HuggingFace id, e.g. `speaches-ai/Kokoro-82M-v1.0-ONNX` | Accepts OpenAI body **plus non-standard `sample_rate`**; api_key must be non-empty/arbitrary (`"cant-be-empty"`); optional `api_key` setting enables auth. Formats: mp3 (default), wav — **opus and aac NOT supported**. |
| **LocalAI** | `http://localhost:8080/v1/audio/speech` | ✅ Active | Backend-dependent (e.g. Qwen3-TTS Vivian/Ryan, VibeVoice Frank/Emma, Piper filename) | Name configured in a **YAML backend file** (qwen-tts, xtts_v2/coqui, piper, bark, …) | Also exposes a native `/tts`. Formats: **wav (default), mp3, aac, flac, opus** (via ffmpeg). Open: whether `/v1/audio/speech` enforces a key when started with `api_keys` config. |
| **llama.cpp** (`llama-server`) | `http://localhost:8080/v1/audio/speech` | ✅ **Only with a Qwen3-Omni talker model** | Model-dependent | n/a (model is loaded via flags) | Endpoint exists **only** when launched with `-tk, --talker-model FILE` ("path to the qwen3-omni talker gguf, enables the /v1/audio/speech endpoint") + `-c2w, --code2wav-model FILE` (talker code detokenizer). **NOT** available for ordinary GGUF chat models. |
| **openedai-speech** | — | ⚠️ **Archived 2026-01-04, "mostly obsolete"** | alloy…shimmer (configurable) | tts-1→Piper, tts-1-hd→Coqui XTTS | Document as **legacy**; schema stable because frozen. Formats mp3/opus/aac/flac/wav/pcm, no API key. Last release v0.18.2 (2024-08). |
| **LM Studio** | — | ❌ **No `/v1/audio/speech`** | — | — | See "LM Studio & Ollama" below — definitively no TTS endpoint. |
| **Ollama** | — | ❌ **No `/v1/audio/speech`** | — | — | See "LM Studio & Ollama" below — no native TTS. |

## The drop-in pattern (verified for Kokoro-FastAPI & Speaches)

The official OpenAI SDK works against all of these by overriding the base URL and passing a
dummy key (SDKs refuse empty keys; the servers don't check the value):

```python
client = OpenAI(base_url="http://localhost:8880/v1", api_key="not-needed")
client.audio.speech.create(model="kokoro", voice="af_sky+af_bella", input="Hello world")
```

For SelectTTS this means: **one `OpenAICompatibleProvider` with `{baseURL, apiKey?, model, voice}`
per user-defined profile** covers every row above — no per-server code, only per-profile config.

## What varies (→ per-profile config, not code)

1. **Voice names** — OpenAI's 13, Kokoro's `af_*`/blends, AllTalk's fixed six. A free-text voice
   field with optional provider-fetched suggestions beats a hard-coded picker.
2. **Model string** — meaningful (OpenAI) / literal `"kokoro"` / ignored (AllTalk). Free text.
3. **Formats** — **mp3 + wav are the safe cross-server baseline.** Per-server (pass 2): Kokoro now
   **CONFIRMED mp3/wav/opus/flac/m4a/pcm**; Speaches is **mp3/wav only** (opus & aac NOT supported);
   LocalAI is wav/mp3/aac/flac/opus (via ffmpeg); openedai-speech is mp3/opus/aac/flac/wav/pcm.
   Default profiles to `wav` and let users override (D5 prefers `wav`/`pcm` for streaming anyway).
4. **Extensions** — Speaches adds `sample_rate`. Tolerate-and-ignore unknown fields; optionally
   expose an "extra JSON fields" box per profile.

## LM Studio & Ollama — definitively NO `/v1/audio/speech`

Resolved in **pass 2 (2026-06-13)** against primary docs/trackers (all 9 localtts claims confirmed
3-0):

- **LM Studio** — its built-in OpenAI-compat server exposes **ONLY** `GET /v1/models`,
  `POST /v1/responses`, `/v1/chat/completions`, `/v1/embeddings`, `/v1/completions`. There is **no
  audio endpoint**. Open feature request **#1715** (filed 2026-03-31, still OPEN) asks for
  "/v1/audio/speech be enabled and supported for all models that can do TTS" — no maintainer
  commitment / ETA. [sources: lmstudio.ai/docs/developer/openai-compat,
  github.com/lmstudio-ai/lmstudio-bug-tracker/issues/1715]
- **Ollama** — **no native TTS** / `/v1/audio/speech`. Issue **#11021** ("Native Text-to-Speech
  (TTS) model support", opened 2025-06-08) proposed a `POST /v1/audio/speech` endpoint + an
  `ollama tts run` CLI; it was **closed as a duplicate of #5424** and remains unimplemented.
  [sources: github.com/ollama/ollama/issues/11021]
- **llama.cpp** is the one mainstream runtime that *can* serve TTS — but **only** when launched
  with a Qwen3-Omni talker model (`--talker-model` + `--code2wav-model`), see the table row above.

### Scoping note for SelectTTS

**TTS profiles point at dedicated TTS servers** (Kokoro-FastAPI, AllTalk V2, Speaches, LocalAI,
openedai-speech, or llama.cpp+Qwen3-Omni) — **NOT** at LM Studio or Ollama. The clean deployment is
to run LM Studio/Ollama for LLM work alongside a **dedicated TTS sidecar**.

However, LM Studio and Ollama **are** the intended targets for *future LLM text-modules* (summarize,
translate, rewrite, etc.) via their `/v1/chat/completions` endpoint — that's a separate axis from
TTS. So: no LM-Studio/Ollama-specific TTS code, and a "custom OpenAI-compatible endpoint" profile
would still cover them if/when they ever ship `/v1/audio/speech` (LM Studio #1715).
