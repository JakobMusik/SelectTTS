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

### Fetched but no surviving verified claims (do NOT cite from pass 1)

- lmstudio-ai/lmstudio-bug-tracker issues #1715, #1205 (forum) — LM Studio TTS status
- console.groq.com/docs/text-to-speech; learn.microsoft.com Azure TTS REST; Google
  `text/synthesize` reference — other-provider shapes
- dev.to/syedharisali/medium streaming-audio blogs, community.openai.com streaming thread,
  github.com/dimitris-c/AudioStreaming, Apple dev forums 124807 — macOS playback
- developer.apple.com AVSpeechSynthesizer / AVSpeechSynthesisVoice / voice-quality /
  pitchMultiplier docs, Apple forums 689461 — system TTS

These areas are covered by **pass 2** (below).

### Refuted / unresolved claims — do not state as fact

| Claim | Vote | Consequence |
|-------|------|-------------|
| Kokoro-FastAPI supports mp3/wav/opus/flac/m4a/pcm response formats | **0-3 refuted** | Kokoro's exact format list unknown; default to wav, let users override |
| openedai-speech is a usable drop-in local backend | **0-3 refuted** | It's archived (Jan 2026); legacy only |
| Speaches lacks opus/aac formats | **1-2 unresolved** | Only mp3+wav confirmed for Speaches |

### Community-sourced caveats (not primary-doc-verified)

- gpt-4o-mini-tts reportedly ignores `speed` in practice (OpenAI community forum reports).

### Time-sensitivity notes

- OpenAI model/voice lists churn; gpt-4o-mini-tts-2025-03-20 shuts down 2026-07-23.
- Kokoro-FastAPI latency figures are self-reported; project recommends pinning release tags.
- AllTalk's OpenAI endpoint exists only on V2/`alltalkbeta`.
- Speaches no-auth is default config, not guaranteed.

## Pass 2 — gap-fill deep-research wf_61a67d5b-8c7 (2026-06-12)

Covers: LM Studio TTS endpoint status; Groq PlayAI OpenAI-compatibility + Azure/Google adapter
assessments; AVAudioEngine/AVAudioPlayer streaming patterns (WAV header strip, MP3
frame-boundary handling); AVSpeechSynthesizer (voices, quality tiers, rate/pitch,
write-to-buffer, delegate callbacks). Results in `04-macos-playback-and-system-tts.md` and the
pending sections of 02/03. *(Section to be completed when the pass finishes.)*
