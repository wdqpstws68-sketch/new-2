"""
Append EN + JA localizations for the 24 new Journey chapters (Ch 7–30) and
96 new levels + new `objects` category into Localizable.xcstrings.

Run:
    python3 Scripts/add_journey30_localizations.py
"""
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
XCSTRINGS = REPO / "PixelColoringGame" / "Resources" / "Localizable.xcstrings"

# --- Chapter translations: id -> (en_title, ja_title, en_sub, ja_sub, en_badge, ja_badge) ---
CHAPTERS = {
    "dawn-petal":        ("Dawn Petal",        "あけぼのの花びら",
                          "Early spring blossoms whisper a gentle hello to the morning.",
                          "春のはじまりを告げる、やさしい朝の挨拶。",
                          "Morning Blossom", "あさの花ひらき"),
    "dewy-meadow":       ("Dewy Meadow",       "朝露の草原",
                          "A meadow glittering with morning dew.",
                          "朝つゆできらきらひかる草原。",
                          "Dewdrop Tag", "朝露のしるし"),
    "rainbow-puddle":    ("Rainbow Puddle",    "虹のみずたまり",
                          "After the rain, tiny rainbows dance in puddles.",
                          "雨あがり、小さな虹が水たまりで踊る。",
                          "Puddle Gem", "水たまりの宝石"),
    "spring-basket":     ("Spring Basket",     "春のかご",
                          "Fresh harvests tucked into a warm picnic basket.",
                          "春のしゅうかくをかごに詰めこんで。",
                          "Basket Charm", "春かごのおまもり"),
    "sunflower-field":   ("Sunflower Field",   "ひまわりばたけ",
                          "Tall sunflowers nodding in a lazy summer breeze.",
                          "夏のそよ風にゆれる、せのたかいひまわりたち。",
                          "Sunbeam Ribbon", "陽だまりリボン"),
    "citrus-grove":      ("Citrus Grove",      "柑橘の森",
                          "Zesty citrus fruits ripen in the warm sun.",
                          "太陽をあびて、みずみずしく色づく柑橘たち。",
                          "Citrus Zest", "柑橘のきらめき"),
    "melon-patch":       ("Melon Patch",       "メロン畑",
                          "Sweet melons and summer fruits all in a row.",
                          "あまいメロンと夏の果実がずらり。",
                          "Sweet Slice", "あまい一切れ"),
    "sandy-cove":        ("Sandy Cove",        "すなはまの入江",
                          "Tiny treasures hidden along a sunny shore.",
                          "日だまりの海べに隠れた小さな宝もの。",
                          "Seaside Pennant", "うみべのペナント"),
    "autumn-orchard":    ("Autumn Orchard",    "秋のくだもの園",
                          "Crisp leaves and warm harvest colors everywhere.",
                          "色づいた葉と、あたたかい実りの色にかこまれて。",
                          "Harvest Leaf", "実りの葉"),
    "harvest-table":     ("Harvest Table",     "しゅうかくの食卓",
                          "A cozy table set with autumn bounty.",
                          "秋の恵みがならぶ、あたたかな食卓。",
                          "Bread & Honey Pin", "パンとはちみつのピン"),
    "forest-sprigs":     ("Forest Sprigs",     "森のこえだ",
                          "Wild sprigs and hidden forest treasures.",
                          "森にひそむ小さな枝と秘密の宝もの。",
                          "Woodland Sprig", "森のこえだ飾り"),
    "tea-garden":        ("Tea Garden",        "ティーガーデン",
                          "A quiet afternoon for tea and little pastries.",
                          "紅茶とお菓子のしずかなひととき。",
                          "Tea Rose Token", "ティーローズのしるし"),
    "snowy-grove":       ("Snowy Grove",       "雪の小道",
                          "Fresh snowfall softens a quiet grove.",
                          "新雪がしずかに小道をつつみこむ。",
                          "Snowcap Charm", "雪のぼうしのおまもり"),
    "cozy-hearth":       ("Cozy Hearth",       "ぬくもりの暖炉",
                          "Warm mittens, hot cocoa, and a crackling fire.",
                          "あたたかい手袋と、はじけるほのおと、ホットココア。",
                          "Hearth Ember", "暖炉のおきび"),
    "gingerbread-lane":  ("Gingerbread Lane",  "ジンジャーブレッドの路地",
                          "Sweet treats and spiced cookies line the lane.",
                          "甘いおかしとスパイスのクッキーが並ぶ小路。",
                          "Sugar Bauble", "シュガーオーナメント"),
    "icy-pond":          ("Icy Pond",          "こおりの池",
                          "Skating circles on a glassy frozen pond.",
                          "つるりと光る氷の上をぐるりとスケート。",
                          "Frost Skate Pin", "こおりスケートのピン"),
    "yarn-nook":         ("Yarn Nook",         "けいとの小部屋",
                          "A cozy corner full of knits and balls of yarn.",
                          "ニットと毛糸玉であふれる、ぬくもりの小部屋。",
                          "Yarn Spool Charm", "毛糸のおまもり"),
    "bookshelf-corner":  ("Bookshelf Corner",  "本だなのすみっこ",
                          "A reading nook with soft lamps and purring cats.",
                          "やさしい灯りと猫のごろごろが聞こえる読書の場所。",
                          "Bookmark Ribbon", "しおりのリボン"),
    "art-studio":        ("Art Studio",        "アトリエ",
                          "Paints, brushes, and small canvases everywhere.",
                          "絵の具と筆と、小さなキャンバスにかこまれて。",
                          "Palette Charm", "パレットのおまもり"),
    "music-nook":        ("Music Nook",        "おんがくコーナー",
                          "Tiny tunes from cozy little instruments.",
                          "小さな楽器たちがあたたかな旋律をかなでる。",
                          "Treble Charm", "音符のおまもり"),
    "firefly-glen":      ("Firefly Glen",      "ほたるの谷",
                          "Dusk glows with soft firefly light.",
                          "夕暮れにやわらかくほたるが灯る。",
                          "Firefly Glimmer", "ほたるのきらめき"),
    "constellation-sky": ("Constellation Sky", "星座の空",
                          "Gentle stars and planets tracing the night.",
                          "夜をゆったり描く星々と惑星たち。",
                          "Starry Compass", "星々のコンパス"),
    "dream-pillow":      ("Dream Pillow",      "ゆめのまくら",
                          "Soft pillows and plush friends at bedtime.",
                          "ふわふわのまくらと、ぬいぐるみの仲間たちとおやすみ。",
                          "Lullaby Star", "ララバイスター"),
    "fairy-hollow":      ("Fairy Hollow",      "ようせいの洞",
                          "Tiny fairy homes deep in a mossy glen.",
                          "苔むす谷の奥にそっと佇む妖精の家々。",
                          "Fairy Wing Seal", "ようせいの羽のしるし"),
}

