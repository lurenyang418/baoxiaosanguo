#!/usr/bin/env python3
"""Render extracted CHR tile candidates for every tile ID used by bank-18 OAM."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

from render_sprite_palette_sheet import draw_digit, png_chunk


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("records", type=Path)
    parser.add_argument("reference_dir", type=Path)
    parser.add_argument("output_png", type=Path)
    parser.add_argument("output_json", type=Path)
    args = parser.parse_args()

    record_data = json.loads(args.records.read_text(encoding="utf-8"))
    records = record_data["records"]
    tile_ids = sorted(
        {
            entry["tile_number"]
            for record in records
            for entry in record["sprite_oam_layout"]["entries"]
        }
        | {
            entry["tile_number"]
            for alias in record_data.get("oam_selector_table_aliases", {}).get("entries", [])
            for entry in alias["entries"]
        }
    )
    sources = []
    for metadata_path in sorted(args.reference_dir.glob("rom_prg*_src_*_ppu_*.json")):
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        source_pointer = metadata.get("source_pointer_cpu", metadata.get("source_cpu"))
        if source_pointer is None:
            continue
        raw_path = metadata_path.with_suffix(".bin")
        payload = raw_path.read_bytes()
        ppu_start = int(metadata["ppu_start_address"].removeprefix("$"), 16)
        sources.append(
            {
                "metadata": metadata,
                "source_pointer_cpu": source_pointer,
                "ppu_start": ppu_start,
                "ppu_end": ppu_start + len(payload),
                "ppu_regions": metadata.get(
                    "ppu_memory_regions_after_14bit_wrap",
                    [{"ppu_start_address": f"${ppu_start:04X}", "payload_offset": 0, "byte_count": len(payload)}],
                ),
                "payload": payload,
                "raw_file": raw_path.name,
            }
        )

    def get_tile(source: dict, table_base: int, tile_id: int) -> bytes | None:
        address = table_base + tile_id * 16
        for region in source["ppu_regions"]:
            region_start = int(region["ppu_start_address"].removeprefix("$"), 16)
            region_offset = region["payload_offset"]
            region_size = region["byte_count"]
            start_in_region = address - region_start
            if 0 <= start_in_region and start_in_region + 16 <= region_size:
                start = region_offset + start_in_region
                return source["payload"][start : start + 16]
        return None

    # Keep the two NES pattern-table possibilities separate: OAM IDs index
    # either $0000 or $1000 depending on PPUCTRL bit 3.
    groups = []
    for table_base in (0x0000, 0x1000):
        for source_index, source in enumerate(sources):
            entries = [
                {"tile_id": tile_id, "bytes_hex": get_tile(source, table_base, tile_id).hex()}
                for tile_id in tile_ids
                if get_tile(source, table_base, tile_id) is not None
            ]
            if entries:
                groups.append(
                    {
                        "candidate_column": len(groups),
                        "pattern_table_base": f"${table_base:04X}",
                        "runtime_sprite_table_status": (
                            "selected_by_static_ppuctrl_trace_on_examined_paths"
                            if table_base == 0x0000
                            else "not_selected_by_static_ppuctrl_trace_on_examined_paths"
                        ),
                        "source_index": source_index,
                        "source_prg_bank": source["metadata"]["source_prg_bank"],
                        "source_pointer_cpu": source["source_pointer_cpu"],
                        "ppu_start_address": source["metadata"]["ppu_start_address"],
                        "raw_file": source["raw_file"],
                        "tiles": entries,
                    }
                )

    scale = 3
    tile_px = 8 * scale
    cell_width, cell_height = tile_px + 4, tile_px + 6
    label_width, header_height = 24, 18
    width = label_width + len(groups) * cell_width
    height = header_height + len(tile_ids) * cell_height
    pixels = bytearray(width * height * 4)

    def set_pixel(x: int, y: int, rgba: bytes) -> None:
        offset = (y * width + x) * 4
        pixels[offset : offset + 4] = rgba

    for column, group in enumerate(groups):
        x = label_width + column * cell_width + 3
        draw_digit(pixels, width, x + 7, 5, str(group["candidate_column"]))

    for row, tile_id in enumerate(tile_ids):
        y = header_height + row * cell_height
        draw_digit(pixels, width, 2, y + 4, str(tile_id // 10))
        draw_digit(pixels, width, 8, y + 4, str(tile_id % 10))
        for column, group in enumerate(groups):
            source = sources[group["source_index"]]
            tile = get_tile(source, int(group["pattern_table_base"].removeprefix("$"), 16), tile_id)
            x0 = label_width + column * cell_width + 2
            if tile is None:
                for py in range(tile_px):
                    for px in range(tile_px):
                        set_pixel(x0 + px, y + 2 + py, b"\x18\x18\x18\xff")
                continue
            for py in range(8):
                lo, hi = tile[py], tile[py + 8]
                for px in range(8):
                    bit = 7 - px
                    shade = ((lo >> bit) & 1) | (((hi >> bit) & 1) << 1)
                    rgba = bytes((shade * 85, shade * 85, shade * 85, 255))
                    for dy in range(scale):
                        for dx in range(scale):
                            set_pixel(x0 + px * scale + dx, y + 2 + py * scale + dy, rgba)

    scanlines = b"".join(b"\x00" + pixels[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    image = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + png_chunk(b"IEND", b"")
    )
    args.output_png.parent.mkdir(parents=True, exist_ok=True)
    args.output_png.write_bytes(image)

    coverage = []
    for tile_id in tile_ids:
        candidates = []
        for group in groups:
            table_base = int(group["pattern_table_base"].removeprefix("$"), 16)
            if get_tile(sources[group["source_index"]], table_base, tile_id) is not None:
                candidates.append(group["candidate_column"])
        coverage.append({"tile_id": tile_id, "candidate_columns": candidates})
    result = {
        "source_records": args.records.name,
        "tile_ids": tile_ids,
        "candidate_columns": groups,
        "coverage_by_oam_tile_id": coverage,
        "limitations": [
            "Columns show byte-range matches only; they do not prove that the source is used by the corresponding OAM record.",
            "Static inspection of the $6401 PPUCTRL shadow selects sprite patterns from $0000 on examined paths; $1000 columns are background-side or boot-only reference data, not active sprite candidates there.",
            "The PPU $3C9C upload wraps at $3FFF; its post-wrap range is considered for tile coverage, but its runtime association with OAM selector 26 is not yet confirmed.",
            "Extracted streams are not asserted to be resident together, and mapper callback timing has not been traced in an emulator.",
        ],
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Rendered {len(tile_ids)} OAM tile IDs against {len(groups)} extracted table/source candidates")


if __name__ == "__main__":
    main()
