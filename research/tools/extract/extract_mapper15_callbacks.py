#!/usr/bin/env python3
"""Extract the banked callback dispatch table used by the target ROM."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
BANK_SIZE = 0x4000
DISPATCH_BANK = 19
DISPATCH_TABLE_CPU = 0xFFAF
DISPATCH_COUNT = 9
CALLBACK_BANK = 10


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    prg_banks = rom[4] * BANK_SIZE
    if rom[:4] != b"NES\x1a" or len(rom) < HEADER_SIZE + prg_banks:
        raise ValueError("Invalid or truncated iNES ROM")

    def bank_slice(bank: int) -> bytes:
        start = HEADER_SIZE + bank * BANK_SIZE
        return rom[start : start + BANK_SIZE]

    dispatch_bank = bank_slice(DISPATCH_BANK)
    callback_bank = bank_slice(CALLBACK_BANK)
    table_offset = DISPATCH_TABLE_CPU - 0xC000
    entries = []
    for index in range(DISPATCH_COUNT):
        offset = table_offset + index * 2
        address = int.from_bytes(dispatch_bank[offset : offset + 2], "little")
        if not 0x8000 <= address < 0xC000:
            raise ValueError(f"Dispatch entry {index} points outside low CPU window: ${address:04X}")
        code_offset = address - 0x8000
        entries.append(
            {
                "index": index,
                "target_cpu": f"${address:04X}",
                "candidate_callback_prg_bank": CALLBACK_BANK,
                "target_bytes_hex": callback_bank[code_offset : code_offset + 16].hex(" "),
            }
        )

    result = {
        "dispatch_table_prg_bank": DISPATCH_BANK,
        "dispatch_table_cpu": f"${DISPATCH_TABLE_CPU:04X}",
        "callback_window_prg_bank": CALLBACK_BANK,
        "entry_count": DISPATCH_COUNT,
        "entries": entries,
        "observed_ending_callback": {
            "requested_bank_value": 0x15,
            "mapped_physical_prg_bank": 42,
            "entry_cpu": "$8006",
            "entry_bytes_hex": bank_slice(42)[:3].hex(" "),
            "evidence": "Controlled FCEUX final-branch trace at frame 4012; $6400=19 and mapped $8000 bytes 4C 06 80",
        },
        "notes": [
            "The shared $FF50 wrapper saves the current bank value from $60DD, selects the bank in $60DC, dispatches through $FF71 using the index in $60DE, then restores the saved bank.",
            "The table contains CPU targets in the $8000-$BFFF window. Bank 10 is an earlier static candidate only; it is not a universal callback bank. The ending request value $15 maps physical PRG bank 42 in the controlled FCEUX trace. Other request values still require separate runtime mapping checks.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} callback vectors to {args.output}")


if __name__ == "__main__":
    main()