# --- Level translations: id -> (en, ja) ---
LEVELS = {
    # Ch 7 dawn-petal
    "sakura":         ("Sakura Bloom",     "さくらのはな"),
    "hummingbird":    ("Tiny Hummingbird", "小さなハチドリ"),
    "bunny":          ("Spring Bunny",     "春のうさぎ"),
    "robin":          ("Red Robin",        "あかむねこまどり"),
    # Ch 8 dewy-meadow
    "clover":         ("Lucky Clover",     "しあわせクローバー"),
    "ladybug":        ("Polka Ladybug",    "てんとうむし"),
    "dandelion":      ("Dandelion Puff",   "たんぽぽのわた"),
    "dragonfly":      ("Glass Dragonfly",  "ガラスのとんぼ"),
    # Ch 9 rainbow-puddle
    "raindrop":       ("Raindrop",         "あまつぶ"),
    "umbrella":       ("Yellow Umbrella",  "きいろいかさ"),
    "rainbow":        ("Arc Rainbow",      "虹のアーチ"),
    "frog":           ("Pond Frog",        "池のかえる"),
    # Ch 10 spring-basket
    "carrot":         ("Garden Carrot",    "にんじん"),
    "radish":         ("Pink Radish",      "ピンクのラディッシュ"),
    "peapod":         ("Peapod",           "さやえんどう"),
    "speckledegg":    ("Speckled Egg",     "まだらのたまご"),
    # Ch 11 sunflower-field
    "sunflower":      ("Sunflower",        "ひまわり"),
    "honeyjar":       ("Honey Jar",        "はちみつの瓶"),
    "bumblebee":      ("Bumblebee",        "まるまるみつばち"),
    "picnicbasket":   ("Picnic Basket",    "ピクニックかご"),
    # Ch 12 citrus-grove
    "lemon":          ("Fresh Lemon",      "フレッシュレモン"),
    "orange":         ("Ripe Orange",      "オレンジ"),
    "lime":           ("Lime Wedge",       "ライム"),
    "tangerine":      ("Mini Tangerine",   "みかん"),
    # Ch 13 melon-patch
    "watermelon":     ("Watermelon Slice", "すいかひとかけ"),
    "cantaloupe":     ("Cantaloupe Half",  "メロン半分"),
    "grapevine":      ("Grape Bunch",      "ぶどうのふさ"),
    "peach":          ("Summer Peach",     "夏のもも"),
    # Ch 14 sandy-cove
    "crab":           ("Little Crab",      "ちいさなカニ"),
    "sandcastle":     ("Sandcastle",       "すなのお城"),
    "beachball":      ("Beach Ball",       "ビーチボール"),
    "sunhat":         ("Straw Sun Hat",    "むぎわら帽子"),
    # Ch 15 autumn-orchard
    "pumpkin":        ("Round Pumpkin",    "まるいかぼちゃ"),
    "mapleleaf":      ("Maple Leaf",       "もみじの葉"),
    "chestnut":       ("Fresh Chestnut",   "くり"),
    "persimmon":      ("Persimmon",        "かき"),
    # Ch 16 harvest-table
    "breadloaf":      ("Rustic Bread",     "まるパン"),
    "cheesewheel":    ("Cheese Wheel",     "チーズの円盤"),
    "grapes":         ("Grape Cluster",    "ぶどうのふさり"),
    "honeypot":       ("Honey Pot",        "はちみつのつぼ"),
    # Ch 17 forest-sprigs
    "fernscroll":     ("Fiddlehead Fern",  "こごみの芽"),
    "pinecone":       ("Pine Cone",        "まつぼっくり"),
    "hazelnut":       ("Hazelnut",         "ヘーゼルナッツ"),
    "wildberry":      ("Wild Berry",       "野いちご"),
    # Ch 18 tea-garden
    "teapot":         ("Teapot",           "ティーポット"),
    "scone":          ("Cream Scone",      "クリームスコーン"),
    "matchacup":      ("Matcha Cup",       "抹茶の茶碗"),
    "cookietin":      ("Cookie Tin",       "クッキー缶"),
    # Ch 19 snowy-grove
    "snowflake":      ("Big Snowflake",    "雪のけっしょう"),
    "wintercone":     ("Frost Cone",       "冬のまつぼっくり"),
    "cardinal":       ("Winter Cardinal",  "ふゆの赤い鳥"),
    "evergreen":      ("Evergreen Tree",   "もみの木"),
    # Ch 20 cozy-hearth
    "mitten":         ("Knit Mitten",      "ニット手袋"),
    "candle":         ("Lit Candle",       "ともしびキャンドル"),
    "cocoacup":       ("Cocoa Mug",        "ココアのマグ"),
    "cinnamonroll":   ("Cinnamon Roll",    "シナモンロール"),
    # Ch 21 gingerbread-lane
    "gingerman":      ("Gingerbread Person","ジンジャーブレッドマン"),
    "candycane":      ("Candy Cane",       "キャンディケーン"),
    "peppermint":     ("Peppermint Swirl", "ペパーミントキャンディ"),
    "frostedbun":     ("Frosted Bun",      "アイシングパン"),
    # Ch 22 icy-pond
    "iceskate":       ("Ice Skate",        "アイススケート"),
    "snowball":       ("Snowball",         "ゆきだま"),
    "winterberry":    ("Winterberry Sprig","ふゆのあかい実"),
    "snowowl":        ("Snowy Owl",        "シロフクロウ"),
    # Ch 23 yarn-nook
    "yarnball":       ("Ball of Yarn",     "けいとだま"),
    "knittedhat":     ("Knitted Hat",      "ニット帽"),
    "sweater":        ("Cozy Sweater",     "セーター"),
    "teacozy":        ("Tea Cozy",         "ティーコージー"),
    # Ch 24 bookshelf-corner
    "bookstack":      ("Stack of Books",   "本のつみかさね"),
    "readinglamp":    ("Reading Lamp",     "デスクランプ"),
    "bookmark":       ("Tassel Bookmark",  "タッセルしおり"),
    "sleepycat":      ("Sleepy Cat",       "ねむりねこ"),
    # Ch 25 art-studio
    "painttube":      ("Paint Tube",       "絵の具のチューブ"),
    "paintbrush":     ("Paintbrush",       "筆"),
    "palette":        ("Paint Palette",    "パレット"),
    "easel":          ("Mini Easel",       "ミニイーゼル"),
    # Ch 26 music-nook
    "musicnote":      ("Music Note",       "おんぷ"),
    "ukulele":        ("Ukulele",          "ウクレレ"),
    "tambourine":     ("Tambourine",       "タンバリン"),
    "gramophone":     ("Old Gramophone",   "蓄音機"),
    # Ch 27 firefly-glen
    "firefly":        ("Glowing Firefly",  "ひかるホタル"),
    "mushroomlamp":   ("Mushroom Lamp",    "きのこランプ"),
    "glowpetal":      ("Glow Petal",       "ひかる花びら"),
    "mothglow":       ("Luna Moth",        "ルナモス"),
    # Ch 28 constellation-sky
    "starcluster":    ("Star Cluster",     "ほしの群れ"),
    "comet":          ("Shooting Comet",   "流れるすいせい"),
    "ringedplanet":   ("Ringed Planet",    "環のわくせい"),
    "crescentmoon":   ("Crescent Moon",    "三日月"),
    # Ch 29 dream-pillow
    "pillow":         ("Soft Pillow",      "ふわふわまくら"),
    "plushbunny":     ("Plush Bunny",      "うさぎのぬいぐるみ"),
    "starmobile":     ("Star Mobile",      "星のモビール"),
    "nightlight":     ("Cozy Nightlight",  "ナイトライト"),
    # Ch 30 fairy-hollow
    "mushroomhouse":  ("Mushroom House",   "きのこの家"),
    "fairywing":      ("Fairy Wing",       "ようせいの羽"),
    "dewberry":       ("Dew Berry",        "つゆの実"),
    "toadstool":      ("Toadstool",        "赤いきのこ"),
}


