#!/usr/bin/env python3
"""Extract the four bank-6 8x8 glyph pages referenced by the ROM."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import zlib
from pathlib import Path

HEADER_SIZE = 16
PRG_BANK_SIZE = 0x4000
FONT_BANK = 6
POINTER_TABLE_CPU = 0x8586
PAGE_COUNT = 4
TILES_PER_PAGE = 128
TILE_BYTES = 16
TILE_SIZE = 8
PAGE_COLUMNS = 16


def png_chunk(kind: bytes, payload: bytes) -> bytes:
	data = kind + payload
	return struct.pack("!I", len(payload)) + data + struct.pack("!I", zlib.crc32(data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, rgb: bytes) -> None:
	rows = b"".join(b"\0" + rgb[y * width * 3 : (y + 1) * width * 3] for y in range(height))
	png = b"\x89PNG\r\n\x1a\n"
	png += png_chunk(b"IHDR", struct.pack("!2I5B", width, height, 8, 2, 0, 0, 0))
	png += png_chunk(b"IDAT", zlib.compress(rows, 9))
	png += png_chunk(b"IEND", b"")
	path.write_bytes(png)


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("rom", type=Path, help="Local iNES ROM")
	parser.add_argument("out_dir", type=Path, help="Output directory for research artifacts")
	args = parser.parse_args()

	rom = args.rom.read_bytes()
	if rom[:4] != b"NES\x1a":
		raise ValueError("Not an iNES ROM")
	bank_offset = HEADER_SIZE + FONT_BANK * PRG_BANK_SIZE
	bank = rom[bank_offset : bank_offset + PRG_BANK_SIZE]
	if len(bank) != PRG_BANK_SIZE:
		raise ValueError(f"ROM does not contain PRG bank {FONT_BANK}")

	pages = []
	for page in range(PAGE_COUNT):
		table_offset = POINTER_TABLE_CPU - 0x8000 + page * 2
		pointer = int.from_bytes(bank[table_offset : table_offset + 2], "little")
		if not 0x8000 <= pointer < 0xC000:
			raise ValueError(f"Page {page} pointer ${pointer:04X} is outside bank window")
		offset = pointer - 0x8000
		data = bank[offset : offset + TILES_PER_PAGE * TILE_BYTES]
		if len(data) != TILES_PER_PAGE * TILE_BYTES:
			raise ValueError(f"Page {page} at ${pointer:04X} is truncated")
		pages.append((pointer, data))

	page_width = PAGE_COLUMNS * TILE_SIZE
	page_height = (TILES_PER_PAGE // PAGE_COLUMNS) * TILE_SIZE
	width, height = page_width * 2, page_height * 2
	pixels = bytearray(width * height * 3)
	for page_index, (pointer, data) in enumerate(pages):
		page_x = (page_index % 2) * page_width
		page_y = (page_index // 2) * page_height
		for tile_index in range(TILES_PER_PAGE):
			tile = data[tile_index * TILE_BYTES : (tile_index + 1) * TILE_BYTES]
			for y in range(TILE_SIZE):
				plane0, plane1 = tile[y], tile[y + TILE_SIZE]
				for x in range(TILE_SIZE):
					bit = 7 - x
					value = ((plane0 >> bit) & 1) | (((plane1 >> bit) & 1) << 1)
					shade = value * 85
					px = page_x + (tile_index % PAGE_COLUMNS) * TILE_SIZE + x
					py = page_y + (tile_index // PAGE_COLUMNS) * TILE_SIZE + y
					at = (py * width + px) * 3
					pixels[at : at + 3] = bytes((shade, shade, shade))

	args.out_dir.mkdir(parents=True, exist_ok=True)
	image_path = args.out_dir / "rom_bank6_glyph_pages.png"
	manifest_path = args.out_dir / "rom_bank6_glyph_pages.json"
	write_png(image_path, width, height, pixels)
	manifest_path.write_text(
		json.dumps(
			{
				"rom_sha256": hashlib.sha256(rom).hexdigest(),
				"source_prg_bank": FONT_BANK,
				"pointer_table_cpu": f"${POINTER_TABLE_CPU:04X}",
				"tile_encoding": "NES 2bpp, 8x8 pixels, 16 bytes per tile",
				"tiles_per_page": TILES_PER_PAGE,
				"atlas_layout": "four pages in a 2x2 grid; each page is 16x8 tiles",
				"pages": [
					{
						"page_index": i,
						"pointer_cpu": f"${pointer:04X}",
						"source_prg_offset": f"${pointer - 0x8000:04X}",
						"atlas_origin_tiles": [i % 2 * PAGE_COLUMNS, i // 2 * (TILES_PER_PAGE // PAGE_COLUMNS)],
						"tile_id_range": [i * TILES_PER_PAGE, (i + 1) * TILES_PER_PAGE - 1],
						"all_zero": not any(data),
					}
					for i, (pointer, data) in enumerate(pages)
				],
				"interpretation": "Candidate dynamic text glyph pages based on visual contents and bank-6 PPU upload references; not yet linked to individual title or battle strings.",
			},
			ensure_ascii=False,
			indent=2,
		)
		+ "\n",
		encoding="utf-8",
	)
	print(f"Wrote {image_path} and {manifest_path}")


if __name__ == "__main__":
	main()
