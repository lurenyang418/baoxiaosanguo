#!/usr/bin/env python3
"""Export battle grids, four-tile composition tables, and palette packets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
BANK_SIZE = 0x4000
RECORD_TABLE = 0x8610
RECORD_COUNT = 19
RECORD_SIZE = 12
MAP_WIDTH = 16
MAP_HEIGHT = 15
MAP_BYTES = MAP_WIDTH * MAP_HEIGHT


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--low-bank", type=int, default=2, help="PRG bank mapped at $8000-$BFFF")
    parser.add_argument("--high-bank", type=int, default=3, help="PRG bank mapped at $C000-$FFFF")
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")

    def read_cpu(pointer: int, count: int) -> bytes:
        result = bytearray()
        while count:
            if 0x8000 <= pointer < 0xC000:
                window_start, window_end, physical_bank = 0x8000, 0xC000, args.low_bank
            elif 0xC000 <= pointer <= 0xFFFF:
                window_start, window_end, physical_bank = 0xC000, 0x10000, args.high_bank
            else:
                break
            chunk = min(count, window_end - pointer)
            start = HEADER_SIZE + physical_bank * BANK_SIZE + pointer - window_start
            result.extend(rom[start : start + chunk])
            pointer += chunk
            count -= chunk
        return bytes(result)

    def rows_for(data: bytes) -> list[list[int]]:
        return [
            list(data[row * MAP_WIDTH : (row + 1) * MAP_WIDTH])
            for row in range(MAP_HEIGHT)
        ]

    bank = rom[HEADER_SIZE + args.low_bank * BANK_SIZE : HEADER_SIZE + (args.low_bank + 1) * BANK_SIZE]
    shared_palette_header = read_cpu(0xB5D5, 2)
    shared_palette_length = shared_palette_header[1] or 256
    shared_palette_payload = read_cpu(0xB5D7, shared_palette_length)
    if len(shared_palette_payload) != shared_palette_length:
        raise ValueError("Shared battle palette packet is truncated")
    shared_palette_packet = {
        "source_cpu": "$B5D5",
        "ppu_address": f"$3F{shared_palette_header[0]:02X}",
        "length": shared_palette_length,
        "bytes": list(shared_palette_payload),
    }
    records = []
    for index in range(RECORD_COUNT):
        address = RECORD_TABLE + index * RECORD_SIZE
        raw = bank[address - 0x8000 : address - 0x8000 + RECORD_SIZE]
        pointers = [raw[i] | (raw[i + 1] << 8) for i in (4, 6, 8, 10)]
        composition_size = pointers[0] - pointers[1]
        composition_bytes = (
            read_cpu(pointers[1], composition_size)
            if composition_size > 0 and composition_size % 4 == 0
            else b""
        )
        # Record byte 3 is the vertical scroll limit (15 or 30 cells).
        # Its source contains two or three vertically stacked 16x15 screens.
        scroll_limit = raw[3]
        screen_count = 1 + (scroll_limit + MAP_WIDTH - 2) // (MAP_WIDTH - 1)
        screen_grids = [read_cpu(pointers[2] + page * MAP_BYTES, MAP_BYTES) for page in range(screen_count)]
        screen_grid = screen_grids[0]
        world_grid = [row for page in screen_grids for row in rows_for(page)]
        palette_lookup_size = pointers[2] - pointers[0]
        palette_lookup = read_cpu(pointers[0], palette_lookup_size)
        palette_header = read_cpu(pointers[3], 2)
        palette_packet = None
        if len(palette_header) == 2:
            palette_length = palette_header[1] or 256
            palette_payload = read_cpu(pointers[3] + 2, palette_length)
            if len(palette_payload) == palette_length:
                palette_packet = {
                    "ppu_address": f"$3F{palette_header[0]:02X}",
                    "length": palette_length,
                    "bytes": list(palette_payload),
                }
        max_map_code = max(screen_grid) if len(screen_grid) == MAP_BYTES else None
        max_world_code = max(max(page) for page in screen_grids)
        if len(composition_bytes) // 4 <= max_world_code:
            raise ValueError(f"Stage {index} world map refers to missing code {max_world_code}")
        if any(len(page) != MAP_BYTES for page in screen_grids):
            raise ValueError(f"Stage {index} has a truncated scrolling map")
        palette_grid = None
        attribute_table = None
        if (
            len(screen_grid) == MAP_BYTES
            and max_map_code is not None
            and len(palette_lookup) > max_map_code
            and all(value <= 3 for value in palette_lookup[: max_map_code + 1])
        ):
            palette_grid = rows_for(bytes(palette_lookup[code] for code in screen_grid))
            # NES attributes select a palette per 2x2 block of 8x8 tiles;
            # each recovered map cell is exactly that 16x16 block.
            packed = [0] * 64
            for cell_y, row in enumerate(palette_grid):
                for cell_x, palette_index in enumerate(row):
                    byte_index = (cell_y // 2) * 8 + cell_x // 2
                    bit_shift = (cell_y % 2) * 4 + (cell_x % 2) * 2
                    packed[byte_index] |= palette_index << bit_shift
            attribute_table = [packed[row * 8 : (row + 1) * 8] for row in range(8)]
        record = {
            "index": index,
            "cpu_address": f"${address:04X}",
            "raw_hex": raw.hex(" "),
            "header_bytes": list(raw[:4]),
            "vertical_scroll_limit_cells": scroll_limit,
            "map_screen_count": screen_count,
            "map_world_dimensions": [MAP_WIDTH, MAP_HEIGHT * screen_count],
            "candidate_source_pointers": [f"${pointer:04X}" for pointer in pointers],
            "record_pointer_roles_for_y3_path": {
                "map_base": f"${pointers[0]:04X}",
                "tile_composition_table": f"${pointers[1]:04X}",
                "display_map_start": f"${pointers[2]:04X}",
                "palette_packet": f"${pointers[3]:04X}",
            },
            "map_base_to_display_offset_bytes": palette_lookup_size,
            "tile_palette_lookup_by_map_code": list(palette_lookup),
            "map_source_pointer": f"${pointers[2]:04X}",
            "map_source_16x15": rows_for(screen_grid) if len(screen_grid) == MAP_BYTES else None,
            "map_source_screens_16x15": [rows_for(page) for page in screen_grids],
            "map_source_world_16x15_pages": world_grid,
            "palette_index_grid_16x15": palette_grid,
            "palette_index_grid_world_16x15_pages": [
                [palette_lookup[code] for code in row] for row in world_grid
            ],
            "nametable_attribute_table_8x8": attribute_table,
            "tile_composition_entry_count": len(composition_bytes) // 4,
            "max_map_code": max_map_code,
            "tile_compositions_2x2": [
                list(composition_bytes[i : i + 4])
                for i in range(0, len(composition_bytes), 4)
            ],
            "palette_packet": palette_packet,
        }
        records.append(record)

    payload = {
        "source_prg_bank": args.low_bank,
        "source_prg_banks_by_cpu_window": {
            "$8000-$BFFF": args.low_bank,
            "$C000-$FFFF": args.high_bank,
        },
        "record_table_cpu": f"${RECORD_TABLE:04X}",
        "record_count": RECORD_COUNT,
        "record_size_bytes": RECORD_SIZE,
        "map_source_dimensions": [MAP_WIDTH, MAP_HEIGHT],
        "scrolling_world_map_note": "Record byte 3 is the vertical scroll limit, 15 or 30; maps contain two or three vertically stacked 16x15 pages",
        "attribute_table_dimensions": [8, 8],
        "shared_battle_palette_packet": shared_palette_packet,
        "combat_y3_path": {
            "condition": "$05CD is neither $00 nor $FF, so the loader starts at record offset 3",
            "map_dimensions": [MAP_WIDTH, MAP_HEIGHT],
            "renderer": "$A15B calls $A06B for 15 rows; each map code indexes four tile bytes and a palette byte, expands to 2x2 background tiles, and packs 2-bit palettes into nametable attributes",
            "composition_table_storage": "offset-6 pointer through offset-4 map pointer (exclusive)",
            "palette_packet_loader": "$A700 reads address-low, length, then payload and stages a PPU $3Fxx update",
        },
        "records": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {RECORD_COUNT} stage records to {args.output}")


if __name__ == "__main__":
    main()
