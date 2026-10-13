#!/usr/bin/env python3
"""Extract the title/boot screen data from the local Bao Xiao San Guo ROM.

The output is a research aid. It does not copy the ROM into this project.
Pass a 192-byte FCEUX .pal file to render the screen in color.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path

HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
BOOT_BANK = 60
NAMETABLE_STREAM_CPU = 0x8165
CHR_START_CPU = 0x82BC
CHR_SIZE = 0x1000


def png_chunk(kind: bytes, data: bytes) -> bytes:
    payload = kind + data
    return struct.pack("!I", len(data)) + payload + struct.pack("!I", zlib.crc32(payload) & 0xFFFFFFFF)


def write_rgb_png(path: Path, width: int, height: int, rgb: bytes) -> None:
    rows = b"".join(b"\0" + rgb[y * width * 3 : (y + 1) * width * 3] for y in range(height))
    png = b"\x89PNG\r\n\x1a\n"
    png += png_chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0))
    png += png_chunk(b"IDAT", zlib.compress(rows, 9))
    png += png_chunk(b"IEND", b"")
    path.write_bytes(png)


def bank_offset(cpu_address: int) -> int:
    if not 0x8000 <= cpu_address < 0xC000:
        raise ValueError(f"CPU address ${cpu_address:04X} is outside bank 60's $8000-$BFFF window")
    return HEADER_SIZE + BOOT_BANK * PRG_BANK_SIZE + cpu_address - 0x8000


def decode_nametable(rom: bytes, stream_cpu: int) -> tuple[list[int], int]:
    pos = bank_offset(stream_cpu)
    output: list[int] = []
    while True:
        token = rom[pos]
        pos += 1
        if token == 0xFF:
            break
        if token == 0xFE:
            count = rom[pos]
            value = rom[pos + 1]
            pos += 2
            output.extend([value] * (count or 256))
        else:
            output.append(token)
        if len(output) > 960:
            raise ValueError("Title nametable RLE exceeds the NES 32x30 tile area")
    if len(output) != 960:
        raise ValueError(f"Expected 960 nametable bytes, decoded {len(output)}")
    return output, pos


def load_palette(path: Path) -> list[tuple[int, int, int]]:
    data = path.read_bytes()
    if len(data) != 64 * 3:
        raise ValueError(f"Expected 192-byte FCEUX .pal file, got {len(data)} bytes")
    return [tuple(data[i : i + 3]) for i in range(0, len(data), 3)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="Path to the local iNES ROM")
    parser.add_argument("out_dir", type=Path, help="Directory for extracted PNG and JSON research files")
    parser.add_argument("--palette", type=Path, required=True, help="FCEUX 192-byte .pal RGB palette")
    args = parser.parse_args()

    image = args.rom.read_bytes()
    if image[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    prg_size = image[4] * 0x4000
    prg = image[HEADER_SIZE : HEADER_SIZE + prg_size]
    if len(prg) != prg_size or len(prg) < (BOOT_BANK + 1) * PRG_BANK_SIZE:
        raise ValueError("ROM does not contain the expected 1 MiB program data")

    nametable, after_terminator_file_offset = decode_nametable(image, NAMETABLE_STREAM_CPU)
    attrs_start = after_terminator_file_offset
    attributes = list(image[attrs_start : attrs_start + 64])
    palette_bytes = list(image[attrs_start + 64 : attrs_start + 80])
    if len(attributes) != 64 or len(palette_bytes) != 16:
        raise ValueError("Title attributes or palette are truncated")

    chr_offset = bank_offset(CHR_START_CPU)
    chr_data = image[chr_offset : chr_offset + CHR_SIZE]
    if len(chr_data) != CHR_SIZE:
        raise ValueError("Title CHR data is truncated")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "boot_screen.json").write_text(
        json.dumps(
            {
                "rom_sha256": hashlib.sha256(image).hexdigest(),
                "source_prg_bank": BOOT_BANK,
                "nametable_source_cpu": f"${NAMETABLE_STREAM_CPU:04X}",
                "nametable_rle_next_cpu": f"${0x8000 + after_terminator_file_offset - bank_offset(0x8000):04X}",
                "chr_source_cpu": f"${CHR_START_CPU:04X}",
                "nametable_32x30": [nametable[y * 32 : (y + 1) * 32] for y in range(30)],
                "attributes_8x8": [attributes[y * 8 : (y + 1) * 8] for y in range(8)],
                "palette_indices": palette_bytes,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    nes_palette = load_palette(args.palette)
    tiles = [chr_data[i : i + 16] for i in range(0, len(chr_data), 16)]

    # A 16x16 tile sheet, useful for inspecting the extracted 8x8 patterns.
    atlas = bytearray(128 * 128 * 3)
    for tile_index, tile in enumerate(tiles):
        for py in range(8):
            plane0, plane1 = tile[py], tile[py + 8]
            for px in range(8):
                bit = 7 - px
                color = ((plane0 >> bit) & 1) | (((plane1 >> bit) & 1) << 1)
                value = color * 85
                at = (((tile_index // 16) * 8 + py) * 128 + (tile_index % 16) * 8 + px) * 3
                atlas[at : at + 3] = bytes((value, value, value))
    write_rgb_png(args.out_dir / "boot_chr_atlas.png", 128, 128, atlas)

    screen = bytearray(256 * 240 * 3)
    for ty in range(30):
        for tx in range(32):
            tile_index = nametable[ty * 32 + tx]
            attr = attributes[(ty // 4) * 8 + tx // 4]
            quadrant = ((ty // 2) % 2) * 2 + ((tx // 2) % 2)
            subpalette = (attr >> (quadrant * 2)) & 3
            tile = tiles[tile_index]
            for py in range(8):
                plane0, plane1 = tile[py], tile[py + 8]
                for px in range(8):
                    bit = 7 - px
                    color = ((plane0 >> bit) & 1) | (((plane1 >> bit) & 1) << 1)
                    palette_index = palette_bytes[0] if color == 0 else palette_bytes[subpalette * 4 + color]
                    rgb = nes_palette[palette_index & 0x3F]
                    at = ((ty * 8 + py) * 256 + tx * 8 + px) * 3
                    screen[at : at + 3] = bytes(rgb)
    write_rgb_png(args.out_dir / "boot_screen.png", 256, 240, screen)

    print(f"Decoded {len(nametable)} nametable tiles, 64 attributes, 16 palette entries, and {len(chr_data)} CHR bytes.")
    print(f"Wrote research artifacts to {args.out_dir}")


if __name__ == "__main__":
    main()
