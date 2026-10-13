#!/usr/bin/env python3
"""Export stage-indexed unit layout streams and their battle-record headers."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
STAGE_COUNT = 19
BATTLE_RECORD_TABLE = 0x8610
BATTLE_RECORD_SIZE = 12
UNIT_LAYOUT_POINTER_TABLE = 0x8241
UNIT_LAYOUT_BANK = 8
UNIT_LAYOUT_END = 0x8B1E
ROSTER_SEED_BANK = 0
ROSTER_SEED_CPU = 0xC195
ROSTER_SEED_COUNT = 20
UNIT_DATA = Path(__file__).resolve().parents[3] / "data/rom_unit_slot_records.json"


def bank_slice(image: bytes, bank: int, address: int, length: int) -> bytes:
    if not 0x8000 <= address < 0xC000:
        raise ValueError(f"CPU address ${address:04X} is outside the low PRG window")
    start = HEADER_SIZE + bank * PRG_BANK_SIZE + address - 0x8000
    result = image[start : start + length]
    if len(result) != length:
        raise ValueError(f"Truncated PRG bank {bank} data at ${address:04X}")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("--output", type=Path, default=Path("data/rom_stage_unit_layouts.json"))
    parser.add_argument("--unit-data", type=Path, default=UNIT_DATA)
    args = parser.parse_args()

    image = args.rom.read_bytes()
    if image[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    if image[4] <= UNIT_LAYOUT_BANK:
        raise ValueError("ROM does not contain unit layout bank 8")

    seed_offset = (
        HEADER_SIZE
        + ROSTER_SEED_BANK * PRG_BANK_SIZE
        + ROSTER_SEED_CPU
        - 0xC000
    )
    roster_type_ids = [
        image[seed_offset + slot * 3]
        for slot in range(ROSTER_SEED_COUNT)
    ]
    unit_data = json.loads(args.unit_data.read_text(encoding="utf-8"))
    unit_records = {
        int(record["unit_id"]): record
        for record in unit_data["records"]
        if record.get("movement_allowance_points") is not None
    }

    ptr_raw = bank_slice(image, UNIT_LAYOUT_BANK, UNIT_LAYOUT_POINTER_TABLE, STAGE_COUNT * 2)
    pointers = [int.from_bytes(ptr_raw[i : i + 2], "little") for i in range(0, len(ptr_raw), 2)]
    if pointers != sorted(pointers) or pointers[-1] >= UNIT_LAYOUT_END:
        raise ValueError("Unexpected stage unit layout pointer order or bounds")

    records = []
    for stage_index, pointer in enumerate(pointers):
        end = pointers[stage_index + 1] if stage_index + 1 < STAGE_COUNT else UNIT_LAYOUT_END
        layout = bank_slice(image, UNIT_LAYOUT_BANK, pointer, end - pointer)
        battle_record = bank_slice(
            image, 2, BATTLE_RECORD_TABLE + stage_index * BATTLE_RECORD_SIZE, BATTLE_RECORD_SIZE
        )
        header = list(battle_record[:4])
        cursor = 0
        layout_records = []
        for _ in range(header[0]):
            roster_index, y, x = layout[cursor : cursor + 3]
            cursor += 3
            deployment = {"position_x": x, "position_y": y}
            if stage_index < 10:
                deployment["roster_index"] = roster_index
                if roster_index >= len(roster_type_ids):
                    raise ValueError(
                        f"Stage {stage_index} references unknown startup roster slot {roster_index}"
                    )
                deployment["unit_type_id"] = roster_type_ids[roster_index]
                deployment["unit_type_basis"] = "startup_campaign_roster_seed"
                movement = unit_records.get(deployment["unit_type_id"], {}).get(
                    "movement_allowance_points"
                )
                if movement is not None:
                    deployment["movement_allowance_points"] = movement
                    deployment["movement_allowance_basis"] = "startup_unit_type_definition"
            else:
                # Bank 8 $8038 jumps over $8041's layout-byte load. Runtime
                # $6807,X supplies the roster index, while Y/X still come here.
                deployment["ignored_layout_roster_byte"] = roster_index
            layout_records.append(deployment)
        player_deployments = layout_records

        unit_group_1 = []
        for _ in range(header[1]):
            unit_type_id, y, x, auxiliary = layout[cursor : cursor + 4]
            cursor += 4
            unit_group_1.append(
                {
                    "unit_type_id": unit_type_id,
                    "position_x": x,
                    "position_y": y,
                    "auxiliary_byte": auxiliary,
                }
            )

        unit_group_2 = []
        for _ in range(header[2]):
            encoded_type, y, x, aux_0, aux_1, aux_2 = layout[cursor : cursor + 6]
            cursor += 6
            unit_group_2.append(
                {
                    "encoded_type_id": encoded_type,
                    "unit_type_id": encoded_type & 0x7F,
                    "position_x": x,
                    "position_y": y,
                    "auxiliary_bytes": [aux_0, aux_1, aux_2],
                    "ai_flags": aux_1,
                }
            )
        if cursor != len(layout):
            raise ValueError(
                f"Stage {stage_index} layout parse consumed {cursor} of {len(layout)} bytes"
            )
        records.append(
            {
                "stage_index": stage_index,
                "unit_layout_pointer_cpu": f"${pointer:04X}",
                "unit_layout_end_cpu_exclusive": f"${end:04X}",
                "unit_layout_bytes": list(layout),
                "unit_layout_hex": layout.hex(" "),
                "battle_record_header_bytes": header,
                "battle_record_cpu": f"${BATTLE_RECORD_TABLE + stage_index * BATTLE_RECORD_SIZE:04X}",
                "player_deployments": player_deployments,
                "unit_group_1": unit_group_1,
                "unit_group_2": unit_group_2,
            }
        )

    result = {
        "source_prg_bank": UNIT_LAYOUT_BANK,
        "pointer_table_cpu": f"${UNIT_LAYOUT_POINTER_TABLE:04X}",
        "battle_record_table_cpu": f"${BATTLE_RECORD_TABLE:04X}",
        "stage_count": STAGE_COUNT,
        "interpretation": (
            "Stage-indexed unit layout streams decoded using the record loops at "
            "bank 8 $8043, $80B2, and $80F5. Each stage is stored as player "
            "deployment triples, group-1 four-byte records, then group-2 "
            "six-byte records. The group-2 type byte's top bit sets a side flag. "
            "Bank 8 $8030 branches at stage index 10: stages 0-9 use the roster "
            "slot IDs in these player entries and set $6813 from the battle "
            "header count; their type IDs are joined from the startup roster "
            "seed. Stages 10-18 read the runtime roster index from $6807,X, "
            "jump over the stage-layout roster byte at $8041, then resolve "
            "the current type through $651B. Those entries expose the ignored "
            "layout byte and Y/X positions, without assigning a fixed type. "
            "The first position byte is world Y and the second is world X; "
            "stage 0 group-2 coordinates exactly match the supplied battle screenshot "
            "when read in that order. Group-2 auxiliary byte 1 is copied to "
            "$67B1 and controls the low-nibble AI branch; all three raw "
            "auxiliary bytes are also preserved."
        ),
        "records": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
