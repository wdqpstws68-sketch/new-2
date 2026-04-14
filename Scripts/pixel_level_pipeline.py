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
import json
import math
import os
import struct
import sys
import textwrap
import zlib
from collections import Counter, deque
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


def palette_distance_issues(manifest: dict, minimum_distance: float = 38.0) -> list[str]:
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

    if len(manifest["palette"]) > 8:
        issues.append("palette exceeds 8 colors")

    if profile == "candidate":
        return issues

    issues.extend(palette_distance_issues(manifest))
    issues.extend(structural_issues(manifest))
    return issues


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
):
    from PIL import Image  # type: ignore

    client = client or load_pixellab_client()
    guarded_prompt = append_pixellab_generation_guardrails(prompt)
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

    cleaned_cells = cleanup_quantized_cells(cells, board_size, board_size)
    cleaned_cells = merge_sparse_colors(cleaned_cells, board_size, board_size, palette_hex)

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
) -> dict:
    require_pillow()
    from PIL import Image  # type: ignore

    preset = STYLE_PRESETS.get(style_preset)
    if preset is None:
        raise SystemExit(f"Unknown style preset: {style_preset}")

    resolved_render_size = max(render_size or board_size, board_size, 32)
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
    if issues:
        raise SystemExit("Generated level failed validation:\n" + "\n".join(f"- {issue}" for issue in issues))
    manifest["prompt"] = append_pixellab_generation_guardrails(prompt)
    return manifest


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
