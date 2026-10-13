#!/usr/bin/env python3
"""Collect the 19 ROM-derived color map candidates into a review gallery."""

from __future__ import annotations

import json
import shutil
import struct
import zlib
from pathlib import Path

from render_sprite_palette_sheet import png_chunk


PROJECT = Path(__file__).resolve().parents[3]
SOURCE = PROJECT / "assets/rom_reference"
DEST = PROJECT / "docs/map-gallery"


def image_dimensions(path: Path) -> tuple[int, int]:
    header = path.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def raw_rgba(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    width, height = image_dimensions(path)
    if data[24:26] != bytes([8, 6]):
        raise ValueError(f"Expected 8-bit RGBA PNG: {path}")
    parts = []
    offset = 8
    while offset < len(data):
        length = int.from_bytes(data[offset : offset + 4], "big")
        if data[offset + 4 : offset + 8] == b"IDAT":
            parts.append(data[offset + 8 : offset + 8 + length])
        offset += length + 12
    raw = zlib.decompress(b"".join(parts))
    stride = width * 4
    if len(raw) != height * (stride + 1):
        raise ValueError(f"Unexpected PNG data length: {path}")
    for y in range(height):
        if raw[y * (stride + 1)] != 0:
            raise ValueError(f"Expected unfiltered ROM render PNG: {path}")
    return width, height, raw


DIGITS = {
    "0": ("111", "101", "101", "101", "111"),
    "1": ("010", "110", "010", "010", "111"),
    "2": ("111", "001", "111", "100", "111"),
    "3": ("111", "001", "111", "001", "111"),
    "4": ("101", "101", "111", "001", "001"),
    "5": ("111", "100", "111", "001", "111"),
    "6": ("111", "100", "111", "101", "111"),
    "7": ("111", "001", "001", "001", "001"),
    "8": ("111", "101", "111", "101", "111"),
    "9": ("111", "101", "111", "001", "111"),
}


def make_overview(images: list[Path], output: Path) -> None:
    columns, rows = 5, 4
    thumb_width, cell_height = 128, 382
    gap, margin, label_height = 8, 12, 22
    width = columns * thumb_width + (columns - 1) * gap + 2 * margin
    height = rows * cell_height + (rows - 1) * gap + 2 * margin
    pixels = bytearray(bytes([18, 24, 32, 255]) * (width * height))
    for stage, image in enumerate(images, start=1):
        source_width, source_height, source = raw_rgba(image)
        left = margin + ((stage - 1) % columns) * (thumb_width + gap)
        top = margin + ((stage - 1) // columns) * (cell_height + gap)
        for digit_index, digit in enumerate(f"{stage:02}"):
            for py, pattern in enumerate(DIGITS[digit]):
                for px, bit in enumerate(pattern):
                    if bit == "1":
                        for dy in range(2):
                            for dx in range(2):
                                dest = ((top + 4 + py * 2 + dy) * width + left + 5 + digit_index * 8 + px * 2 + dx) * 4
                                pixels[dest : dest + 4] = bytes([238, 240, 207, 255])
        for y in range(source_height // 2):
            source_row = (y * 2) * (source_width * 4 + 1) + 1
            dest_row = ((top + label_height + y) * width + left) * 4
            for x in range(thumb_width):
                source_pixel = source_row + x * 8
                dest_pixel = dest_row + x * 4
                pixels[dest_pixel : dest_pixel + 4] = source[source_pixel : source_pixel + 4]
    scanlines = b"".join(
        b"\x00" + pixels[y * width * 4 : (y + 1) * width * 4]
        for y in range(height)
    )
    output.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + png_chunk(b"IEND", b"")
    )


def main() -> None:
    records = json.loads((PROJECT / "data/rom_battle_stage_records.json").read_text())["records"]
    DEST.mkdir(exist_ok=True)
    manifest = []
    cards = []
    for stage_index, record in enumerate(records):
        source = SOURCE / (
            "rom_stage00_composed_stage_chr_candidate_color.png"
            if stage_index == 0
            else f"rom_battle_stage_candidate_{stage_index:02}_color.png"
        )
        target = DEST / f"{stage_index + 1:02}.png"
        width, height = image_dimensions(source)
        expected_height = record["map_world_dimensions"][1] * 16
        if (width, height) != (256, expected_height):
            raise ValueError(f"Stage {stage_index + 1} has unexpected image dimensions: {width}x{height}")
        shutil.copyfile(source, target)
        manifest.append(
            {
                "stage": stage_index + 1,
                "image": target.name,
                "source": str(source.relative_to(PROJECT)),
                "dimensions": [width, height],
                "map_cells": record["map_world_dimensions"],
                "vertical_scroll_limit_cells": record["vertical_scroll_limit_cells"],
                "status": "ROM-derived color candidate, not pixel-verified against live game",
            }
        )
        cards.append(
            f'<a class="card" href="{target.name}" target="_blank" download>'
            f'<span>第 {stage_index + 1:02} 关</span>'
            f'<img src="{target.name}" alt="第 {stage_index + 1} 关地图" loading="lazy">'
            f'<small>{width} × {height} 像素 · {record["map_world_dimensions"][0]} × '
            f'{record["map_world_dimensions"][1]} 格</small></a>'
        )

    (DEST / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    (DEST / "index.html").write_text(
        """<!doctype html>
<html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>爆笑三国 · 19 关 ROM 地图候选图</title>
<style>
html{background:#10141a;color:#e9edf2;font:16px system-ui,sans-serif}
body{max-width:1200px;margin:0 auto;padding:24px}
h1{font-size:26px;margin:0 0 8px}p{color:#bac4cf;line-height:1.6;max-width:900px}
a{color:inherit}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:16px;margin-top:24px}
.card{display:flex;flex-direction:column;gap:8px;background:#202832;padding:12px;border:1px solid #40505d;text-decoration:none}
.card:hover{border-color:#8fd4ee}.card span{font-weight:700}.card small{color:#bac4cf}
.card img{width:100%;height:auto;max-height:480px;object-fit:contain;object-position:top;background:#080b0e;image-rendering:pixelated}
</style>
<h1>爆笑三国 · 19 关地图</h1>
<p>按 ROM 地图数据合成的背景候选图，不含单位与界面。点击图片下载原生分辨率 PNG。
它们尚未逐关与原版实机画面对照，不能视为 100% 像素复刻。</p>
<p><a href="overview.png">打开全部地图总览图</a></p>
<div class="grid">"""
        + "\n".join(cards)
        + "</div></html>\n",
        encoding="utf-8",
    )
    make_overview([DEST / f"{number:02}.png" for number in range(1, 20)], DEST / "overview.png")
    print(f"Wrote {len(manifest)} native PNG maps, overview.png, index.html, and manifest.json to {DEST}")


if __name__ == "__main__":
    main()
