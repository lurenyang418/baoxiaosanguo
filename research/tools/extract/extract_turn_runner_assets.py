#!/usr/bin/env python3
"""Isolate the first turn runners from verified FCEUX frames.

Stable stage-0 frames 3860 and 4900 are the backgrounds for the enemy and
player sequences respectively. Each later capture is compared with its
background so the moving character retains the ROM's pixels while the map
becomes transparent. Source captures stay in rom_reference.
"""

from pathlib import Path

from extract_combat_capture_assets import read_rgb, write_rgba


ASSETS = Path(__file__).resolve().parents[3] / "assets" / "rom_reference"
SEQUENCES = (
    ("enemy", "turn_capture_", 3860, (3880, 3900, 3920, 3940, 3960, 3980, 4000)),
    ("player", "turn_capture_player_", 4900, (4920, 4940, 4960, 4980, 5000, 5020, 5040)),
)


def main() -> None:
    for side, prefix, background_frame, frames in SEQUENCES:
        width, height, background = read_rgb(ASSETS / f"{prefix}{background_frame}.png")
        for frame in frames:
            frame_width, frame_height, image = read_rgb(ASSETS / f"{prefix}{frame}.png")
            if (frame_width, frame_height) != (width, height):
                raise ValueError(f"Unexpected capture size at frame {frame}")
            changed = [i for i in range(width * height) if image[3 * i:3 * i + 3] != background[3 * i:3 * i + 3]]
            if not changed:
                raise ValueError(f"No runner pixels at frame {frame}")
            left = min(i % width for i in changed)
            top = min(i // width for i in changed)
            right = max(i % width for i in changed) + 1
            bottom = max(i // width for i in changed) + 1
            output = bytearray()
            for y in range(top, bottom):
                for x in range(left, right):
                    i = y * width + x
                    output.extend(image[3 * i:3 * i + 3])
                    output.append(255 if image[3 * i:3 * i + 3] != background[3 * i:3 * i + 3] else 0)
            name = f"turn_runner_{side}_{frame}.png"
            write_rgba(ASSETS / name, right - left, bottom - top, bytes(output))
            print(name, f"{left},{top} {right - left}x{bottom - top}")


if __name__ == "__main__":
    main()
