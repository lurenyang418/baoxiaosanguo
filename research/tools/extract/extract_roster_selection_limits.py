#!/usr/bin/env python3
"""Export verified roster-selection caps from the stage 10–18 ROM table."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
BANK = 10
POINTER_TABLE = 0x8D3E


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--output", type=Path, default=Path("data/rom_roster_selection_limits.json"))
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    bank_start = HEADER_SIZE + BANK * PRG_BANK_SIZE
    bank = rom[bank_start : bank_start + PRG_BANK_SIZE]

    def read_byte(address: int) -> int:
        offset = address - 0x8000
        if offset < 0 or offset >= len(bank):
            raise ValueError(f"Address ${address:04X} is outside PRG bank window")
        return bank[offset]

    records = []
    for stage in range(10, 19):
        offset = POINTER_TABLE - 0x8000 + (stage - 10) * 2
        pointer = bank[offset] | bank[offset + 1] << 8
        if not 0x8000 <= pointer < 0xC000:
            raise ValueError(f"Stage {stage} has invalid cap-record pointer ${pointer:04X}")
        records.append({
            "stage_index": stage,
            "max_selected_units": read_byte(pointer + 1),
            "source_pointer": f"${pointer:04X}",
            "cap_source_address": f"${pointer + 1:04X}",
        })

    result = {
        "source_prg_bank": BANK,
        "stage_range": [10, 18],
        "cap_ram_address": "$05EF",
        "current_count_ram_address": "$6813",
        "add_routine": "$8BA0-$8BCF",
        "records": records,
        "limitations": "This table establishes caps only for stages 10-18. The selection-cap path for stages 0-9 is not established by this table.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
