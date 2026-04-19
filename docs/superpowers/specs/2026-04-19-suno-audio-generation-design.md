# Suno Audio Generation Design — PixelColoringGame

Date: 2026-04-19
Target app: PixelColoringGame (iOS)
Scope: External audio generation via Suno + integration plan

## 1. Goals and Constraints

Generate a cohesive set of BGM and musical SFX for PixelColoringGame using Suno. The set must:

- Fit the cozy pixel-art coloring aesthetic (6 journey chapters with warm / cool palettes, Daily, Event).
- Avoid fatiguing the player during long coloring sessions.
- Stay within a reasonable Suno credit budget (10 total clips).
- Ship as a small audio payload (~15 MB total) bundled inside the app.

Non-goals:

- Per-chapter individual BGM (6+ tracks) — rejected for cost and redundancy.
- Functional SFX like tap / palette click / error feedback — handled by a different pipeline (ElevenLabs Sound Effects / Freesound / hand-crafted in Audacity), not Suno.
- In-app audio playback implementation — covered later in a separate implementation plan.

## 2. Stylistic Direction

**Hybrid: chiptune melody × lo-fi / acoustic texture.**

- 8-bit / 16-bit square-wave and bell leads for pixel-game identity.
- Lo-fi hip hop drums + vinyl crackle + soft pads for long-session comfort.
- Acoustic accents (ukulele, fingerpicked guitar, accordion, glockenspiel) for cozy warmth.
- All tracks instrumental. Lyrics distract from coloring focus.

## 3. Clip Inventory (10 total)

### 3.1 BGM — 5 tracks (scene-based, not chapter-based)

| # | Name | Scene | Mood | Target BPM |
|---|------|-------|------|------------|
| B1 | Home / Journey Map | Chapter-select / home screen | Welcoming, slightly bright, adventure-starting | 85 |
| B2 | Gameplay – Warm | Berry Meadow / Bakery Path / Petal Pond coloring | Sunlit, gentle, sustained focus | 75 |
| B3 | Gameplay – Cool | Tide Garden / Moonlit Shore / Starlit Garden coloring | Moonlit, airy, meditative | 70 |
| B4 | Collection Book | Completed-artwork review screen | Music box, nostalgic, no drums | 65 |
| B5 | Event / Daily Special | Limited-time and daily puzzles | Festive but cozy, playful | 100 |

Warm / Cool split is by **chapter motif**, not strictly by accent color hue. Petal Pond's accent is purple but its floral theme sits naturally in Warm. Tide Garden's accent is green but its ocean theme belongs in Cool. Moonlit Shore's accent is pink but the night-shore theme is Cool.

### 3.2 Musical SFX — 5 stingers

| # | Name | Trigger | Target length (after trim) |
|---|------|---------|---------------------------|
| S1 | Level Complete | Every level finish | 3–5 s |
| S2 | Badge Earned | Badge unlock (layered with S1) | 2–3 s |
| S3 | Chapter Clear | Chapter completion (6 times total across whole game) | 8–10 s |
| S4 | Daily Streak | Daily puzzle completion / streak tick | 2–3 s |
| S5 | Event Complete | Event completion | 5–8 s |

## 4. Suno Prompts

Use **Custom Mode** in Suno (separate Style and Lyrics fields). Generate 2–3 variants per prompt and pick the best take.

### B1 — Home / Journey Map
**Style:**
```
cozy lofi chiptune, soft 8-bit square wave lead, mellow lofi hip hop drums, warm vinyl crackle, gentle acoustic guitar, nostalgic welcoming mood, 85 BPM, calm adventure, instrumental, loopable
```
**Lyrics:** `[Instrumental] [Intro] [Main] [Outro]`

### B2 — Gameplay – Warm
**Style:**
```
warm cozy lofi, soft 8-bit bell melody, mellow boom bap lofi beat, vinyl crackle, ukulele fingerpicking, sunlit afternoon mood, 75 BPM, minimal and non-distracting background focus music, instrumental, loopable
```
**Lyrics:** `[Instrumental]`

### B3 — Gameplay – Cool
**Style:**
```
dreamy chiptune lofi, crystalline 8-bit bell lead, slow lofi beat, glassy synth pad, soft vinyl warmth, moonlit starry night mood, 70 BPM, airy meditative focus music, instrumental, loopable
```
**Lyrics:** `[Instrumental]`

### B4 — Collection Book
**Style:**
```
delicate music box lullaby, soft chiptune chimes, airy acoustic guitar fingerpicking, subtle vinyl warmth, no drums, nostalgic reverie, 65 BPM, gentle peaceful memory, instrumental
```
**Lyrics:** `[Instrumental]`

