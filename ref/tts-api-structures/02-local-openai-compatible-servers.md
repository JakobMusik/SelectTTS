# Local OpenAI-Compatible TTS Servers

Which local servers expose `POST /v1/audio/speech` with the OpenAI body shape. All "verified"
items confirmed 3-0 on 2026-06-12 against the projects' READMEs/wikis and (for AllTalk and
Speaches) the actual server source code.

## Comparison

| Server | Endpoint | Status (2026-06) | Voices | Model field | Verified quirks |
|--------|----------|------------------|--------|-------------|-----------------|
| **Kokoro-FastAPI** | `http://localhost:8880/v1/audio/speech` | ✅ Active (v0.5.0, 2026-06-06) | Kokoro's own names, **blendable**: `"af_sky+af_bella"` | `"kokoro"` | Streaming with adjustable chunk size; <1 s first-token on Apple M3 Pro (self-reported, chunksize 200); smaller chunks → more intonation artifacts; pin release tags |
| **AllTalk V2** | `http://{ip}:7851/v1/audio/speech` | ✅ Active (V2 / `alltalkbeta` branch only) | The six classic OpenAI names (alloy, echo, fable, nova, onyx, shimmer) mapped to local engine voices; remap via `PUT /api/openai-voicemap` | Required **but ignored** (any string) | Limits mirror OpenAI exactly, enforced in code: input ≤ 4096, speed 0.25–4.0. No `instructions` / `stream_format`. |
| **Speaches** | `http://localhost:8000/v1/audio/speech` | ✅ Active | Per loaded model (Kokoro/piper) | Per loaded model | Accepts OpenAI body **plus non-standard `sample_rate`**; no auth by default but OpenAI SDKs require a non-empty dummy key; optional `api_key` setting enables auth. Confirmed formats: mp3, wav (opus/aac unresolved). |
| **openedai-speech** | — | ⚠️ **Archived 2026-01-04, "mostly obsolete"** | alloy…shimmer (configurable) | tts-1→Piper, tts-1-hd→Coqui XTTS | Document as **legacy**; schema stable because frozen. Last release v0.18.2 (2024-08). |
| **LM Studio** | — | ⏳ see below | — | — | — |

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
3. **Formats** — only mp3+wav are confirmed across the board. **Kokoro's exact format list is
   UNVERIFIED** (the claimed mp3/wav/opus/flac/m4a/pcm list was refuted 0-3); Speaches' opus/aac
   support is unresolved (1-2 split). Default profiles to `wav` and let users override.
4. **Extensions** — Speaches adds `sample_rate`. Tolerate-and-ignore unknown fields; optionally
   expose an "extra JSON fields" box per profile.

## LM Studio

⏳ **Pending targeted follow-up research** (first pass produced no surviving verified claims;
bug-tracker issues lmstudio-ai/lmstudio-bug-tracker#1715 and #1205 were fetched as sources but
their claims didn't survive verification). Working assumption — to be confirmed before writing
any LM-Studio-specific code or docs: its OpenAI-compatible server exposes chat/completions/
embeddings but **no `/v1/audio/speech`**. Either way SelectTTS needs no LM-Studio-specific work:
"custom OpenAI-compatible endpoint" profiles cover it if/when it ships TTS.
