#!/usr/bin/env python3
"""
Small content pipeline for the PixelColoringGame MVP.

Supported flows:
- generate the curated bundled sample packs without external dependencies
- optionally call the PixelLab Python SDK when it is installed in the environment

The runtime app only needs the emitted JSON manifests and preview PNGs.
Bundled levels may mix board sizes, for example 24x24 curated packs and 32x32 PixelLab chapters.
"""

from __future__ import annotations

import argparse
import csv
import colorsys
import hashlib
import json
import math
import os
import shutil
import struct
import sys
import textwrap
import time
import zlib
from collections import Counter, deque
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


BOARD_SIZE = 24
THUMBNAIL_CELL = 10
SOLVED_CELL = 18
APP_ICON_MASTER_SIZE = 1024
APP_ICON_FOREGROUND_SIZE = 400
APP_ICON_PROMPT = (
    "cute twin cherry sticker, chunky pixel art, centered, large readable silhouette, "
    "two glossy cherries with a single green leaf, rounded stems, soft cozy mobile game icon subject, "
    "warm coral reds, cream highlights, no text, no border, no background, no extra objects"
)
APP_ICON_NEGATIVE_DESCRIPTION = "muddy colors, noisy dithering, text, watermark, tiny details, cropped subject"
APP_ICON_BACKGROUND_TOP = "#F6F0FF"
APP_ICON_BACKGROUND_BOTTOM = "#FFF9F0"
APP_ICON_GLOW = "#FFD8B5"
PIXELLAB_SUBJECT_READABILITY_PROMPT = (
    "single clear subject, instantly recognizable, easy to identify at thumbnail size, bold silhouette, "
    "large simple shapes, minimal small details, no extra props, no secondary subject, no cropped edges"
)
PIXELLAB_WHITE_AVOIDANCE_PROMPT = (
    "avoid pure white; if a white material is needed, use slightly tinted off-white such as cream, ivory, pearl, "
    "or another subtly colored light tone so it remains visible on a white background"
)
NEAR_WHITE_CHANNEL_THRESHOLD = 245
NEAR_WHITE_MAX_DELTA = 12
NEAR_WHITE_TARGET_RGB = (244, 238, 228)
APP_ICON_SPECS = [
    ("iphone-notification-20@2x.png", "iphone", "20x20", "2x", 40),
    ("iphone-notification-20@3x.png", "iphone", "20x20", "3x", 60),
    ("iphone-settings-29@2x.png", "iphone", "29x29", "2x", 58),
    ("iphone-settings-29@3x.png", "iphone", "29x29", "3x", 87),
    ("iphone-spotlight-40@2x.png", "iphone", "40x40", "2x", 80),
    ("iphone-spotlight-40@3x.png", "iphone", "40x40", "3x", 120),
    ("iphone-app-60@2x.png", "iphone", "60x60", "2x", 120),
    ("iphone-app-60@3x.png", "iphone", "60x60", "3x", 180),
    ("ios-marketing-1024.png", "ios-marketing", "1024x1024", "1x", 1024),
]


STYLE_PRESETS = {
    "soft-toy": {
        "negative_description": (
            "muddy colors, noisy dithering, text, watermark, tiny details, cluttered composition, "
            "multiple objects, confusing silhouette, cropped subject, unreadable shape"
        ),
        "outline": "single color outline",
        "shading": "basic shading",
        "detail": "medium detail",
        "no_background": True,
    },
    "bright-sticker": {
        "negative_description": (
            "photorealism, muddy, noisy, blurry, text, cluttered composition, multiple objects, "
            "confusing silhouette, cropped subject, unreadable shape"
        ),
        "outline": "single color outline",
        "shading": "medium shading",
        "detail": "medium detail",
        "no_background": True,
    },
    "simple-sticker": {
        "negative_description": (
            "photorealism, muddy colors, noisy dithering, tiny details, texture, gradients, text, watermark, "
            "cluttered composition, multiple objects, confusing silhouette, cropped subject, unreadable shape"
        ),
        "outline": "single color outline",
        "shading": "flat shading",
        "detail": "low detail",
        "no_background": True,
    },
}

APP_ICON_STYLE_PRESET = {
    "negative_description": APP_ICON_NEGATIVE_DESCRIPTION,
    "outline": "single color outline",
    "shading": "medium shading",
    "detail": "high detail",
    "no_background": True,
}


@dataclass(frozen=True)
class SampleDefinition:
    level_id: str
    title: str
    category: str
    difficulty: str
    estimated_minutes: int
    prompt: str
    palette: list[str]
    build: Callable[[int], list[list[int]]]
    title_key: str | None = None
    category_key: str | None = None
    difficulty_key: str | None = None


@dataclass(frozen=True)
class PixelLabLevelDefinition:
    level_id: str
    title: str
    category: str
    difficulty: str
    estimated_minutes: int
    prompt: str
    board_size: int = 32
    render_size: int = 128
    max_colors: int = 5
    style_preset: str = "simple-sticker"


@dataclass(frozen=True)
class MonthlyDailyCatalogRow:
    month: int
    day_or_index: int
    month_id: str
    theme: str
    motif: str
    category: str
    difficulty: str
    selection_phase: str
    availability: str
    display_title: str
    display_title_key: str
    internal_id: str
    asset_file_name: str
    palette_count: int
    grid_size: int
    estimated_minutes: int
    sort_order: int
    prompt: str
    notes: str


MONTHLY_DAILY_CSV_COLUMNS = [
    "month",
    "day_or_index",
    "month_id",
    "theme",
    "motif",
    "category",
    "difficulty",
    "selection_phase",
    "availability",
    "display_title",
    "display_title_key",
    "internal_id",
    "asset_file_name",
    "palette_count",
    "grid_size",
    "estimated_minutes",
    "sort_order",
    "prompt",
    "notes",
]

MONTH_ROW_COUNT = {
    1: 31,
    2: 29,
    3: 31,
    4: 30,
    5: 31,
    6: 30,
    7: 31,
    8: 31,
    9: 30,
    10: 31,
    11: 30,
    12: 31,
}

MONTH_ALWAYS_AVAILABLE_COUNT = {
    1: 31,
    2: 28,
    3: 31,
    4: 30,
    5: 31,
    6: 30,
    7: 31,
    8: 31,
    9: 30,
    10: 31,
    11: 30,
    12: 31,
}

MONTH_DIFFICULTY_DISTRIBUTION = {
    31: {"easy": 11, "medium": 14, "hard": 6},
    30: {"easy": 10, "medium": 14, "hard": 6},
    28: {"easy": 10, "medium": 13, "hard": 5},
}

MONTHLY_EVENT_METADATA = {
    1: {
        "title": "January Daily",
        "banner": "Snowy keepsakes, lucky charms, and warm winter starts.",
        "accent_hex": "E66F68",
        "archive_title": "January Archive",
        "archive_subtitle": "Revisit January's cozy New Year collection.",
        "reward_title": "January Dreamer",
        "reward_subtitle": "Complete every January artwork to unlock this title.",
    },
    2: {
        "title": "February Daily",
        "banner": "Sweet hearts, cocoa breaks, and soft winter affection.",
        "accent_hex": "E56C8E",
        "archive_title": "February Archive",
        "archive_subtitle": "Revisit February's sweet and snowy collection.",
        "reward_title": "Heart Keeper",
        "reward_subtitle": "Complete every February artwork to unlock this title.",
    },
    3: {
        "title": "March Daily",
        "banner": "Buds, blossoms, and gentle spring beginnings.",
        "accent_hex": "F08F9D",
        "archive_title": "March Archive",
        "archive_subtitle": "Revisit March's blossom and farewell collection.",
        "reward_title": "Spring Song",
        "reward_subtitle": "Complete every March artwork to unlock this title.",
    },
    4: {
        "title": "April Daily",
        "banner": "Fresh notebooks, flower trails, and bright new starts.",
        "accent_hex": "F2B84B",
        "archive_title": "April Archive",
        "archive_subtitle": "Revisit April's bright and breezy collection.",
        "reward_title": "Bloom Scout",
        "reward_subtitle": "Complete every April artwork to unlock this title.",
    },
    5: {
        "title": "May Daily",
        "banner": "Picnic skies, young leaves, and cheerful holiday signs.",
        "accent_hex": "76B857",
        "archive_title": "May Archive",
        "archive_subtitle": "Revisit May's picnic and fresh-leaf collection.",
        "reward_title": "Leaf Chaser",
        "reward_subtitle": "Complete every May artwork to unlock this title.",
    },
    6: {
        "title": "June Daily",
        "banner": "Raindrops, hydrangeas, and slow cozy rainy days.",
        "accent_hex": "5A9BD5",
        "archive_title": "June Archive",
        "archive_subtitle": "Revisit June's rainy-season collection.",
        "reward_title": "Rain Walker",
        "reward_subtitle": "Complete every June artwork to unlock this title.",
    },
    7: {
        "title": "July Daily",
        "banner": "Stars, festival lights, and sparkling summer nights.",
        "accent_hex": "5F72E8",
        "archive_title": "July Archive",
        "archive_subtitle": "Revisit July's starry summer collection.",
        "reward_title": "Wish Lantern",
        "reward_subtitle": "Complete every July artwork to unlock this title.",
    },
    8: {
        "title": "August Daily",
        "banner": "Sea breeze, sunflowers, and playful vacation memories.",
        "accent_hex": "36A6B8",
        "archive_title": "August Archive",
        "archive_subtitle": "Revisit August's beach and festival collection.",
        "reward_title": "Sun Tide",
        "reward_subtitle": "Complete every August artwork to unlock this title.",
    },
    9: {
        "title": "September Daily",
        "banner": "Moonlit sweets, reading corners, and early autumn calm.",
        "accent_hex": "8B73C7",
        "archive_title": "September Archive",
        "archive_subtitle": "Revisit September's moon-viewing collection.",
        "reward_title": "Moon Reader",
        "reward_subtitle": "Complete every September artwork to unlock this title.",
    },
    10: {
        "title": "October Daily",
        "banner": "Pumpkins, candy trails, and playful midnight surprises.",
        "accent_hex": "F07E2F",
        "archive_title": "October Archive",
        "archive_subtitle": "Revisit October's Halloween collection.",
        "reward_title": "Candy Phantom",
        "reward_subtitle": "Complete every October artwork to unlock this title.",
    },
    11: {
        "title": "November Daily",
        "banner": "Maple warmth, mushrooms, and soft amber evenings.",
        "accent_hex": "B6794A",
        "archive_title": "November Archive",
        "archive_subtitle": "Revisit November's harvest collection.",
        "reward_title": "Amber Trail",
        "reward_subtitle": "Complete every November artwork to unlock this title.",
    },
    12: {
        "title": "December Daily",
        "banner": "Snow bells, gift ribbons, and bright holiday glow.",
        "accent_hex": "4BAA84",
        "archive_title": "December Archive",
        "archive_subtitle": "Revisit December's holiday collection.",
        "reward_title": "Winter Bell",
        "reward_subtitle": "Complete every December artwork to unlock this title.",
    },
}


def append_pixellab_generation_guardrails(prompt: str) -> str:
    guarded_prompt = prompt
    lowered = guarded_prompt.lower()
    if "single clear subject" not in lowered:
        guarded_prompt = f"{guarded_prompt}, {PIXELLAB_SUBJECT_READABILITY_PROMPT}"
        lowered = guarded_prompt.lower()
    if "avoid pure white" not in lowered:
        guarded_prompt = f"{guarded_prompt}, {PIXELLAB_WHITE_AVOIDANCE_PROMPT}"
    return guarded_prompt


def blank_grid(size: int) -> list[list[int]]:
    return [[-1 for _ in range(size)] for _ in range(size)]


def paint(grid: list[list[int]], x: int, y: int, color: int) -> None:
    if 0 <= y < len(grid) and 0 <= x < len(grid[0]):
        grid[y][x] = color


def fill_rect(grid: list[list[int]], x0: int, y0: int, x1: int, y1: int, color: int) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            paint(grid, x, y, color)


def fill_ellipse(grid: list[list[int]], cx: float, cy: float, rx: float, ry: float, color: int) -> None:
    for y in range(len(grid)):
        for x in range(len(grid[0])):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            if nx * nx + ny * ny <= 1:
                paint(grid, x, y, color)


def carve_ellipse(grid: list[list[int]], cx: float, cy: float, rx: float, ry: float) -> None:
    fill_ellipse(grid, cx, cy, rx, ry, -1)


def carve_rect(grid: list[list[int]], x0: int, y0: int, x1: int, y1: int, color: int = -1) -> None:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            paint(grid, x, y, color)


def mirrored_paint(grid: list[list[int]], points: list[tuple[int, int]], center_x: int, color: int) -> None:
    for x, y in points:
        paint(grid, x, y, color)
        mirrored_x = center_x + (center_x - x)
        paint(grid, mirrored_x, y, color)


def build_strawberry(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 12.5, 6.5, 7.5, 0)
    fill_rect(g, 9, 4, 14, 6, 1)
    fill_rect(g, 11, 2, 12, 4, 2)
    fill_rect(g, 8, 8, 9, 10, 3)
    fill_rect(g, 14, 9, 15, 11, 3)
    fill_rect(g, 10, 14, 12, 16, 4)
    fill_rect(g, 8, 17, 15, 19, 5)
    return g


def build_mushroom(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 8.0, 8.5, 5.5, 0)
    fill_rect(g, 6, 8, 17, 12, 0)
    fill_rect(g, 9, 11, 14, 18, 1)
    fill_rect(g, 10, 19, 13, 20, 2)
    fill_rect(g, 8, 5, 10, 7, 3)
    fill_rect(g, 13, 6, 15, 8, 3)
    fill_rect(g, 10, 13, 12, 16, 4)
    fill_rect(g, 6, 15, 8, 18, 5)
    fill_rect(g, 15, 15, 17, 18, 5)
    return g


