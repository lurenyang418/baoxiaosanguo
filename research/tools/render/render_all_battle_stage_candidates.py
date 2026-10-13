#!/usr/bin/env python3
"""Render grayscale battle map candidates from recovered ROM map and CHR streams."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def main() -> None:
    project = Path(__file__).resolve().parents[3]
    ref = project / "assets/rom_reference"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ref)
    args = parser.parse_args()
    renderer = project / "research/tools/render/render_battle_stage_preview.py"
    records = project / "data/rom_battle_stage_records.json"
    base = ref / "rom_prg60_src_82bc_ppu_1000.bin"
    for stage in range(19):
        output = args.output_dir / f"rom_battle_stage_candidate_{stage:02}.png"
        overlays = [
            (ref / "rom_prg11_src_c64a_ppu_1000.bin", "0x1000"),
            (ref / "rom_prg11_src_ca2e_ppu_1400.bin", "0x1400"),
            (ref / "rom_prg11_src_ceb0_ppu_1a00.bin", "0x1A00"),
            (ref / "rom_battle_shared_chr_00_ppu_1700.bin", "0x1700"),
            (ref / "rom_battle_shared_chr_01_ppu_1910.bin", "0x1910"),
            (ref / f"rom_battle_stage_{stage:02}_chr_ppu_1010.bin", "0x1010"),
        ]
        command = [sys.executable, str(renderer), str(records), str(base), str(output), "--stage", str(stage)]
        for path, address in overlays:
            command.extend(["--overlay-chr", str(path), "--overlay-ppu-address", address])
        subprocess.run(command, check=True)


if __name__ == "__main__":
    main()
