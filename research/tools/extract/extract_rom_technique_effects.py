#!/usr/bin/env python3
"""Extract battle technique effect/range/area packets from PRG bank 8."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


BANK = 8
BANK_SIZE = 0x4000
HEADER = 16
TABLE_CPU = 0x9155
LAST_PACKET_END_CPU = 0x9282
SKILL_COUNT = 34


def read_bank(image: bytes, address: int, length: int) -> bytes:
    start = HEADER + BANK * BANK_SIZE + address - 0x8000
    chunk = image[start : start + length]
    if len(chunk) != length:
        raise ValueError(f"Truncated bank-8 read at ${address:04X}")
    return chunk


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--output", type=Path, default=Path("data/rom_technique_effects.json"))
    args = parser.parse_args()
    image = args.rom.read_bytes()
    if image[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    pointer_data = read_bank(image, TABLE_CPU, SKILL_COUNT * 2)
    pointers = [int.from_bytes(pointer_data[i : i + 2], "little") for i in range(0, len(pointer_data), 2)]
    if pointers != sorted(pointers) or pointers[0] < TABLE_CPU + SKILL_COUNT * 2:
        raise ValueError("Unexpected technique pointer table")

    skills = []
    for index, start in enumerate(pointers):
        end = pointers[index + 1] if index + 1 < SKILL_COUNT else LAST_PACKET_END_CPU
        packet = list(read_bank(image, start, end - start))
        width = 3 if index < 18 or index == 33 else 4
        if not packet or len(packet) % width:
            raise ValueError(f"Unexpected skill {index + 1} packet length {len(packet)}")
        variants = []
        for offset in range(0, len(packet), width):
            row = packet[offset : offset + width]
            variant = {
                "effect_magnitude": row[0],
                "maximum_range_cells": row[1],
                "area_code": row[2],
            }
            if width == 4:
                variant["auxiliary_byte"] = row[3]
            variants.append(variant)
        skills.append(
            {
                "technique_id": index + 1,
                "packet_cpu": f"${start:04X}",
                "packet_bytes": packet,
                "variants": variants,
            }
        )

    result = {
        "source_prg_bank": BANK,
        "pointer_table_cpu": f"${TABLE_CPU:04X}",
        "loader_cpu": "$903F-$906F",
        "effect_application_cpu": "$9A69-$9B57",
        "interpretation": (
            "The loader indexes technique ID minus one, selects a packet variant "
            "using $05CD, and copies effect magnitude to $05EB. The damage path "
            "subtracts $05EB from target HP; techniques 19-33 with variant zero "
            "use the healing path, adding $05EB and clamping to maximum HP. "
            "IDs 1-18 and 34 cross-check the "
            "supplied technical-parameters chart. Range and area bytes for "
            "unlisted IDs are ROM values; their exact targeting semantics may vary."
        ),
        "player_variant_menu": {
            "source_prg_bank": 8,
            "setup_cpu": "$8F24-$8F78",
            "input_cpu": "$8FAD-$903F",
            "setup_bytes": list(read_bank(image, 0x8F3C, 0x8F78 - 0x8F3C)),
            "records": [{"technique_id": skill, "highest_selectable_variant": (1 + int(skill >= 24) + int(skill >= 30)) if 19 <= skill <= 33 else 0} for skill in range(1, 35)],
            "interpretation": "Menu starts variant zero; Down increments through $05EA, Up decrements to zero, B returns variant FF without loading an effect, A loads the chosen packet. IDs 19-23 expose two entries, 24-29 three, 30-33 four; IDs 1-18 and 34 one.",
            "limitations": "Static control-flow evidence. Original text labels, auxiliary-byte meaning and any resource costs are not decoded. Godot lists unsupported status variants as unavailable.",
        },
        "damage_area_selection": {
            "source_prg_bank": 8,
            "selector_cpu": "$96C7-$98AA",
            "effect_cpu": "$9AC3-$9B57",
            "areas": {"1": "selected slot only", "5": "selected slot plus four orthogonal neighbors", "9": "selected slot plus eight neighbors"},
            "faction_filter": "Damage scans the opposing player-plus-group1 or group2 faction. Other slots on the center cell are not appended.",
            "runtime_evidence": ["rom_area5_damage_effect.tsv", "rom_area9_damage_effect.tsv", "rom_skill25_variant2_damage_effect.tsv"],
            "limitations": "Controlled skill, variant and target setup verifies effect routines, not natural AI decisions, original player menu selection or costs.",
        },
        "healing_area_selection": {
            "source_prg_bank": 8,
            "selector_cpu": "$96C7-$98AA",
            "effect_cpu": "$9A69-$9AC2",
            "areas": {"1": "selected center", "5": "center plus four orthogonal neighbors", "9": "center plus eight neighbors"},
            "faction_filter": "Variant-zero techniques 19-33 scan the caster's player-plus-group1 or group2 faction, with selected center first.",
            "runtime_evidence": ["rom_area5_healing_effect.tsv", "rom_area9_healing_effect.tsv"],
            "limitations": "Area9 runtime record forces the area register on a type60 action; it verifies the area branch, not a natural type69 AI choice. Godot excludes defeated slots and does not implement resurrection.",
        },
        "enemy_healing_targeting": {
            "source_prg_bank": 2,
            "range_table_cpu": "$ADF6",
            "area_table_cpu": "$AE01",
            "records": [
                {"unit_type_id": 56 + i, "maximum_range_cells": image[HEADER + 2 * BANK_SIZE + 0xADF6 - 0x8000 + i],
                 "area_code": image[HEADER + 2 * BANK_SIZE + 0xAE01 - 0x8000 + i]}
                for i in range(11)
            ],
            "interpretation": "AD30 uses these targeting tables for types 56-66; effect magnitude still comes from variant zero in bank 8. Entries beyond 66 overlap code and are not claimed here. Type 59 dynamically verified: range 3, area 1, heals one target by 30.",
        },
        "skills": skills,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
