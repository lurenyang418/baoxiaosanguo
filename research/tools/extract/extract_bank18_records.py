#!/usr/bin/env python3
"""Extract a fixed-record lookup table from bank 18 of the local NES ROM."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
INDEX_BANK = 18
INDEX_CPU = 0x8543
RECORD_COUNT = 25
RECORD_SIZE = 0x16
WORDS_PER_RECORD = 11
SPRITE_BANK_LOW = 18
SPRITE_BANK_HIGH = 19


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path, help="Path to the local iNES ROM")
    parser.add_argument("output", type=Path, help="Output JSON path")
    args = parser.parse_args()

    image = args.rom.read_bytes()
    if image[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    prg_size = image[4] * PRG_BANK_SIZE
    bank_start = HEADER_SIZE + INDEX_BANK * PRG_BANK_SIZE
    if prg_size < (INDEX_BANK + 1) * PRG_BANK_SIZE or len(image) < bank_start + PRG_BANK_SIZE:
        raise ValueError("ROM does not contain PRG bank 18")
    bank = image[bank_start : bank_start + PRG_BANK_SIZE]

    def read_prg_cpu_address(cpu_address: int) -> int:
        if 0x8000 <= cpu_address < 0xC000:
            source_bank = SPRITE_BANK_LOW
            bank_cpu_start = 0x8000
        elif 0xC000 <= cpu_address <= 0xFFFF:
            source_bank = SPRITE_BANK_HIGH
            bank_cpu_start = 0xC000
        else:
            raise ValueError(f"Sprite data pointer ${cpu_address:04X} is outside ROM windows")
        file_offset = HEADER_SIZE + source_bank * PRG_BANK_SIZE + cpu_address - bank_cpu_start
        return file_offset

    def read_word(cpu_address: int) -> int:
        offset = cpu_address - 0x8000
        if offset < 0 or offset + 1 >= len(bank):
            raise ValueError(f"CPU address ${cpu_address:04X} is outside bank 18")
        return int.from_bytes(bank[offset : offset + 2], "little")

    records = []
    for index in range(RECORD_COUNT):
        table_address = INDEX_CPU + index * 2
        descriptor = read_word(table_address)
        expected = 0x8575 + index * RECORD_SIZE
        if descriptor != expected:
            raise ValueError(
                f"Unexpected descriptor {index}: ${descriptor:04X}, expected ${expected:04X}"
            )
        fields = [read_word(descriptor + slot * 2) for slot in range(WORDS_PER_RECORD)]
        sprite_cpu = fields[0]
        sprite_offset = read_prg_cpu_address(sprite_cpu)
        entry_count = image[sprite_offset]
        if entry_count == 0 or image[sprite_offset + 1] != entry_count:
            raise ValueError(f"Unexpected sprite header at ${sprite_cpu:04X}")
        entries = []
        for entry in range(entry_count):
            y, tile, attributes, x = image[
                sprite_offset + 1 + entry * 4 : sprite_offset + 5 + entry * 4
            ]
            entries.append(
                {
                    "y_offset": y,
                    "tile_number": tile,
                    "attributes": attributes,
                    "x_offset": x,
                }
            )
        oam_bytes_0_15 = image[sprite_offset + 2 : sprite_offset + 18]
        if len(oam_bytes_0_15) != 16:
            raise ValueError(f"Truncated OAM/palette packet at ${sprite_cpu:04X}")
        buffer_cpu = fields[8]
        buffer_offset = read_prg_cpu_address(buffer_cpu)
        buffer_count = image[buffer_offset + 1]
        buffer_bytes = image[buffer_offset + 2 : buffer_offset + 2 + buffer_count]
        if len(buffer_bytes) != buffer_count:
            raise ValueError(f"Truncated buffer descriptor at ${buffer_cpu:04X}")
        records.append(
            {
                "index": index,
                "descriptor_cpu": f"${descriptor:04X}",
                "words_u16": [f"${address:04X}" for address in fields],
                "sprite_oam_layout": {
                    "source_cpu": f"${sprite_cpu:04X}",
                    "source_prg_bank": SPRITE_BANK_LOW if sprite_cpu < 0xC000 else SPRITE_BANK_HIGH,
                    "header_bytes": [image[sprite_offset], image[sprite_offset + 1]],
                    "entries": entries,
                },
                "palette_packet_from_oam_template": {
                    "ppu_start_address": "$3F10",
                    "payload_bytes": list(oam_bytes_0_15),
                    "payload_nes_color_indices": list(oam_bytes_0_15),
                    "four_sprite_palettes_nes_color_indices": [
                        list(oam_bytes_0_15[offset : offset + 4])
                        for offset in range(0, 16, 4)
                    ],
                    "same_bytes_as_first_oam_entries": 4,
                    "evidence": "Bank 18 $8030 passes the field-0 template pointer to bank 19 $F307; $F307 stages the 16 bytes after its two-byte header as a $3F10 PPU update.",
                },
                "field_8_buffer_record": {
                    "source_cpu": f"${buffer_cpu:04X}",
                    "source_prg_bank": SPRITE_BANK_LOW if buffer_cpu < 0xC000 else SPRITE_BANK_HIGH,
                    "header_bytes": [image[buffer_offset], image[buffer_offset + 1]],
                    "payload_bytes": list(buffer_bytes),
                },
                "sprite_palettes": {
                    "ppu_start_address": "$3F10",
                    "palette_count": 2,
                    "colors_per_palette": 4,
                    "palette_0_nes_color_indices": list(buffer_bytes[:4]),
                    "palette_1_nes_color_indices": list(buffer_bytes[4:8]),
                    "matches_oam_packet_prefix": list(buffer_bytes[:8]) == list(oam_bytes_0_15[:8]),
                },
            }
        )

    palette_match_records = [
        record["index"] for record in records if record["sprite_palettes"]["matches_oam_packet_prefix"]
    ]
    selector_aliases = []
    for selector_index in (25, 26):
        pointer_table_address = INDEX_CPU + selector_index * 2
        template_cpu = read_word(pointer_table_address)
        template_offset = read_prg_cpu_address(template_cpu)
        entry_count = image[template_offset]
        template_bytes = image[template_offset + 2 : template_offset + 2 + entry_count * 4]
        if len(template_bytes) != entry_count * 4:
            raise ValueError(f"Truncated aliased OAM template at ${template_cpu:04X}")
        palette_length = image[template_offset + 1]
        palette_payload = image[
            template_offset + 2 : template_offset + 2 + palette_length
        ]
        if len(palette_payload) != palette_length:
            raise ValueError(f"Truncated aliased palette packet at ${template_cpu:04X}")
        entries = []
        for entry in range(entry_count):
            y, tile, attributes, x = template_bytes[entry * 4 : entry * 4 + 4]
            entries.append(
                {
                    "y_offset": y,
                    "tile_number": tile,
                    "attributes": attributes,
                    "x_offset": x,
                }
            )
        selector_aliases.append(
            {
                "selector_index": selector_index,
                "pointer_read_cpu": f"${pointer_table_address:04X}",
                "pointer_storage_alias": f"bank 18 record 0 word {selector_index - 25}",
                "template_cpu": f"${template_cpu:04X}",
                "header_bytes": [image[template_offset], image[template_offset + 1]],
                "oam_entry_count": entry_count,
                "entries": entries,
                "palette_upload_from_header": {
                    "ppu_start_address": f"$3F{image[template_offset]:02X}",
                    "payload_length": palette_length,
                    "payload_bytes": list(palette_payload),
                    "evidence": "The shared bank-19 $F307 worker interprets header byte 0 as the low PPU address byte and byte 1 as payload length.",
                },
            }
        )
    result = {
        "source_prg_bank": INDEX_BANK,
        "index_cpu": f"${INDEX_CPU:04X}",
        "record_count": RECORD_COUNT,
        "record_size_bytes": RECORD_SIZE,
        "u16_words_per_record": WORDS_PER_RECORD,
        "palette_prefix_cross_check": {
            "matches": len(palette_match_records),
            "record_count": len(records),
            "matching_record_indices": palette_match_records,
            "mismatch_record_indices": [record["index"] for record in records if record["index"] not in palette_match_records],
        },
        "oam_selector_table_aliases": {
            "primary_pointer_count": RECORD_COUNT,
            "evidence": "The OAM lookup doubles the selector and reads from $8543. Selector indices 25 and 26 therefore read the first two words at $8575/$8577, which are record 0 words 0/1.",
            "entries": selector_aliases,
            "interpretation": "These adjacent words resolve to structurally valid OAM templates, including a 56-entry layout for selector 26. This makes selector 26 valid for the inspected OAM path despite lying beyond the 25-pointer primary table.",
        },
        "interpretation": "Raw 16-bit fields except field 0 (OAM layout; its first four entries are also staged as a 16-byte $3F10 palette packet by F307) and field 8 (two four-color palettes staged at $3F10 by F0E4; they match the field-0 packet prefix in 23 of 25 records).",
        "records": records,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(records)} records ({len(records) * WORDS_PER_RECORD} raw fields); palette prefix matches {len(palette_match_records)}/{len(records)}")


if __name__ == "__main__":
    main()
