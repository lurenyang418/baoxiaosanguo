#!/usr/bin/env python3
"""Rebuild stage-zero terrain and two screenshot-matched unit poses from ROM CHR.

The reference screenshot is used only to measure emulator RGB colors. Pixel
patterns come from the extracted ROM uploads, never from a screenshot crop.
"""
from pathlib import Path
import argparse
import json
import struct
import subprocess
import sys
import zlib
from collections import Counter, defaultdict
from render_sprite_palette_sheet import png_chunk

PROJECT = Path(__file__).resolve().parents[3]
REF = PROJECT / "assets/rom_reference"


def read_png(path):
    data = path.read_bytes()
    width, height, depth, kind, _, _, interlace = struct.unpack(">IIBBBBB", data[16:29])
    if depth != 8 or kind not in (2, 6) or interlace:
        raise ValueError("Reference must be a noninterlaced RGB/RGBA 8-bit PNG")
    channels = 4 if kind == 6 else 3
    compressed, offset = bytearray(), 8
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        if data[offset + 4:offset + 8] == b"IDAT":
            compressed.extend(data[offset + 8:offset + 8 + length])
        offset += length + 12
    raw = zlib.decompress(compressed)
    rows, previous = [], bytearray(width * channels)
    stride = width * channels
    for y in range(height):
        mode = raw[y * (stride + 1)]
        row = bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            left = row[i - channels] if i >= channels else 0
            up = previous[i]
            corner = previous[i - channels] if i >= channels else 0
            estimate = left + up - corner
            distances = abs(estimate - left), abs(estimate - up), abs(estimate - corner)
            paeth = (left, up, corner)[distances.index(min(distances))]
            row[i] = (row[i] + (0, left, up, (left + up) // 2, paeth)[mode]) & 255
        rows.append([tuple(row[x * channels:x * channels + 3]) for x in range(width)])
        previous = row
    return width, height, rows


def write_png(path, width, height, pixels):
    scanlines = b"".join(b"\0" + pixels[y * width * 4:(y + 1) * width * 4] for y in range(height))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)) + png_chunk(b"IDAT", zlib.compress(scanlines, 9)) + png_chunk(b"IEND", b""))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rgb-palette", type=Path, required=True)
    parser.add_argument("--reference", type=Path, help="image5.png: 4x capture cropped one pixel left and eight pixels top")
    args = parser.parse_args()
    records = json.loads((PROJECT / "data/rom_battle_stage_records.json").read_text())
    record = records["records"][0]
    chr_data = bytearray((REF / "rom_prg11_src_c64a_ppu_1000.bin").read_bytes())
    upload = (REF / "rom_battle_stage_00_chr_ppu_1010.bin").read_bytes()
    chr_data[16:16 + len(upload)] = upload
    palette = records["shared_battle_palette_packet"]["bytes"].copy()
    palette[8:16] = record["palette_packet"]["bytes"]
    rgb = bytearray(args.rgb_palette.read_bytes())
    report = {"pattern_source": "ROM uploads decoded with one initial length and contiguous 256-byte blocks", "reference": str(args.reference) if args.reference else None}
    if args.reference:
        width, height, rows = read_png(args.reference)
        if (width, height) != (1020, 894):
            raise ValueError("This reference alignment requires the supplied 1020x894 image5.png")
        counts = defaultdict(Counter)
        # Screen capture starts at logical x=1,y=8; capture scale is exactly 4.
        for y in range(8, 231):
            for x in range(1, 255):
                code = record["map_source_16x15"][y // 16][x // 16]
                quadrant = ((y % 16) // 8) * 2 + (x % 16) // 8
                tile = record["tile_compositions_2x2"][code][quadrant]
                offset, bit = tile * 16 + y % 8, 7 - x % 8
                color = ((chr_data[offset] >> bit) & 1) | (((chr_data[offset + 8] >> bit) & 1) << 1)
                sub = record["palette_index_grid_16x15"][y // 16][x // 16]
                index = palette[0] if color == 0 else palette[sub * 4 + color]
                counts[index][rows[(y - 8) * 4 + 2][x * 4 - 2]] += 1
        report["measured_palette"] = []
        for index, samples in sorted(counts.items()):
            value, count = samples.most_common(1)[0]
            rgb[index * 3:index * 3 + 3] = bytes(value)
            report["measured_palette"].append({"nes_index": index, "rgb": value, "matching_samples": count, "samples": samples.total()})
        # Original screenshot's red unit pixels use sprite color $26.
        rgb[0x26 * 3:0x26 * 3 + 3] = bytes((255, 117, 97))
    palette_path = REF / "rom_stage00_reference_display.pal"
    palette_path.write_bytes(rgb)
    subprocess.run([sys.executable, str(PROJECT / "research/tools/render/render_battle_stage_preview.py"), str(PROJECT / "data/rom_battle_stage_records.json"), str(REF / "rom_prg11_src_c64a_ppu_1000.bin"), str(REF / "rom_stage00_composed_stage_chr_candidate_color.png"), "--overlay-chr", str(REF / "rom_battle_stage_00_chr_ppu_1010.bin"), "--overlay-ppu-address", "0x1010", "--rgb-palette", str(palette_path)], check=True)
    shared = (REF / "rom_battle_shared_chr_00_ppu_1700.bin").read_bytes()
    # Bank 2 $B5D5 uploads four sprite palettes at $3F10. Palette 0 has
    # blue $11; palette 1 replaces only that color with red $26.
    sprite_palettes = {
        "player": palette[16:20],
        "enemy": palette[20:24],
    }
    sprite_records = []
    for name, tile_offsets in [("infantry", [0, 16, 128, 144]), ("mounted", [256, 272, 352, 368])]:
        for side, sprite_pal in sprite_palettes.items():
            pixels = bytearray(16 * 16 * 4)
            for q, offset in enumerate(tile_offsets):
                tile = shared[offset:offset + 16]
                for y in range(8):
                    for x in range(8):
                        color = (tile[y] >> (7 - x) & 1) | ((tile[y + 8] >> (7 - x) & 1) << 1)
                        if color:
                            index = sprite_pal[color]
                            at = (((q // 2) * 8 + y) * 16 + (q % 2) * 8 + x) * 4
                            pixels[at:at + 4] = rgb[index * 3:index * 3 + 3] + b"\xff"
            filename = f"rom_stage00_{name}_pose.png" if side == "enemy" else f"rom_stage00_{name}_{side}_pose.png"
            path = REF / filename
            write_png(path, 16, 16, pixels)
            sprite_records.append({"pose": name, "side_palette": side, "palette_nes_indices": sprite_pal, "file": path.name, "source_cpu_tiles": [f"${0x8326 + off:04X}" for off in tile_offsets], "source_bank": 4, "runtime_oam_selection": "not yet traced; red pose assembly matched pixel-for-pixel against screenshot"})
    report["sprites"] = sprite_records
    (REF / "rom_stage00_visual_provenance.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("Rebuilt ROM terrain and transparent 16x16 unit poses")


if __name__ == "__main__":
    main()
