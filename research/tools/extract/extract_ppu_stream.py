#!/usr/bin/env python3
"""Extract one contiguous block-counted PPU upload and preview its 2bpp tiles."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

HEADER_SIZE = 16
BANK_SIZE = 0x4000


def png_chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def write_tile_sheet(data: bytes, path: Path, columns: int = 16, scale: int = 4) -> tuple[int, int, int]:
    tile_count = (len(data) + 15) // 16
    rows = (tile_count + columns - 1) // columns
    tile_width, tile_height = columns * 8, rows * 8
    width, height = tile_width * scale, tile_height * scale
    pixels = bytearray(tile_width * tile_height * 4)
    shades = (0, 85, 170, 255)

    for tile in range(tile_count):
        tile_data = data[tile * 16 : (tile + 1) * 16]
        tile_x, tile_y = (tile % columns) * 8, (tile // columns) * 8
        for y in range(8):
            low = tile_data[y] if y < len(tile_data) else 0
            high = tile_data[y + 8] if y + 8 < len(tile_data) else 0
            for x in range(8):
                bit = 7 - x
                color = ((low >> bit) & 1) | (((high >> bit) & 1) << 1)
                shade = shades[color]
                offset = ((tile_y + y) * tile_width + tile_x + x) * 4
                pixels[offset : offset + 4] = bytes((shade, shade, shade, 255))

    scaled = bytearray(width * height * 4)
    for y in range(tile_height):
        row = pixels[y * tile_width * 4 : (y + 1) * tile_width * 4]
        expanded = b"".join(row[x : x + 4] * scale for x in range(0, len(row), 4))
        for dy in range(scale):
            start = ((y * scale + dy) * width) * 4
            scaled[start : start + width * 4] = expanded
    scanlines = b"".join(b"\x00" + scaled[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    image = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + png_chunk(b"IEND", b"")
    )
    path.write_bytes(image)
    return tile_count, width, height


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--bank", type=int, default=10, help="Physical 16 KiB PRG bank containing the stream")
    parser.add_argument("--low-bank", type=int, help="Physical PRG bank mapped at $8000-$BFFF when the stream crosses windows")
    parser.add_argument("--high-bank", type=int, help="Physical PRG bank mapped at $C000-$FFFF when the stream crosses windows")
    parser.add_argument("--pointer", type=lambda value: int(value, 0), default=0x99A6, help="CPU pointer to the PPU stream")
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    prg_banks = rom[4] * BANK_SIZE
    if args.bank < 0 or args.bank * BANK_SIZE >= prg_banks:
        raise ValueError(f"PRG bank {args.bank} is outside the ROM")
    if 0x8000 <= args.pointer < 0xC000:
        low_bank = args.bank if args.low_bank is None else args.low_bank
        high_bank = args.bank + 1 if args.high_bank is None else args.high_bank
    elif 0xC000 <= args.pointer <= 0xFFFF:
        high_bank = args.bank if args.high_bank is None else args.high_bank
        low_bank = args.bank - 1 if args.low_bank is None else args.low_bank
    else:
        raise ValueError("Stream pointer must be in the $8000-$FFFF PRG windows")
    if not 0 <= low_bank < rom[4]:
        raise ValueError(f"Low-window PRG bank {low_bank} is outside the ROM")
    if not 0 <= high_bank < rom[4]:
        raise ValueError(f"High-window PRG bank {high_bank} is outside the ROM")
    cpu_cursor = args.pointer

    def take(count: int) -> bytes:
        nonlocal cpu_cursor
        value = bytearray()
        remaining = count
        while remaining:
            if 0x8000 <= cpu_cursor < 0xC000:
                window_start, window_end, physical_bank = 0x8000, 0xC000, low_bank
            elif 0xC000 <= cpu_cursor <= 0xFFFF:
                window_start, window_end, physical_bank = 0xC000, 0x10000, high_bank
            else:
                raise ValueError(f"CPU address ${cpu_cursor:04X} is outside mapped PRG windows")
            chunk_size = min(remaining, window_end - cpu_cursor)
            file_start = HEADER_SIZE + physical_bank * BANK_SIZE + cpu_cursor - window_start
            value.extend(rom[file_start : file_start + chunk_size])
            if len(value) < count - remaining + chunk_size:
                raise ValueError(f"Truncated stream at CPU ${cpu_cursor:04X}")
            cpu_cursor += chunk_size
            remaining -= chunk_size
        return bytes(value)

    address_hi, address_lo, segment_count = take(3)
    ppu_address = (address_hi << 8) | address_lo
    payload = bytearray()
    segments = []
    first_length = take(1)[0]
    for index in range(segment_count):
        length_byte = first_length if index == 0 else 0
        length = length_byte or 256
        data_start_cpu = cpu_cursor
        data = take(length)
        segments.append(
            {
                "index": index,
                "encoded_length": length_byte,
                "decoded_length": length,
                "source_cpu": f"${data_start_cpu:04X}",
            }
        )
        payload.extend(data)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    stem = f"rom_prg{args.bank}_src_{args.pointer:04x}_ppu_{ppu_address:04x}"
    raw_path = args.output_dir / f"{stem}.bin"
    image_path = args.output_dir / f"{stem}_tiles.png"
    json_path = args.output_dir / f"{stem}.json"
    raw_path.write_bytes(payload)
    wraps_ppu_address_space = (ppu_address & 0x3FFF) + len(payload) > 0x4000
    if wraps_ppu_address_space:
        tile_count = (len(payload) + 15) // 16
        width = height = None
    else:
        tile_count, width, height = write_tile_sheet(payload, image_path)
    ppu_regions = []
    chr_region_previews = []
    data_offset = 0
    ppu_cursor = ppu_address & 0x3FFF
    while data_offset < len(payload):
        chunk_size = min(len(payload) - data_offset, 0x4000 - ppu_cursor)
        region = {
            "ppu_start_address": f"${ppu_cursor:04X}",
            "payload_offset": data_offset,
            "byte_count": chunk_size,
        }
        ppu_regions.append(region)
        if ppu_cursor < 0x2000:
            chr_payload = payload[data_offset : data_offset + chunk_size]
            chr_image_path = args.output_dir / f"{stem}_ppu_{ppu_cursor:04x}_tiles.png"
            chr_tile_count, chr_width, chr_height = write_tile_sheet(chr_payload, chr_image_path)
            chr_region_previews.append(
                {
                    **region,
                    "image_file": chr_image_path.name,
                    "tile_count_including_partial": chr_tile_count,
                    "preview_size": [chr_width, chr_height],
                }
            )
        data_offset += chunk_size
        ppu_cursor = 0
    metadata = {
        "source_prg_bank": args.bank,
        "source_pointer_cpu": f"${args.pointer:04X}",
        "source_end_cpu_exclusive": f"${cpu_cursor:04X}",
        "source_prg_bank_by_cpu_window": {"$8000-$BFFF": low_bank, "$C000-$FFFF": high_bank},
        "ppu_start_address": f"${ppu_address:04X}",
        "segment_count": segment_count,
        "segment_length_zero_means": 256,
        "payload_bytes": len(payload),
        "payload_end_address_exclusive": f"${ppu_address + len(payload):04X}",
        "ppu_address_space_bytes": 0x4000,
        "ppu_memory_regions_after_14bit_wrap": ppu_regions,
        "decoded_as": (
            "linear payload bytes; full-payload tile preview omitted because the PPU address wraps"
            if wraps_ppu_address_space
            else "NES 2bpp 8x8 tiles, grayscale preview; last tile may be partial"
        ),
        "tile_count_including_partial": tile_count,
        "preview_size": [width, height],
        "segments": segments,
        "chr_region_previews": chr_region_previews,
        "outputs": [raw_path.name]
        + ([] if wraps_ppu_address_space else [image_path.name])
        + [entry["image_file"] for entry in chr_region_previews],
    }
    json_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    preview_note = "CHR-region previews" if wraps_ppu_address_space else f"{tile_count} tile slots"
    print(f"Extracted {len(payload)} bytes at PPU ${ppu_address:04X}; wrote {preview_note} to {args.output_dir}")


if __name__ == "__main__":
    main()
