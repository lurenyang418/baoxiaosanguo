#!/usr/bin/env python3
"""Render the four 4-color palettes staged from each OAM template."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

from render_sprite_palette_sheet import draw_digit, png_chunk


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("records", type=Path)
    parser.add_argument("palette", type=Path, help="FCEUX 64-color .pal file (192 RGB bytes)")
    parser.add_argument("output_png", type=Path)
    parser.add_argument("output_json", type=Path)
    args = parser.parse_args()

    records = json.loads(args.records.read_text(encoding="utf-8"))["records"]
    palette_data = args.palette.read_bytes()
    if len(palette_data) != 64 * 3:
        raise ValueError(f"Expected 192 RGB bytes in {args.palette}, got {len(palette_data)}")

    label_width, swatch_width, header_height, row_height = 24, 14, 16, 16
    width = label_width + 16 * swatch_width
    height = header_height + len(records) * row_height
    pixels = bytearray(width * height * 4)
    output_rows = []

    # Group labels 0-3 correspond to the four NES sprite palettes.
    for palette_index in range(4):
        draw_digit(pixels, width, label_width + palette_index * 4 * swatch_width + 5, 5, str(palette_index))

    for row, record in enumerate(records):
        y = header_height + row * row_height
        draw_digit(pixels, width, 2, y + 5, str(record["index"] // 10))
        draw_digit(pixels, width, 8, y + 5, str(record["index"] % 10))
        colors = record["palette_packet_from_oam_template"]["payload_nes_color_indices"]
        if len(colors) != 16:
            raise ValueError(f"Record {record['index']} has {len(colors)} palette bytes, expected 16")
        output_rows.append({"record": record["index"], "palettes": [colors[i : i + 4] for i in range(0, 16, 4)]})
        for slot, color_index in enumerate(colors):
            if not 0 <= color_index < 64:
                raise ValueError(f"Record {record['index']} has invalid NES color index {color_index}")
            rgb = palette_data[color_index * 3 : color_index * 3 + 3]
            color = bytes((*rgb, 255))
            x0 = label_width + slot * swatch_width
            for dy in range(row_height - 1):
                start = ((y + dy) * width + x0) * 4
                pixels[start : start + swatch_width * 4] = color * swatch_width

        for group in (1, 2, 3):
            x = label_width + group * 4 * swatch_width - 1
            for dy in range(row_height):
                offset = ((y + dy) * width + x) * 4
                pixels[offset : offset + 4] = b"\x50\x50\x50\xff"

    scanlines = b"".join(b"\x00" + pixels[y * width * 4 : (y + 1) * width * 4] for y in range(height))
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
                "source": "First 16 bytes after each OAM template header, queued at PPU $3F10 by bank19 $F307.",
                "source_palette_file": args.palette.name,
                "ppu_start_address": "$3F10",
                "records": output_rows,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Rendered {len(records)} OAM template palette packets to {args.output_png}")


if __name__ == "__main__":
    main()
