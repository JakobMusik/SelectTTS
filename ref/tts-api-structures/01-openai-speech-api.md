# OpenAI Speech API — `POST /v1/audio/speech`

All claims below verified **3-0 live on 2026-06-12** against OpenAI's API reference
(`developers.openai.com/api/docs/api-reference/audio/createSpeech`) and the text-to-speech guide.

## Request

```http
POST https://api.openai.com/v1/audio/speech
Authorization: Bearer $OPENAI_API_KEY
Content-Type: application/json
```

```json
{
  "model": "gpt-4o-mini-tts",
  "input": "Text to speak — maximum length is 4096 characters.",
  "voice": "marin",
  "response_format": "wav",
  "speed": 1.0,
  "instructions": "Speak in a calm, low tone.",
  "stream_format": "audio"
}
```

| Field | Required | Values / limits | Caveats |
|-------|:---:|------------------|---------|
| `model` | ✅ | `tts-1` (low latency), `tts-1-hd` (quality), `gpt-4o-mini-tts` (flagship), `gpt-4o-mini-tts-2025-12-15` (snapshot) | Deprecated `gpt-4o-mini-tts-2025-03-20` callable until 2026-07-23 shutdown |
| `input` | ✅ | **≤ 4096 characters** | Client must chunk longer text (see SelectTTS chunking design) |
| `voice` | ✅ | 13 built-ins: alloy, ash, ballad, coral, echo, fable, onyx, nova, sage, shimmer, verse, marin, cedar | **Model-dependent**: tts-1/tts-1-hd accept only 9 (no ballad, verse, marin, cedar). marin/cedar recommended for best quality. **Voice picker must be model-aware.** |
| `response_format` | — | `mp3` (default), `opus`, `aac`, `flac`, `wav`, `pcm` | `pcm` = raw **24 kHz, 16-bit signed, little-endian, no header**. `wav` recommended "to avoid decoding overhead" (low latency). |
| `speed` | — | 0.25 – 4.0, default 1.0 | Community reports: **gpt-4o-mini-tts ignores `speed`** in practice; reliable only on tts-1/tts-1-hd. (Verifier caveat, community-sourced.) |
| `instructions` | — | free text, ≤ 4096 chars | Voice steering ("speak like X"). **Does not work with tts-1 / tts-1-hd.** |
| `stream_format` | — | `audio` (default), `sse` | **`sse` not supported on tts-1 / tts-1-hd.** |

## Response

- Default (`stream_format: "audio"` or omitted): **raw audio file content** in the requested
  format. Delivered with **HTTP chunked transfer encoding on all models** — "the audio can be
  played before the full file is generated". Docs: "For the fastest response times, we recommend
  using wav or pcm."
- `stream_format: "sse"` (gpt-4o-mini-tts only): Server-Sent Events stream of
  `speech.audio.delta` events carrying **base64-encoded** audio chunks, terminated by
  `speech.audio.done`.

## Implications for SelectTTS

1. **Chunker is mandatory** — selections routinely exceed 4096 chars. Split on sentence
   boundaries; synthesize chunk N+1 while N plays.
2. **Prefer `wav` (or `pcm`)** for time-to-first-audio and decoding simplicity; both sidestep
   MP3 frame-boundary issues when streaming (see `04-…`).
3. **Capability flags per model**, not per provider: `supportsInstructions`, `supportsSSE`,
   `speedHonored`, `voiceCatalog` all differ between tts-1-family and gpt-4o-mini-tts.
4. Plain chunked-transfer streaming is the portable mode; treat SSE as an OpenAI-only optimization.
5. Model/voice lists churn — keep them as editable strings + refreshable presets, not enums.
