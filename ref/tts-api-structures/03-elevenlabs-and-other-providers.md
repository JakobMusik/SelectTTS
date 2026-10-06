# ElevenLabs & Other BYOK Providers

## ElevenLabs — verified 3-0 (2026-06-12, primary docs) — needs its own adapter

ElevenLabs is **not** OpenAI-shaped in three load-bearing ways: the voice lives in the URL path,
auth is a custom header, and voices come from a separate listing endpoint.

```http
POST https://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream?output_format=pcm_24000
xi-api-key: $ELEVENLABS_API_KEY
Content-Type: application/json
```

```json
{
  "text": "The text that will get converted into speech.",
  "model_id": "eleven_multilingual_v2",
  "voice_settings": { "speed": 1.1 }
}
```

| Aspect | Verified detail |
|--------|-----------------|
| Endpoint | `POST /v1/text-to-speech/{voice_id}` (buffered file, has `content-length`) and `POST /v1/text-to-speech/{voice_id}/stream` (chunked as generated). Same body/query. `voice_id` is a **required path parameter** |
| Auth | `xi-api-key` HTTP header; Bearer tokens **not** a supported method. Keys can be scope-restricted (e.g. a key without `user_read` gets 401 `missing_permissions` on `/v1/user/*`) |
| Hosts | `https://api.elevenlabs.io` (default), `https://api.us.elevenlabs.io`, data residency `https://api.{eu,in,sg}.residency.elevenlabs.io` |
| `text` | Required body field |
| `model_id` | Optional, **default `eleven_multilingual_v2`**. Live `GET /v1/models` (2026-10-07): `eleven_v4`, `eleven_v4_turbo`, `eleven_v3`, `eleven_multilingual_v2` (10k chars), `eleven_flash_v2_5` / `eleven_turbo_v2_5` (40k), `eleven_flash_v2` / `eleven_turbo_v2` (30k). Per-model cap = `maximum_text_length_per_request` |
| Speed | `voice_settings.speed`, **0.7–1.2** (outside → 400 `invalid_voice_settings`) |
| `voice_settings` | Overrides the voice's saved settings for one request, but **any field missing or `null` gets the API default, not the saved value** (verified 2026-10-07 via `/v1/history` settings: speed-only and speed+nulls both reset stability/similarity/style/speaker-boost). To change only speed, send the saved settings (`GET /v1/voices/{id}/settings`) with `speed` replaced |
| `output_format` | Query param, default `mp3_44100_128`. `pcm_{8000…48000}`, `mp3_*`, `opus_48000_*`, `ulaw_8000`, `alaw_8000`; the non-stream endpoint also offers `wav_*`. `pcm_44100` needs Pro tier (403 otherwise); `pcm_24000` works on any tier and is headerless 16-bit LE mono |
| Voice discovery | `GET /v2/voices?page_size=100[&next_page_token=…]` → `{voices, has_more, next_page_token, total_count}`; `GET /v1/voices` is now under "Legacy". Voices carry `labels` (`gender`, `accent`, `language`, …) and `verified_languages[].locale` (BCP-47, e.g. `en-GB`) |
| Plan limits | Free tier: library ("copied" professional) voices → 402 `paid_plan_required`; `pcm_44100` → 403 `output_format_not_allowed` |
| Errors | JSON `detail`: an object `{status, message, …}` (401 `invalid_api_key`, 404 `voice_not_found`, 400 `model_not_found` / `invalid_voice_settings`), a 422 list `[{loc, msg, type}]`, or a string (`"Not Found"` for an empty voice id) |
| Response headers | `request-id`, `character-cost`, `x-trace-id` |
| Continuity | `previous_text`/`next_text` or `previous_request_ids`/`next_request_ids` (≤ 3) stitch multi-request audio; not used yet |

Measured 2026-10-07 (pcm_24000, ~470 chars, `eleven_flash_v2_5`): time-to-first-byte **0.87 s on
`/stream` vs 1.45 s** on the buffered endpoint, and the gap grows with text length.

**Adapter in SelectTTS** (`ElevenLabsProvider`): base URL = API root (a trailing `/v1` is tolerated);
`synthesize` → `/stream` with `output_format=pcm_24000` and `voice_settings.speed` (clamped, omitted at
1.0; a non-1.0 speed is merged into the voice's fetched saved settings, falling back to speed-only); refuses compressed formats (the streaming player can only consume PCM); surfaces `detail`
messages in `SpeechProviderError.httpStatus`; `availableVoices()` pages `/v2/voices`.

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
