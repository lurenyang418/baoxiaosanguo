#!/usr/bin/env python3
"""Extract per-stage passable map-code lists used by the ROM movement cursor."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
POINTER_TABLE_BANK = 2
POINTER_TABLE_CPU = 0x8CD0
STAGE_COUNT = 19
LOW_WINDOW_BANK = 2
HIGH_WINDOW_BANK = 3


def bank_slice(image: bytes, bank: int, address: int, length: int) -> bytes:
    window_base = 0x8000 if address < 0xC000 else 0xC000
    offset = HEADER_SIZE + bank * PRG_BANK_SIZE + address - window_base
    data = image[offset : offset + length]
    if len(data) != length:
        raise ValueError(f"Truncated PRG bank {bank} data at ${address:04X}")
    return data


def read_cpu_pointer(image: bytes, address: int, length: int) -> bytes:
    if 0x8000 <= address < 0xC000:
        return bank_slice(image, LOW_WINDOW_BANK, address, length)
    if 0xC000 <= address <= 0xFFFF:
        return bank_slice(image, HIGH_WINDOW_BANK, address, length)
    raise ValueError(f"CPU address ${address:04X} is outside the mapped PRG windows")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--output", type=Path, default=Path("data/rom_stage_movement_rules.json"))
    args = parser.parse_args()

    image = args.rom.read_bytes()
    if image[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    table = bank_slice(image, POINTER_TABLE_BANK, POINTER_TABLE_CPU, STAGE_COUNT * 2)
    pointers = [int.from_bytes(table[index : index + 2], "little") for index in range(0, len(table), 2)]

    stages = []
    for stage_index, pointer in enumerate(pointers):
        header = read_cpu_pointer(image, pointer, 1)[0]
        passable_codes = list(read_cpu_pointer(image, pointer + 1, header))
        stages.append(
            {
                "stage_index": stage_index,
                "list_pointer_cpu": f"${pointer:04X}",
                "entry_count": header,
                "passable_map_codes": passable_codes,
            }
        )

    result = {
        "source_prg_banks": {"pointer_table": POINTER_TABLE_BANK, "low_window": LOW_WINDOW_BANK, "high_window": HIGH_WINDOW_BANK},
        "pointer_table_cpu": f"${POINTER_TABLE_CPU:04X}",
        "source_routine": "bank 2 $8C2F-$8C98",
        "interpretation": (
            "The movement cursor reads the current stage's map code and searches "
            "this whitelist. A missing map code sets the movement-blocked result. "
            "The following routine separately rejects occupied unit positions."
        ),
        "stages": stages,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
