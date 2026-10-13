#!/usr/bin/env python3
"""Extract the 13 PPU streams selected by bank 12's $05ED callback."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HEADER_SIZE = 16
BANK_SIZE = 0x4000
POINTER_TABLE = 0x8065
SELECTOR_COUNT = 13
UNIT_GRAPHICS_MAP_BANK = 2
UNIT_TYPE_GRAPHICS_TABLE = 0x983F
UNIT_TYPE_COUNT = 73
UNIT_RECORD_BANK = 8
UNIT_RECORD_BASE_CPU = 0x8B7C
UNIT_RECORD_STRIDE = 13
OAM_SELECTOR_OFFSET = 9


def main() -> None:
    project = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--low-bank", type=int, default=12)
    parser.add_argument("--high-bank", type=int, default=13)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    table_offset = HEADER_SIZE + args.low_bank * BANK_SIZE + POINTER_TABLE - 0x8000
    table = rom[table_offset : table_offset + SELECTOR_COUNT * 2]
    if len(table) != SELECTOR_COUNT * 2:
        raise ValueError("Truncated selector pointer table")

    unit_table_offset = HEADER_SIZE + UNIT_GRAPHICS_MAP_BANK * BANK_SIZE + UNIT_TYPE_GRAPHICS_TABLE - 0x8000
    unit_map = rom[unit_table_offset : unit_table_offset + UNIT_TYPE_COUNT]
    if len(unit_map) != UNIT_TYPE_COUNT:
        raise ValueError("Truncated unit-type graphics lookup")
    unit_ids_by_selector: dict[int, list[int]] = {selector: [] for selector in range(SELECTOR_COUNT)}
    for unit_id, selector in enumerate(unit_map):
        if selector == 0xFF:
            continue
        if selector >= SELECTOR_COUNT:
            raise ValueError(f"Unit ID {unit_id} maps to out-of-range graphics selector {selector}")
        unit_ids_by_selector[selector].append(unit_id)

    unit_record_offset = HEADER_SIZE + UNIT_RECORD_BANK * BANK_SIZE + UNIT_RECORD_BASE_CPU - 0x8000
    unit_record_bytes = rom[unit_record_offset : unit_record_offset + UNIT_TYPE_COUNT * UNIT_RECORD_STRIDE]
    if len(unit_record_bytes) != UNIT_TYPE_COUNT * UNIT_RECORD_STRIDE:
        raise ValueError("Truncated unit definition records")
    oam_selector_by_unit_id = {
        unit_id: unit_record_bytes[unit_id * UNIT_RECORD_STRIDE + OAM_SELECTOR_OFFSET]
        for unit_id in range(UNIT_TYPE_COUNT)
    }

    records = []
    seen: set[int] = set()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for selector in range(SELECTOR_COUNT):
        pointer = int.from_bytes(table[selector * 2 : selector * 2 + 2], "little")
        if pointer not in seen:
            command = [
                sys.executable,
                str(project / "research/tools/extract/extract_ppu_stream.py"),
                str(args.rom),
                str(args.output_dir),
                "--bank", str(args.low_bank),
                "--low-bank", str(args.low_bank),
                "--high-bank", str(args.high_bank),
                "--pointer", hex(pointer),
            ]
            subprocess.run(command, check=True)
            seen.add(pointer)
        stem = f"rom_prg{args.low_bank}_src_{pointer:04x}_ppu_1010"
        metadata = json.loads((args.output_dir / f"{stem}.json").read_text(encoding="utf-8"))
        records.append({
            "selector": selector,
            "unit_ids": unit_ids_by_selector[selector],
            "oam_graphic_selectors": [oam_selector_by_unit_id[unit_id] for unit_id in unit_ids_by_selector[selector]],
            "source_pointer_cpu": f"${pointer:04X}",
            "source_end_cpu_exclusive": metadata["source_end_cpu_exclusive"],
            "ppu_start_address": metadata["ppu_start_address"],
            "payload_bytes": metadata["payload_bytes"],
            "preview_file": f"{stem}_tiles.png",
            "metadata_file": f"{stem}.json",
        })

    manifest = {
        "callback_bank": args.low_bank,
        "callback_entry_cpu": "$804E",
        "callback_index": 1,
        "selector_ram": "$05ED",
        "pointer_table_cpu": f"${POINTER_TABLE:04X}",
        "stream_writer_cpu": "$807F",
        "source_prg_banks_by_cpu_window": {
            "$8000-$BFFF": args.low_bank,
            "$C000-$FFFF": args.high_bank,
        },
        "selector_count": SELECTOR_COUNT,
        "unique_stream_count": len(seen),
        "unit_type_graphics_lookup": {
            "source_prg_bank": UNIT_GRAPHICS_MAP_BANK,
            "source_cpu": f"${UNIT_TYPE_GRAPHICS_TABLE:04X}",
            "entry_count": UNIT_TYPE_COUNT,
            "unmapped_value": "$FF",
            "meaning": "unit type ID to $05ED graphics selector; the decoded stream pixels' rendered role remains under study",
        },
        "unit_ids_by_selector": {str(key): value for key, value in unit_ids_by_selector.items()},
        "unit_oam_graphic_selectors": {str(key): [oam_selector_by_unit_id[unit_id] for unit_id in value] for key, value in unit_ids_by_selector.items()},
        "records": records,
    }
    path = args.output_dir / "rom_bank12_selector_streams.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Extracted {len(seen)} unique PPU streams for {SELECTOR_COUNT} selectors to {args.output_dir}")


if __name__ == "__main__":
    main()
