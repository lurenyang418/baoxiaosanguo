#!/usr/bin/env python3
"""Render the extracted per-record NES sprite palettes as a labeled swatch sheet."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

GLYPHS = {
    "0": (0b111, 0b101, 0b101, 0b101, 0b111),
    "1": (0b010, 0b110, 0b010, 0b010, 0b111),
    "2": (0b111, 0b001, 0b111, 0b100, 0b111),
    "3": (0b111, 0b001, 0b111, 0b001, 0b111),
    "4": (0b101, 0b101, 0b111, 0b001, 0b001),
    "5": (0b111, 0b100, 0b111, 0b001, 0b111),
    "6": (0b111, 0b100, 0b111, 0b101, 0b111),
    "7": (0b111, 0b001, 0b010, 0b010, 0b010),
    "8": (0b111, 0b101, 0b111, 0b101, 0b111),
    "9": (0b111, 0b101, 0b111, 0b001, 0b111),
}


def png_chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def draw_digit(pixels: bytearray, width: int, x: int, y: int, digit: str) -> None:
    for row, bits in enumerate(GLYPHS[digit]):
        for col in range(3):
            if bits & (1 << (2 - col)):
                offset = ((y + row) * width + x + col) * 4
                pixels[offset : offset + 4] = b"\xff\xff\xff\xff"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("records", type=Path, help="rom_bank18_records.json")
    parser.add_argument("palette", type=Path, help="FCEUX 64-color .pal file (192 RGB bytes)")
    parser.add_argument("output_png", type=Path)
    parser.add_argument("output_json", type=Path)
    args = parser.parse_args()

    records = json.loads(args.records.read_text(encoding="utf-8"))["records"]
    palette_data = args.palette.read_bytes()
    if len(palette_data) != 64 * 3:
        raise ValueError(f"Expected 192 RGB bytes in {args.palette}, got {len(palette_data)}")

    label_width, swatch_width, row_height, header_height = 24, 24, 16, 16
    width = label_width + 8 * swatch_width
    height = header_height + len(records) * row_height
    pixels = bytearray(width * height * 4)
    color_index_data = []

    # Palette index labels 0–3 above each four-color NES sprite palette.
    for slot in range(8):
        x = label_width + slot * swatch_width + 10
        draw_digit(pixels, width, x, 5, str(slot % 4))

    for row, record in enumerate(records):
        y = header_height + row * row_height
        index = record["index"]
        draw_digit(pixels, width, 2, y + 5, str(index // 10))
        draw_digit(pixels, width, 8, y + 5, str(index % 10))
        palettes = record["sprite_palettes"]
        indices = palettes["palette_0_nes_color_indices"] + palettes["palette_1_nes_color_indices"]
        color_index_data.append({"record": index, "palette0": indices[:4], "palette1": indices[4:]})
        for slot, color_index in enumerate(indices):
            if not 0 <= color_index < 64:
                raise ValueError(f"Record {index} has invalid NES color index {color_index}")
            rgb = palette_data[color_index * 3 : color_index * 3 + 3]
            color = bytes((*rgb, 255))
            x0 = label_width + slot * swatch_width
            for dy in range(row_height - 1):
                start = ((y + dy) * width + x0) * 4
                pixels[start : start + swatch_width * 4] = color * swatch_width

        # A dark separator distinguishes palette 0 from palette 1.
        x_sep = label_width + 4 * swatch_width - 1
        for dy in range(row_height):
            offset = ((y + dy) * width + x_sep) * 4
            pixels[offset : offset + 4] = b"\x50\x50\x50\xff"

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
    args.output_png.parent.mkdir(parents=True, exist_ok=True)
    args.output_png.write_bytes(image)
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(
        json.dumps(
            {
                "source_palette_file": args.palette.name,
                "ppu_start_address": "$3F10",
                "nes_palette_entries_per_sprite_palette": 4,
                "records": color_index_data,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Rendered {len(records)} record palette pairs to {args.output_png}")


if __name__ == "__main__":
    main()
