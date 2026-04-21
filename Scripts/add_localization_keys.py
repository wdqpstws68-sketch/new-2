#!/usr/bin/env python3
"""Add localization keys for title screen and tab bar. Idempotent."""
import json
from pathlib import Path

XCSTRINGS = Path(__file__).resolve().parents[1] / "PixelColoringGame" / "Resources" / "Localizable.xcstrings"

LANGUAGES = ["en", "ja", "zh-Hans", "zh-Hant", "es", "de", "fr", "ko"]

# Each entry: (key, comment, {lang: value})
NEW_ENTRIES = [
    (
        "title.app.name",
        "App title shown prominently on the launch/title screen.",
        {
            "en": "Pixel Cozy",
            "ja": "ピクセルコージー",
            "zh-Hans": "像素小屋",
            "zh-Hant": "像素小屋",
            "es": "Pixel Cozy",
            "de": "Pixel Cozy",
            "fr": "Pixel Cozy",
            "ko": "픽셀 코지",
        },
    ),
    (
        "title.tapToStart",
        "Prompt on the title screen inviting the player to tap anywhere to start.",
        {
            "en": "Tap to Start",
            "ja": "タップしてスタート",
            "zh-Hans": "点击开始",
            "zh-Hant": "點擊開始",
            "es": "Toca para empezar",
            "de": "Zum Starten tippen",
            "fr": "Touchez pour commencer",
            "ko": "탭하여 시작",
        },
    ),
    (
        "title.mascot.accessibility",
        "VoiceOver label for the mascot image on the title screen.",
        {
            "en": "Mascot",
            "ja": "マスコット",
            "zh-Hans": "吉祥物",
            "zh-Hant": "吉祥物",
            "es": "Mascota",
            "de": "Maskottchen",
            "fr": "Mascotte",
            "ko": "마스코트",
        },
    ),
    (
        "tab.journey",
        "Tab bar label for the main journey (coloring progression) tab.",
        {
            "en": "Journey",
            "ja": "ジャーニー",
            "zh-Hans": "旅程",
            "zh-Hant": "旅程",
            "es": "Viaje",
            "de": "Reise",
            "fr": "Voyage",
            "ko": "여정",
        },
    ),
    (
        "tab.daily",
        "Tab bar label for the daily challenge tab.",
        {
            "en": "Daily",
            "ja": "デイリー",
            "zh-Hans": "每日",
            "zh-Hant": "每日",
            "es": "Diario",
            "de": "Täglich",
            "fr": "Quotidien",
            "ko": "데일리",
        },
    ),
    (
        "tab.library",
        "Tab bar label for the collection book / library tab.",
        {
            "en": "Library",
            "ja": "ライブラリ",
            "zh-Hans": "图册",
            "zh-Hant": "圖冊",
            "es": "Biblioteca",
            "de": "Sammlung",
            "fr": "Bibliothèque",
            "ko": "도감",
        },
    ),
    (
        "daily.hub.eyebrow",
        "Small eyebrow text shown above the Daily tab's title.",
        {
            "en": "TODAY'S PICK",
            "ja": "きょうのおすすめ",
            "zh-Hans": "今日精选",
            "zh-Hant": "今日精選",
            "es": "ELECCIÓN DE HOY",
            "de": "HEUTIGE AUSWAHL",
            "fr": "SÉLECTION DU JOUR",
            "ko": "오늘의 선택",
        },
    ),
    (
        "daily.hub.title",
        "Header title for the Daily tab.",
        {
            "en": "Daily Challenge",
            "ja": "デイリーチャレンジ",
            "zh-Hans": "每日挑战",
            "zh-Hant": "每日挑戰",
            "es": "Desafío diario",
            "de": "Tägliche Herausforderung",
            "fr": "Défi quotidien",
            "ko": "데일리 챌린지",
        },
    ),
    (
        "daily.hub.empty.title",
        "Title shown on Daily tab when no challenge is currently available.",
        {
            "en": "Come back tomorrow",
            "ja": "あしたまたきてね",
            "zh-Hans": "明天再来吧",
            "zh-Hant": "明天再來吧",
            "es": "Vuelve mañana",
            "de": "Komm morgen wieder",
            "fr": "Reviens demain",
            "ko": "내일 다시 오세요",
        },
    ),
    (
        "daily.hub.empty.subtitle",
        "Subtitle shown on Daily tab when no challenge is currently available.",
        {
            "en": "A new artwork will be waiting for you.",
            "ja": "あたらしいさくひんがまっているよ。",
            "zh-Hans": "新的作品在等着你。",
            "zh-Hant": "新的作品在等著你。",
            "es": "Te espera una nueva obra.",
            "de": "Ein neues Kunstwerk wartet auf dich.",
            "fr": "Une nouvelle œuvre t'attend.",
            "ko": "새로운 작품이 기다리고 있어요.",
        },
    ),
    (
        "daily.hub.event.eyebrow",
        "Eyebrow label for the monthly event digest row on the Daily tab.",
        {
            "en": "THIS MONTH",
            "ja": "こんげつ",
            "zh-Hans": "本月",
            "zh-Hant": "本月",
            "es": "ESTE MES",
            "de": "DIESER MONAT",
            "fr": "CE MOIS-CI",
            "ko": "이달의 이벤트",
        },
    ),
]


def entry_dict(comment: str, translations: dict[str, str]) -> dict:
    return {
        "comment": comment,
        "extractionState": "manual",
        "localizations": {
            lang: {
                "stringUnit": {
                    "state": "translated",
                    "value": translations[lang],
                }
            }
            for lang in LANGUAGES
        },
    }


def main() -> None:
    data = json.loads(XCSTRINGS.read_text())
    strings = data["strings"]

    added = []
    updated = []
    for key, comment, translations in NEW_ENTRIES:
        if key in strings:
            # Only fill any missing language — do not overwrite existing translations.
            existing = strings[key].setdefault("localizations", {})
            touched = False
            for lang in LANGUAGES:
                if lang not in existing:
                    existing[lang] = {
                        "stringUnit": {
                            "state": "translated",
                            "value": translations[lang],
                        }
                    }
                    touched = True
            if touched:
                updated.append(key)
        else:
            strings[key] = entry_dict(comment, translations)
            added.append(key)

    # Keep keys sorted as Xcode expects (alphabetical).
    sorted_strings = {k: strings[k] for k in sorted(strings.keys())}
    data["strings"] = sorted_strings

    XCSTRINGS.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"Added {len(added)} keys: {added}")
    print(f"Backfilled {len(updated)} keys: {updated}")


if __name__ == "__main__":
    main()
