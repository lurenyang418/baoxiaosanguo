#!/usr/bin/env python3
"""Render raw 16x15 ROM map codes as a labeled debug atlas, not game art."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

from render_sprite_palette_sheet import png_chunk


GLYPHS = {
    "0": (7, 5, 5, 5, 7), "1": (2, 6, 2, 2, 7), "2": (7, 1, 7, 4, 7),
    "3": (7, 1, 7, 1, 7), "4": (5, 5, 7, 1, 1), "5": (7, 4, 7, 1, 7),
    "6": (7, 4, 7, 5, 7), "7": (7, 1, 2, 2, 2), "8": (7, 5, 7, 5, 7),
    "9": (7, 5, 7, 1, 7), "A": (2, 5, 7, 5, 5), "B": (6, 5, 6, 5, 6),
    "C": (3, 4, 4, 4, 3), "D": (6, 5, 5, 5, 6), "E": (7, 4, 6, 4, 7),
    "F": (7, 4, 6, 4, 4),
}


def code_color(code: int) -> tuple[int, int, int]:
    if code == 0:
        return 35, 39, 47
    hue = (code * 137.508) % 360.0
    chroma, low = 125, 74
    sector = hue / 60.0
    x = round(chroma * (1 - abs(sector % 2 - 1)))
    if sector < 1:
        rgb = chroma, x, 0
    elif sector < 2:
        rgb = x, chroma, 0
    elif sector < 3:
        rgb = 0, chroma, x
    elif sector < 4:
        rgb = 0, x, chroma
    elif sector < 5:
        rgb = x, 0, chroma
    else:
        rgb = chroma, 0, x
    return tuple(channel + low for channel in rgb)


def set_pixel(pixels: bytearray, width: int, x: int, y: int, color: tuple[int, int, int]) -> None:
    offset = (y * width + x) * 4
    pixels[offset : offset + 4] = bytes((*color, 255))


def draw_hex(pixels: bytearray, width: int, x: int, y: int, value: int, color: tuple[int, int, int]) -> None:
    draw_text(pixels, width, x, y, f"{value:02X}", color)


def draw_text(pixels: bytearray, width: int, x: int, y: int, text: str, color: tuple[int, int, int]) -> None:
    for digit_index, digit in enumerate(text):
        for row, bits in enumerate(GLYPHS[digit]):
            for col in range(3):
                if bits & (1 << (2 - col)):
                    set_pixel(pixels, width, x + digit_index * 4 + col, y + row, color)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("records", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--columns", type=int, default=4)
    args = parser.parse_args()
    records = json.loads(args.records.read_text(encoding="utf-8"))["records"]

    cell, label, gap, columns = 12, 14, 8, args.columns
    panel_width = cell * 16
    panel_height = label + cell * 15
    rows = (len(records) + columns - 1) // columns
    width = columns * panel_width + (columns + 1) * gap
    height = rows * panel_height + (rows + 1) * gap
    pixels = bytearray(width * height * 4)

    for index, record in enumerate(records):
        grid = record["map_source_16x15"]
        x0 = gap + (index % columns) * (panel_width + gap)
        y0 = gap + (index // columns) * (panel_height + gap)
        draw_text(pixels, width, x0, y0 + 3, str(record["index"]), (240, 240, 240))
        for y, row in enumerate(grid):
            for x, code in enumerate(row):
                color = code_color(code)
                px, py = x0 + x * cell, y0 + label + y * cell
                for dy in range(cell - 1):
                    for dx in range(cell - 1):
                        set_pixel(pixels, width, px + dx, py + dy, color)
                # The two-digit hexadecimal value keeps this useful as a code map.
                text_color = (250, 250, 250) if sum(color) < 390 else (24, 24, 24)
                draw_hex(pixels, width, px + 1, py + 3, code, text_color)

    scanlines = b"".join(
        b"\x00" + pixels[y * width * 4 : (y + 1) * width * 4]
        for y in range(height)
    )
    image = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + png_chunk(b"IEND", b"")
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(image)
    print(f"Rendered {len(records)} raw map-code grids to {args.output} ({width}x{height})")


if __name__ == "__main__":
    main()
