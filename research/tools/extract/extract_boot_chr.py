#!/usr/bin/env python3
"""Extract the 4 KiB CHR-RAM initialization block copied from PRG bank 60."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from extract_ppu_stream import write_tile_sheet

HEADER_SIZE = 16
BANK_SIZE = 0x4000
SOURCE_BANK = 60
SOURCE_CPU = 0x82BC
CHR_BYTES = 0x1000
PPU_START = 0x1000


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rom", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    if rom[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")
    if rom[4] <= SOURCE_BANK:
        raise ValueError(f"ROM does not contain PRG bank {SOURCE_BANK}")

    start = HEADER_SIZE + SOURCE_BANK * BANK_SIZE + SOURCE_CPU - 0x8000
    payload = rom[start : start + CHR_BYTES]
    if len(payload) != CHR_BYTES:
        raise ValueError("CHR initialization block is truncated")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    stem = f"rom_prg{SOURCE_BANK}_src_{SOURCE_CPU:04x}_ppu_{PPU_START:04x}"
    raw_path = args.output_dir / f"{stem}.bin"
    image_path = args.output_dir / f"{stem}_tiles.png"
    metadata_path = args.output_dir / f"{stem}.json"
    raw_path.write_bytes(payload)
    tile_count, width, height = write_tile_sheet(payload, image_path)
    metadata_path.write_text(
        json.dumps(
            {
                "source_prg_bank": SOURCE_BANK,
                "source_cpu": f"${SOURCE_CPU:04X}",
                "ppu_start_address": f"${PPU_START:04X}",
                "payload_bytes": len(payload),
                "tile_count": tile_count,
                "preview_size": [width, height],
                "rom_sha256": hashlib.sha256(rom).hexdigest(),
                "evidence": "The bank-60 initialization routine copies $82BC-$92BB to PPU $1000-$1FFF.",
                "decoded_as": "NES 2bpp 8x8 tiles, grayscale preview",
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Extracted {len(payload)} bytes ({tile_count} tiles) from PRG bank {SOURCE_BANK} to PPU ${PPU_START:04X}")


if __name__ == "__main__":
    main()
