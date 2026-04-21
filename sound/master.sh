#!/bin/bash
# Auto-mastering pipeline for PixelColoringGame audio assets.
# BGM: loudnorm (EBU R128, I=-16 LUFS, TP=-1.5 dB) -> AAC 128kbps M4A, 44.1kHz stereo. No fades (preserve loop seam).
# SFX: peak-normalize to -3 dB, 50ms fade-out, WAV 16-bit, 44.1kHz stereo.

set -euo pipefail

SRC="/Users/100dodo/Documents/GitHub/new-2/sound"
BGM_OUT="/Users/100dodo/Documents/GitHub/new-2/PixelColoringGame/Resources/Audio/BGM"
SFX_OUT="/Users/100dodo/Documents/GitHub/new-2/PixelColoringGame/Resources/Audio/SFX"

master_bgm() {
  local in="$1" out="$2"
  echo "BGM: $(basename "$in") -> $(basename "$out")"
  ffmpeg -y -hide_banner -loglevel error \
    -i "$in" \
    -ar 44100 -ac 2 \
    -af "loudnorm=I=-16:TP=-1.5:LRA=11" \
    -c:a aac -b:a 128k \
    "$out"
}

master_sfx() {
  local in="$1" out="$2"
  echo "SFX: $(basename "$in") -> $(basename "$out")"
  # Pass 1: detect peak
  local peak
  peak=$(ffmpeg -hide_banner -i "$in" -af volumedetect -f null - 2>&1 \
    | grep 'max_volume' | awk -F': ' '{print $2}' | awk '{print $1}')
  # Compute gain to bring peak to -3 dB
  local gain
  gain=$(python3 -c "print(-3.0 - ($peak))")
  # Duration for fade-out position
  local dur
  dur=$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$in")
  local fade_start
  fade_start=$(python3 -c "print(max(0.0, $dur - 0.05))")
  ffmpeg -y -hide_banner -loglevel error \
    -i "$in" \
    -ar 44100 -ac 2 \
    -af "volume=${gain}dB,afade=t=out:st=${fade_start}:d=0.05" \
    -c:a pcm_s16le \
    "$out"
}

master_bgm "$SRC/B1. Home : Journey Map.wav"     "$BGM_OUT/b1_home.m4a"
master_bgm "$SRC/B2. Gameplay – Warm.wav"        "$BGM_OUT/b2_gameplay_warm.m4a"
master_bgm "$SRC/B3. Gameplay – Cool.wav"        "$BGM_OUT/b3_gameplay_cool.m4a"
master_bgm "$SRC/B4. Collection Book.wav"        "$BGM_OUT/b4_collection.m4a"
master_bgm "$SRC/B5. Event : Daily Special.wav"  "$BGM_OUT/b5_event.m4a"

master_sfx "$SRC/S1. Level Complete.wav"  "$SFX_OUT/s1_level_complete.wav"
master_sfx "$SRC/S2. Badge Earned.wav"    "$SFX_OUT/s2_badge_earned.wav"
master_sfx "$SRC/S3. Chapter Clear.wav"   "$SFX_OUT/s3_chapter_clear.wav"
master_sfx "$SRC/S4. Daily Streak.wav"    "$SFX_OUT/s4_daily_streak.wav"
master_sfx "$SRC/S5. Event Complete.wav"  "$SFX_OUT/s5_event_complete.wav"

echo "Done."
