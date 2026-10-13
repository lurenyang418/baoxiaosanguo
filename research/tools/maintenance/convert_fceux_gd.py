#!/usr/bin/env python3
"""Convert FCEUX gui.gdscreenshot() true-color GD bytes to an RGB PNG."""
import argparse
import struct
import zlib
from pathlib import Path


def png_chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    return struct.pack('>I', len(data)) + body + struct.pack('>I', zlib.crc32(body) & 0xffffffff)


def convert(source: Path, target: Path) -> None:
    content = source.read_bytes()
    if len(content) < 11 or content[:2] != b'\xff\xfe':
        raise ValueError('Expected FCEUX true-color GD screenshot')
    width, height = struct.unpack('>HH', content[2:6])
    if width <= 0 or height <= 0 or len(content) != 11 + width * height * 4:
        raise ValueError('Invalid GD dimensions or pixel count')
    rgb = bytearray()
    for row in range(height):
        rgb.append(0)
        start = 11 + row * width * 4
        for col in range(width):
            offset = start + col * 4
            rgb.extend(content[offset + 1:offset + 4])
    target.write_bytes(b'\x89PNG\r\n\x1a\n' + png_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) + png_chunk(b'IDAT', zlib.compress(rgb, 9)) + png_chunk(b'IEND', b''))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('target', type=Path)
    args = parser.parse_args()
    convert(args.source, args.target)
