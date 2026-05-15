#!/usr/bin/env python3
"""Analyze Localizable.xcstrings to surface user-facing keys missing translations."""
import json
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
XCSTRINGS = PROJECT_ROOT / "PixelColoringGame" / "Resources" / "Localizable.xcstrings"
EXPECTED = {"de", "en", "es", "fr", "ja", "ko", "zh-Hans", "zh-Hant"}
DEBUG_KEY_HINTS = (
    "Debug ", "debug.", "Clear all", "Fire celebration",
    "celebrationsSeen", "Test ", "TEST_", "Reset Journey", "reset journey",
)

def main() -> int:
    d = json.loads(XCSTRINGS.read_text())
    ss = d.get("strings", {})
    prod_missing = []
    debug_missing = []
    for k, v in ss.items():
        locs = set(v.get("localizations", {}).keys())
        miss = EXPECTED - locs
        if not miss:
            continue
        if any(h in k for h in DEBUG_KEY_HINTS):
            debug_missing.append((k, sorted(miss)))
        else:
            prod_missing.append((k, sorted(miss)))

    print(f"=== Production (user-facing) keys missing translations: {len(prod_missing)} ===")
    for k, miss in prod_missing:
        loc = ss[k].get("localizations", {}).get("en", {}).get("stringUnit", {}).get("value")
        if loc is None:
            loc = "[fallback to key]"
        print(f"  KEY: {k}")
        print(f"  EN : {loc}")
        print(f"  MISS: {miss}")
        print()

    print(f"=== Debug-like keys missing translations: {len(debug_missing)} ===")
    for k, miss in debug_missing:
        print(f"  {k}  miss={miss}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
