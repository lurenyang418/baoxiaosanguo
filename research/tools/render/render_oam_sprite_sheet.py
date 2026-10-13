#!/usr/bin/env python3
"""Compose the bank-18 OAM templates using a candidate extracted CHR stream."""

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
    parser.add_argument("stream_json", type=Path)
    parser.add_argument("stream_bin", type=Path)
    parser.add_argument("palette", type=Path)
    parser.add_argument("output_png", type=Path)
    parser.add_argument("output_json", type=Path)
    parser.add_argument("--pattern-table-base", type=lambda value: int(value, 0), default=0x1000)
    parser.add_argument("--record-index", type=int, help="Render one OAM record instead of the full sheet")
    args = parser.parse_args()

    records = json.loads(args.records.read_text(encoding="utf-8"))["records"]
    if args.record_index is not None:
        records = [record for record in records if record["index"] == args.record_index]
        if not records:
            raise ValueError(f"No OAM record with index {args.record_index}")
    stream_meta = json.loads(args.stream_json.read_text(encoding="utf-8"))
    stream = args.stream_bin.read_bytes()
    palette_data = args.palette.read_bytes()
    if len(palette_data) != 64 * 3:
        raise ValueError(f"Expected 192 RGB bytes in {args.palette}, got {len(palette_data)}")
    ppu_start = int(stream_meta["ppu_start_address"].removeprefix("$"), 16)

    cell_width, cell_height, label_height = 76, 84, 10
    columns = 5
    rows = (len(records) + columns - 1) // columns
    width, height = columns * cell_width, rows * cell_height
    pixels = bytearray(width * height * 4)
    rendered = []

    for record in records:
        idx = record["index"]
        cell_x = (idx % columns) * cell_width
        cell_y = (idx // columns) * cell_height
        draw_digit(pixels, width, cell_x + 2, cell_y + 2, str(idx // 10))
        draw_digit(pixels, width, cell_x + 8, cell_y + 2, str(idx % 10))
        entries = record["sprite_oam_layout"]["entries"]
        missing_tiles = sorted(
            {
                e["tile_number"]
                for e in entries
                if _tile_offset(stream, ppu_start, args.pattern_table_base, e["tile_number"]) is None
            }
        )

        for entry in entries:
            tile_id = entry["tile_number"]
            tile_offset = _tile_offset(stream, ppu_start, args.pattern_table_base, tile_id)
            x0 = cell_x + entry["x_offset"] + 3
            y0 = cell_y + label_height + entry["y_offset"]
            tile = stream[tile_offset : tile_offset + 16] if tile_offset is not None else None
            if tile is None:
                _draw_missing_tile(pixels, width, x0, y0)
                continue

            attributes = entry["attributes"]
            palette_index = attributes & 0x03
            flip_h = bool(attributes & 0x40)
            flip_v = bool(attributes & 0x80)
            colors = record["palette_packet_from_oam_template"]["four_sprite_palettes_nes_color_indices"][palette_index]
            for py in range(8):
                sy = 7 - py if flip_v else py
                plane0, plane1 = tile[sy], tile[sy + 8]
                for px in range(8):
                    sx = 7 - px if flip_h else px
                    bit = 7 - sx
                    color = ((plane0 >> bit) & 1) | (((plane1 >> bit) & 1) << 1)
                    if color == 0:
                        continue
                    color_index = colors[color]
                    rgb = palette_data[color_index * 3 : color_index * 3 + 3]
                    at = ((y0 + py) * width + x0 + px) * 4
                    pixels[at : at + 4] = bytes((*rgb, 255))

        rendered.append(
            {
                "record": idx,
                "missing_tile_ids_in_candidate_stream": missing_tiles,
                "entries": len(entries),
                "palette_source": "palette_packet_from_oam_template",
            }
        )

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
                "candidate_stream": stream_meta,
                "sprite_pattern_table_base_assumption": f"${args.pattern_table_base:04X} (PPUCTRL bit 3 set for 8x8 sprites when $1000)",
                "palette_source": "16-byte palette packet derived from each OAM template",
                "records": rendered,
                "limitations": [
                    "Tiles absent from this candidate stream are shown with a magenta checker.",
                    "The OAM-to-stream residency and PPUCTRL state are candidate interpretations, not emulator-confirmed runtime state.",
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Rendered {len(records)} OAM templates using candidate stream {args.stream_json.name}")


def _tile_offset(stream: bytes, ppu_start: int, table_base: int, tile_id: int) -> int | None:
    ppu_address = (table_base + tile_id * 16) % 0x4000
    offset = ppu_address - ppu_start if ppu_address >= ppu_start else 0x4000 - ppu_start + ppu_address
    return offset if offset + 16 <= len(stream) else None


def _draw_missing_tile(pixels: bytearray, width: int, x0: int, y0: int) -> None:
    for y in range(8):
        for x in range(8):
            color = b"\xff\x00\xff\xff" if (x // 2 + y // 2) % 2 == 0 else b"\x30\x00\x30\xff"
            at = ((y0 + y) * width + x0 + x) * 4
            pixels[at : at + 4] = color


if __name__ == "__main__":
    main()
