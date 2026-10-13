#!/usr/bin/env python3
"""Compose the 56-entry selector-26 OAM layout using its post-wrap CHR bytes."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path


def png_chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("records", type=Path)
    parser.add_argument("stream_json", type=Path)
    parser.add_argument("stream_bin", type=Path)
    parser.add_argument("output_png", type=Path)
    parser.add_argument("output_json", type=Path)
    parser.add_argument("--scale", type=int, default=4)
    args = parser.parse_args()

    records = json.loads(args.records.read_text(encoding="utf-8"))
    alias = next(
        entry
        for entry in records["oam_selector_table_aliases"]["entries"]
        if entry["selector_index"] == 26
    )
    metadata = json.loads(args.stream_json.read_text(encoding="utf-8"))
    payload = args.stream_bin.read_bytes()
    chr_region = next(
        region
        for region in metadata["ppu_memory_regions_after_14bit_wrap"]
        if int(region["ppu_start_address"].removeprefix("$"), 16) == 0
    )
    chr_offset = chr_region["payload_offset"]
    chr_size = chr_region["byte_count"]
    chr_data = payload[chr_offset : chr_offset + chr_size]
    entries = alias["entries"]
    tile_ids = sorted({entry["tile_number"] for entry in entries})
    missing = [tile for tile in tile_ids if (tile + 1) * 16 > len(chr_data)]
    if missing:
        raise ValueError(f"CHR upload does not contain selector-26 tiles: {missing}")

    min_x = min(entry["x_offset"] for entry in entries)
    min_y = min(entry["y_offset"] for entry in entries)
    max_x = max(entry["x_offset"] + 8 for entry in entries)
    max_y = max(entry["y_offset"] + 8 for entry in entries)
    width, height = max_x - min_x, max_y - min_y
    scale = max(1, args.scale)
    pixels = bytearray(width * height * 4)
    shades = (0, 85, 170, 255)

    for entry in entries:
        tile = chr_data[entry["tile_number"] * 16 : (entry["tile_number"] + 1) * 16]
        flip_h = bool(entry["attributes"] & 0x40)
        flip_v = bool(entry["attributes"] & 0x80)
        for y in range(8):
            source_y = 7 - y if flip_v else y
            low, high = tile[source_y], tile[source_y + 8]
            for x in range(8):
                source_x = 7 - x if flip_h else x
                bit = 7 - source_x
                color = ((low >> bit) & 1) | (((high >> bit) & 1) << 1)
                if color == 0:
                    continue
                px = entry["x_offset"] - min_x + x
                py = entry["y_offset"] - min_y + y
                rgba = bytes((shades[color],) * 3 + (255,))
                start = (py * width + px) * 4
                pixels[start : start + 4] = rgba

    scaled_width, scaled_height = width * scale, height * scale
    scaled = bytearray(scaled_width * scaled_height * 4)
    for y in range(height):
        for x in range(width):
            color = pixels[(y * width + x) * 4 : (y * width + x + 1) * 4]
            for dy in range(scale):
                start = ((y * scale + dy) * scaled_width + x * scale) * 4
                scaled[start : start + scale * 4] = color * scale
    scanlines = b"".join(
        b"\x00" + scaled[y * scaled_width * 4 : (y + 1) * scaled_width * 4]
        for y in range(scaled_height)
    )
    image = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", scaled_width, scaled_height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + png_chunk(b"IEND", b"")
    )
    args.output_png.parent.mkdir(parents=True, exist_ok=True)
    args.output_png.write_bytes(image)
    result = {
        "selector_index": 26,
        "oam_template_cpu": alias["template_cpu"],
        "chr_source_pointer_cpu": metadata["source_pointer_cpu"],
        "chr_ppu_start_address": "$0000 after 14-bit PPU wrap",
        "raw_oam_entries": len(entries),
        "unique_tile_ids": tile_ids,
        "tile_count": len(tile_ids),
        "tile_bounds": [min_x, min_y, max_x, max_y],
        "composed_size": [width, height],
        "display_scale": scale,
        "render_mode": "grayscale; color 0 transparent; OAM flip bits applied",
        "limitations": [
            "Palette colors are not reconstructed in this preview.",
            "Sprite priority and runtime position offsets are not represented.",
            "The ROM proves static table pairing, but emulator residency is not captured.",
        ],
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Rendered selector 26: {len(entries)} OAM entries, {len(tile_ids)} tile IDs, {width}x{height} logical pixels")


if __name__ == "__main__":
    main()
