#!/usr/bin/env python3
"""Add v0.7 Feel Good celebration localization keys. Idempotent."""
import json
from pathlib import Path

XCSTRINGS = Path(__file__).resolve().parents[1] / "PixelColoringGame" / "Resources" / "Localizable.xcstrings"

LANGUAGES = ["en", "ja", "zh-Hans", "zh-Hant", "es", "de", "fr", "ko"]

# Each entry: (key, comment, {lang: value})
NEW_ENTRIES = [
    # Chapter clear
    (
        "chapter.clear.eyebrow",
        "Small label above the chapter title on the Chapter Clear celebration.",
        {
            "en": "Chapter Cleared",
            "ja": "章クリア!",
            "zh-Hans": "章节通关",
            "zh-Hant": "章節通關",
            "es": "Capítulo completado",
            "de": "Kapitel abgeschlossen",
            "fr": "Chapitre terminé",
            "ko": "챕터 완료",
        },
    ),
    (
        "chapter.clear.next",
        "Label introducing the next chapter that has been unlocked.",
        {
            "en": "Up Next",
            "ja": "次の章",
            "zh-Hans": "下一章",
            "zh-Hant": "下一章",
            "es": "A continuación",
            "de": "Als Nächstes",
            "fr": "Prochain",
            "ko": "다음",
        },
    ),
    (
        "chapter.clear.continue",
        "Button label on the Chapter Clear celebration that dismisses the view.",
        {
            "en": "Continue",
            "ja": "つづける",
            "zh-Hans": "继续",
            "zh-Hant": "繼續",
            "es": "Continuar",
            "de": "Weiter",
            "fr": "Continuer",
            "ko": "계속",
        },
    ),
    (
        "chapter.clear.title",
        "Fallback chapter name shown if a chapter title is missing on the Chapter Clear view.",
        {
            "en": "Chapter Cleared",
            "ja": "章クリア",
            "zh-Hans": "章节完成",
            "zh-Hant": "章節完成",
            "es": "Capítulo completado",
            "de": "Kapitel geschafft",
            "fr": "Chapitre terminé",
            "ko": "챕터 완료",
        },
    ),
    # Journey complete
    (
        "journey.complete.eyebrow",
        "Small label above the title on the Journey Complete celebration.",
        {
            "en": "Journey Complete",
            "ja": "旅の完走",
            "zh-Hans": "旅程完成",
            "zh-Hant": "旅程完成",
            "es": "Viaje completado",
            "de": "Reise abgeschlossen",
            "fr": "Voyage terminé",
            "ko": "여정 완료",
        },
    ),
    (
        "journey.complete.title",
        "Hero title on the Journey Complete celebration.",
        {
            "en": "You Bloomed Every Pixel",
            "ja": "全てのピクセルが咲きました",
            "zh-Hans": "你点亮了每一个像素",
            "zh-Hant": "你點亮了每一個像素",
            "es": "Floreciste cada píxel",
            "de": "Du hast jeden Pixel zum Erblühen gebracht",
            "fr": "Vous avez fait fleurir chaque pixel",
            "ko": "모든 픽셀을 피워냈어요",
        },
    ),
    (
        "journey.complete.subtitle",
        "Subtitle text on the Journey Complete celebration.",
        {
            "en": "Thank you for coloring with us.",
            "ja": "あなたの旅をありがとう",
            "zh-Hans": "感谢与我们一起涂色",
            "zh-Hant": "感謝與我們一起塗色",
            "es": "Gracias por colorear con nosotros.",
            "de": "Danke, dass du mit uns gemalt hast.",
            "fr": "Merci d'avoir colorié avec nous.",
            "ko": "함께 칠해 주셔서 고마워요",
        },
    ),
    (
        "journey.complete.continue",
        "Button label on the Journey Complete celebration that returns the player home.",
        {
            "en": "Return Home",
            "ja": "ホームに戻る",
            "zh-Hans": "返回首页",
            "zh-Hant": "返回首頁",
            "es": "Volver al inicio",
            "de": "Zur Startseite",
            "fr": "Retour à l'accueil",
            "ko": "홈으로",
        },
    ),
    # Monthly complete
    (
        "monthly.complete.eyebrow",
        "Small label above the year-month on the Monthly Complete celebration.",
        {
            "en": "Monthly Complete",
            "ja": "今月コンプリート",
            "zh-Hans": "本月完成",
            "zh-Hant": "本月完成",
            "es": "Mes completado",
            "de": "Monat abgeschlossen",
            "fr": "Mois terminé",
            "ko": "이번 달 완료",
        },
    ),
    (
        "monthly.complete.subtitle",
        "Subtitle on the Monthly Complete celebration.",
        {
            "en": "Every day this month bloomed.",
            "ja": "今月、毎日花が咲きました",
            "zh-Hans": "本月每天都绽放",
            "zh-Hant": "本月每天都綻放",
            "es": "Cada día de este mes floreció.",
            "de": "Jeder Tag dieses Monats erblühte.",
            "fr": "Chaque jour de ce mois a fleuri.",
            "ko": "이번 달, 매일이 피었어요",
        },
    ),
    (
        "monthly.complete.nextMonth",
        "Button label on the Monthly Complete celebration when the next month's content is released.",
        {
            "en": "Next Month →",
            "ja": "次の月へ →",
            "zh-Hans": "下个月 →",
            "zh-Hant": "下個月 →",
            "es": "Próximo mes →",
            "de": "Nächster Monat →",
            "fr": "Mois prochain →",
            "ko": "다음 달 →",
        },
    ),
    (
        "monthly.complete.continue",
        "Button label on the Monthly Complete celebration when the next month's content is not yet released.",
        {
            "en": "Continue",
            "ja": "つづける",
            "zh-Hans": "继续",
            "zh-Hant": "繼續",
            "es": "Continuar",
            "de": "Weiter",
            "fr": "Continuer",
            "ko": "계속",
        },
    ),
    # Milestone toast: first perfect
    (
        "toast.firstPerfect.title",
        "Title on the toast that celebrates the player's first perfect-rank level.",
        {
            "en": "First Perfect!",
            "ja": "はじめての完璧!",
            "zh-Hans": "首次完美通关!",
            "zh-Hant": "首次完美通關!",
            "es": "¡Primer perfecto!",
            "de": "Erstes perfektes Bild!",
            "fr": "Premier sans-faute !",
            "ko": "첫 퍼펙트!",
        },
    ),
    (
        "toast.firstPerfect.subtitle",
        "Subtitle on the toast that celebrates the player's first perfect-rank level.",
        {
            "en": "No hints, no missteps. Beautiful.",
            "ja": "ノーヒント・ノーミス。お見事!",
            "zh-Hans": "无提示、零失误。漂亮!",
            "zh-Hant": "無提示、零失誤。漂亮!",
            "es": "Sin pistas, sin errores. Precioso.",
            "de": "Ohne Hinweise, ohne Fehler. Wunderschön.",
            "fr": "Sans indice, sans faute. Magnifique.",
            "ko": "힌트 없이, 실수 없이. 멋져요.",
        },
    ),
    # Milestone toast: streak 7
    (
        "toast.streak7.title",
        "Title on the toast for reaching a 7-day streak.",
        {
            "en": "7-Day Streak!",
            "ja": "7日連続!",
            "zh-Hans": "连续 7 天!",
            "zh-Hant": "連續 7 天!",
            "es": "¡Racha de 7 días!",
            "de": "7-Tage-Serie!",
            "fr": "Série de 7 jours !",
            "ko": "7일 연속!",
        },
    ),
    (
        "toast.streak7.subtitle",
        "Subtitle on the toast for reaching a 7-day streak.",
        {
            "en": "A whole week of cozy painting.",
            "ja": "1週間、毎日塗り絵。",
            "zh-Hans": "整整一周的悠然涂色。",
            "zh-Hant": "整整一週的悠然塗色。",
            "es": "Una semana entera pintando con calma.",
            "de": "Eine ganze Woche entspanntes Malen.",
            "fr": "Une semaine entière de coloriage douillet.",
            "ko": "일주일 내내 포근한 색칠.",
        },
    ),
    # Milestone toast: streak 14
    (
        "toast.streak14.title",
        "Title on the toast for reaching a 14-day streak.",
        {
            "en": "14-Day Streak!",
            "ja": "14日連続!",
            "zh-Hans": "连续 14 天!",
            "zh-Hant": "連續 14 天!",
            "es": "¡Racha de 14 días!",
            "de": "14-Tage-Serie!",
            "fr": "Série de 14 jours !",
            "ko": "14일 연속!",
        },
    ),
    (
        "toast.streak14.subtitle",
        "Subtitle on the toast for reaching a 14-day streak.",
        {
            "en": "Two weeks of daily blossoms.",
            "ja": "2週間、毎日のひと花。",
            "zh-Hans": "两周里每日一朵花。",
            "zh-Hant": "兩週裡每日一朵花。",
            "es": "Dos semanas de flores diarias.",
            "de": "Zwei Wochen tägliche Blüten.",
            "fr": "Deux semaines de floraisons quotidiennes.",
            "ko": "2주간의 매일의 꽃.",
        },
    ),
    # Milestone toast: streak 30
    (
        "toast.streak30.title",
        "Title on the toast for reaching a 30-day streak.",
        {
            "en": "30-Day Streak!",
            "ja": "30日連続!",
            "zh-Hans": "连续 30 天!",
            "zh-Hant": "連續 30 天!",
            "es": "¡Racha de 30 días!",
            "de": "30-Tage-Serie!",
            "fr": "Série de 30 jours !",
            "ko": "30일 연속!",
        },
    ),
    (
        "toast.streak30.subtitle",
        "Subtitle on the toast for reaching a 30-day streak.",
        {
            "en": "A month of color. Beautifully done.",
            "ja": "ひと月の色。本当にお見事。",
            "zh-Hans": "整月色彩,真漂亮。",
            "zh-Hant": "整月色彩,真漂亮。",
            "es": "Un mes de color. Bien hecho.",
            "de": "Ein Monat voller Farben. Wundervoll.",
            "fr": "Un mois de couleurs. Magnifiquement fait.",
            "ko": "한 달의 색. 정말 멋져요.",
        },
    ),
    # Milestone toast: levels 10
    (
        "toast.levels10.title",
        "Title on the toast for completing 10 levels in total.",
        {
            "en": "10 Levels Complete",
            "ja": "10レベル達成",
            "zh-Hans": "10 关达成",
            "zh-Hant": "10 關達成",
            "es": "10 niveles completados",
            "de": "10 Level geschafft",
            "fr": "10 niveaux terminés",
            "ko": "10레벨 달성",
        },
    ),
    (
        "toast.levels10.subtitle",
        "Subtitle on the toast for completing 10 levels.",
        {
            "en": "Your collection is taking shape.",
            "ja": "コレクションが育ってきた。",
            "zh-Hans": "你的收藏正在成形。",
            "zh-Hant": "你的收藏正在成形。",
            "es": "Tu colección está tomando forma.",
            "de": "Deine Sammlung nimmt Gestalt an.",
            "fr": "Votre collection prend forme.",
            "ko": "컬렉션이 자라고 있어요.",
        },
    ),
    # Milestone toast: levels 50
    (
        "toast.levels50.title",
        "Title on the toast for completing 50 levels in total.",
        {
            "en": "50 Levels Complete",
            "ja": "50レベル達成",
            "zh-Hans": "50 关达成",
            "zh-Hant": "50 關達成",
            "es": "50 niveles completados",
            "de": "50 Level geschafft",
            "fr": "50 niveaux terminés",
            "ko": "50레벨 달성",
        },
    ),
    (
        "toast.levels50.subtitle",
        "Subtitle on the toast for completing 50 levels.",
        {
            "en": "Halfway across the meadow.",
            "ja": "草原の半ばまで。",
            "zh-Hans": "穿过草原一半。",
            "zh-Hant": "穿過草原一半。",
            "es": "A medio camino del prado.",
            "de": "Auf halbem Weg über die Wiese.",
            "fr": "À mi-chemin de la prairie.",
            "ko": "들판의 절반을 건넜어요.",
        },
    ),
    # Milestone toast: levels 100
    (
        "toast.levels100.title",
        "Title on the toast for completing 100 levels in total.",
        {
            "en": "100 Levels!",
            "ja": "100レベル達成!",
            "zh-Hans": "100 关!",
            "zh-Hant": "100 關!",
            "es": "¡100 niveles!",
            "de": "100 Level!",
            "fr": "100 niveaux !",
            "ko": "100레벨 달성!",
        },
    ),
    (
        "toast.levels100.subtitle",
        "Subtitle on the toast for completing 100 levels.",
        {
            "en": "A century of color. Thank you.",
            "ja": "百色のあかし。ありがとう。",
            "zh-Hans": "百色为证,谢谢你。",
            "zh-Hant": "百色為證,謝謝你。",
            "es": "Un siglo de color. Gracias.",
            "de": "Hundert Farben. Danke.",
            "fr": "Un siècle de couleurs. Merci.",
            "ko": "백 가지 색의 증표. 고마워요.",
        },
    ),
    # Generic fallback
    (
        "toast.generic.title",
        "Generic fallback title for a celebration toast.",
        {
            "en": "Milestone",
            "ja": "マイルストーン",
            "zh-Hans": "里程碑",
            "zh-Hant": "里程碑",
            "es": "Logro",
            "de": "Meilenstein",
            "fr": "Étape",
            "ko": "이정표",
        },
    ),
    (
        "toast.generic.subtitle",
        "Generic fallback subtitle for a celebration toast.",
        {
            "en": "Keep going.",
            "ja": "このちょうし。",
            "zh-Hans": "继续加油。",
            "zh-Hant": "繼續加油。",
            "es": "Sigue así.",
            "de": "Weiter so.",
            "fr": "Continuez ainsi.",
            "ko": "계속 가요.",
        },
    ),
]


def entry_dict(comment: str, translations: dict) -> dict:
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

    sorted_strings = {k: strings[k] for k in sorted(strings.keys())}
    data["strings"] = sorted_strings

    XCSTRINGS.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(f"Added {len(added)} keys: {added}")
    print(f"Backfilled {len(updated)} keys: {updated}")


if __name__ == "__main__":
    main()
