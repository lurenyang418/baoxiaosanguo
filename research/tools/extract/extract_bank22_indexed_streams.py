#!/usr/bin/env python3
"""Extract the 25 PPU streams selected by bank 22's indexed callback table."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

HEADER_SIZE = 16
BANK_SIZE = 0x4000
TABLE_BANK = 22
TABLE_CPU = 0x8028
STREAM_COUNT = 25


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a" or rom[4] <= TABLE_BANK + 1:
        raise ValueError("Expected the 64-bank Bao Xiao San Guo iNES ROM")
    table_offset = HEADER_SIZE + TABLE_BANK * BANK_SIZE + TABLE_CPU - 0x8000
    table = rom[table_offset : table_offset + STREAM_COUNT * 2]
    if len(table) != STREAM_COUNT * 2:
        raise ValueError("Indexed PPU stream pointer table is truncated")

    tool = Path(__file__).with_name("extract_ppu_stream.py")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    entries = []
    for index in range(STREAM_COUNT):
        pointer = int.from_bytes(table[index * 2 : index * 2 + 2], "little")
        if not 0x8000 <= pointer <= 0xFFFF:
            raise ValueError(f"Stream pointer {index} is outside mapped PRG windows: ${pointer:04X}")
        start_bank = TABLE_BANK if pointer < 0xC000 else TABLE_BANK + 1
        command = [
            sys.executable,
            str(tool),
            str(args.rom),
            str(args.output_dir),
            "--bank",
            str(start_bank),
            "--low-bank",
            str(TABLE_BANK),
            "--high-bank",
            str(TABLE_BANK + 1),
            "--pointer",
            hex(pointer),
        ]
        subprocess.run(command, check=True)
        stem = f"rom_prg{start_bank}_src_{pointer:04x}_ppu_0800"
        metadata = json.loads((args.output_dir / f"{stem}.json").read_text(encoding="utf-8"))
        entries.append(
            {
                "record_index": index,
                "pointer_table_cpu": f"${TABLE_CPU + index * 2:04X}",
                "source_pointer_cpu": f"${pointer:04X}",
                "starting_prg_bank": start_bank,
                "source_end_cpu_exclusive": metadata["source_end_cpu_exclusive"],
                "payload_bytes": metadata["payload_bytes"],
                "ppu_start_address": metadata["ppu_start_address"],
                "stream_count": metadata["segment_count"],
                "files": metadata["outputs"],
                "metadata_file": f"{stem}.json",
            }
        )

    manifest = {
        "source_prg_bank": TABLE_BANK,
        "pointer_table_cpu": f"${TABLE_CPU:04X}",
        "record_count": STREAM_COUNT,
        "callback_path": "NMI at bank 60 $E8E0 requests bank $16 callback index 0; bank 22 $8003 indexes this table and invokes $805A.",
        "cpu_window_mapping_assumption": {"$8000-$BFFF": TABLE_BANK, "$C000-$FFFF": TABLE_BANK + 1},
        "records": entries,
        "limitations": [
            "The Mapper 15 hack's exact upper-window mapping still needs emulator debugger confirmation.",
            "All streams target PPU $0800; this is not a direct mapping to the low OAM tile IDs.",
        ],
    }
    output = args.output_dir / "rom_bank22_indexed_ppu_streams.json"
    output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} indexed PPU streams to {args.output_dir}")


if __name__ == "__main__":
    main()