### B5 — Event / Daily Special
**Style:**
```
upbeat cozy chiptune lofi, cheerful 8-bit lead melody, playful lofi hip hop groove, accordion accent, soft tambourine, festive but cozy mood, 100 BPM, special occasion, instrumental, loopable
```
**Lyrics:** `[Instrumental]`

### S1 — Level Complete
**Style:**
```
short chiptune fanfare stinger, bright 8-bit brass lead, quick ascending victory melody, sparkly bell chime ending, warm lofi pad underneath, cheerful triumph, instrumental
```
**Lyrics:** `[Fanfare]`

### S2 — Badge Earned
**Style:**
```
tiny sparkle stinger, twinkling 8-bit arpeggio, soft glockenspiel shimmer, magical achievement chime, instrumental
```
**Lyrics:** `[Chime]`

### S3 — Chapter Clear
**Style:**
```
triumphant chiptune orchestral fanfare, layered 8-bit brass and strings, warm acoustic guitar strum, soft lofi texture, uplifting ascending melody resolving to warm major chord, epic but cozy chapter completion, instrumental
```
**Lyrics:** `[Grand Fanfare] [Resolution]`

### S4 — Daily Streak
**Style:**
```
gentle small chime stinger, soft 8-bit bell double tap, subtle ukulele pluck, warm and brief, quiet daily achievement, non-intrusive, instrumental
```
**Lyrics:** `[Chime]`

### S5 — Event Complete
**Style:**
```
festive cheerful stinger, 8-bit melodic flourish, playful accordion accent, tambourine hit, warm lofi bed, rising and settling, special event completion, instrumental
```
**Lyrics:** `[Flourish]`

## 5. File Formats

| Asset | Received from Suno | During editing | Final in app |
|-------|-------------------|----------------|--------------|
| BGM (B1–B5) | WAV (paid plan) or MP3 320 kbps (free plan) | WAV 16-bit / 44.1 kHz | **M4A (AAC 128 kbps)** |
| SFX (S1–S5) | Same as above | WAV 16-bit / 44.1 kHz | **WAV 16-bit / 44.1 kHz** (optionally CAF) |

Rationale:

- **M4A (AAC) for BGM:** Apple-preferred, lighter `AVAudioPlayer` decode than MP3, better quality per bit. ~1.8 MB per 2-minute loop → ~10 MB for 5 tracks.
- **WAV for SFX:** Compressed formats introduce tens of ms of decode latency that feels sluggish on stingers. WAV plays instantly. 5 × ~800 KB ≈ 4 MB.
- **Never re-encode MP3 → MP3.** If Suno free plan output is MP3, edit directly and export to final format once.
- Total on-disk payload target: **~15 MB.**

## 6. File Layout

```
PixelColoringGame/Resources/Audio/
├── BGM/
│   ├── b1_home.m4a
│   ├── b2_gameplay_warm.m4a
│   ├── b3_gameplay_cool.m4a
│   ├── b4_collection.m4a
│   └── b5_event.m4a
└── SFX/
    ├── s1_level_complete.wav
    ├── s2_badge_earned.wav
    ├── s3_chapter_clear.wav
    ├── s4_daily_streak.wav
    └── s5_event_complete.wav
```

## 7. Post-Generation Workflow (per clip)

1. Generate 2–3 Suno variants from the prompt above. Pick the best take.
2. Export from Suno at highest quality (WAV if available).
3. Open in Audacity / Logic. Trim:
   - **BGM**: find a clean loop region (4–8 bars), crossfade start/end for seamless loop.
   - **SFX**: trim to target length, apply short fade-out if abrupt.
4. Normalize to –1 dBFS true peak. Keep perceived loudness consistent across BGM tracks; SFX can sit slightly below BGM so it doesn't startle.
5. Export to final format per section 5. Name per section 6.
6. Drop into Xcode project, tick all relevant targets, confirm "Copy items if needed".

## 8. Out of Scope (follow-up work)

- Functional SFX (tap, fill, wrong-color feedback, UI button, palette select). Handle via ElevenLabs Sound Effects or Freesound in a later pass.
- Chapter-specific BGM layers. Can be layered later if Warm/Cool split feels too broad.
- In-app audio playback code (`AVAudioPlayer` / `AVAudioEngine` setup, volume settings, mute toggle, interruption handling). Covered by a separate implementation plan after assets land.

## 9. Open Questions

None at spec time. Reopen if Suno output consistently misses a mood and prompt iteration doesn't close the gap.
