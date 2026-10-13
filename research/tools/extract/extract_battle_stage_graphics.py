#!/usr/bin/env python3
"""Extract the per-stage CHR stream selected by battle callback bank 4."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from extract_ppu_stream import write_tile_sheet

HEADER_SIZE = 16
BANK_SIZE = 0x4000
STAGE_COUNT = 19
CALLBACK_POINTER_TABLE = 0x804B
SHARED_STREAM_POINTERS = (0x8322, 0x8506, 0x80DE)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--low-bank", type=int, default=4, help="Physical bank mapped at $8000-$BFFF")
    parser.add_argument("--high-bank", type=int, default=5, help="Physical bank mapped at $C000-$FFFF")
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    prg_bank_count = rom[4]
    if not (0 <= args.low_bank < prg_bank_count and 0 <= args.high_bank < prg_bank_count):
        raise ValueError("Callback PRG bank is outside the ROM")

    def read_cpu(pointer: int, count: int) -> bytes:
        result = bytearray()
        while count:
            if 0x8000 <= pointer < 0xC000:
                window_start, window_end, bank = 0x8000, 0xC000, args.low_bank
            elif 0xC000 <= pointer <= 0xFFFF:
                window_start, window_end, bank = 0xC000, 0x10000, args.high_bank
            else:
                raise ValueError(f"CPU pointer ${pointer:04X} left the mapped PRG windows")
            chunk = min(count, window_end - pointer)
            offset = HEADER_SIZE + bank * BANK_SIZE + pointer - window_start
            data = rom[offset : offset + chunk]
            if len(data) != chunk:
                raise ValueError(f"Truncated ROM data at CPU ${pointer:04X}")
            result.extend(data)
            pointer += chunk
            count -= chunk
        return bytes(result)

    def read_stream(pointer: int) -> tuple[int, bytes, list[dict[str, int]], int]:
        header = read_cpu(pointer, 3)
        ppu_address = (header[0] << 8) | header[1]
        segment_count = header[2]
        cursor = pointer + 3
        first_length = read_cpu(cursor, 1)[0]
        cursor += 1
        payload = bytearray()
        segments = []
        for index in range(segment_count):
            # $8094 reads X once. After the first block X is zero, so
            # subsequent blocks copy 256 bytes without another length byte.
            encoded_length = first_length if index == 0 else 0
            length = encoded_length or 256
            source_pointer = cursor
            payload.extend(read_cpu(cursor, length))
            cursor += length
            segments.append(
                {
                    "index": index,
                    "encoded_length": encoded_length,
                    "decoded_length": length,
                    "source_cpu": source_pointer,
                }
            )
        return ppu_address, bytes(payload), segments, cursor

    def write_stream_preview(stem: str, ppu_address: int, payload: bytes) -> dict[str, object]:
        raw_path = args.output_dir / f"{stem}.bin"
        preview_path = args.output_dir / f"{stem}_tiles.png"
        args.output_dir.mkdir(parents=True, exist_ok=True)
        raw_path.write_bytes(payload)
        tile_count, width, height = write_tile_sheet(payload, preview_path)
        return {
            "ppu_start_address": f"${ppu_address:04X}",
            "payload_bytes": len(payload),
            "payload_end_address_exclusive": f"${ppu_address + len(payload):04X}",
            "tile_count_including_partial": tile_count,
            "preview_size": [width, height],
            "raw_file": raw_path.name,
            "preview_file": preview_path.name,
        }

    callback_bank = rom[
        HEADER_SIZE + args.low_bank * BANK_SIZE : HEADER_SIZE + (args.low_bank + 1) * BANK_SIZE
    ]
    shared_streams = []
    for index, source_pointer in enumerate(SHARED_STREAM_POINTERS):
        ppu_address, payload, segments, source_end = read_stream(source_pointer)
        stem = f"rom_battle_shared_chr_{index:02}_ppu_{ppu_address:04x}"
        shared_streams.append(
            {
                "load_order": index,
                "source_pointer_cpu": f"${source_pointer:04X}",
                "source_end_cpu_exclusive": f"${source_end:04X}",
                "segments": [
                    {**segment, "source_cpu": f"${segment['source_cpu']:04X}"}
                    for segment in segments
                ],
                **write_stream_preview(stem, ppu_address, payload),
            }
        )

    records = []
    for stage in range(STAGE_COUNT):
        table_offset = CALLBACK_POINTER_TABLE - 0x8000 + stage * 2
        source_pointer = int.from_bytes(callback_bank[table_offset : table_offset + 2], "little")
        ppu_address, payload, segments, source_end = read_stream(source_pointer)
        stem = f"rom_battle_stage_{stage:02}_chr_ppu_{ppu_address:04x}"
        records.append(
            {
                "stage_index": stage,
                "callback_bank": args.low_bank,
                "callback_entry_cpu": "$8006",
                "pointer_table_cpu": f"${CALLBACK_POINTER_TABLE:04X}",
                "source_pointer_cpu": f"${source_pointer:04X}",
                "source_end_cpu_exclusive": f"${source_end:04X}",
                "source_prg_banks_by_cpu_window": {
                    "$8000-$BFFF": args.low_bank,
                    "$C000-$FFFF": args.high_bank,
                },
                "ppu_start_address": f"${ppu_address:04X}",
                "payload_bytes": len(payload),
                "payload_end_address_exclusive": f"${ppu_address + len(payload):04X}",
                "segments": [
                    {**segment, "source_cpu": f"${segment['source_cpu']:04X}"}
                    for segment in segments
                ],
                **write_stream_preview(stem, ppu_address, payload),
            }
        )

    output_path = args.output_dir / "rom_battle_stage_graphics.json"
    manifest = {
        "source_rom": args.rom.name,
        "stage_count": STAGE_COUNT,
        "callback_selection": {
            "caller_cpu": "$8046",
            "callback_bank": args.low_bank,
            "callback_index": 0,
            "stage_index_source": "$6400",
            "stream_pointer_table_cpu": f"${CALLBACK_POINTER_TABLE:04X}",
            "stream_format": "PPU address high/low, block count, first block length (zero means 256), contiguous payload; remaining blocks are 256 bytes each",
            "shared_stream_load_order": [f"${pointer:04X}" for pointer in SHARED_STREAM_POINTERS],
        },
        "shared_streams": shared_streams,
        "records": records,
    }
    output_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Extracted {len(shared_streams)} shared and {STAGE_COUNT} per-stage PPU streams to {args.output_dir}")


if __name__ == "__main__":
    main()
