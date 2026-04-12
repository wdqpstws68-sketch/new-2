#!/usr/bin/env python3
"""
Small content pipeline for the PixelColoringGame MVP.

Supported flows:
- generate a curated 24x24 sample pack without external dependencies
- optionally call the PixelLab Python SDK when it is installed in the environment

The runtime app only needs the emitted JSON manifests and preview PNGs.
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


STYLE_PRESETS = {
    "soft-toy": {
        "negative_description": "muddy colors, noisy dithering, text, watermark, tiny details",
        "outline": "single color outline",
        "shading": "basic shading",
        "detail": "medium detail",
        "no_background": True,
    },
    "bright-sticker": {
        "negative_description": "photorealism, muddy, noisy, blurry, text",
        "outline": "single color outline",
        "shading": "medium shading",
        "detail": "medium detail",
        "no_background": True,
    },
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


def validate_manifest(manifest: dict) -> list[str]:
    issues: list[str] = []

    if len(manifest["cells"]) != manifest["boardWidth"] * manifest["boardHeight"]:
        issues.append("cell count does not match board dimensions")

    palette_total = sum(entry["targetCellCount"] for entry in manifest["palette"])
    if palette_total != manifest["paintableCellCount"]:
        issues.append("paintableCellCount does not match palette totals")

    if len(manifest["palette"]) > 8:
        issues.append("palette exceeds 8 colors")

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


def generate_sample_pack(output_root: Path) -> None:
    failures: list[str] = []

    for sort_order, sample in enumerate(SAMPLES, start=1):
        manifest = build_manifest(sample, sort_order, sample.build(BOARD_SIZE))
        issues = validate_manifest(manifest)
        if issues:
            failures.append(f"{sample.level_id}: {', '.join(issues)}")
            continue
        write_manifest_and_images(manifest, output_root)

    if failures:
        raise SystemExit("Sample pack validation failed:\n" + "\n".join(failures))


def require_optional_dependency(name: str, install_hint: str) -> None:
    raise SystemExit(f"{name} is required for this flow. {install_hint}")


def build_level_from_pixellab(args: argparse.Namespace) -> None:
    try:
        from PIL import Image  # type: ignore
    except ImportError:
        require_optional_dependency("Pillow", "Install with `python3 -m pip install pillow`.")
    try:
        import pixellab  # type: ignore
    except ImportError:
        require_optional_dependency("pixellab", "Install PixelLab's SDK before using `build-level --pixellab`.")

    preset = STYLE_PRESETS.get(args.style_preset)
    if preset is None:
        raise SystemExit(f"Unknown style preset: {args.style_preset}")

    render_size = max(args.board_size, 32)
    client_class = getattr(pixellab, "PixelLabClient", None) or getattr(pixellab, "Client", None)
    if client_class is None:
        raise SystemExit("Unsupported PixelLab SDK: missing client class")

    client = client_class.from_env()
    if hasattr(client, "generate_image_pixflux"):
        response = client.generate_image_pixflux(
            description=args.prompt,
            image_size={"width": render_size, "height": render_size},
            negative_description=preset["negative_description"],
            outline=preset["outline"],
            shading=preset["shading"],
            detail=preset["detail"],
            no_background=preset["no_background"],
        )
    elif hasattr(client, "generateImagePixflux"):
        response = client.generateImagePixflux({
            "description": args.prompt,
            "imageSize": {"width": render_size, "height": render_size},
            "negativeDescription": preset["negative_description"],
            "outline": preset["outline"],
            "shading": preset["shading"],
            "detail": preset["detail"],
            "noBackground": preset["no_background"],
        })
    else:
        raise SystemExit("Unsupported PixelLab SDK: missing generate_image_pixflux API")

    pil_image = response.image.pil_image() if hasattr(response.image, "pil_image") else Image.open(response.image.to_bytes_io())
    rgba_image = pil_image.convert("RGBA")
    if render_size != args.board_size:
        rgba_image = rgba_image.resize((args.board_size, args.board_size), resample=Image.Resampling.BOX)
    quantized = rgba_image.quantize(colors=args.max_colors).convert("RGBA")

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

    sample = SampleDefinition(
        level_id=args.level_id,
        title=args.title,
        category=args.category,
        difficulty=args.difficulty,
        estimated_minutes=args.estimated_minutes,
        prompt=args.prompt,
        palette=palette_hex,
        build=lambda _: [],
        title_key=args.title_key,
        category_key=args.category_key,
        difficulty_key=args.difficulty_key,
    )
    manifest = build_manifest(sample, args.sort_order, [cells[i:i + args.board_size] for i in range(0, len(cells), args.board_size)])
    issues = validate_manifest(manifest)
    if issues:
        raise SystemExit("Generated level failed validation:\n" + "\n".join(f"- {issue}" for issue in issues))

    write_manifest_and_images(manifest, Path(args.output_folder))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="PixelColoringGame content pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            """\
            Examples:
              python3 Scripts/pixel_level_pipeline.py generate-sample-pack --output PixelColoringGame/Resources
              python3 Scripts/pixel_level_pipeline.py build-level --pixellab --prompt "cute snail" --level-id snail-02 --title "Snail 02" --category animals --difficulty Medium --estimated-minutes 5 --sort-order 11 --output-folder PixelColoringGame/Resources
            """
        ),
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate_parser = subparsers.add_parser("generate-sample-pack", help="Emit the curated MVP sample pack")
    generate_parser.add_argument("--output", required=True, help="Resource output root")

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
    build_parser.add_argument("--max-colors", type=int, default=6)
    build_parser.add_argument("--style-preset", default="soft-toy")
    build_parser.add_argument("--title-key")
    build_parser.add_argument("--output-folder", required=True)

    args = parser.parse_args()

    if args.command == "generate-sample-pack":
        generate_sample_pack(Path(args.output))
        return

    if args.command == "build-level":
        if not args.pixellab:
            raise SystemExit("`build-level` currently supports the PixelLab SDK flow only. Pass `--pixellab`.")
        build_level_from_pixellab(args)
        return

    raise SystemExit(f"Unknown command: {args.command}")


if __name__ == "__main__":
    main()
