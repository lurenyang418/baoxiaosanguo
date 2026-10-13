#!/usr/bin/env python3
"""Crop verified first-battle combat pixels from FCEUX ROM captures.

The source PNGs are unscaled 256x240 captures from deterministic enemy and
player attacks in the supplied Chinese ROM. Black is transparent in the
cropped layers because the original combat screen has a black backdrop.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path


ASSETS = Path(__file__).resolve().parents[3] / "assets" / "rom_reference"
LAYERS = {
    "combat_roof_a.png": (4200, (0, 0, 256, 72)),
    "combat_roof_b.png": (4280, (0, 0, 256, 72)),
    "combat_figure_right_idle.png": (4200, (180, 148, 54, 58)),
    "combat_figure_right_throw.png": (4240, (180, 148, 54, 58)),
    "combat_figure_left_idle.png": (4280, (24, 148, 54, 58)),
    "combat_figure_left_run.png": (4320, (48, 148, 54, 58)),
    "combat_shoe.png": (4240, (154, 132, 32, 28)),
}
PLAYER_LAYERS = {
    "combat_player_roof_a.png": (3700, (0, 0, 256, 90)),
    "combat_player_roof_b.png": (3800, (0, 0, 256, 90)),
    "combat_player_roof_c.png": (3840, (0, 0, 256, 90)),
    "combat_player_left_idle.png": (3700, (48, 148, 52, 58)),
    "combat_player_left_throw.png": (3740, (46, 148, 52, 58)),
    "combat_player_shoe.png": (3760, (105, 110, 42, 45)),
    "combat_player_right_idle.png": (3840, (128, 148, 58, 58)),
    "combat_player_right_run.png": (3880, (160, 148, 58, 58)),
}
MOUNTED_LAYERS = {
    "combat_mounted_roof_a.png": (4680, (0, 0, 256, 90)),
    "combat_mounted_roof_b.png": (4760, (0, 0, 256, 90)),
    "combat_mounted_right_idle.png": (4680, (180, 148, 54, 58)),
    "combat_mounted_right_throw.png": (4700, (180, 148, 54, 58)),
    "combat_mounted_shoe.png": (4720, (128, 108, 48, 45)),
    "combat_mounted_left_idle.png": (4760, (45, 148, 54, 58)),
    "combat_mounted_left_hit.png": (4800, (45, 148, 54, 58)),
}


def chunk(kind: bytes, data: bytes) -> bytes:
    payload = kind + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)


def read_rgb(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    pos = 8
    compressed = bytearray()
    width = height = 0
    while pos < len(data):
        size = struct.unpack_from(">I", data, pos)[0]
        kind = data[pos + 4 : pos + 8]
        payload = data[pos + 8 : pos + 8 + size]
        pos += size + 12
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            if (depth, color, compression, filtering, interlace) != (8, 2, 0, 0, 0):
                raise ValueError("Expected an unscaled, noninterlaced RGB capture")
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    pixels = zlib.decompress(compressed)
    stride = width * 3
    if len(pixels) != (stride + 1) * height:
        raise ValueError("PNG scanline length does not match its dimensions")
    rows = []
    for y in range(height):
        row = pixels[y * (stride + 1) : (y + 1) * (stride + 1)]
        if row[0] != 0:
            raise ValueError("Expected PNG filter type 0 from the FCEUX capture converter")
        rows.append(row[1:])
    return width, height, b"".join(rows)


def crop_transparent(source: bytes, source_width: int, rect: tuple[int, int, int, int]) -> bytes:
    x, y, width, height = rect
    output = bytearray()
    for py in range(y, y + height):
        for px in range(x, x + width):
            start = (py * source_width + px) * 3
            rgb = source[start : start + 3]
            output.extend(rgb)
            output.append(0 if rgb == b"\x00\x00\x00" else 255)
    return bytes(output)


def write_rgba(path: Path, width: int, height: int, pixels: bytes) -> None:
    rows = b"".join(b"\x00" + pixels[y * width * 4 : (y + 1) * width * 4] for y in range(height))
    image = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(image)


def main() -> None:
    captures = {}
    for prefix, layers in (
        ("combat_capture_", LAYERS),
        ("combat_capture_player_", PLAYER_LAYERS),
        ("combat_capture_mounted_", MOUNTED_LAYERS),
    ):
        for name, (frame, rect) in layers.items():
            source_name = f"{prefix}{frame}.png"
            if source_name not in captures:
                captures[source_name] = read_rgb(ASSETS / source_name)
            source_width, source_height, source = captures[source_name]
            x, y, width, height = rect
            if x + width > source_width or y + height > source_height:
                raise ValueError(f"Crop outside capture: {name}")
            write_rgba(ASSETS / name, width, height, crop_transparent(source, source_width, rect))
            print(name, f"{width}x{height}")


if __name__ == "__main__":
    main()
