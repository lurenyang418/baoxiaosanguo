#!/usr/bin/env python3
"""Inventory static JSR references to the ROM's $941C PPU stream writer."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
BANK_SIZE = 0x4000
TARGET = bytes((0x20, 0x1C, 0x94))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    bank_count = rom[4]
    if len(rom) < HEADER_SIZE + bank_count * BANK_SIZE:
        raise ValueError("Truncated PRG data")

    sites = []
    for bank_id in range(bank_count):
        bank = rom[HEADER_SIZE + bank_id * BANK_SIZE : HEADER_SIZE + (bank_id + 1) * BANK_SIZE]
        cursor = 0
        while True:
            cursor = bank.find(TARGET, cursor)
            if cursor < 0:
                break
            cpu = 0x8000 + cursor
            source = None
            if (
                cursor >= 8
                and bank[cursor - 8] == 0xA9
                and bank[cursor - 6] == 0x85
                and bank[cursor - 5] == 0x18
                and bank[cursor - 4] == 0xA9
                and bank[cursor - 2] == 0x85
                and bank[cursor - 1] == 0x19
            ):
                source = bank[cursor - 7] | (bank[cursor - 3] << 8)
            sites.append(
                {
                    "callsite_prg_bank": bank_id,
                    "callsite_cpu": f"${cpu:04X}",
                    "source_pointer_cpu": f"${source:04X}" if source is not None else None,
                    "source_pointer_inferred_from_immediate_setup": source is not None,
                }
            )
            cursor += 1

    result = {
        "target": "$941C",
        "scan": "All PRG banks, byte scan for opcode bytes 20 1C 94; source pointer is labeled only when immediately set by LDA #low / STA $18 / LDA #high / STA $19.",
        "static_call_count": len(sites),
        "sites": sites,
        "limitations": [
            "Byte-pattern scanning can report data that happens to resemble a JSR instruction.",
            "Indirect calls and other PPU transfer helpers are outside this inventory.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(sites)} static call-site candidates to {args.output}")


if __name__ == "__main__":
    main()