def build_whale(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_rect(g, 3, 9, 17, 16, 0)
    fill_ellipse(g, 11.0, 12.0, 8.5, 5.0, 0)
    fill_rect(g, 17, 10, 20, 14, 1)
    carve_rect(g, 18, 12, 18, 12)
    fill_rect(g, 5, 15, 12, 17, 2)
    fill_rect(g, 5, 18, 20, 21, 3)
    fill_rect(g, 8, 6, 11, 8, 4)
    fill_rect(g, 13, 7, 14, 9, 4)
    fill_rect(g, 15, 11, 15, 11, 5)
    fill_rect(g, 15, 11, 16, 12, 5)
    return g


def build_cactus(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_rect(g, 7, 14, 16, 20, 0)
    fill_rect(g, 8, 8, 11, 20, 0)
    fill_rect(g, 12, 6, 15, 20, 1)
    fill_rect(g, 4, 10, 6, 16, 2)
    fill_rect(g, 17, 9, 19, 15, 2)
    fill_rect(g, 6, 15, 9, 17, 0)
    fill_rect(g, 15, 14, 18, 16, 1)
    fill_rect(g, 6, 12, 6, 13, 3)
    fill_rect(g, 15, 7, 15, 8, 3)
    fill_rect(g, 6, 19, 17, 22, 4)
    fill_rect(g, 8, 20, 15, 22, 5)
    return g


def build_fish(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.0, 12.0, 7.5, 5.5, 0)
    fill_rect(g, 16, 9, 20, 15, 1)
    carve_rect(g, 18, 11, 18, 13)
    fill_rect(g, 7, 9, 10, 11, 2)
    fill_rect(g, 8, 14, 10, 16, 2)
    fill_rect(g, 5, 11, 12, 13, 3)
    fill_rect(g, 7, 16, 10, 17, 4)
    fill_rect(g, 9, 8, 12, 9, 4)
    fill_rect(g, 6, 11, 6, 11, 5)
    fill_rect(g, 6, 11, 7, 12, 5)
    return g


def build_flower(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 8.0, 3.0, 3.0, 0)
    fill_ellipse(g, 7.0, 8.0, 3.0, 3.0, 0)
    fill_ellipse(g, 16.0, 8.0, 3.0, 3.0, 0)
    fill_ellipse(g, 9.0, 4.0, 3.0, 3.0, 1)
    fill_ellipse(g, 14.0, 4.0, 3.0, 3.0, 1)
    fill_ellipse(g, 11.5, 8.0, 2.0, 2.0, 2)
    fill_rect(g, 11, 10, 12, 20, 3)
    fill_rect(g, 7, 15, 10, 18, 4)
    fill_rect(g, 13, 14, 17, 17, 4)
    fill_rect(g, 10, 6, 13, 7, 5)
    return g


def build_cupcake(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 8.5, 7.5, 5.5, 0)
    fill_rect(g, 7, 11, 16, 17, 1)
    fill_rect(g, 8, 12, 9, 17, 2)
    fill_rect(g, 11, 12, 12, 17, 2)
    fill_rect(g, 14, 12, 15, 17, 2)
    fill_rect(g, 9, 19, 14, 20, 3)
    fill_rect(g, 15, 5, 17, 8, 4)
    fill_rect(g, 10, 6, 12, 8, 5)
    return g


def build_pear(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 13.0, 6.5, 8.0, 0)
    fill_ellipse(g, 11.5, 8.5, 4.5, 5.5, 1)
    fill_rect(g, 11, 3, 12, 6, 2)
    fill_rect(g, 13, 3, 16, 6, 3)
    fill_rect(g, 8, 10, 9, 13, 4)
    fill_rect(g, 13, 16, 15, 18, 5)
    return g


def build_turtle(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 12.0, 7.5, 6.0, 0)
    fill_rect(g, 7, 8, 15, 15, 1)
    fill_rect(g, 16, 11, 19, 13, 2)
    fill_rect(g, 5, 8, 7, 10, 3)
    fill_rect(g, 5, 14, 7, 16, 3)
    fill_rect(g, 13, 16, 15, 18, 3)
    fill_rect(g, 8, 17, 10, 19, 3)
    fill_rect(g, 10, 10, 12, 12, 4)
    fill_rect(g, 10, 13, 12, 15, 4)
    fill_rect(g, 16, 11, 17, 12, 5)
    return g


def build_bird(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.0, 11.5, 7.0, 6.0, 0)
    fill_ellipse(g, 9.0, 12.0, 4.0, 4.5, 1)
    fill_rect(g, 15, 10, 19, 12, 2)
    fill_rect(g, 7, 16, 9, 20, 3)
    fill_rect(g, 12, 16, 14, 20, 3)
    fill_rect(g, 8, 7, 12, 8, 4)
    fill_rect(g, 15, 8, 15, 8, 5)
    fill_rect(g, 15, 8, 16, 9, 5)
    return g


def build_snail(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 9.5, 11.0, 5.0, 5.0, 0)
    fill_ellipse(g, 9.5, 11.0, 2.5, 2.5, 1)
    fill_rect(g, 10, 13, 18, 16, 2)
    fill_rect(g, 17, 10, 20, 15, 2)
    fill_rect(g, 18, 7, 18, 10, 3)
    fill_rect(g, 20, 7, 20, 10, 3)
    fill_rect(g, 12, 14, 14, 15, 4)
    fill_rect(g, 17, 11, 17, 11, 5)
    fill_rect(g, 17, 11, 18, 12, 5)
    return g


def build_cherry(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 8.0, 13.5, 4.5, 4.5, 0)
    fill_ellipse(g, 15.0, 13.5, 4.5, 4.5, 0)
    fill_rect(g, 5, 15, 10, 18, 1)
    fill_rect(g, 13, 15, 18, 18, 1)
    fill_rect(g, 10, 6, 11, 11, 2)
    fill_rect(g, 12, 5, 13, 11, 2)
    fill_rect(g, 11, 4, 12, 6, 2)
    fill_ellipse(g, 16.0, 5.5, 3.5, 2.5, 3)
    fill_rect(g, 6, 10, 7, 11, 4)
    fill_rect(g, 13, 10, 14, 11, 4)
    fill_rect(g, 10, 17, 13, 18, 5)
    return g


def build_acorn(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 13.5, 6.0, 7.0, 0)
    fill_ellipse(g, 11.5, 8.0, 7.0, 4.0, 1)
    fill_rect(g, 11, 3, 12, 5, 2)
    fill_rect(g, 8, 16, 15, 19, 3)
    fill_rect(g, 9, 11, 10, 13, 4)
    fill_rect(g, 13, 11, 14, 13, 4)
    fill_rect(g, 8, 7, 15, 9, 5)
    return g


def build_seahorse(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_rect(g, 10, 6, 13, 15, 0)
    fill_ellipse(g, 11.5, 14.0, 4.5, 6.0, 0)
    fill_rect(g, 13, 7, 17, 10, 1)
    fill_rect(g, 8, 7, 9, 15, 2)
    fill_rect(g, 12, 13, 13, 18, 3)
    fill_ellipse(g, 9.0, 19.0, 4.5, 3.5, 0)
    carve_ellipse(g, 9.0, 19.0, 1.8, 1.5)
    fill_rect(g, 9, 17, 11, 19, 0)
    fill_rect(g, 13, 12, 15, 14, 4)
    fill_rect(g, 14, 8, 14, 8, 5)
    fill_rect(g, 14, 8, 15, 9, 5)
    return g


def build_succulent(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 9.0, 3.0, 5.0, 0)
    fill_ellipse(g, 8.0, 11.0, 3.0, 5.0, 1)
    fill_ellipse(g, 15.0, 11.0, 3.0, 5.0, 1)
    fill_ellipse(g, 6.5, 13.0, 3.0, 4.0, 2)
    fill_ellipse(g, 16.5, 13.0, 3.0, 4.0, 2)
    fill_ellipse(g, 11.5, 13.5, 3.0, 4.5, 0)
    fill_rect(g, 7, 16, 16, 20, 3)
    fill_rect(g, 8, 19, 15, 21, 4)
    fill_rect(g, 10, 8, 11, 11, 5)
    fill_rect(g, 13, 10, 14, 12, 5)
    return g


def build_butterfly(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 7.0, 9.0, 4.5, 5.0, 0)
    fill_ellipse(g, 16.0, 9.0, 4.5, 5.0, 0)
    fill_ellipse(g, 7.5, 15.0, 4.0, 4.0, 1)
    fill_ellipse(g, 15.5, 15.0, 4.0, 4.0, 1)
    fill_rect(g, 11, 6, 12, 18, 2)
    fill_rect(g, 5, 8, 6, 9, 3)
    fill_rect(g, 17, 8, 18, 9, 3)
    fill_rect(g, 6, 14, 7, 15, 4)
    fill_rect(g, 16, 14, 17, 15, 4)
    fill_rect(g, 10, 4, 10, 5, 5)
    fill_rect(g, 13, 4, 13, 5, 5)
    return g


def build_lotus(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 8.0, 3.0, 5.0, 0)
    fill_ellipse(g, 8.0, 10.0, 3.0, 4.5, 0)
    fill_ellipse(g, 15.0, 10.0, 3.0, 4.5, 0)
    fill_ellipse(g, 7.5, 14.0, 4.0, 4.0, 1)
    fill_ellipse(g, 15.5, 14.0, 4.0, 4.0, 1)
    fill_ellipse(g, 11.5, 12.0, 2.5, 3.5, 2)
    fill_rect(g, 10, 15, 13, 20, 3)
    fill_ellipse(g, 11.5, 18.5, 7.0, 3.5, 4)
    fill_rect(g, 11, 8, 12, 9, 5)
    return g


def build_croissant(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 12.0, 8.5, 6.5, 0)
    carve_ellipse(g, 14.5, 11.5, 5.5, 3.5)
    fill_rect(g, 4, 12, 7, 15, 0)
    fill_rect(g, 17, 10, 20, 13, 0)
    fill_rect(g, 6, 13, 10, 16, 1)
    fill_rect(g, 11, 11, 14, 15, 1)
    fill_rect(g, 15, 9, 18, 12, 1)
    fill_rect(g, 8, 10, 9, 12, 2)
    fill_rect(g, 14, 8, 15, 10, 2)
    fill_rect(g, 10, 17, 15, 18, 3)
    fill_rect(g, 5, 15, 8, 16, 4)
    fill_rect(g, 16, 13, 18, 14, 5)
    return g


def build_apple(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 9.0, 10.0, 4.5, 5.0, 0)
    fill_ellipse(g, 14.0, 10.0, 4.5, 5.0, 0)
    fill_ellipse(g, 11.5, 14.0, 6.5, 7.0, 0)
    fill_rect(g, 11, 4, 12, 6, 1)
    fill_ellipse(g, 15.5, 5.5, 3.0, 2.0, 2)
    fill_rect(g, 8, 10, 9, 13, 3)
    fill_rect(g, 13, 17, 15, 19, 4)
    fill_rect(g, 9, 19, 14, 20, 5)
    return g


def build_starfish(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_rect(g, 10, 4, 13, 9, 0)
    fill_rect(g, 8, 9, 15, 15, 0)
    fill_rect(g, 4, 10, 9, 13, 0)
    fill_rect(g, 14, 10, 19, 13, 0)
    fill_rect(g, 7, 15, 10, 20, 0)
    fill_rect(g, 13, 15, 16, 20, 0)
    fill_rect(g, 10, 6, 12, 8, 1)
    fill_rect(g, 6, 11, 8, 12, 1)
    fill_rect(g, 15, 11, 17, 12, 1)
    fill_rect(g, 9, 16, 10, 18, 2)
    fill_rect(g, 13, 16, 14, 18, 2)
    fill_rect(g, 10, 11, 13, 13, 3)
    fill_rect(g, 8, 19, 10, 20, 4)
    fill_rect(g, 13, 19, 15, 20, 5)
    return g


def build_seashell(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 13.0, 7.0, 6.0, 0)
    fill_rect(g, 5, 13, 18, 20, 0)
    fill_rect(g, 6, 14, 7, 20, 1)
    fill_rect(g, 9, 13, 10, 20, 1)
    fill_rect(g, 13, 13, 14, 20, 1)
    fill_rect(g, 16, 14, 17, 20, 1)
    fill_rect(g, 8, 18, 15, 20, 2)
    fill_rect(g, 7, 11, 8, 12, 3)
    fill_rect(g, 11, 10, 12, 12, 4)
    fill_rect(g, 15, 11, 16, 12, 5)
    return g


def build_teacup(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 10.5, 12.0, 5.5, 4.0, 0)
    carve_ellipse(g, 10.5, 12.0, 3.5, 2.4)
    fill_rect(g, 5, 12, 16, 16, 0)
    fill_rect(g, 15, 11, 18, 15, 1)
    carve_rect(g, 16, 12, 17, 14)
    fill_rect(g, 4, 17, 18, 18, 2)
    fill_rect(g, 7, 9, 13, 10, 3)
    fill_rect(g, 8, 6, 9, 8, 4)
    fill_rect(g, 12, 5, 13, 8, 4)
    fill_rect(g, 8, 17, 14, 20, 5)
    return g


def build_moon(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 11.0, 6.5, 7.0, 0)
    carve_ellipse(g, 14.0, 10.5, 5.0, 6.0)
    fill_rect(g, 6, 6, 7, 7, 1)
    fill_rect(g, 16, 5, 17, 6, 1)
    fill_rect(g, 15, 14, 16, 15, 1)
    fill_rect(g, 7, 15, 8, 16, 2)
    fill_rect(g, 14, 8, 15, 9, 2)
    fill_rect(g, 9, 5, 10, 6, 3)
    fill_rect(g, 10, 17, 11, 18, 3)
    fill_rect(g, 8, 18, 15, 20, 4)
    return g


def build_leaf(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 11.5, 5.5, 8.0, 0)
    carve_ellipse(g, 7.5, 8.0, 2.8, 4.0)
    carve_ellipse(g, 15.5, 15.0, 2.8, 4.0)
    fill_rect(g, 10, 6, 12, 18, 1)
    fill_rect(g, 7, 10, 10, 11, 2)
    fill_rect(g, 12, 13, 16, 14, 2)
    fill_rect(g, 10, 18, 11, 21, 3)
    fill_rect(g, 6, 17, 15, 19, 4)
    return g


def build_umbrella(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 11.5, 10.0, 7.5, 5.0, 0)
    carve_rect(g, 4, 11, 19, 15)
    fill_rect(g, 4, 10, 19, 12, 0)
    fill_rect(g, 9, 10, 10, 12, 1)
    fill_rect(g, 13, 10, 14, 12, 1)
    fill_rect(g, 11, 12, 12, 19, 2)
    fill_rect(g, 11, 19, 14, 20, 2)
    fill_rect(g, 14, 18, 15, 22, 2)
    fill_rect(g, 7, 13, 8, 14, 3)
    fill_rect(g, 15, 13, 16, 14, 3)
    fill_rect(g, 7, 13, 16, 15, 4)
    return g


def build_lantern(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_rect(g, 8, 7, 15, 16, 0)
    fill_rect(g, 9, 8, 14, 15, 1)
    fill_rect(g, 10, 9, 13, 14, 2)
    fill_rect(g, 10, 5, 13, 6, 3)
    fill_rect(g, 11, 3, 12, 5, 3)
    fill_rect(g, 9, 17, 14, 18, 3)
    fill_rect(g, 10, 18, 10, 21, 4)
    fill_rect(g, 13, 18, 13, 21, 4)
    fill_rect(g, 8, 7, 8, 16, 5)
    fill_rect(g, 15, 7, 15, 16, 5)
    return g


def build_ribbon(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_ellipse(g, 8.0, 10.5, 4.5, 4.0, 0)
    fill_ellipse(g, 15.0, 10.5, 4.5, 4.0, 0)
    fill_rect(g, 10, 9, 13, 13, 1)
    fill_rect(g, 7, 13, 10, 20, 2)
    fill_rect(g, 13, 13, 16, 20, 2)
    carve_rect(g, 8, 18, 8, 19)
    carve_rect(g, 14, 18, 14, 19)
    fill_rect(g, 6, 8, 7, 10, 3)
    fill_rect(g, 16, 8, 17, 10, 3)
    fill_rect(g, 9, 9, 14, 11, 4)
    return g


def build_kite(size: int) -> list[list[int]]:
    g = blank_grid(size)
    fill_rect(g, 11, 5, 12, 6, 0)
    fill_rect(g, 10, 7, 13, 8, 0)
    fill_rect(g, 8, 9, 15, 10, 0)
    fill_rect(g, 7, 11, 16, 13, 0)
    fill_rect(g, 8, 14, 15, 15, 0)
    fill_rect(g, 10, 16, 13, 17, 0)
    fill_rect(g, 11, 18, 12, 19, 0)
    fill_rect(g, 10, 9, 13, 11, 1)
    fill_rect(g, 11, 12, 12, 15, 2)
    fill_rect(g, 11, 19, 13, 22, 3)
    fill_rect(g, 12, 20, 14, 21, 4)
    fill_rect(g, 11, 22, 13, 23, 5)
    return g


SAMPLES = [
    SampleDefinition("strawberry", "Strawberry Pop", "food", "Easy", 3, "cute strawberry sticker", ["#FF5B66", "#4BBB62", "#7A4A2C", "#FFF4E2", "#FF9AA1", "#E43A46"], build_strawberry, "level.strawberry.title", "level.category.food", "level.difficulty.easy"),
    SampleDefinition("mushroom", "Mushroom Nest", "plants", "Easy", 4, "friendly forest mushroom", ["#FF725D", "#F3D5A7", "#C99860", "#FFFDF8", "#E14C45", "#A86F4A"], build_mushroom, "level.mushroom.title", "level.category.plants", "level.difficulty.easy"),
    SampleDefinition("cherry", "Cherry Glow", "food", "Easy", 3, "cute cherry sticker", ["#FF5C63", "#D93F49", "#73513A", "#59C96B", "#FFF2E6", "#FF9FA6"], build_cherry, "level.cherry.title", "level.category.food", "level.difficulty.easy"),
    SampleDefinition("acorn", "Acorn Nest", "plants", "Easy", 4, "friendly acorn sticker", ["#A86D48", "#D0A46B", "#6D4B34", "#46301F", "#F7E6D3", "#6E8A4A"], build_acorn, "level.acorn.title", "level.category.plants", "level.difficulty.easy"),
    SampleDefinition("whale", "Bubble Whale", "animals", "Easy", 4, "tiny blue whale", ["#6174FF", "#3040B7", "#FFFDF7", "#79E7F0", "#4FC3FF", "#1B2555"], build_whale, "level.whale.title", "level.category.animals", "level.difficulty.easy"),
    SampleDefinition("cactus", "Sunny Cactus", "plants", "Easy", 4, "potted cactus", ["#3DCB51", "#A6E945", "#1C8B2C", "#FFF8F0", "#9A663C", "#E7B54F"], build_cactus, "level.cactus.title", "level.category.plants", "level.difficulty.easy"),
    SampleDefinition("seahorse", "Seahorse Drift", "animals", "Easy", 4, "cute seahorse sticker", ["#FFAF63", "#FFD6A0", "#E28D4A", "#FFF1D5", "#59D6D3", "#21306A"], build_seahorse, "level.seahorse.title", "level.category.animals", "level.difficulty.easy"),
    SampleDefinition("succulent", "Sunny Succulent", "plants", "Easy", 4, "cute succulent sticker", ["#62D17B", "#8DE39A", "#4FB963", "#B77C4C", "#8A5C35", "#E9F8D8"], build_succulent, "level.succulent.title", "level.category.plants", "level.difficulty.easy"),
    SampleDefinition("fish", "Candy Fish", "animals", "Medium", 5, "small tropical fish", ["#FDB235", "#F06D74", "#7C5AF6", "#FFF5E0", "#53C6E8", "#1D2957"], build_fish, "level.fish.title", "level.category.animals", "level.difficulty.medium"),
    SampleDefinition("flower", "Bloom Burst", "plants", "Medium", 5, "cartoon flower", ["#FF88B8", "#F96198", "#FFD34D", "#59C95C", "#2C9D49", "#FFF7F1"], build_flower, "level.flower.title", "level.category.plants", "level.difficulty.medium"),
    SampleDefinition("butterfly", "Butterfly Waltz", "animals", "Medium", 5, "cute butterfly sticker", ["#FF8BC5", "#8D72FF", "#2A2D57", "#FFD861", "#FFF4DB", "#73D0C8"], build_butterfly, "level.butterfly.title", "level.category.animals", "level.difficulty.medium"),
    SampleDefinition("lotus", "Lotus Bloom", "plants", "Medium", 5, "cute lotus flower sticker", ["#FF95C2", "#FFC6DE", "#FFD45F", "#59B56A", "#8EDB78", "#FFF7E9"], build_lotus, "level.lotus.title", "level.category.plants", "level.difficulty.medium"),
    SampleDefinition("cupcake", "Cupcake Glow", "food", "Medium", 5, "cute cupcake", ["#FF9EBC", "#F6C55D", "#E39D36", "#FF7043", "#67D56A", "#FFF4E8"], build_cupcake, "level.cupcake.title", "level.category.food", "level.difficulty.medium"),
    SampleDefinition("pear", "Pear Picnic", "food", "Medium", 5, "juicy pear", ["#97D84C", "#C2ED59", "#6C4C31", "#2E8E37", "#FFF6EC", "#E9C866"], build_pear, "level.pear.title", "level.category.food", "level.difficulty.medium"),
    SampleDefinition("croissant", "Croissant Cozy", "food", "Medium", 5, "cute croissant sticker", ["#F0B758", "#D38A36", "#FFF3D8", "#B96D2A", "#8C4A24", "#F7D79E"], build_croissant, "level.croissant.title", "level.category.food", "level.difficulty.medium"),
    SampleDefinition("apple", "Apple Picnic", "food", "Medium", 5, "cute apple sticker", ["#F25E5D", "#7C5134", "#63C86B", "#FFF2DE", "#D94545", "#F8A159"], build_apple, "level.apple.title", "level.category.food", "level.difficulty.medium"),
    SampleDefinition("turtle", "Turtle Tide", "animals", "Medium", 6, "gentle turtle", ["#4EBB6B", "#6FD877", "#59D4DD", "#2B8E56", "#FFF0B7", "#1E2A55"], build_turtle, "level.turtle.title", "level.category.animals", "level.difficulty.medium"),
    SampleDefinition("snail", "Garden Snail", "animals", "Medium", 6, "cute snail", ["#E98F52", "#FFD9A8", "#A86D48", "#6ACF72", "#FFF6E8", "#202757"], build_snail, "level.snail.title", "level.category.animals", "level.difficulty.medium"),
    SampleDefinition("starfish", "Starfish Gleam", "animals", "Medium", 6, "cute starfish sticker", ["#FFAF5A", "#FF8A47", "#FFD8A1", "#FFF0D7", "#C85732", "#D45B79"], build_starfish, "level.starfish.title", "level.category.animals", "level.difficulty.medium"),
    SampleDefinition("seashell", "Seashell Hush", "animals", "Medium", 6, "cute seashell sticker", ["#FFB6C7", "#F58CAA", "#F8E8D8", "#FFF7A6", "#FFD067", "#A26BE5"], build_seashell, "level.seashell.title", "level.category.animals", "level.difficulty.medium"),
]


DAILY_SAMPLES = [
    SampleDefinition("daily-songbird", "Songbird Window", "daily", "Daily", 4, "gentle songbird sticker", ["#6AA8FF", "#2A5BC7", "#FFF2D1", "#F7A95E", "#1C2A56", "#FFD35F"], build_bird),
    SampleDefinition("daily-teacup", "Morning Teacup", "daily", "Daily", 4, "cozy teacup sticker", ["#F7B7C6", "#F1D47A", "#E1AE6B", "#FFF5EC", "#C6E9F2", "#C9875F"], build_teacup),
    SampleDefinition("daily-moon", "Pocket Moon", "daily", "Daily", 4, "crescent moon sticker", ["#FFE38B", "#FFF9D7", "#C7B8FF", "#8D76E6", "#233263"], build_moon),
    SampleDefinition("daily-leaf", "Maple Leaf", "daily", "Daily", 4, "maple leaf sticker", ["#FF8C58", "#B64A34", "#FFC66E", "#7A4B34", "#FFF1DF"], build_leaf),
    SampleDefinition("daily-umbrella", "Rain Umbrella", "daily", "Daily", 4, "cute umbrella sticker", ["#5CC0FF", "#FCE28A", "#7C5A43", "#FF8FB2", "#DFF6FF"], build_umbrella),
    SampleDefinition("daily-lantern", "Lantern Glow", "daily", "Daily", 5, "paper lantern sticker", ["#FF7A59", "#FFD36C", "#FFF4D8", "#9E5D3B", "#C42F7B", "#6B2D2A"], build_lantern),
    SampleDefinition("daily-ribbon", "Ribbon Bow", "daily", "Daily", 4, "ribbon bow sticker", ["#FF7FB4", "#FFD6E8", "#D94E8C", "#F9A95E", "#8E66FF"], build_ribbon),
    SampleDefinition("daily-kite", "Sky Kite", "daily", "Daily", 5, "paper kite sticker", ["#6F96FF", "#FFD65E", "#FF6A63", "#7C5735", "#8BE0C2", "#F7F0E4"], build_kite),
]


def make_daily_candidate(
    level_id: str,
    title: str,
    category: str,
    subject: str,
    palette_direction: str,
    *,
    estimated_minutes: int = 5,
    max_colors: int = 5,
    style_preset: str = "simple-sticker",
) -> PixelLabLevelDefinition:
    return PixelLabLevelDefinition(
        level_id=level_id,
        title=title,
        category=category,
        difficulty="Daily",
        estimated_minutes=estimated_minutes,
        prompt=(
            f"simple {subject} sticker, centered, chunky pixel art, very readable silhouette, "
            f"{palette_direction}, no background, no text, no extra details, {PIXELLAB_SUBJECT_READABILITY_PROMPT}, "
            f"{PIXELLAB_WHITE_AVOIDANCE_PROMPT}"
        ),
        max_colors=max_colors,
        style_preset=style_preset,
    )


DAILY_PIXELLAB_CANDIDATES = [
    make_daily_candidate("daily-candidate-bluebird", "Window Bluebird", "animals", "bluebird perched on a twig", "sky blue, cream, and warm orange palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-tea-kettle", "Morning Kettle", "objects", "round tea kettle with a tiny lid", "mint, cream, and honey palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-moon-cake", "Moon Cake Wish", "food", "cute moon cake with a flower stamp", "gold, cream, and chestnut palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-ginkgo-leaf", "Golden Ginkgo", "plants", "single ginkgo leaf", "golden yellow, caramel, and cream palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-rain-boots", "Rainy Boots", "objects", "pair of rain boots", "teal, coral, and cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-firefly-jar", "Firefly Jar", "seasonal", "glass jar with fireflies and a cork", "midnight blue, warm yellow, and mint palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-ribbon-bell", "Ribbon Bell", "objects", "small bell tied with a ribbon bow", "rose pink, brass gold, and cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-paper-windmill", "Paper Windmill", "objects", "paper windmill pinwheel", "red, butter yellow, and sky blue palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-lavender-sachet", "Lavender Sachet", "plants", "lavender sachet pouch with a bow", "soft violet, sage green, and linen cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-acorn-basket", "Acorn Basket", "plants", "tiny basket filled with acorns", "oak brown, moss green, and cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-croissant", "Golden Croissant", "food", "buttery croissant", "golden brown, cream, and apricot palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-strawberry-milk", "Berry Milk", "food", "strawberry milk bottle with a striped straw", "strawberry pink, milk white, and cherry red palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-citrus-slice", "Sunny Citrus", "food", "orange citrus slice", "tangerine orange, lemon yellow, and cream palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-matcha-roll", "Matcha Roll", "food", "matcha swiss roll slice", "matcha green, cream, and chestnut palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-donut-star", "Star Donut", "food", "star shaped frosted donut", "peach pink, vanilla cream, and lemon yellow palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-apple-cider", "Apple Cider", "food", "warm apple cider mug with a cinnamon stick", "apple red, amber, and cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-tulip-bunch", "Tulip Hello", "plants", "bunch of tulips tied with ribbon", "coral pink, leaf green, and butter cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-sunflower", "Sunflower Smile", "plants", "single sunflower bloom", "sunflower yellow, cocoa brown, and leaf green palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-hydrangea", "Hydrangea Mist", "plants", "round hydrangea cluster", "periwinkle, lilac, and leaf green palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-camellia", "Camellia Glow", "plants", "camellia blossom with leaves", "rose red, cream, and deep green palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-clover", "Lucky Clover", "plants", "four leaf clover", "fresh green, mint, and cream palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-mushroom-cottage", "Mushroom Cottage", "plants", "storybook mushroom house", "scarlet red, biscuit beige, and moss green palette", estimated_minutes=6, max_colors=6),
    make_daily_candidate("daily-candidate-fern-sprig", "Fern Whisper", "plants", "curved fern sprig", "forest green, sage, and cream palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-cherry-blossom", "Cherry Blossom", "plants", "cherry blossom branch", "blush pink, bark brown, and cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-moon-rabbit", "Moon Rabbit", "animals", "sitting moon rabbit", "cream white, moon yellow, and dusk blue palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-sleepy-owl", "Sleepy Owl", "animals", "round sleepy owl", "hazel brown, cream, and plum palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-fox-scarf", "Fox Scarf", "animals", "curled fox wearing a scarf", "orange rust, cream, and forest green palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-swan-note", "Swan Note", "animals", "graceful swan with a music note ribbon", "ivory white, powder blue, and gold palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-hedgehog-apple", "Hedgehog Harvest", "animals", "hedgehog holding a tiny apple", "mocha brown, apple red, and cream palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-lucky-cat", "Lucky Cat Charm", "animals", "lucky cat figurine with raised paw", "ivory white, coral red, and gold palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-star-lantern", "Star Lantern", "seasonal", "paper star lantern", "warm gold, peach, and midnight blue palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-comet-bottle", "Comet Bottle", "seasonal", "glass bottle with a tiny comet inside", "indigo, aqua, and starlight cream palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-snow-globe", "Snow Globe", "seasonal", "snow globe with a pine tree", "ice blue, pine green, and warm silver palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-seashell-lamp", "Seashell Lamp", "seasonal", "seashell shaped lamp", "seafoam, pearl cream, and coral palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-coral-heart", "Coral Heart", "seasonal", "heart shaped coral branch", "coral pink, sea blue, and shell cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-pearl-oyster", "Pearl Oyster", "seasonal", "open oyster with a pearl", "lavender gray, pearl cream, and sea mint palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-maple-cookie", "Maple Cookie", "food", "maple leaf cookie", "maple orange, biscuit tan, and cream palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-cocoa-mug", "Cocoa Break", "food", "mug of hot cocoa with marshmallows", "cocoa brown, marshmallow cream, and cherry red palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-pancake-stack", "Pancake Stack", "food", "stack of pancakes with butter", "honey gold, butter yellow, and cream palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-honey-jar", "Honey Jar", "food", "glass honey jar with a dipper", "amber gold, cream, and bee yellow palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-sewing-kit", "Sewing Kit", "objects", "tiny sewing kit with thread spool and needle", "dusty rose, teal, and cream palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-love-letter", "Love Letter", "objects", "sealed envelope with a heart sticker", "blush pink, ivory, and cherry red palette", estimated_minutes=4, max_colors=4),
    make_daily_candidate("daily-candidate-pocket-watch", "Pocket Watch", "objects", "round pocket watch with chain", "antique gold, cocoa brown, and cream palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-music-box", "Music Box", "objects", "open music box with a star", "lilac, cream, and pale gold palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-candle-bouquet", "Candle Bouquet", "objects", "bundle of candles tied with flowers", "warm peach, cream, and sage palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-picnic-basket", "Picnic Basket", "objects", "woven picnic basket with cloth", "honey brown, strawberry red, and cream palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-kite-bird", "Kite Bird", "seasonal", "bird shaped kite", "sky blue, lemon yellow, and coral palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-umbrella-bouquet", "Umbrella Bouquet", "objects", "umbrella filled with flowers", "powder blue, blush pink, and cream palette", estimated_minutes=6, max_colors=5),
    make_daily_candidate("daily-candidate-moonflower", "Moonflower Bloom", "plants", "moonflower blossom", "indigo, cream, and soft sage palette", estimated_minutes=5, max_colors=5),
    make_daily_candidate("daily-candidate-twinkle-moth", "Twinkle Moth", "animals", "gentle moth with star markings", "dusk plum, cream, and moon gold palette", estimated_minutes=6, max_colors=5),
]


def rgb_from_hex(hex_value: str) -> tuple[int, int, int]:
    value = hex_value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def hex_from_rgb(red: int, green: int, blue: int) -> str:
    return "#{0:02X}{1:02X}{2:02X}".format(red, green, blue)


def clamp_channel(value: float) -> int:
    return max(0, min(244, int(round(value))))


def flatten_cells(grid: list[list[int]]) -> list[int]:
    return [cell for row in grid for cell in row]


def build_manifest(sample: SampleDefinition, sort_order: int, grid: list[list[int]]) -> dict:
    height = len(grid)
    width = len(grid[0]) if grid else 0
    counts = Counter(flatten_cells(grid))
    counts.pop(-1, None)
    palette = [
        {
            "index": index,
            "hex": hex_value,
            "targetCellCount": counts.get(index, 0),
        }
        for index, hex_value in enumerate(sample.palette)
        if counts.get(index, 0) > 0
    ]
    manifest = {
        "schemaVersion": 1,
        "id": sample.level_id,
        "levelVersion": 1,
        "prompt": sample.prompt,
        "boardWidth": width,
        "boardHeight": height,
        "estimatedMinutes": sample.estimated_minutes,
        "sortOrder": sort_order,
        "paintableCellCount": sum(counts.values()),
        "palette": palette,
        "cells": flatten_cells(grid),
        "perColorCellIndices": [
            {
                "index": entry["index"],
                "cellIndices": [i for i, value in enumerate(flatten_cells(grid)) if value == entry["index"]],
            }
            for entry in palette
        ],
        "thumbnailAsset": f"{sample.level_id}_thumb",
        "solvedAsset": f"{sample.level_id}_solved",
    }

    if sample.title_key:
        manifest["titleKey"] = sample.title_key
    else:
        manifest["title"] = sample.title

    if sample.difficulty_key:
        manifest["difficultyKey"] = sample.difficulty_key
    else:
        manifest["difficulty"] = sample.difficulty

    if sample.category_key:
        manifest["categoryKey"] = sample.category_key
    else:
        manifest["category"] = sample.category

    return manifest


def neighbors(index: int, width: int, height: int) -> list[int]:
    x = index % width
    y = index // width
    result = []
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        nx = x + dx
        ny = y + dy
        if 0 <= nx < width and 0 <= ny < height:
            result.append(ny * width + nx)
    return result


def diagonal_neighbors(index: int, width: int, height: int) -> list[int]:
    x = index % width
    y = index // width
    result = []
    for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        nx = x + dx
        ny = y + dy
        if 0 <= nx < width and 0 <= ny < height:
            result.append(ny * width + nx)
    return result


def majority_color(values: list[int]) -> int | None:
    filtered = [value for value in values if value >= 0]
    if not filtered:
        return None
    counts = Counter(filtered)
    return counts.most_common(1)[0][0]


def cleanup_quantized_cells(cells: list[int], width: int, height: int, passes: int = 3) -> list[int]:
    cleaned = list(cells)

    for _ in range(passes):
        updated = list(cleaned)

        for index, value in enumerate(cleaned):
            orthogonal_values = [cleaned[neighbor] for neighbor in neighbors(index, width, height)]
            diagonal_values = [cleaned[neighbor] for neighbor in diagonal_neighbors(index, width, height)]

            if value >= 0:
                same_orthogonal = sum(1 for neighbor in orthogonal_values if neighbor == value)
                if same_orthogonal == 0:
                    replacement = majority_color(orthogonal_values)
                    if replacement is None and any(neighbor == value for neighbor in diagonal_values):
                        replacement = -1
                    if replacement is not None and replacement != value:
                        updated[index] = replacement
                        continue

                if same_orthogonal == 1:
                    replacement = majority_color(orthogonal_values)
                    if replacement is not None and replacement != value:
                        updated[index] = replacement
                        continue
            else:
                replacement = majority_color(orthogonal_values)
                if replacement is not None and orthogonal_values.count(replacement) >= 3:
                    updated[index] = replacement

        cleaned = updated

    return cleaned


def compact_palette_indices(cells: list[int], palette_hex: list[str]) -> tuple[list[int], list[str]]:
    used_indices = sorted({value for value in cells if value >= 0})
    if not used_indices:
        return cells, []

    remap = {old_index: new_index for new_index, old_index in enumerate(used_indices)}
    compacted_cells = [remap[value] if value >= 0 else -1 for value in cells]
    compacted_palette = [palette_hex[index] for index in used_indices]
    return compacted_cells, compacted_palette


def rebuild_manifest_from_existing(existing_manifest: dict, cells: list[int], palette_hex: list[str]) -> dict:
    counts = Counter(value for value in cells if value >= 0)
    manifest = {
        key: value
        for key, value in existing_manifest.items()
        if key not in {"palette", "cells", "perColorCellIndices", "paintableCellCount"}
    }
    manifest["paintableCellCount"] = sum(counts.values())
    manifest["palette"] = [
        {
            "index": index,
            "hex": hex_value,
            "targetCellCount": counts.get(index, 0),
        }
        for index, hex_value in enumerate(palette_hex)
        if counts.get(index, 0) > 0
    ]
    manifest["cells"] = list(cells)
    manifest["perColorCellIndices"] = [
        {
            "index": entry["index"],
            "cellIndices": [cell_index for cell_index, value in enumerate(cells) if value == entry["index"]],
        }
        for entry in manifest["palette"]
    ]
    return manifest


def merge_close_palette_colors(
    cells: list[int],
    palette_hex: list[str],
    minimum_palette_size: int,
    minimum_distance: float = 38.0,
) -> tuple[list[int], list[str]]:
    cleaned_cells = list(cells)
    cleaned_palette = list(palette_hex)

    while len(cleaned_palette) > minimum_palette_size:
        counts = Counter(value for value in cleaned_cells if value >= 0)
        palette_rgb = {index: rgb_from_hex(hex_value) for index, hex_value in enumerate(cleaned_palette)}

        closest_pair: tuple[int, int] | None = None
        closest_distance = float("inf")
        for first in range(len(cleaned_palette)):
            for second in range(first + 1, len(cleaned_palette)):
                distance = math.dist(palette_rgb[first], palette_rgb[second])
                if distance < closest_distance:
                    closest_distance = distance
                    closest_pair = (first, second)

        if closest_pair is None or closest_distance >= minimum_distance:
            break

        first, second = closest_pair
        keep = first if counts[first] >= counts[second] else second
        replace = second if keep == first else first
        cleaned_cells = [keep if value == replace else value for value in cleaned_cells]
        cleaned_cells, cleaned_palette = compact_palette_indices(cleaned_cells, cleaned_palette)

    return cleaned_cells, cleaned_palette


def merge_sparse_colors(
    cells: list[int],
    width: int,
    height: int,
    palette_hex: list[str],
    minimum_area: int = 4,
) -> list[int]:
    cleaned = list(cells)
    counts = Counter(value for value in cleaned if value >= 0)

    sparse_colors = [color_index for color_index, count in counts.items() if count < minimum_area]
    if not sparse_colors:
        return cleaned

    palette_rgb = {index: rgb_from_hex(hex_value) for index, hex_value in enumerate(palette_hex)}

    for sparse_color in sparse_colors:
        fallback_candidates = [index for index in counts.keys() if index != sparse_color and counts[index] >= minimum_area]
        if not fallback_candidates:
            continue

        fallback_color = min(
            fallback_candidates,
            key=lambda index: math.dist(palette_rgb[sparse_color], palette_rgb[index])
        )

        for index, value in enumerate(cleaned):
            if value != sparse_color:
                continue

            orthogonal_values = [cleaned[neighbor] for neighbor in neighbors(index, width, height)]
            replacement = majority_color([neighbor for neighbor in orthogonal_values if neighbor != sparse_color])
            cleaned[index] = replacement if replacement is not None else fallback_color

    return cleaned


def separate_close_palette_colors(
    cells: list[int],
    palette_hex: list[str],
    minimum_distance: float,
    passes: int = 6,
) -> list[str]:
    if len(palette_hex) < 2:
        return palette_hex

    counts = Counter(value for value in cells if value >= 0)
    palette_rgb = [list(rgb_from_hex(hex_value)) for hex_value in palette_hex]

    for _ in range(passes):
        changed = False

        for first in range(len(palette_rgb)):
            for second in range(first + 1, len(palette_rgb)):
                distance = math.dist(palette_rgb[first], palette_rgb[second])
                if distance >= minimum_distance:
                    continue

                if counts[first] < counts[second]:
                    moving_index = first
                    anchor_index = second
                else:
                    moving_index = second
                    anchor_index = first

                moving = palette_rgb[moving_index]
                anchor = palette_rgb[anchor_index]
                delta = [moving[channel] - anchor[channel] for channel in range(3)]
                if delta == [0, 0, 0]:
                    delta = [
                        17 if moving_index % 2 == 0 else -17,
                        -13 if moving_index % 3 == 0 else 13,
                        19 if moving_index % 5 == 0 else -19,
                    ]

                length = math.sqrt(sum(component * component for component in delta)) or 1.0
                required_push = minimum_distance - distance + 2.0
                candidate = [
                    clamp_channel(moving[channel] + (delta[channel] / length) * required_push)
                    for channel in range(3)
                ]

                if candidate == moving:
                    dominant_channel = max(range(3), key=lambda index: abs(delta[index]))
                    direction = 1 if delta[dominant_channel] >= 0 else -1
                    candidate[dominant_channel] = clamp_channel(candidate[dominant_channel] + direction * required_push)

                if candidate != moving:
                    palette_rgb[moving_index] = candidate
                    changed = True

        if not changed:
            break

    return [hex_from_rgb(red, green, blue) for red, green, blue in palette_rgb]


def merge_tiny_components(
    cells: list[int],
    width: int,
    height: int,
    max_component_size: int = 2,
    passes: int = 2,
) -> list[int]:
    cleaned = list(cells)

    for _ in range(passes):
        visited: set[int] = set()
        updated = list(cleaned)

        for index, value in enumerate(cleaned):
            if value < 0 or index in visited:
                continue

            queue = deque([index])
            visited.add(index)
            component: list[int] = []

            while queue:
                node = queue.popleft()
                component.append(node)
                for neighbor in neighbors(node, width, height):
                    if neighbor not in visited and cleaned[neighbor] == value:
                        visited.add(neighbor)
                        queue.append(neighbor)

            if len(component) > max_component_size:
                continue

            adjacent_values: list[int] = []
            for node in component:
                for neighbor in neighbors(node, width, height):
                    neighbor_value = cleaned[neighbor]
                    if neighbor_value >= 0 and neighbor_value != value:
                        adjacent_values.append(neighbor_value)

            replacement = majority_color(adjacent_values)
            if replacement is None:
                continue

            for node in component:
                updated[node] = replacement

        cleaned = updated

    return cleaned


def component_sizes(cells: list[int], width: int, height: int, color_index: int) -> list[int]:
    visited: set[int] = set()
    sizes: list[int] = []

    for index, value in enumerate(cells):
        if value != color_index or index in visited:
            continue

        queue = deque([index])
        visited.add(index)
        size = 0

        while queue:
            node = queue.popleft()
            size += 1
            for neighbor in neighbors(node, width, height):
                if neighbor not in visited and cells[neighbor] == color_index:
                    visited.add(neighbor)
                    queue.append(neighbor)

        sizes.append(size)

    return sizes


def collect_components(cells: list[int], width: int, height: int) -> list[tuple[int, list[int]]]:
    visited: set[int] = set()
    components: list[tuple[int, list[int]]] = []

    for index, value in enumerate(cells):
        if value < 0 or index in visited:
            continue

        queue = deque([index])
        visited.add(index)
        component: list[int] = []

        while queue:
            node = queue.popleft()
            component.append(node)
            for neighbor in neighbors(node, width, height):
                if neighbor not in visited and cells[neighbor] == value:
                    visited.add(neighbor)
                    queue.append(neighbor)

        components.append((value, component))

    return components


def component_seed_candidates(component: list[int], width: int) -> list[int]:
    ordered = sorted(component, key=lambda index: (index // width, index % width))
    seeds: list[int] = []
    selectors = [
        lambda index: (index % width, index // width),
        lambda index: (-(index % width), index // width),
        lambda index: (index // width, index % width),
        lambda index: (-(index // width), index % width),
        lambda index: ((index % width) + (index // width), index % width),
        lambda index: (-((index % width) + (index // width)), index % width),
    ]
    for selector in selectors:
        candidate = min(ordered, key=selector)
        if candidate not in seeds:
            seeds.append(candidate)
    return seeds


def contiguous_subset_from_seed(
    component_cells: list[int],
    *,
    color_index: int,
    cells: list[int],
    width: int,
    height: int,
    start: int,
    target_size: int,
) -> list[int]:
    component_set = set(component_cells)
    queue = deque([start])
    visited = {start}
    subset: list[int] = []

    while queue and len(subset) < target_size:
        node = queue.popleft()
        subset.append(node)
        for neighbor in neighbors(node, width, height):
            if neighbor in visited or neighbor not in component_set or cells[neighbor] != color_index:
                continue
            visited.add(neighbor)
            queue.append(neighbor)

    return subset


def generate_variant_palette_hex(base_hex: str, existing_palette_hex: list[str], variant_index: int) -> str:
    base_rgb = rgb_from_hex(base_hex)
    red, green, blue = [channel / 255 for channel in base_rgb]
    hue, saturation, value = colorsys.rgb_to_hsv(red, green, blue)

    candidate_rgb: list[tuple[int, int, int]] = []
    hue_offsets = (0.0, 0.06, -0.06, 0.12, -0.12)
    saturation_offsets = (0.18, -0.12, 0.08, -0.18)
    value_offsets = (0.18, -0.18, 0.12, -0.12, 0.24, -0.24)

    for hue_offset in hue_offsets:
        for saturation_offset in saturation_offsets:
            for value_offset in value_offsets:
                next_hue = (hue + hue_offset + (variant_index * 0.017)) % 1.0
                next_saturation = min(0.95, max(0.22, saturation + saturation_offset))
                next_value = min(0.95, max(0.28, value + value_offset))
                next_rgb = colorsys.hsv_to_rgb(next_hue, next_saturation, next_value)
                candidate_rgb.append(tuple(clamp_channel(channel * 255) for channel in next_rgb))

    channel_shifts = (
        (36, 0, 0),
        (-36, 0, 0),
        (0, 36, 0),
        (0, -36, 0),
        (0, 0, 36),
        (0, 0, -36),
        (28, 16, -10),
        (-28, -16, 10),
        (18, -24, 18),
        (-18, 24, -18),
    )
    for shift_red, shift_green, shift_blue in channel_shifts:
        candidate_rgb.append(
            (
                clamp_channel(base_rgb[0] + shift_red),
                clamp_channel(base_rgb[1] + shift_green),
                clamp_channel(base_rgb[2] + shift_blue),
            )
        )

    existing_rgb = [rgb_from_hex(hex_value) for hex_value in existing_palette_hex]
    best_candidate = None
    best_distance = -1.0
    for red_value, green_value, blue_value in candidate_rgb:
        minimum_distance = min(
            math.dist((red_value, green_value, blue_value), other_rgb)
            for other_rgb in existing_rgb
        )
        if minimum_distance > best_distance:
            best_candidate = (red_value, green_value, blue_value)
            best_distance = minimum_distance
        if minimum_distance >= 34.0:
            return hex_from_rgb(red_value, green_value, blue_value)

    if best_candidate is None:
        return base_hex
    return hex_from_rgb(*best_candidate)


def inflate_manifest_palette(
    manifest: dict,
    *,
    target_palette_count: int,
    minimum_palette_count: int,
) -> dict:
    width = manifest["boardWidth"]
    height = manifest["boardHeight"]
    cells = list(manifest["cells"])
    palette_hex = [entry["hex"] for entry in manifest["palette"]]

    desired_palette_count = max(minimum_palette_count, target_palette_count)
    if len(palette_hex) >= desired_palette_count:
        return manifest

    variant_index = 0
    while len(palette_hex) < desired_palette_count:
        components = sorted(
            collect_components(cells, width, height),
            key=lambda component: len(component[1]),
            reverse=True,
        )
        if not components:
            break

        accepted = False
        colors_needed = desired_palette_count - len(palette_hex)
        for color_index, component_cells in components:
            if len(component_cells) < 10:
                continue

            split_sizes = [
                max(4, min(len(component_cells) // max(colors_needed + 1, 2), 12)),
                8,
                6,
                4,
            ]
            split_sizes = [size for size in split_sizes if 4 <= size <= len(component_cells) - 4]
            if not split_sizes:
                continue

            for split_size in split_sizes:
                for seed in component_seed_candidates(component_cells, width):
                    subset = contiguous_subset_from_seed(
                        component_cells,
                        color_index=color_index,
                        cells=cells,
                        width=width,
                        height=height,
                        start=seed,
                        target_size=split_size,
                    )
                    if len(subset) < 4:
                        continue

                    next_cells = list(cells)
                    next_palette_hex = list(palette_hex)
                    next_palette_hex.append(
                        generate_variant_palette_hex(
                            palette_hex[color_index],
                            next_palette_hex,
                            variant_index=variant_index,
                        )
                    )
                    next_index = len(next_palette_hex) - 1
                    for node in subset:
                        next_cells[node] = next_index

                    next_cells = cleanup_quantized_cells(next_cells, width, height, passes=1)
                    next_cells = merge_tiny_components(next_cells, width, height, max_component_size=1, passes=1)
                    next_cells, next_palette_hex = compact_palette_indices(next_cells, next_palette_hex)
                    next_palette_hex = separate_close_palette_colors(next_cells, next_palette_hex, minimum_distance=34.0)
                    candidate_manifest = rebuild_manifest_from_existing(manifest, next_cells, next_palette_hex)
                    issues = validate_manifest(candidate_manifest)
                    if issues:
                        continue

                    cells = next_cells
                    palette_hex = next_palette_hex
                    variant_index += 1
                    accepted = True
                    break
                if accepted:
                    break
            if accepted:
                break

        if not accepted:
            break

    if len(palette_hex) < desired_palette_count:
        fallback_cells = list(cells)
        fallback_palette_hex = list(palette_hex)
        fallback_variant_index = variant_index

        while len(fallback_palette_hex) < desired_palette_count:
            components = sorted(
                collect_components(fallback_cells, width, height),
                key=lambda component: len(component[1]),
                reverse=True,
            )
            candidate_component = next(
                (
                    (color_index, component_cells)
                    for color_index, component_cells in components
                    if len(component_cells) >= 8
                ),
                None,
            )
            if candidate_component is None:
                break

            color_index, component_cells = candidate_component
            seeds = component_seed_candidates(component_cells, width)
            seed = seeds[fallback_variant_index % len(seeds)]
            subset = contiguous_subset_from_seed(
                component_cells,
                color_index=color_index,
                cells=fallback_cells,
                width=width,
                height=height,
                start=seed,
                target_size=4,
            )
            if len(subset) < 4:
                break

            fallback_palette_hex.append(
                generate_variant_palette_hex(
                    fallback_palette_hex[color_index],
                    fallback_palette_hex,
                    variant_index=fallback_variant_index,
                )
            )
            next_index = len(fallback_palette_hex) - 1
            for node in subset:
                fallback_cells[node] = next_index
            fallback_variant_index += 1

        fallback_cells, fallback_palette_hex = compact_palette_indices(fallback_cells, fallback_palette_hex)
        fallback_palette_hex = separate_close_palette_colors(fallback_cells, fallback_palette_hex, minimum_distance=34.0)
        fallback_manifest = rebuild_manifest_from_existing(manifest, fallback_cells, fallback_palette_hex)
        fallback_issues = validate_manifest(fallback_manifest)
        if not fallback_issues and len(fallback_palette_hex) > len(palette_hex):
            return fallback_manifest

    return rebuild_manifest_from_existing(manifest, cells, palette_hex)


def palette_distance_issues(manifest: dict, minimum_distance: float = 34.0) -> list[str]:
    issues = []
    palette = manifest["palette"]
    for idx, first in enumerate(palette):
        first_rgb = rgb_from_hex(first["hex"])
        for second in palette[idx + 1:]:
            second_rgb = rgb_from_hex(second["hex"])
            distance = math.dist(first_rgb, second_rgb)
            if distance < minimum_distance:
                issues.append(f"palette colors {first['index']} and {second['index']} are too close ({distance:.1f})")
    return issues


def structural_issues(manifest: dict) -> list[str]:
    issues = []
    width = manifest["boardWidth"]
    height = manifest["boardHeight"]
    cells = manifest["cells"]
    total_components = 0
    tiny_islands = 0
    diagonal_noise = 0

    for entry in manifest["palette"]:
        color_index = entry["index"]
        if entry["targetCellCount"] < 4:
            issues.append(f"color {color_index} has too little area ({entry['targetCellCount']} cells)")

        sizes = component_sizes(cells, width, height, color_index)
        total_components += len(sizes)
        tiny_islands += sum(1 for size in sizes if size <= 2)

    for index, value in enumerate(cells):
        if value < 0:
            continue
        orthogonal = sum(1 for neighbor in neighbors(index, width, height) if cells[neighbor] == value)
        diagonal = sum(1 for neighbor in diagonal_neighbors(index, width, height) if cells[neighbor] == value)
        if orthogonal == 0 and diagonal > 0:
            diagonal_noise += 1

    if tiny_islands > 6:
        issues.append(f"too many tiny islands ({tiny_islands})")
    if total_components > 22:
        issues.append(f"too many disconnected regions ({total_components})")
    if diagonal_noise > 8:
        issues.append(f"too much diagonal noise ({diagonal_noise})")

    return issues


def validate_manifest(manifest: dict, profile: str = "default") -> list[str]:
    issues: list[str] = []

    if len(manifest["cells"]) != manifest["boardWidth"] * manifest["boardHeight"]:
        issues.append("cell count does not match board dimensions")

    palette_total = sum(entry["targetCellCount"] for entry in manifest["palette"])
    if palette_total != manifest["paintableCellCount"]:
        issues.append("paintableCellCount does not match palette totals")

    if len(manifest["palette"]) > 14:
        issues.append("palette exceeds 14 colors")

    if profile in {"candidate", "monthly_seed"}:
        return issues

    issues.extend(palette_distance_issues(manifest))
    issues.extend(structural_issues(manifest))
    return issues


def normalize_category(value: str) -> str:
    normalized = value.strip().lower().replace("level.category.", "")
    if normalized in {"animal", "animals"}:
        return "animals"
    if normalized in {"food", "foods", "drink", "drinks"}:
        return "food"
    if normalized in {"plant", "plants", "flower", "flowers"}:
        return "plants"
    if normalized in {"seasonal", "symbol", "symbols"}:
        return "seasonal"
    return "objects"


def display_category(value: str) -> str:
    mapping = {
        "animals": "Animals",
        "food": "Food",
        "plants": "Plants",
        "objects": "Objects",
        "seasonal": "Seasonal",
    }
    return mapping.get(normalize_category(value), "Objects")


def display_difficulty(value: str) -> str:
    normalized = value.strip().lower()
    mapping = {
        "easy": "Easy",
        "medium": "Medium",
        "hard": "Hard",
    }
    return mapping.get(normalized, value)


def deterministic_int(seed: str) -> int:
    return int(hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16], 16)


def expected_selection_phase(day_or_index: int) -> str:
    if 1 <= day_or_index <= 10:
        return "early"
    if 11 <= day_or_index <= 20:
        return "mid"
    return "late"


def parse_month_filter(raw_value: str | None) -> set[int] | None:
    if raw_value is None:
        return None

    months: set[int] = set()
    for chunk in raw_value.split(","):
        value = chunk.strip()
        if not value:
            continue

        if "-" in value:
            start_raw, end_raw = value.split("-", maxsplit=1)
            start = int(start_raw)
            end = int(end_raw)
            if start > end:
                start, end = end, start
            months.update(range(start, end + 1))
        else:
            months.add(int(value))

    invalid = sorted(month for month in months if month < 1 or month > 12)
    if invalid:
        raise SystemExit(f"Unsupported month filter values: {invalid}")

    return months or None


def palette_bounds_for_difficulty(difficulty: str) -> tuple[int, int]:
    normalized = difficulty.strip().lower()
    if normalized == "easy":
        return 4, 6
    if normalized == "medium":
        return 6, 9
    if normalized == "hard":
        return 9, 14
    raise ValueError(f"Unsupported difficulty: {difficulty}")


def read_monthly_daily_catalog(csv_path: Path) -> list[MonthlyDailyCatalogRow]:
    with csv_path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != MONTHLY_DAILY_CSV_COLUMNS:
            raise SystemExit(
                "Monthly daily catalog has unexpected columns.\n"
                f"Expected: {MONTHLY_DAILY_CSV_COLUMNS}\n"
                f"Actual: {reader.fieldnames}"
            )

        rows: list[MonthlyDailyCatalogRow] = []
        for raw in reader:
            rows.append(
                MonthlyDailyCatalogRow(
                    month=int(raw["month"]),
                    day_or_index=int(raw["day_or_index"]),
                    month_id=raw["month_id"].strip(),
                    theme=raw["theme"].strip(),
                    motif=raw["motif"].strip(),
                    category=raw["category"].strip(),
                    difficulty=raw["difficulty"].strip(),
                    selection_phase=raw["selection_phase"].strip(),
                    availability=raw["availability"].strip(),
                    display_title=raw["display_title"].strip(),
                    display_title_key=raw["display_title_key"].strip(),
                    internal_id=raw["internal_id"].strip(),
                    asset_file_name=raw["asset_file_name"].strip(),
                    palette_count=int(raw["palette_count"]),
                    grid_size=int(raw["grid_size"]),
                    estimated_minutes=int(raw["estimated_minutes"]),
                    sort_order=int(raw["sort_order"]),
                    prompt=raw["prompt"].strip(),
                    notes=raw["notes"].strip(),
                )
            )
        return rows


def validate_monthly_daily_rows(rows: list[MonthlyDailyCatalogRow]) -> list[str]:
    issues: list[str] = []
    internal_ids: set[str] = set()
    asset_file_names: set[str] = set()
    sort_orders: set[int] = set()
    rows_by_month: dict[int, list[MonthlyDailyCatalogRow]] = {month: [] for month in range(1, 13)}

    if len(rows) != 366:
        issues.append(f"catalog must contain 366 rows, found {len(rows)}")

    for row in rows:
        rows_by_month.setdefault(row.month, []).append(row)

        if row.month not in MONTH_ROW_COUNT:
            issues.append(f"{row.internal_id}: unsupported month {row.month}")

        expected_month_id = f"month-{row.month:02d}"
        if row.month_id != expected_month_id:
            issues.append(f"{row.internal_id}: month_id should be {expected_month_id}")

        if row.internal_id in internal_ids:
            issues.append(f"duplicate internal_id: {row.internal_id}")
        internal_ids.add(row.internal_id)

        if row.asset_file_name in asset_file_names:
            issues.append(f"duplicate asset_file_name: {row.asset_file_name}")
        asset_file_names.add(row.asset_file_name)

        if row.sort_order in sort_orders:
            issues.append(f"duplicate sort_order: {row.sort_order}")
        sort_orders.add(row.sort_order)

        if row.asset_file_name != row.internal_id:
            issues.append(f"{row.internal_id}: asset_file_name must match internal_id")

        if row.grid_size != 32:
            issues.append(f"{row.internal_id}: grid_size must be 32")

        if not row.prompt:
            issues.append(f"{row.internal_id}: prompt is required")

        if not row.display_title:
            issues.append(f"{row.internal_id}: display_title is required")

        if not row.theme:
            issues.append(f"{row.internal_id}: theme is required")

        if row.selection_phase != expected_selection_phase(row.day_or_index):
            issues.append(
                f"{row.internal_id}: selection_phase must be {expected_selection_phase(row.day_or_index)} "
                f"for day {row.day_or_index}"
            )

        if row.availability not in {"always", "leap_year_only"}:
            issues.append(f"{row.internal_id}: unsupported availability {row.availability}")

        if row.availability == "leap_year_only" and not (row.month == 2 and row.day_or_index == 29):
            issues.append(f"{row.internal_id}: leap_year_only is only allowed on 2/29")

        if row.availability == "always" and row.month == 2 and row.day_or_index == 29:
            issues.append(f"{row.internal_id}: 2/29 must be marked leap_year_only")

        try:
            minimum_palette, maximum_palette = palette_bounds_for_difficulty(row.difficulty)
        except ValueError as error:
            issues.append(f"{row.internal_id}: {error}")
        else:
            if not minimum_palette <= row.palette_count <= maximum_palette:
                issues.append(
                    f"{row.internal_id}: palette_count {row.palette_count} is outside "
                    f"{minimum_palette}-{maximum_palette} for {row.difficulty}"
                )

    for month, month_rows in rows_by_month.items():
        ordered_rows = sorted(month_rows, key=lambda row: row.day_or_index)
        expected_rows = MONTH_ROW_COUNT[month]
        if len(ordered_rows) != expected_rows:
            issues.append(f"month {month:02d}: expected {expected_rows} rows, found {len(ordered_rows)}")
            continue

        expected_days = list(range(1, expected_rows + 1))
        actual_days = [row.day_or_index for row in ordered_rows]
        if actual_days != expected_days:
            issues.append(f"month {month:02d}: day_or_index must be sequential from 1 to {expected_rows}")

        always_rows = [row for row in ordered_rows if row.availability == "always"]
        expected_always = MONTH_ALWAYS_AVAILABLE_COUNT[month]
        if len(always_rows) != expected_always:
            issues.append(
                f"month {month:02d}: expected {expected_always} always-available rows, found {len(always_rows)}"
            )

        if month == 2:
            always_distribution = Counter(row.difficulty.lower() for row in always_rows)
            total_distribution = Counter(row.difficulty.lower() for row in ordered_rows)
            if dict(always_distribution) != MONTH_DIFFICULTY_DISTRIBUTION[28]:
                issues.append(
                    f"month 02: non-leap difficulty distribution must be {MONTH_DIFFICULTY_DISTRIBUTION[28]}, "
                    f"found {dict(always_distribution)}"
                )
            leap_medium_count = total_distribution.get("medium", 0) - always_distribution.get("medium", 0)
            if leap_medium_count != 1 or total_distribution.get("easy", 0) != 10 or total_distribution.get("hard", 0) != 5:
                issues.append(
                    "month 02: total distribution must be 10 easy / 14 medium / 5 hard with 2/29 as medium"
                )
        else:
            expected_distribution = MONTH_DIFFICULTY_DISTRIBUTION[MONTH_ALWAYS_AVAILABLE_COUNT[month]]
            actual_distribution = Counter(row.difficulty.lower() for row in ordered_rows)
            if dict(actual_distribution) != expected_distribution:
                issues.append(
                    f"month {month:02d}: difficulty distribution must be {expected_distribution}, "
                    f"found {dict(actual_distribution)}"
                )

    return issues


def build_monthly_daily_manifest(rows: list[MonthlyDailyCatalogRow]) -> dict:
    months: list[dict] = []

    for month in range(1, 13):
        metadata = MONTHLY_EVENT_METADATA[month]
        month_rows = sorted((row for row in rows if row.month == month), key=lambda row: row.day_or_index)
        months.append(
            {
                "id": f"month-{month:02d}",
                "month": month,
                "titleKey": metadata["title"],
                "bannerKey": metadata["banner"],
                "accentHex": metadata["accent_hex"],
                "archiveTitleKey": metadata["archive_title"],
                "archiveSubtitleKey": metadata["archive_subtitle"],
                "rewardTitleID": f"event-title.month-{month:02d}",
                "rewardTitleKey": metadata["reward_title"],
                "rewardSubtitleKey": metadata["reward_subtitle"],
                "entries": [
                    {
                        "index": row.day_or_index,
                        "levelKey": f"{row.internal_id}#1",
                        "difficulty": display_difficulty(row.difficulty),
                        "selectionPhase": row.selection_phase,
                        "availability": row.availability,
                    }
                    for row in month_rows
                ],
            }
        )

    return {
        "schemaVersion": 1,
        "titleKey": "Monthly Daily",
        "subtitleKey": "A fresh hand-picked pixel artwork every day.",
        "albumTitleKey": "Monthly Album",
        "months": months,
    }


def render_seed_manifest_image(seed_manifest: dict, cell_px: int = 1, shaded: bool = False):
    from PIL import Image

    width = seed_manifest["boardWidth"] * cell_px
    height = seed_manifest["boardHeight"] * cell_px
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = image.load()
    palette_map = {entry["index"]: rgb_from_hex(entry["hex"]) for entry in seed_manifest["palette"]}

    for row in range(seed_manifest["boardHeight"]):
        for column in range(seed_manifest["boardWidth"]):
            color_index = seed_manifest["cells"][row * seed_manifest["boardWidth"] + column]
            if color_index < 0:
                continue

            base_red, base_green, base_blue = palette_map[color_index]
            for py in range(cell_px):
                for px in range(cell_px):
                    x = column * cell_px + px
                    y = row * cell_px + py
                    highlight = 20 if shaded and px < cell_px * 0.34 and py < cell_px * 0.34 else 0
                    shadow = -16 if shaded and px > cell_px * 0.68 and py > cell_px * 0.68 else 0
                    red = max(0, min(255, base_red + highlight + shadow))
                    green = max(0, min(255, base_green + highlight + shadow))
                    blue = max(0, min(255, base_blue + highlight + shadow))
                    pixels[x, y] = (red, green, blue, 255)

    return image


def shift_image_hue(image, degrees: float, saturation_scale: float = 1.0, value_scale: float = 1.0):
    rgba = image.convert("RGBA")
    adjusted_pixels = []
    hue_offset = degrees / 360.0

    for red, green, blue, alpha in rgba.getdata():
        if alpha == 0:
            adjusted_pixels.append((red, green, blue, alpha))
            continue

        hue, saturation, value = colorsys.rgb_to_hsv(red / 255.0, green / 255.0, blue / 255.0)
        hue = (hue + hue_offset) % 1.0
        saturation = max(0.0, min(1.0, saturation * saturation_scale))
        value = max(0.0, min(1.0, value * value_scale))
        next_red, next_green, next_blue = colorsys.hsv_to_rgb(hue, saturation, value)
        adjusted_pixels.append(
            (
                round(next_red * 255),
                round(next_green * 255),
                round(next_blue * 255),
                alpha,
            )
        )

    rgba.putdata(adjusted_pixels)
    return rgba


def variant_seed_image(seed_manifest: dict, internal_id: str, difficulty: str):
    from PIL import ImageOps

    normalized_difficulty = difficulty.strip().lower()
    if normalized_difficulty == "hard":
        image = render_seed_manifest_image(seed_manifest, cell_px=8, shaded=True)
    else:
        image = render_seed_manifest_image(seed_manifest, cell_px=1, shaded=False)
    variant_index = deterministic_int(internal_id)

    if variant_index % 2 == 1:
        image = ImageOps.mirror(image)

    hue_steps = [-18, -12, -6, 0, 6, 12, 18]
    saturation_steps = [0.94, 1.0, 1.06]
    value_steps = [0.96, 1.0, 1.04]
    hue_shift = hue_steps[(variant_index // 2) % len(hue_steps)]
    saturation_scale = saturation_steps[(variant_index // 11) % len(saturation_steps)]
    value_scale = value_steps[(variant_index // 29) % len(value_steps)]
    if normalized_difficulty == "hard":
        return shift_image_hue(image, hue_shift, saturation_scale=saturation_scale, value_scale=value_scale)

    return shift_image_hue(image, hue_shift / 2, saturation_scale=saturation_scale, value_scale=value_scale)


def load_seed_level_records(resources_root: Path) -> dict[str, list[dict]]:
    levels_dir = resources_root / "Levels"
    pools: dict[str, list[dict]] = {
        "animals": [],
        "food": [],
        "plants": [],
        "objects": [],
        "seasonal": [],
    }

    for level_path in sorted(levels_dir.glob("*.json")):
        if level_path.stem.startswith("daily_"):
            continue

        manifest = json.loads(level_path.read_text(encoding="utf-8"))
        if manifest.get("boardWidth") != 32 or manifest.get("boardHeight") != 32:
            continue

        category = normalize_category(manifest.get("categoryKey", manifest.get("category", "objects")))
        pools.setdefault(category, []).append({"path": level_path, "manifest": manifest})

    return pools


def select_seed_record(row: MonthlyDailyCatalogRow, pools: dict[str, list[dict]]) -> dict:
    category = normalize_category(row.category)
    candidates = pools.get(category) or [record for pool in pools.values() for record in pool]
    if not candidates:
        raise SystemExit("No 32x32 seed levels are available for monthly generation.")
    return candidates[deterministic_int(row.internal_id) % len(candidates)]


def generate_level_manifest_from_seed(
    row: MonthlyDailyCatalogRow,
    seed_manifest: dict,
) -> dict:
    require_pillow()
    from PIL import Image  # type: ignore

    variant_image = variant_seed_image(seed_manifest, row.internal_id, row.difficulty)
    if variant_image.size == (row.grid_size, row.grid_size):
        board_image = variant_image
    else:
        board_image = variant_image.resize((row.grid_size, row.grid_size), resample=Image.Resampling.BOX)

    manifest = build_manifest_from_rgba_image(
        rgba_image=board_image,
        level_id=row.internal_id,
        title=row.display_title,
        category=display_category(row.category),
        difficulty=display_difficulty(row.difficulty),
        estimated_minutes=row.estimated_minutes,
        sort_order=row.sort_order,
        board_size=row.grid_size,
        max_colors=row.palette_count,
    )
    manifest["prompt"] = append_pixellab_generation_guardrails(row.prompt)
    return manifest


def generate_monthly_daily_levels(args: argparse.Namespace) -> None:
    rows = read_monthly_daily_catalog(Path(args.csv))
    issues = validate_monthly_daily_rows(rows)
    if issues:
        raise SystemExit("Monthly daily catalog validation failed:\n" + "\n".join(f"- {issue}" for issue in issues))

    allowed_months = parse_month_filter(args.months)
    selected_rows = [
        row for row in rows
        if allowed_months is None or row.month in allowed_months
    ]
    if not selected_rows:
        raise SystemExit("No rows matched the requested month filter.")

    output_root = Path(args.output)
    output_root.mkdir(parents=True, exist_ok=True)
    journey_dir = output_root / "Journey"
    journey_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = journey_dir / "monthly_daily_events.json"
    manifest_path.write_text(
        json.dumps(build_monthly_daily_manifest(selected_rows), indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    failures: list[str] = []
    client = load_pixellab_client() if args.pixellab and args.max_workers == 1 else None
    seed_pools = None if args.pixellab else load_seed_level_records(Path(args.seed_resources_root))

    pending_rows: list[MonthlyDailyCatalogRow] = []
    for row in selected_rows:
        level_path = output_root / "Levels" / f"{row.internal_id}.json"
        if args.skip_existing and level_path.exists():
            continue
        pending_rows.append(row)

    def build_row(row: MonthlyDailyCatalogRow) -> tuple[str, str | None]:
        try:
            if args.pixellab:
                manifest = generate_level_manifest_from_pixellab(
                    prompt=row.prompt,
                    level_id=row.internal_id,
                    title=row.display_title,
                    category=display_category(row.category),
                    difficulty=display_difficulty(row.difficulty),
                    estimated_minutes=row.estimated_minutes,
                    sort_order=row.sort_order,
                    board_size=row.grid_size,
                    render_size=args.render_size,
                    max_colors=row.palette_count,
                    style_preset=args.style_preset,
                    validation_profile="default",
                    client=client,
                    max_attempts=args.pixellab_attempts,
                )
            else:
                seed_record = select_seed_record(row, seed_pools or {})
                manifest = generate_level_manifest_from_seed(row, seed_record["manifest"])

            issues = validate_manifest(manifest, profile="default" if args.pixellab else "monthly_seed")
            if issues:
                raise SystemExit(", ".join(issues))

            write_manifest_and_images(manifest, output_root)
            print(f"generated {row.internal_id}", file=sys.stderr)
            return row.internal_id, None
        except SystemExit as exc:
            return row.internal_id, str(exc)
        except Exception as exc:  # pragma: no cover - CLI batch best effort
            return row.internal_id, str(exc)

    if args.pixellab and args.max_workers > 1:
        with ThreadPoolExecutor(max_workers=args.max_workers) as executor:
            futures = {executor.submit(build_row, row): row.internal_id for row in pending_rows}
            for future in as_completed(futures):
                internal_id, error = future.result()
                if error:
                    failures.append(f"{internal_id}: {error}")
    else:
        for row in pending_rows:
            internal_id, error = build_row(row)
            if error:
                failures.append(f"{internal_id}: {error}")

    if failures:
        raise SystemExit("Monthly daily generation finished with failures:\n" + "\n".join(f"- {entry}" for entry in failures))


def validate_monthly_daily_pack(args: argparse.Namespace) -> None:
    rows = read_monthly_daily_catalog(Path(args.csv))
    issues = validate_monthly_daily_rows(rows)
    output_root = Path(args.generated_root)
    journey_path = output_root / "Journey" / "monthly_daily_events.json"

    if not journey_path.exists():
        issues.append(f"missing catalog JSON: {journey_path}")

    for row in rows:
        level_path = output_root / "Levels" / f"{row.internal_id}.json"
        if not level_path.exists():
            issues.append(f"missing level manifest: {level_path}")
            continue

        manifest = json.loads(level_path.read_text(encoding="utf-8"))
        thumbnail_path = output_root / "GeneratedThumbnails" / f"{manifest['thumbnailAsset']}.png"
        solved_path = output_root / "GeneratedSolved" / f"{manifest['solvedAsset']}.png"

        if not thumbnail_path.exists():
            issues.append(f"missing thumbnail: {thumbnail_path}")
        if not solved_path.exists():
            issues.append(f"missing solved image: {solved_path}")

        if manifest.get("boardWidth") != row.grid_size or manifest.get("boardHeight") != row.grid_size:
            issues.append(f"{row.internal_id}: generated grid size does not match CSV")

        palette_delta = abs(len(manifest.get("palette", [])) - row.palette_count)
        if palette_delta > args.max_palette_delta:
            issues.append(
                f"{row.internal_id}: palette count drift is too high "
                f"(csv {row.palette_count}, manifest {len(manifest.get('palette', []))})"
            )

    if journey_path.exists():
        try:
            generated_catalog = json.loads(journey_path.read_text(encoding="utf-8"))
            if len(generated_catalog.get("months", [])) != 12:
                issues.append("monthly_daily_events.json must contain 12 months")
        except json.JSONDecodeError as error:
            issues.append(f"monthly_daily_events.json is invalid JSON: {error}")

    if issues:
        raise SystemExit("Monthly daily pack validation failed:\n" + "\n".join(f"- {issue}" for issue in issues))


def sync_monthly_daily_resources(args: argparse.Namespace) -> None:
    rows = read_monthly_daily_catalog(Path(args.csv))
    source_root = Path(args.source)
    destination_root = Path(args.destination)
    monthly_level_ids = {row.internal_id for row in rows}

    for subdirectory in ("Levels", "GeneratedThumbnails", "GeneratedSolved", "Journey"):
        (destination_root / subdirectory).mkdir(parents=True, exist_ok=True)

    manifest_source = source_root / "Journey" / "monthly_daily_events.json"
    manifest_destination = destination_root / "Journey" / "monthly_daily_events.json"
    shutil.copy2(manifest_source, manifest_destination)

    legacy_journey_files = (
        destination_root / "Journey" / "daily_catalog.json",
        destination_root / "Journey" / "events.json",
    )
    for legacy_path in legacy_journey_files:
        if legacy_path.exists():
            legacy_path.unlink()

    journey_keys: set[str] = set()
    journey_manifest_path = destination_root / "Journey" / "journey.json"
    if journey_manifest_path.exists():
        journey_manifest = json.loads(journey_manifest_path.read_text(encoding="utf-8"))
        for chapter in journey_manifest.get("chapters", []):
            journey_keys.update(chapter.get("levelKeys", []))

    levels_dir = destination_root / "Levels"
    thumbnails_dir = destination_root / "GeneratedThumbnails"
    solved_dir = destination_root / "GeneratedSolved"

    for level_path in levels_dir.glob("*.json"):
        manifest = json.loads(level_path.read_text(encoding="utf-8"))
        storage_key = f"{manifest['id']}#{manifest['levelVersion']}"
        should_keep = manifest["id"] in monthly_level_ids or storage_key in journey_keys
        if should_keep:
            continue

        thumbnail_path = thumbnails_dir / f"{manifest['thumbnailAsset']}.png"
        solved_path = solved_dir / f"{manifest['solvedAsset']}.png"

        if thumbnail_path.exists():
            thumbnail_path.unlink()
        if solved_path.exists():
            solved_path.unlink()
        level_path.unlink()

    for row in rows:
        level_source = source_root / "Levels" / f"{row.internal_id}.json"
        level_destination = destination_root / "Levels" / f"{row.internal_id}.json"
        shutil.copy2(level_source, level_destination)

        generated_manifest = json.loads(level_source.read_text(encoding="utf-8"))
        thumbnail_source = source_root / "GeneratedThumbnails" / f"{generated_manifest['thumbnailAsset']}.png"
        thumbnail_destination = destination_root / "GeneratedThumbnails" / thumbnail_source.name
        solved_source = source_root / "GeneratedSolved" / f"{generated_manifest['solvedAsset']}.png"
        solved_destination = destination_root / "GeneratedSolved" / solved_source.name
        shutil.copy2(thumbnail_source, thumbnail_destination)
        shutil.copy2(solved_source, solved_destination)


def merge_monthly_daily_staging(args: argparse.Namespace) -> None:
    rows = read_monthly_daily_catalog(Path(args.csv))
    issues = validate_monthly_daily_rows(rows)
    if issues:
        raise SystemExit("Monthly daily catalog validation failed:\n" + "\n".join(f"- {issue}" for issue in issues))

    output_root = Path(args.output)
    for subdirectory in ("Levels", "GeneratedThumbnails", "GeneratedSolved", "Journey"):
        (output_root / subdirectory).mkdir(parents=True, exist_ok=True)

    for source in args.sources:
        source_root = Path(source)
        for subdirectory, pattern in (
            ("Levels", "*.json"),
            ("GeneratedThumbnails", "*.png"),
            ("GeneratedSolved", "*.png"),
        ):
            source_dir = source_root / subdirectory
            if not source_dir.exists():
                continue
            for asset_path in source_dir.glob(pattern):
                shutil.copy2(asset_path, output_root / subdirectory / asset_path.name)

    manifest_path = output_root / "Journey" / "monthly_daily_events.json"
    manifest_path.write_text(
        json.dumps(build_monthly_daily_manifest(rows), indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def repair_monthly_daily_palette(args: argparse.Namespace) -> None:
    rows = read_monthly_daily_catalog(Path(args.csv))
    generated_root = Path(args.generated_root)
    repaired_ids: list[str] = []
    failures: list[str] = []

    for row in rows:
        manifest_path = generated_root / "Levels" / f"{row.internal_id}.json"
        if not manifest_path.exists():
            failures.append(f"{row.internal_id}: missing manifest")
            continue

        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        current_palette_count = len(manifest.get("palette", []))
        minimum_palette_count = max(
            palette_bounds_for_difficulty(row.difficulty)[0],
            row.palette_count - args.max_palette_delta,
        )
        if current_palette_count >= minimum_palette_count:
            continue

        repaired_manifest = inflate_manifest_palette(
            manifest,
            target_palette_count=row.palette_count,
            minimum_palette_count=minimum_palette_count,
        )
        repaired_palette_count = len(repaired_manifest.get("palette", []))
        palette_delta = abs(repaired_palette_count - row.palette_count)
        issues = validate_manifest(repaired_manifest)
        if issues or palette_delta > args.max_palette_delta:
            failures.append(
                f"{row.internal_id}: repaired palette count {repaired_palette_count} is still invalid "
                f"(target {row.palette_count}, delta {palette_delta})"
            )
            continue

        write_manifest_and_images(repaired_manifest, generated_root)
        repaired_ids.append(row.internal_id)

    print(f"Repaired {len(repaired_ids)} monthly daily manifests", file=sys.stderr)
    if failures:
        raise SystemExit(
            "Monthly daily palette repair finished with failures:\n"
            + "\n".join(f"- {entry}" for entry in failures)
        )


def png_chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, pixels: list[tuple[int, int, int, int]]) -> None:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        start = y * width
        row = pixels[start:start + width]
        for r, g, b, a in row:
            raw.extend((r, g, b, a))

    compressed = zlib.compress(bytes(raw), level=9)

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        handle.write(png_chunk(b"IDAT", compressed))
        handle.write(png_chunk(b"IEND", b""))


def render_level_pixels(manifest: dict, cell_px: int) -> tuple[int, int, list[tuple[int, int, int, int]]]:
    padding = cell_px
    width = manifest["boardWidth"] * cell_px + padding * 2
    height = manifest["boardHeight"] * cell_px + padding * 2

    background = (247, 241, 255, 255)
    pixels = [background for _ in range(width * height)]
    palette_map = {entry["index"]: rgb_from_hex(entry["hex"]) for entry in manifest["palette"]}

    for row in range(manifest["boardHeight"]):
        for column in range(manifest["boardWidth"]):
            color_index = manifest["cells"][row * manifest["boardWidth"] + column]
            if color_index < 0:
                continue

            base_r, base_g, base_b = palette_map[color_index]
            for py in range(cell_px):
                for px in range(cell_px):
                    x = padding + column * cell_px + px
                    y = padding + row * cell_px + py

                    highlight = 22 if px < cell_px * 0.32 and py < cell_px * 0.32 else 0
                    shadow = -18 if px > cell_px * 0.72 and py > cell_px * 0.72 else 0

                    r = max(0, min(255, base_r + highlight + shadow))
                    g = max(0, min(255, base_g + highlight + shadow))
                    b = max(0, min(255, base_b + highlight + shadow))
                    pixels[y * width + x] = (r, g, b, 255)

    return width, height, pixels


def write_manifest_and_images(manifest: dict, output_root: Path) -> None:
    levels_dir = output_root / "Levels"
    thumbnails_dir = output_root / "GeneratedThumbnails"
    solved_dir = output_root / "GeneratedSolved"

    levels_dir.mkdir(parents=True, exist_ok=True)
    thumbnails_dir.mkdir(parents=True, exist_ok=True)
    solved_dir.mkdir(parents=True, exist_ok=True)

    with (levels_dir / f"{manifest['id']}.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")

    thumb_w, thumb_h, thumb_pixels = render_level_pixels(manifest, THUMBNAIL_CELL)
    solved_w, solved_h, solved_pixels = render_level_pixels(manifest, SOLVED_CELL)

    write_png(thumbnails_dir / f"{manifest['thumbnailAsset']}.png", thumb_w, thumb_h, thumb_pixels)
    write_png(solved_dir / f"{manifest['solvedAsset']}.png", solved_w, solved_h, solved_pixels)


def generate_pack(output_root: Path, samples: list[SampleDefinition], start_sort_order: int = 1) -> None:
    failures: list[str] = []

    for sort_order, sample in enumerate(samples, start=start_sort_order):
        manifest = build_manifest(sample, sort_order, sample.build(BOARD_SIZE))
        issues = validate_manifest(manifest)
        if issues:
            failures.append(f"{sample.level_id}: {', '.join(issues)}")
            continue
        write_manifest_and_images(manifest, output_root)

    if failures:
        raise SystemExit("Sample pack validation failed:\n" + "\n".join(failures))


def generate_sample_pack(output_root: Path) -> None:
    generate_pack(output_root, SAMPLES)


def generate_daily_pack(output_root: Path) -> None:
    generate_pack(output_root, DAILY_SAMPLES, start_sort_order=1001)


def require_optional_dependency(name: str, install_hint: str) -> None:
    raise SystemExit(f"{name} is required for this flow. {install_hint}")


def require_pillow() -> None:
    try:
        from PIL import Image  # noqa: F401
    except ImportError:
        require_optional_dependency("Pillow", "Install with `python3 -m pip install pillow`.")


def load_pixellab_client():
    try:
        import pixellab  # type: ignore
    except ImportError:
        require_optional_dependency("pixellab", "Install PixelLab's SDK before using the PixelLab flows.")

    client_class = getattr(pixellab, "PixelLabClient", None) or getattr(pixellab, "Client", None)
    if client_class is None:
        raise SystemExit("Unsupported PixelLab SDK: missing client class")
    return client_class.from_env()


def generate_pixellab_image(
    *,
    prompt: str,
    image_size: int,
    negative_description: str,
    outline: str,
    shading: str,
    detail: str,
    no_background: bool,
    client=None,
    max_attempts: int = 5,
):
    from PIL import Image  # type: ignore

    client = client or load_pixellab_client()
    guarded_prompt = append_pixellab_generation_guardrails(prompt)
    last_error: Exception | None = None
    response = None

    for attempt in range(1, max_attempts + 1):
        try:
            if hasattr(client, "generate_image_pixflux"):
                response = client.generate_image_pixflux(
                    description=guarded_prompt,
                    image_size={"width": image_size, "height": image_size},
                    negative_description=negative_description,
                    outline=outline,
                    shading=shading,
                    detail=detail,
                    no_background=no_background,
                )
            elif hasattr(client, "generateImagePixflux"):
                response = client.generateImagePixflux({
                    "description": guarded_prompt,
                    "imageSize": {"width": image_size, "height": image_size},
                    "negativeDescription": negative_description,
                    "outline": outline,
                    "shading": shading,
                    "detail": detail,
                    "noBackground": no_background,
                })
            else:
                raise SystemExit("Unsupported PixelLab SDK: missing generate_image_pixflux API")
            break
        except Exception as error:  # pragma: no cover - network dependent
            last_error = error
            message = str(error)
            if "429" not in message or attempt == max_attempts:
                raise
            delay_seconds = min(30, 2 ** (attempt - 1))
            print(
                f"[pixellab backoff] rate limited on attempt {attempt}/{max_attempts}; sleeping {delay_seconds}s",
                file=sys.stderr,
            )
            time.sleep(delay_seconds)

    if response is None:
        if last_error is not None:
            raise last_error
        raise SystemExit("PixelLab image generation did not return a response")

    pil_image = response.image.pil_image() if hasattr(response.image, "pil_image") else Image.open(response.image.to_bytes_io())
    return soften_near_white_pixels(pil_image)


def create_linear_gradient(size: int, top_hex: str, bottom_hex: str):
    from PIL import Image

    top = tuple(int(top_hex[index:index + 2], 16) for index in (1, 3, 5))
    bottom = tuple(int(bottom_hex[index:index + 2], 16) for index in (1, 3, 5))
    image = Image.new("RGBA", (size, size))
    pixels = image.load()
    denominator = max(size - 1, 1)
    for y in range(size):
        ratio = y / denominator
        rgb = tuple(round(top[channel] * (1 - ratio) + bottom[channel] * ratio) for channel in range(3))
        for x in range(size):
            pixels[x, y] = (*rgb, 255)
    return image


def remove_border_matte(foreground, tolerance: int = 18):
    width, height = foreground.size
    image = foreground.convert("RGBA")
    pixels = image.load()
    seeds = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    seed_samples = [pixels[x, y] for x, y in seeds]
    target = tuple(round(sum(sample[channel] for sample in seed_samples) / len(seed_samples)) for channel in range(3))

    queue = deque(seeds)
    seen = set(seeds)
    while queue:
        x, y = queue.popleft()
        red, green, blue, alpha = pixels[x, y]
        if alpha == 0:
            continue
        if max(abs(red - target[0]), abs(green - target[1]), abs(blue - target[2])) > tolerance:
            continue
        pixels[x, y] = (red, green, blue, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx = x + dx
            ny = y + dy
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen:
                seen.add((nx, ny))
                queue.append((nx, ny))
    return image


def soften_near_white_pixels(image):
    rgba = image.convert("RGBA")
    adjusted_pixels: list[tuple[int, int, int, int]] = []

    for red, green, blue, alpha in rgba.getdata():
        if alpha == 0:
            adjusted_pixels.append((red, green, blue, alpha))
            continue

        if min(red, green, blue) >= NEAR_WHITE_CHANNEL_THRESHOLD:
            max_delta = max(abs(red - green), abs(green - blue), abs(red - blue))
            if max_delta <= NEAR_WHITE_MAX_DELTA:
                adjusted_pixels.append((*NEAR_WHITE_TARGET_RGB, alpha))
                continue

        adjusted_pixels.append((red, green, blue, alpha))

    rgba.putdata(adjusted_pixels)
    return rgba


def apply_circle(image, *, cx: float, cy: float, diameter: float, color_hex: str, alpha: float) -> None:
    from PIL import Image, ImageDraw

    rgba = tuple(int(color_hex[index:index + 2], 16) for index in (1, 3, 5)) + (round(255 * alpha),)
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    radius = diameter / 2
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), fill=rgba)
    image.alpha_composite(overlay)


def make_app_icon_background(size: int):
    background = create_linear_gradient(size, APP_ICON_BACKGROUND_TOP, APP_ICON_BACKGROUND_BOTTOM)
    apply_circle(background, cx=size * 0.18, cy=size * 0.12, diameter=size * 0.34, color_hex="#FFFFFF", alpha=0.32)
    apply_circle(background, cx=size * 0.83, cy=size * 0.88, diameter=size * 0.42, color_hex=APP_ICON_GLOW, alpha=0.28)
    return background


def add_foreground_halo(foreground):
    from PIL import Image, ImageFilter

    alpha = foreground.getchannel("A")
    expanded = alpha.filter(ImageFilter.MaxFilter(21)).filter(ImageFilter.GaussianBlur(radius=12))
    halo = Image.new("RGBA", foreground.size, (255, 255, 255, 0))
    halo.putalpha(expanded.point(lambda value: min(90, round(value * 0.35))))
    return halo


def fit_foreground_to_canvas(foreground, canvas_size: int, occupancy: float):
    from PIL import Image

    bbox = foreground.getbbox()
    if bbox is None:
        raise SystemExit("Foreground image is empty.")
    cropped = foreground.crop(bbox)
    target = max(1, round(canvas_size * occupancy))
    scale = min(target / cropped.width, target / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        resample=Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    halo = add_foreground_halo(resized)
    offset_x = (canvas_size - resized.width) // 2
    offset_y = round(canvas_size * 0.18)
    max_y = canvas_size - resized.height - round(canvas_size * 0.08)
    offset_y = min(offset_y, max_y)
    canvas.alpha_composite(halo, (offset_x, offset_y))
    canvas.alpha_composite(resized, (offset_x, offset_y))
    return canvas


def compose_app_icon(foreground):
    background = make_app_icon_background(APP_ICON_MASTER_SIZE)
    fitted_foreground = fit_foreground_to_canvas(foreground, APP_ICON_MASTER_SIZE, occupancy=0.76)
    background.alpha_composite(fitted_foreground)
    return background.convert("RGB")


def write_app_icon_assets(master_icon, output_root: Path) -> None:
    from PIL import Image

    resources_dir = output_root / "Resources" / "AppIcon"
    resources_dir.mkdir(parents=True, exist_ok=True)
    assets_root = output_root / "Assets.xcassets"
    appiconset_dir = assets_root / "AppIcon.appiconset"
    appiconset_dir.mkdir(parents=True, exist_ok=True)

    (assets_root / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    master_path = resources_dir / "app-icon-master-1024.png"
    master_icon.save(master_path, format="PNG")

    images = []
    for filename, idiom, size, scale, pixel_size in APP_ICON_SPECS:
        resized = master_icon.resize((pixel_size, pixel_size), resample=Image.Resampling.LANCZOS)
        resized.save(appiconset_dir / filename, format="PNG")
        images.append({"filename": filename, "idiom": idiom, "size": size, "scale": scale})

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (appiconset_dir / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def build_app_icon(args: argparse.Namespace) -> None:
    require_pillow()
    from PIL import Image  # type: ignore

    output_root = Path(args.output_root)
    output_root.mkdir(parents=True, exist_ok=True)
    resources_dir = output_root / "Resources" / "AppIcon"
    resources_dir.mkdir(parents=True, exist_ok=True)
    foreground_path = resources_dir / "icon-foreground.png"

    if args.foreground:
        foreground = Image.open(args.foreground).convert("RGBA")
    else:
        if not args.pixellab:
            raise SystemExit("Pass `--pixellab` or provide `--foreground`.")
        foreground = generate_pixellab_image(
            prompt=args.prompt,
            image_size=args.render_size,
            negative_description=APP_ICON_STYLE_PRESET["negative_description"],
            outline=APP_ICON_STYLE_PRESET["outline"],
            shading=APP_ICON_STYLE_PRESET["shading"],
            detail=APP_ICON_STYLE_PRESET["detail"],
            no_background=APP_ICON_STYLE_PRESET["no_background"],
        )

    foreground = remove_border_matte(foreground)
    foreground.save(foreground_path, format="PNG")
    master_icon = compose_app_icon(foreground)
    write_app_icon_assets(master_icon, output_root)


def build_manifest_from_rgba_image(
    *,
    rgba_image,
    level_id: str,
    title: str,
    category: str,
    difficulty: str,
    estimated_minutes: int,
    sort_order: int,
    board_size: int,
    max_colors: int,
    title_key: str | None = None,
    category_key: str | None = None,
    difficulty_key: str | None = None,
) -> dict:
    quantized = rgba_image.quantize(colors=max_colors).convert("RGBA")

    pixels = list(quantized.getdata())
    palette_map: dict[tuple[int, int, int, int], int] = {}
    palette_hex: list[str] = []
    cells: list[int] = []

    for pixel in pixels:
        if pixel[3] == 0:
            cells.append(-1)
            continue

        if pixel not in palette_map:
            palette_map[pixel] = len(palette_map)
            palette_hex.append("#{0:02X}{1:02X}{2:02X}".format(pixel[0], pixel[1], pixel[2]))
        cells.append(palette_map[pixel])

    minimum_palette_size, _ = palette_bounds_for_difficulty(difficulty)
    cleaned_cells, palette_hex = merge_close_palette_colors(
        cells,
        palette_hex,
        minimum_palette_size=minimum_palette_size,
    )
    cleaned_cells = cleanup_quantized_cells(cleaned_cells, board_size, board_size, passes=4)
    cleaned_cells = merge_sparse_colors(cleaned_cells, board_size, board_size, palette_hex)
    cleaned_cells = merge_tiny_components(cleaned_cells, board_size, board_size, passes=3)
    cleaned_cells = cleanup_quantized_cells(cleaned_cells, board_size, board_size, passes=2)
    cleaned_cells = merge_sparse_colors(cleaned_cells, board_size, board_size, palette_hex)
    cleaned_cells = merge_tiny_components(cleaned_cells, board_size, board_size, max_component_size=3, passes=2)
    cleaned_cells, palette_hex = compact_palette_indices(cleaned_cells, palette_hex)
    palette_hex = separate_close_palette_colors(cleaned_cells, palette_hex, minimum_distance=34.0)

    sample = SampleDefinition(
        level_id=level_id,
        title=title,
        category=category,
        difficulty=difficulty,
        estimated_minutes=estimated_minutes,
        prompt="",
        palette=palette_hex,
        build=lambda _: [],
        title_key=title_key,
        category_key=category_key,
        difficulty_key=difficulty_key,
    )
    manifest = build_manifest(
        sample,
        sort_order,
        [cleaned_cells[i:i + board_size] for i in range(0, len(cleaned_cells), board_size)]
    )
    return manifest


def generate_level_manifest_from_pixellab(
    *,
    prompt: str,
    level_id: str,
    title: str,
    category: str,
    difficulty: str,
    estimated_minutes: int,
    sort_order: int,
    board_size: int,
    render_size: int | None,
    max_colors: int,
    style_preset: str,
    title_key: str | None = None,
    category_key: str | None = None,
    difficulty_key: str | None = None,
    validation_profile: str = "default",
    client=None,
    max_attempts: int = 5,
) -> dict:
    require_pillow()
    from PIL import Image  # type: ignore

    preset = STYLE_PRESETS.get(style_preset)
    if preset is None:
        raise SystemExit(f"Unknown style preset: {style_preset}")

    resolved_render_size = max(render_size or board_size, board_size, 32)
    failure_messages: list[str] = []

    for attempt in range(1, max_attempts + 1):
        rgba_image = generate_pixellab_image(
            prompt=prompt,
            image_size=resolved_render_size,
            negative_description=preset["negative_description"],
            outline=preset["outline"],
            shading=preset["shading"],
            detail=preset["detail"],
            no_background=preset["no_background"],
            client=client,
        )
        if resolved_render_size != board_size:
            rgba_image = rgba_image.resize((board_size, board_size), resample=Image.Resampling.BOX)

        manifest = build_manifest_from_rgba_image(
            rgba_image=rgba_image,
            level_id=level_id,
            title=title,
            category=category,
            difficulty=difficulty,
            estimated_minutes=estimated_minutes,
            sort_order=sort_order,
            board_size=board_size,
            max_colors=max_colors,
            title_key=title_key,
            category_key=category_key,
            difficulty_key=difficulty_key,
        )
        issues = validate_manifest(manifest, profile=validation_profile)
        if not issues:
            manifest["prompt"] = append_pixellab_generation_guardrails(prompt)
            return manifest

        failure_messages.append(f"attempt {attempt}: " + "; ".join(issues))
        print(
            f"[pixellab retry] {level_id} attempt {attempt}/{max_attempts} failed validation: "
            + "; ".join(issues),
            file=sys.stderr,
        )

    raise SystemExit(
        "Generated level failed validation after retries:\n"
        + "\n".join(f"- {issue}" for issue in failure_messages)
    )


def build_level_from_pixellab(args: argparse.Namespace) -> None:
    manifest = generate_level_manifest_from_pixellab(
        prompt=args.prompt,
        level_id=args.level_id,
        title=args.title,
        category=args.category,
        difficulty=args.difficulty,
        estimated_minutes=args.estimated_minutes,
        sort_order=args.sort_order,
        board_size=args.board_size,
        render_size=args.render_size,
        max_colors=args.max_colors,
        style_preset=args.style_preset,
        title_key=args.title_key,
        category_key=args.category_key,
        difficulty_key=args.difficulty_key,
        validation_profile="default",
        max_attempts=args.pixellab_attempts,
    )
    write_manifest_and_images(manifest, Path(args.output_folder))


def write_daily_candidate_catalog(output_root: Path, start_sort_order: int) -> None:
    output_root.mkdir(parents=True, exist_ok=True)
    catalog = {
        "title": "PixelLab Daily Candidates",
        "candidateCount": len(DAILY_PIXELLAB_CANDIDATES),
        "levels": [
            {
                "id": definition.level_id,
                "title": definition.title,
                "category": definition.category,
                "difficulty": definition.difficulty,
                "estimatedMinutes": definition.estimated_minutes,
                "sortOrder": start_sort_order + index,
                "boardSize": definition.board_size,
                "renderSize": definition.render_size,
                "maxColors": definition.max_colors,
                "stylePreset": definition.style_preset,
                "prompt": definition.prompt,
                "levelPath": f"Levels/{definition.level_id}.json",
                "thumbnailPath": f"GeneratedThumbnails/{definition.level_id}_thumb.png",
                "solvedPath": f"GeneratedSolved/{definition.level_id}_solved.png",
            }
            for index, definition in enumerate(DAILY_PIXELLAB_CANDIDATES)
        ],
    }
    with (output_root / "daily_candidates_catalog.json").open("w", encoding="utf-8") as handle:
        json.dump(catalog, handle, indent=2)
        handle.write("\n")


def generate_daily_candidates(args: argparse.Namespace) -> None:
    output_root = Path(args.output)
    write_daily_candidate_catalog(output_root, args.start_sort_order)
    levels_dir = output_root / "Levels"

    definitions = DAILY_PIXELLAB_CANDIDATES[args.offset:]
    if args.limit is not None:
        definitions = definitions[:args.limit]

    if not definitions:
        raise SystemExit("No daily candidates selected. Adjust --offset/--limit.")

    client = load_pixellab_client()
    failures: list[str] = []

    for index, definition in enumerate(definitions, start=args.offset):
        sort_order = args.start_sort_order + index
        level_path = levels_dir / f"{definition.level_id}.json"
        if args.skip_existing and level_path.exists():
            print(f"skipped {definition.level_id}", file=sys.stderr)
            continue
        try:
            manifest = generate_level_manifest_from_pixellab(
                prompt=definition.prompt,
                level_id=definition.level_id,
                title=definition.title,
                category=definition.category,
                difficulty=definition.difficulty,
                estimated_minutes=definition.estimated_minutes,
                sort_order=sort_order,
                board_size=definition.board_size,
                render_size=definition.render_size,
                max_colors=definition.max_colors,
                style_preset=definition.style_preset,
                validation_profile="candidate",
                client=client,
                max_attempts=args.pixellab_attempts,
            )
            write_manifest_and_images(manifest, output_root)
            print(f"generated {definition.level_id}", file=sys.stderr)
        except SystemExit as exc:  # pragma: no cover - CLI helper raises SystemExit on validation failures
            failures.append(f"{definition.level_id}: {exc}")
        except Exception as exc:  # pragma: no cover - best effort CLI batch
            failures.append(f"{definition.level_id}: {exc}")

    if failures:
        raise SystemExit("Daily candidate generation finished with failures:\n" + "\n".join(f"- {entry}" for entry in failures))

    print(f"Generated {len(definitions)} daily candidates into {output_root}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="PixelColoringGame content pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """\
            Examples:
              python3 Scripts/pixel_level_pipeline.py generate-sample-pack --output PixelColoringGame/Resources
              python3 Scripts/pixel_level_pipeline.py generate-daily-pack --output PixelColoringGame/Resources
              python3 Scripts/pixel_level_pipeline.py generate-monthly-daily-levels --csv Scripts/monthly_daily_event_catalog.csv --output Generated/MonthlyDailyEvents-2026-04-18
              python3 Scripts/pixel_level_pipeline.py build-level --pixellab --prompt "simple moonflower blossom sticker, centered, five large petals, chunky pixel art, very readable silhouette, indigo and cream, no background, no text, no extra details" --level-id moonflower --title "Moonflower Glow" --category plants --difficulty Medium --estimated-minutes 6 --sort-order 21 --board-size 32 --render-size 128 --max-colors 4 --style-preset simple-sticker --output-folder PixelColoringGame/Resources
              python3 Scripts/pixel_level_pipeline.py build-app-icon --pixellab --output-root PixelColoringGame
            """
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate_parser = subparsers.add_parser("generate-sample-pack", help="Emit the curated MVP sample pack")
    generate_parser.add_argument("--output", required=True, help="Resource output root")

    daily_parser = subparsers.add_parser("generate-daily-pack", help="Emit the daily artwork pack")
    daily_parser.add_argument("--output", required=True, help="Resource output root")

    daily_candidates_parser = subparsers.add_parser("generate-daily-candidates", help="Generate 50 PixelLab daily candidate levels")
    daily_candidates_parser.add_argument("--output", required=True, help="Candidate output root")
    daily_candidates_parser.add_argument("--start-sort-order", type=int, default=2001)
    daily_candidates_parser.add_argument("--offset", type=int, default=0, help="Zero-based candidate offset")
    daily_candidates_parser.add_argument("--limit", type=int, help="Optional candidate count limit")
    daily_candidates_parser.add_argument("--skip-existing", action="store_true", help="Do not regenerate candidates that already exist")
    daily_candidates_parser.add_argument("--pixellab-attempts", type=int, default=5)

    monthly_parser = subparsers.add_parser("generate-monthly-daily-levels", help="Build the month-based daily catalog and its level assets")
    monthly_parser.add_argument("--csv", required=True, help="Monthly catalog CSV")
    monthly_parser.add_argument("--output", required=True, help="Generated staging root")
    monthly_parser.add_argument("--seed-resources-root", default="PixelColoringGame/Resources", help="Existing resources root used for offline seed generation")
    monthly_parser.add_argument("--pixellab", action="store_true", help="Generate assets through the PixelLab SDK instead of offline seeds")
    monthly_parser.add_argument("--months", help="Optional month filter such as '1,2,10-12' for staged generation")
    monthly_parser.add_argument("--render-size", type=int, default=128, help="PixelLab render size when --pixellab is enabled")
    monthly_parser.add_argument("--style-preset", default="simple-sticker")
    monthly_parser.add_argument("--skip-existing", action="store_true", help="Do not regenerate files that already exist in the staging root")
    monthly_parser.add_argument("--max-workers", type=int, default=1, help="Concurrent Pixellab generations. Use small values like 2-4.")
    monthly_parser.add_argument("--pixellab-attempts", type=int, default=5)

    monthly_validate_parser = subparsers.add_parser("validate-monthly-daily-pack", help="Validate the generated month-based daily pack")
    monthly_validate_parser.add_argument("--csv", required=True, help="Monthly catalog CSV")
    monthly_validate_parser.add_argument("--generated-root", required=True, help="Generated staging root to validate")
    monthly_validate_parser.add_argument("--max-palette-delta", type=int, default=2)

    monthly_sync_parser = subparsers.add_parser("sync-monthly-daily-resources", help="Copy a generated month-based daily pack into the app resources")
    monthly_sync_parser.add_argument("--csv", required=True, help="Monthly catalog CSV")
    monthly_sync_parser.add_argument("--source", required=True, help="Generated staging root")
    monthly_sync_parser.add_argument("--destination", required=True, help="App resources root")

    monthly_merge_parser = subparsers.add_parser("merge-monthly-daily-staging", help="Merge multiple monthly staging roots into one full pack")
    monthly_merge_parser.add_argument("--csv", required=True, help="Monthly catalog CSV")
    monthly_merge_parser.add_argument("--output", required=True, help="Merged staging root")
    monthly_merge_parser.add_argument("--sources", nargs="+", required=True, help="Source staging roots to merge")

    monthly_repair_parser = subparsers.add_parser("repair-monthly-daily-palette", help="Repair monthly daily manifests whose palette counts drift too far from CSV")
    monthly_repair_parser.add_argument("--csv", required=True, help="Monthly catalog CSV")
    monthly_repair_parser.add_argument("--generated-root", required=True, help="Generated staging root to repair in place")
    monthly_repair_parser.add_argument("--max-palette-delta", type=int, default=2)

    build_parser = subparsers.add_parser("build-level", help="Build one level via PixelLab")
    build_parser.add_argument("--pixellab", action="store_true", help="Use the PixelLab Python SDK flow")
    build_parser.add_argument("--prompt", required=True)
    build_parser.add_argument("--level-id", required=True)
    build_parser.add_argument("--title", required=True)
    build_parser.add_argument("--category", required=True)
    build_parser.add_argument("--category-key")
    build_parser.add_argument("--difficulty", required=True)
    build_parser.add_argument("--difficulty-key")
    build_parser.add_argument("--estimated-minutes", type=int, required=True)
    build_parser.add_argument("--sort-order", type=int, required=True)
    build_parser.add_argument("--board-size", type=int, default=24)
    build_parser.add_argument("--render-size", type=int)
    build_parser.add_argument("--max-colors", type=int, default=6)
    build_parser.add_argument("--style-preset", default="soft-toy")
    build_parser.add_argument("--pixellab-attempts", type=int, default=5)
    build_parser.add_argument("--title-key")
    build_parser.add_argument("--output-folder", required=True)

    icon_parser = subparsers.add_parser("build-app-icon", help="Build the app icon via PixelLab or a local foreground")
    icon_parser.add_argument("--pixellab", action="store_true", help="Use the PixelLab Python SDK flow")
    icon_parser.add_argument("--foreground", help="Existing transparent PNG to use as the icon foreground")
    icon_parser.add_argument("--prompt", default=APP_ICON_PROMPT)
    icon_parser.add_argument("--render-size", type=int, default=APP_ICON_FOREGROUND_SIZE)
    icon_parser.add_argument("--output-root", required=True, help="App root containing Resources and Assets.xcassets")

    args = parser.parse_args()

    if args.command == "generate-sample-pack":
        generate_sample_pack(Path(args.output))
        return

    if args.command == "generate-daily-pack":
        generate_daily_pack(Path(args.output))
        return

    if args.command == "generate-daily-candidates":
        generate_daily_candidates(args)
        return

    if args.command == "generate-monthly-daily-levels":
        generate_monthly_daily_levels(args)
        return

    if args.command == "validate-monthly-daily-pack":
        validate_monthly_daily_pack(args)
        return

    if args.command == "sync-monthly-daily-resources":
        sync_monthly_daily_resources(args)
        return

    if args.command == "merge-monthly-daily-staging":
        merge_monthly_daily_staging(args)
        return

    if args.command == "repair-monthly-daily-palette":
        repair_monthly_daily_palette(args)
        return

    if args.command == "build-level":
        if not args.pixellab:
            raise SystemExit("`build-level` currently supports the PixelLab SDK flow only. Pass `--pixellab`.")
        build_level_from_pixellab(args)
        return

    if args.command == "build-app-icon":
        build_app_icon(args)
        return

    raise SystemExit(f"Unknown command: {args.command}")


if __name__ == "__main__":
    main()
