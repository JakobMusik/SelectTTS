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

## Groq / Azure / Google / Deepgram — verified pass 2 (2026-06-13)

Resolved in the **pass-2 gap-fill** (wf_011ff0d2-367); all five cloudtts claims confirmed against
cited primary vendor docs. **Central result: only Groq is OpenAI-shaped; Azure/Google/Deepgram each
need a bespoke adapter; Google alone returns base64-in-JSON.**

### Groq — OpenAI-compatible (reuse the OpenAI adapter via baseURL swap)

Groq's TTS **follows the OpenAI `/v1/audio/speech` schema**, so it's a **preset profile, not a new
adapter**:

```http
POST https://api.groq.com/openai/v1/audio/speech
Authorization: Bearer $GROQ_API_KEY
Content-Type: application/json
```

```json
{ "model": "canopylabs/orpheus-v1-english", "voice": "troy", "input": "Hello.", "response_format": "wav" }
```

- JSON body `model` / `voice` / `input` / `response_format` (**defaults `wav`**), returns **raw audio
  bytes**.
- Models: `canopylabs/orpheus-v1-english` (+ `canopylabs/orpheus-arabic-saudi`); example voices
  troy / hannah / austin.
- **PlayAI is deprecated**: `playai-tts` / `playai-tts-arabic` deprecation **announced 2025-12-23**,
  **shutdown 2025-12-31**, replaced by Orpheus. Don't preset PlayAI models.
- Open: Groq HTTP streaming for Orpheus is not explicitly documented.

[source: console.groq.com/docs/text-to-speech]

### Azure AI Speech — bespoke adapter (SSML + output-format header)

```http
POST https://{region}.tts.speech.microsoft.com/cognitiveservices/v1
Ocp-Apim-Subscription-Key: $AZURE_KEY        # OR Authorization: Bearer <token>
Content-Type: application/ssml+xml            # 415 if wrong
X-Microsoft-OutputFormat: audio-24khz-48kbitrate-mono-mp3   # REQUIRED
```

- Regional host (e.g. `eastus.tts.speech.microsoft.com`); path `/cognitiveservices/v1`.
- **Body is SSML XML** (not JSON); response is **raw audio bytes** (streaming + non-streaming
  formats). The `X-Microsoft-OutputFormat` header is **required**. **NOT OpenAI-shaped.**

[source: learn.microsoft.com/en-us/azure/ai-services/speech-service/rest-text-to-speech (2026-05-21)]

### Google Cloud TTS — bespoke adapter; the only base64-in-JSON one

```http
POST https://texttospeech.googleapis.com/v1/text:synthesize
Authorization: Bearer <OAuth token>           # scope https://www.googleapis.com/auth/cloud-platform
Content-Type: application/json
```

- JSON body = `input` + `voice` + `audioConfig`. **Response is JSON with base64 audio in
  `audioContent`** — the **only** provider here that does base64-in-JSON rather than binary audio.
- The sync `text:synthesize` endpoint is non-streaming; `streamingSynthesize` / `synthesizeLongAudio`
  are separate methods. **NOT OpenAI-shaped.**
- ⚠️ Auth: only the **OAuth cloud-platform scope** is confirmed for this endpoint; the API-key form
  (`?key=` / `X-goog-api-key`) is **unverified** here (Google APIs generally accept it, but it wasn't
  pinned on this reference page).

[source: docs.cloud.google.com/text-to-speech/docs/reference/rest/v1/text/synthesize]

### Deepgram Aura — bespoke adapter (text-field JSON + query-param model, binary mpeg)

```http
POST https://api.deepgram.com/v1/speak?model=aura-asteria-en
Authorization: Token $DEEPGRAM_KEY
Content-Type: application/json
```

```json
{ "text": "The text to speak." }
```

- Model selected via the **`?model=` query param** (default `aura-asteria-en`); JSON body is just
  `{"text": …}`; streams **raw `audio/mpeg`**. A separate **WebSocket** interface handles input
  streaming. **NOT OpenAI-shaped.**
- ⚠️ Auth: only `Authorization: Token` is confirmed; a Bearer/short-lived-JWT form is plausible but
  **unverified** on the TTS reference page.

[source: developers.deepgram.com/docs/text-to-speech]

## Adapter-fit summary

| Provider | Adapter | Endpoint | Auth | Request body | Voice/model selection | Response |
|----------|---------|----------|------|--------------|-----------------------|----------|
| **Groq** | ♻️ **reuse OpenAI** (baseURL swap) | `…groq.com/openai/v1/audio/speech` | `Authorization: Bearer` | OpenAI JSON | `model`/`voice` fields | binary (default wav) |
| **OpenAI** | OpenAI | `…openai.com/v1/audio/speech` | `Authorization: Bearer` | OpenAI JSON | `model`/`voice` fields | binary |
| **ElevenLabs** | bespoke | `/v1/text-to-speech/{voice_id}` | `xi-api-key` header | JSON `text`+`model_id` | **voice id in URL path** | binary (octet-stream) |
| **Azure** | bespoke | `/cognitiveservices/v1` (regional) | `Ocp-Apim-Subscription-Key` / Bearer | **SSML XML** | voice in SSML | binary (`X-Microsoft-OutputFormat`) |
| **Google** | bespoke | `/v1/text:synthesize` | OAuth (API-key unverified) | JSON `input`+`voice`+`audioConfig` | `voice` object | **base64 in JSON `audioContent`** |
| **Deepgram** | bespoke | `/v1/speak` | `Authorization: Token` | JSON `{text}` | **`?model=` query param** | binary `audio/mpeg` |

**Only Google returns base64-in-JSON; everyone else returns binary audio.** No OpenAI-compatible
`/openai/v1` surface was found for Deepgram or ElevenLabs.

**Planning stance:** v1 ships the OpenAI-compatible adapter + **Groq as a preset profile**
(`baseURL = https://api.groq.com/openai/v1`, Orpheus models) + ElevenLabs adapter + system voice.
Azure / Google / Deepgram each need a nontrivial bespoke adapter and stay out of scope for v1, but
the shapes above are now documented for when they're wanted.
