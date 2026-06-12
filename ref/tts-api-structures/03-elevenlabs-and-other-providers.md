# ElevenLabs & Other BYOK Providers

## ElevenLabs — verified 3-0 (2026-06-12, primary docs) — needs its own adapter

ElevenLabs is **not** OpenAI-shaped in three load-bearing ways: the voice lives in the URL path,
auth is a custom header, and voices come from a separate listing endpoint.

```http
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}
xi-api-key: $ELEVENLABS_API_KEY
Content-Type: application/json
```

```json
{
  "text": "The text that will get converted into speech.",
  "model_id": "eleven_multilingual_v2"
}
```

| Aspect | Verified detail |
|--------|-----------------|
| Endpoint | `POST /v1/text-to-speech/{voice_id}` — `voice_id` is a **required path parameter** |
| Auth | `xi-api-key` HTTP header; Bearer tokens **not** a supported method |
| `text` | Required body field |
| `model_id` | Optional, **default `eleven_multilingual_v2`** |
| Voice discovery | Separate **Get voices** endpoint lists available `voice_id`s |
| Response | Binary audio (`application/octet-stream`) |
| Streaming | Dedicated `/v1/text-to-speech/{voice_id}/stream` endpoint exists (fetched as source; details not among surviving verified claims — re-verify before implementing) |

**Adapter shape for SelectTTS** (`ElevenLabsProvider`): config `{apiKeyRef, voiceID, modelID,
outputFormat}`; implement `availableVoices()` via Get-voices; map `SpeechRequest` → path+body.

## Azure Speech / Google Cloud TTS / Groq PlayAI

⏳ **Pending targeted follow-up research** — the first pass fetched primary docs for all three
(Microsoft Learn REST reference, Google `text/synthesize` reference, Groq TTS docs) but none of
their claims survived the verification cut, so nothing is citable yet. The follow-up pass is
assessing: whether Groq's TTS follows the OpenAI `/v1/audio/speech` schema (which would make it
free via the OpenAI adapter), and what custom adapters Azure (SSML body, subscription-key header)
and Google (JSON + base64 `audioContent`) would need.

**Planning stance until then:** v1 ships the OpenAI-compatible adapter + ElevenLabs + system
voice. Azure/Google are explicitly out of scope for v1 (each is a nontrivial adapter); Groq is
in scope only if the follow-up confirms OpenAI-compatibility (then it's just a preset profile:
`baseURL = https://api.groq.com/openai/v1`).