def localization_entry(en: str, ja: str) -> dict:
    """Build a localizations dict with EN+JA only (Xcode will pass others through to en).
    Using extractionState=stale to match the existing journey.chapter.* entries."""
    return {
        "extractionState": "stale",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": en}},
            "ja": {"stringUnit": {"state": "translated", "value": ja}},
        },
    }


def main():
    data = json.loads(XCSTRINGS.read_text())
    strings = data["strings"]

    added = 0
    skipped = 0

    # Category: objects
    if "level.category.objects" not in strings:
        strings["level.category.objects"] = localization_entry("Objects", "こもの")
        added += 1
    else:
        skipped += 1

    # Chapter keys
    for cid, (en_t, ja_t, en_s, ja_s, en_b, ja_b) in CHAPTERS.items():
        for suffix, (en, ja) in [("title", (en_t, ja_t)), ("subtitle", (en_s, ja_s)), ("badge", (en_b, ja_b))]:
            key = f"journey.chapter.{cid}.{suffix}"
            if key in strings:
                skipped += 1
            else:
                strings[key] = localization_entry(en, ja)
                added += 1

    # Level title keys
    for lid, (en, ja) in LEVELS.items():
        key = f"level.{lid}.title"
        if key in strings:
            skipped += 1
        else:
            strings[key] = localization_entry(en, ja)
            added += 1

    # Append new entries to the end (the file is not alphabetically sorted).
    data["strings"] = strings

    # Write back.  The file uses 2-space indent in source.
    XCSTRINGS.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")

    print(f"added:   {added}")
    print(f"skipped: {skipped}")
    print(f"total strings now: {len(data['strings'])}")


if __name__ == "__main__":
    main()
