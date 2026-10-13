#!/usr/bin/env python3
"""Extract the six PPU streams selected by bank 4 callback entry 1."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

# Six little-endian pointers at $8088. Callback code at $8071 indexes this
# table with $05ED and forwards the selected stream to the $8094 writer.
POINTERS = (0xD2C2, 0xDC46, 0xE36A, 0xE9BE, 0xF072, 0xF756)


def main() -> None:
    project = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--low-bank", type=int, default=4)
    parser.add_argument("--high-bank", type=int, default=5)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    records = []
    for selector, pointer in enumerate(POINTERS):
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
        stem = f"rom_prg{args.low_bank}_src_{pointer:04x}_ppu_1010"
        metadata = json.loads((args.output_dir / f"{stem}.json").read_text(encoding="utf-8"))
        records.append({
            "selector": selector,
            "source_pointer_cpu": f"${pointer:04X}",
            "source_end_cpu_exclusive": metadata["source_end_cpu_exclusive"],
            "ppu_start_address": metadata["ppu_start_address"],
            "payload_bytes": metadata["payload_bytes"],
            "preview_file": f"{stem}_ppu_1010_tiles.png",
            "metadata_file": f"{stem}.json",
        })

    manifest = {
        "callback_bank": args.low_bank,
        "callback_entry_cpu": "$8071",
        "callback_index": 1,
        "selector_ram": "$05ED",
        "pointer_table_cpu": "$8088",
        "stream_writer_cpu": "$8094",
        "source_prg_banks_by_cpu_window": {
            "$8000-$BFFF": args.low_bank,
            "$C000-$FFFF": args.high_bank,
        },
        "selector_count": len(POINTERS),
        "selection_meaning": "not yet confirmed",
        "records": records,
    }
    path = args.output_dir / "rom_bank4_callback1_streams.json"
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Extracted {len(records)} callback-1 PPU streams to {args.output_dir}")


if __name__ == "__main__":
    main()
