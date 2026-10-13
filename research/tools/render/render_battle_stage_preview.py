#!/usr/bin/env python3
"""Compose a ROM battle map from decoded tile compositions and CHR uploads."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

from render_sprite_palette_sheet import png_chunk


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("records", type=Path)
    parser.add_argument("chr", type=Path, help="Raw decoded CHR upload beginning at PPU $1000")
    parser.add_argument("output", type=Path)
    parser.add_argument("--overlay-chr", type=Path, action="append", help="ROM CHR stream written over the base; may be repeated")
    parser.add_argument("--overlay-ppu-address", type=lambda value: int(value, 0), action="append", help="PPU address for each --overlay-chr, in matching order")
    parser.add_argument("--rgb-palette", type=Path, help="Optional 192-byte FCEUX RGB palette")
    parser.add_argument("--stage", type=int, default=0)
    args = parser.parse_args()

    data = json.loads(args.records.read_text(encoding="utf-8"))
    record = data["records"][args.stage]
    chr_data = bytearray(args.chr.read_bytes())
    overlays = args.overlay_chr or []
    addresses = args.overlay_ppu_address or []
    if len(overlays) != len(addresses):
        raise ValueError("Pass one --overlay-ppu-address for each --overlay-chr")
    for overlay_path, ppu_address in zip(overlays, addresses):
        overlay = overlay_path.read_bytes()
        overlay_offset = ppu_address - 0x1000
        if overlay_offset < 0:
            raise ValueError("Background overlays must be at or above PPU $1000")
        required_size = overlay_offset + len(overlay)
        if required_size > len(chr_data):
            chr_data.extend(bytes(required_size - len(chr_data)))
        chr_data[overlay_offset:required_size] = overlay
    grid = record.get("map_source_world_16x15_pages", record["map_source_16x15"])
    palette_grid = record.get("palette_index_grid_world_16x15_pages", record["palette_index_grid_16x15"])
    rgb_palette = None
    ppu_palette = None
    if args.rgb_palette:
        rgb_data = args.rgb_palette.read_bytes()
        if len(rgb_data) != 64 * 3:
            raise ValueError("RGB palette must contain 64 RGB triples (192 bytes)")
        rgb_palette = [tuple(rgb_data[i : i + 3]) for i in range(0, len(rgb_data), 3)]
        shared = data["shared_battle_palette_packet"]
        ppu_palette = [0] * 32
        shared_offset = int(shared["ppu_address"][1:], 16) - 0x3F00
        ppu_palette[shared_offset : shared_offset + shared["length"]] = shared["bytes"]
        stage_palette = record["palette_packet"]
        stage_offset = int(stage_palette["ppu_address"][1:], 16) - 0x3F00
        ppu_palette[stage_offset : stage_offset + stage_palette["length"]] = stage_palette["bytes"]
    width, height = len(grid[0]) * 16, len(grid) * 16
    pixels = bytearray(width * height * 4)
    shades = (0, 85, 170, 255)

    for cell_y, row in enumerate(grid):
        for cell_x, code in enumerate(row):
            tiles = record["tile_compositions_2x2"][code]
            for quadrant, tile_id in enumerate(tiles):
                tile_start = tile_id * 16
                tile_data = chr_data[tile_start : tile_start + 16]
                if len(tile_data) != 16:
                    raise ValueError(
                        f"CHR data has no full tile {tile_id} (needs bytes {tile_start}–{tile_start + 15})"
                    )
                tile_x = cell_x * 16 + (quadrant & 1) * 8
                tile_y = cell_y * 16 + (quadrant >> 1) * 8
                for y in range(8):
                    low, high = tile_data[y], tile_data[y + 8]
                    for x in range(8):
                        bit = 7 - x
                        color = (low >> bit & 1) | ((high >> bit & 1) << 1)
                        px, py = tile_x + x, tile_y + y
                        offset = (py * width + px) * 4
                        if rgb_palette is None:
                            shade = shades[color]
                            rgba = (shade, shade, shade, 255)
                        else:
                            subpalette = palette_grid[cell_y][cell_x]
                            palette_index = ppu_palette[0] if color == 0 else ppu_palette[subpalette * 4 + color]
                            rgba = (*rgb_palette[palette_index & 0x3F], 255)
                        pixels[offset : offset + 4] = bytes(rgba)

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
    print(
        f"Composed stage {args.stage} at {width}x{height} from "
        f"{record['map_source_pointer']} and CHR at PPU $1000"
        + (f" with {len(overlays)} CHR overlays" if overlays else "")
    )


if __name__ == "__main__":
    main()
