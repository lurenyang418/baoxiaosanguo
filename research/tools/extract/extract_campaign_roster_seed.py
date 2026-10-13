#!/usr/bin/env python3
"""Export the startup campaign roster seed and confirmed movement allowances."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
ROSTER_CPU = 0xC195
ROSTER_COUNT = 20
RECORD_SIZE = 3
UNIT_DATA = Path(__file__).resolve().parents[3] / "data/rom_unit_slot_records.json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--output", type=Path, default=Path("data/rom_campaign_roster_seed.json"))
    parser.add_argument("--unit-data", type=Path, default=UNIT_DATA)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")

    # The table is in the fixed upper PRG window, physical bank 0.
    start = HEADER_SIZE + ROSTER_CPU - 0xC000
    raw = rom[start : start + ROSTER_COUNT * RECORD_SIZE]
    if len(raw) != ROSTER_COUNT * RECORD_SIZE:
        raise ValueError("Campaign roster seed is truncated")

    unit_data = json.loads(args.unit_data.read_text(encoding="utf-8"))
    definitions = {row["unit_id"]: row for row in unit_data["records"]}
    rows = []
    for slot in range(ROSTER_COUNT):
        type_id, value_lo, value_hi = raw[slot * RECORD_SIZE : (slot + 1) * RECORD_SIZE]
        definition = definitions.get(type_id)
        rows.append(
            {
                "roster_index": slot,
                "unit_type_id": type_id,
                "movement_allowance_points": (
                    definition["movement_allowance_points"] if definition else None
                ),
                "unknown_value_16bit": value_lo | (value_hi << 8),
                "experience": value_lo | (value_hi << 8),
                "source_cpu": f"${ROSTER_CPU + slot * RECORD_SIZE:04X}",
            }
        )

    result = {
        "source_prg_bank": 0,
        "source_cpu": f"${ROSTER_CPU:04X}",
        "copied_by": "bank 0 $80C6-$80F4",
        "destination_arrays": {
            "unit_type_id": "$651B",
            "unknown_value_low": "$652F",
            "unknown_value_high": "$6530",
            "experience_low": "$652F",
            "experience_high": "$6530",
        },
        "entry_count": ROSTER_COUNT,
        "interpretation": (
            "Startup campaign roster seed. Movement points are joined from confirmed "
            "13-byte unit definitions. This table does not establish which roster "
            "members appear in any particular battle or their on-map slots."
        ),
        "entries": rows,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
