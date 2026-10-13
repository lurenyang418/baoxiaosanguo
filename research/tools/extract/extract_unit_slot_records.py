#!/usr/bin/env python3
"""Extract the ROM's counted unit-ID groups and their 13-byte definition records."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
BANK = 8
GROUP_POINTER_TABLE = 0x8B1E
GROUP_COUNT = 7
DEFINITION_BASE = 0x8B7C
DEFINITION_STRIDE = 13
DEFINITION_DATA_END = 0x8F24
GRAPHIC_SELECTOR_COUNT = 25
OAM_POINTER_TABLE = 0x8543
UNIT_STREAM_BANK = 12
UNIT_STREAM_TABLE = 0x801C
EXTENDED_SELECTOR = 26
UNIT_STREAM_CALLER_BANK = 18
UNIT_STREAM_DISPATCH = bytes(
    (
        0xA9, 0x0C, 0x8D, 0xDC, 0x60,  # LDA #$0C / STA $60DC
        0xA9, 0x00, 0x8D, 0xDE, 0x60,  # LDA #$00 / STA $60DE
        0xA9, 0x09, 0x8D, 0xDD, 0x60,  # LDA #$09 / STA $60DD
        0x20, 0x50, 0xFF,              # JSR $FF50
    )
)
UNIT_STREAM_INDEX1_DISPATCH = bytes(
    (
        0xA9, 0x0C, 0x8D, 0xDC, 0x60,  # LDA #$0C / STA $60DC
        0xA9, 0x01, 0x8D, 0xDE, 0x60,  # LDA #$01 / STA $60DE
        0x20, 0x50, 0xFF,              # JSR $FF50
    )
)
RECORD_DESTINATIONS = [
    "$6557",
    "$6558",
    "$6647",
    "$6648",
    "$65F7",
    "$65F8",
    "$6697",
    "$66BF",
    "$66E7",
    "$6467",
    "$6711",
    "$6739",
    "$6761",
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="Path to the local iNES ROM")
    parser.add_argument("output", type=Path, help="Output JSON path")
    args = parser.parse_args()

    image = args.rom.read_bytes()
    if image[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    if image[4] <= BANK:
        raise ValueError("ROM does not contain PRG bank 8")
    bank_start = HEADER_SIZE + BANK * PRG_BANK_SIZE
    bank = image[bank_start : bank_start + PRG_BANK_SIZE]

    def mapped_prg_offset(low_bank: int, cpu_address: int) -> int:
        if 0x8000 <= cpu_address < 0xC000:
            physical_bank = low_bank
            window_start = 0x8000
        elif 0xC000 <= cpu_address <= 0xFFFF:
            physical_bank = low_bank + 1
            window_start = 0xC000
        else:
            raise ValueError(f"CPU address ${cpu_address:04X} is outside mapped PRG windows")
        return HEADER_SIZE + physical_bank * PRG_BANK_SIZE + cpu_address - window_start

    def bank_offset(cpu_address: int, length: int = 1) -> int:
        offset = cpu_address - 0x8000
        if offset < 0 or offset + length > len(bank):
            raise ValueError(f"CPU address ${cpu_address:04X} is outside bank 8")
        return offset

    def read_word(cpu_address: int) -> int:
        offset = bank_offset(cpu_address, 2)
        return int.from_bytes(bank[offset : offset + 2], "little")

    caller_bank_start = HEADER_SIZE + UNIT_STREAM_CALLER_BANK * PRG_BANK_SIZE
    caller_bank = image[caller_bank_start : caller_bank_start + PRG_BANK_SIZE]
    dispatch_callsites = []
    cursor = 0
    while True:
        cursor = caller_bank.find(UNIT_STREAM_DISPATCH, cursor)
        if cursor < 0:
            break
        dispatch_callsites.append(f"${0x8000 + cursor:04X}")
        cursor += 1
    index1_dispatch_matches = []
    for bank_id in range(image[4]):
        start = HEADER_SIZE + bank_id * PRG_BANK_SIZE
        bank_data = image[start : start + PRG_BANK_SIZE]
        cursor = 0
        while True:
            cursor = bank_data.find(UNIT_STREAM_INDEX1_DISPATCH, cursor)
            if cursor < 0:
                break
            index1_dispatch_matches.append(
                {"prg_bank": bank_id, "cpu_address": f"${0x8000 + cursor:04X}"}
            )
            cursor += 1

    groups = []
    all_ids: set[int] = set()
    for group_index in range(GROUP_COUNT):
        pointer = read_word(GROUP_POINTER_TABLE + group_index * 2)
        count = bank[bank_offset(pointer)]
        start = bank_offset(pointer + 1, count)
        ids = list(bank[start : start + count])
        all_ids.update(ids)
        groups.append(
            {
                "group_index": group_index,
                "list_cpu": f"${pointer:04X}",
                "count": count,
                "unit_ids": ids,
            }
        )

    records = []
    selector_counts: dict[int, int] = {}
    for unit_id in sorted(all_ids):
        cpu_address = DEFINITION_BASE + unit_id * DEFINITION_STRIDE
        start = bank_offset(cpu_address, DEFINITION_STRIDE)
        raw = list(bank[start : start + DEFINITION_STRIDE])
        record_is_data = cpu_address + DEFINITION_STRIDE <= DEFINITION_DATA_END
        if record_is_data:
            selector = raw[9]
            selector_counts[selector] = selector_counts.get(selector, 0) + 1
        records.append(
            {
                "unit_id": unit_id,
                "source_cpu": f"${cpu_address:04X}",
                "raw_bytes": raw,
                "movement_allowance_points": raw[7] if record_is_data else None,
                "record_status": (
                    "fixed_stride_data"
                    if record_is_data
                    else "overlaps_executable_entrypoint_at_$8F24"
                ),
                "field_destinations": (
                    [
                        {
                            "record_byte_offset": offset,
                            "ram_array": destination,
                            "semantic_status": (
                                "maximum HP field; matches the supplied parameter-chart transcription"
                                if offset in (0, 1)
                                else "attack field; matches the supplied parameter-chart transcription"
                                if offset in (2, 3)
                                else "experience-related field; chart value differs at type IDs 14 and 17"
                                if offset in (4, 5)
                                else "defense field; matches the supplied parameter-chart transcription"
                                if offset == 6
                                else "movement allowance points; consumed by bank-2 movement-cost routine at $8B8A"
                                if offset == 7
                                else "skill/technique ID; matches listed skill IDs where shown"
                                if offset == 8
                                else "graphic selector consumed by OAM/PPU lookups"
                                if offset == 9
                                else "copied by loader; meaning unresolved"
                            ),
                        }
                        for offset, destination in enumerate(RECORD_DESTINATIONS)
                    ]
                    if record_is_data
                    else []
                ),
            }
        )

    # Trace the extended selector 26 through the bank-12 stream table and the
    # overlapping bank-18 OAM pointer table. Both paths index with $6467.
    stream_table_offset = mapped_prg_offset(UNIT_STREAM_BANK, UNIT_STREAM_TABLE + EXTENDED_SELECTOR * 2)
    stream_pointer = int.from_bytes(image[stream_table_offset : stream_table_offset + 2], "little")
    stream_cursor = mapped_prg_offset(UNIT_STREAM_BANK, stream_pointer)
    stream_header = image[stream_cursor : stream_cursor + 3]
    if len(stream_header) != 3:
        raise ValueError("Truncated selector-26 PPU stream header")
    ppu_start = ((stream_header[0] << 8) | stream_header[1]) & 0x3FFF
    segment_count = stream_header[2]
    stream_cursor += 3
    payload_bytes = 0
    for _ in range(segment_count):
        length_offset = stream_cursor
        encoded_length = image[length_offset]
        segment_length = encoded_length or 256
        stream_cursor += 1 + segment_length
        payload_bytes += segment_length
        if stream_cursor > len(image):
            raise ValueError("Truncated selector-26 PPU stream payload")
    ppu_wrap_offset = 0x4000 - ppu_start
    chr_bytes_after_wrap = max(0, payload_bytes - ppu_wrap_offset)

    oam_pointer_table_offset = mapped_prg_offset(18, OAM_POINTER_TABLE + EXTENDED_SELECTOR * 2)
    oam_pointer = int.from_bytes(image[oam_pointer_table_offset : oam_pointer_table_offset + 2], "little")
    oam_template_offset = mapped_prg_offset(18, oam_pointer)
    oam_entry_count = image[oam_template_offset]
    oam_palette_length = image[oam_template_offset + 1]
    oam_bytes = image[oam_template_offset + 2 : oam_template_offset + 2 + oam_entry_count * 4]
    if len(oam_bytes) != oam_entry_count * 4:
        raise ValueError("Truncated selector-26 OAM template")
    oam_tile_ids = sorted({oam_bytes[index + 1] for index in range(0, len(oam_bytes), 4)})
    chr_tiles_available = chr_bytes_after_wrap // 16
    covered_tile_ids = [tile_id for tile_id in oam_tile_ids if tile_id < chr_tiles_available]

    result = {
        "source_prg_bank": BANK,
        "group_pointer_table_cpu": f"${GROUP_POINTER_TABLE:04X}",
        "group_count": GROUP_COUNT,
        "definition_base_cpu": f"${DEFINITION_BASE:04X}",
        "definition_stride_bytes": DEFINITION_STRIDE,
        "unique_unit_id_count": len(records),
        "graphic_selector_audit": {
            "primary_oam_and_ppu_table_entries": GRAPHIC_SELECTOR_COUNT,
            "valid_record_selector_value_counts": {
                str(selector): count for selector, count in sorted(selector_counts.items())
            },
            "record_ids_above_primary_table_range": [
                record["unit_id"]
                for record in records
                if record["record_status"] == "fixed_stride_data"
                and record["raw_bytes"][9] >= GRAPHIC_SELECTOR_COUNT
            ],
            "oam_selector_26_alias": {
                "pointer_read_cpu": "$8577",
                "pointer_value_cpu": "$BA0F",
                "template_header_bytes": [oam_entry_count, oam_palette_length],
                "oam_entry_count": oam_entry_count,
                "palette_upload_ppu_start": f"$3F{image[oam_template_offset]:02X}",
                "palette_upload_bytes": oam_palette_length,
                "evidence_file": "rom_bank18_records.json:oam_selector_table_aliases",
                "interpretation": "Valid extended OAM layout reached through the first record's second word; ID 71 selector 26 is not out of range for this OAM lookup."
            },
            "bank12_selector_26_stream": {
                "callback_index": 0,
                "callback_entry_cpu": "$8006",
                "dispatcher_prg_bank": UNIT_STREAM_CALLER_BANK,
                "dispatcher_callsites_cpu": dispatch_callsites,
                "callback_index_1_direct_dispatch_search": {
                    "pattern": "LDA #$0C; STA $60DC; LDA #$01; STA $60DE; JSR $FF50",
                    "matches": index1_dispatch_matches,
                    "interpretation": "No exact immediate-parameter callsite found; this does not rule out split or computed callback parameters.",
                },
                "dispatcher_parameters": {
                    "$60DC": UNIT_STREAM_BANK,
                    "$60DE": 0,
                    "$60DD": 9,
                },
                "adjacent_slot_state_evidence": {
                    "render_prg_bank": 18,
                    "oam_selector_read_sites_cpu": ["$81A2", "$8433"],
                    "slot_copy_prg_bank": 2,
                    "slot_copy_cpu": "$9351",
                    "slot_copy_condition": "$670F == 0",
                    "invalid_slot_write_cpu": "$94E9",
                    "invalid_slot_value": "$FF",
                    "neighbor_list_builder_cpu": "$AA48",
                    "neighbor_selector_cpu": "$9A24",
                    "neighbor_selection": "build candidates adjacent to the $6408 slot from paired $64B7/$648F fields; choose one candidate by $65A8:$65A7 when multiple qualify",
                    "neighbor_path_evidence_file": "rom_sprite_selector_trace.json:slot_list_selection_path",
                    "interpretation": "$6409 may mirror $6408 on the $670F==0 path, be selected from slots adjacent to $6408, or be explicitly invalidated; the active state at either bank-12 dispatch is not established.",
                },
                "slot_selector_address": "$6408",
                "graphic_id_array": "$6467",
                "table_cpu": f"${UNIT_STREAM_TABLE + EXTENDED_SELECTOR * 2:04X}",
                "matching_oam_layout_lookup": {
                    "prg_bank": 18,
                    "entry_cpu": "$802E",
                    "slot_selector_address": "$6408",
                    "graphic_id_array": "$6467",
                    "pointer_table_cpu": "$8543",
                    "template_pointer_cpu": f"${oam_pointer:04X}",
                    "entry_count": oam_entry_count,
                    "relationship": "same $6408 slot and $6467 graphic ID as bank-12 CHR callback index 0",
                },
                "source_pointer_cpu": f"${stream_pointer:04X}",
                "source_prg_bank_for_pointer": UNIT_STREAM_BANK + (1 if stream_pointer >= 0xC000 else 0),
                "ppu_start_address": f"${ppu_start:04X}",
                "segment_count": segment_count,
                "payload_bytes": payload_bytes,
                "ppu_wrap_offset": ppu_wrap_offset,
                "chr_bytes_after_wrap": chr_bytes_after_wrap,
                "chr_tiles_available": chr_tiles_available,
                "oam_template_pointer_cpu": f"${oam_pointer:04X}",
                "oam_entry_count": oam_entry_count,
                "oam_tile_ids": oam_tile_ids,
                "oam_tile_ids_covered_by_post_wrap_chr": covered_tile_ids,
                "all_oam_tile_ids_covered": covered_tile_ids == oam_tile_ids,
        "interpretation": "Bank 18 selects the OAM layout at $802E using $6408 and $6467, then calls bank-12 callback index 0 at $8285/$8529, which uses the same $6408 slot and $6467 graphic ID to select CHR. This is a direct static pairing for selector 26. Bank 18 also has another OAM path that reads $6409; bank 2 can copy $6408 into $6409, select a slot adjacent to $6408 into $6409, or invalidate it, so that secondary path is state-dependent. Runtime CHR residency is not emulator-confirmed."
            },
            "ppu_callback_selector_26": {
                "pointer_read_cpu": "$805C",
                "pointer_value_cpu": "$9848",
                "observed_stream_header": [0, 0, 128],
                "status": "not included in the 25 canonical PPU streams; requires callback-gate/runtime tracing before treating as a valid upload"
            },
            "interpretation": "The 25-entry primary tables have adjacent data/code aliases. Selector 26 resolves to a structurally valid 56-entry OAM layout, while its NMI PPU-stream path remains unresolved.",
        },
        "movement_allowance": {
            "status": "confirmed_static_code_trace",
            "record_byte_offset": 7,
            "ram_array": "$66BF",
            "consumer_prg_bank": 2,
            "consumer_cpu_address": "$8B8A",
            "selection": "LDX $6408 selects the active unit slot; when $05CC == 0, LDA $66BF,X reads that unit's movement allowance",
            "cost_accounting": "subtracts $05E6 from the allowance, stores the remainder back to $05E6, and callers reject negative remainder; $05CC != 0 uses $670F instead",
            "distance_formula": "Manhattan distance: absolute horizontal delta plus absolute vertical delta, with screen/map offsets normalized and each axis converted to 16-pixel tiles",
            "unit": "movement points compared against Manhattan tile distance",
            "caveat": "passability and occupancy constraints are not fully decoded; no terrain-weighted cost appears in this helper"
        },
        "interpretation": "Counted groups and referenced IDs are byte-verified. IDs 0-71 index fixed-stride data before the $8F24 code entrypoint. ID 72 is preserved as a special overlapping index and must not be decoded as a 13-byte unit definition. The supplied parameter-chart transcription independently matches movement allowances for visible IDs 0-55 and corroborates bytes 0-3 and 6 as HP, attack, and defense fields in its displayed rows; bytes 4-5 mostly align with required experience but differ at type IDs 14 and 17; byte 8 matches listed skill IDs where shown; byte 9 feeds the graphic selector array. Byte 7 is also consumed by the bank-2 movement-cost routine at $8B8A. Bytes 10-12 remain unresolved.",
        "groups": groups,
        "records": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(groups)} groups and {len(records)} unique 13-byte records")


if __name__ == "__main__":
    main()
