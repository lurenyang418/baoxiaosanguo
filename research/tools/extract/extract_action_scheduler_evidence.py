#!/usr/bin/env python3
"""Record ROM bytes that expose the battle action-list and phase loop."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


HEADER_SIZE = 16
BANK_SIZE = 0x4000


def bank_bytes(image: bytes, bank: int, address: int, length: int) -> bytes:
    base = 0x8000 if address < 0xC000 else 0xC000
    offset = HEADER_SIZE + bank * BANK_SIZE + address - base
    result = image[offset : offset + length]
    if len(result) != length:
        raise ValueError(f"Bank {bank} ${address:04X} is truncated")
    return result


def window(image: bytes, bank: int, start: int, end: int, meaning: str) -> dict:
    return {
        "bank": bank,
        "cpu_start": f"${start:04X}",
        "cpu_end_exclusive": f"${end:04X}",
        "bytes_hex": bank_bytes(image, bank, start, end - start).hex(" "),
        "meaning": meaning,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("canonical_rom", type=Path)
    parser.add_argument("--output", type=Path, default=Path("research/evidence/records/rom_action_scheduler_evidence.json"))
    args = parser.parse_args()
    image = args.canonical_rom.read_bytes()
    if image[:4] != b"NES\x1a":
        raise ValueError("Not an iNES ROM")

    result = {
        "source": str(args.canonical_rom),
        "action_list": {"count_ram": "$6822", "slot_array_ram": "$6816", "current_slot_ram": "$6408"},
        "unit_state_ram": "$6789 + slot",
        "evidence_windows": [
            window(image, 0, 0x8159, 0x817F, "Outer campaign loop handles first-slot defeat and increments stage index after success"),
            window(image, 8, 0x8135, 0x8144, "Initialize all $6789 slot states to zero"),
            window(image, 8, 0x806C, 0x8078, "Copy stage-layout Y then X bytes to $648F and $64B7"),
            window(image, 2, 0x886C, 0x8882, "Render $648F with vertical scroll and $64B7 on the other axis"),
            window(image, 2, 0x8175, 0x817A, "Zero action-list count during battle setup"),
            window(image, 10, 0x81BD, 0x81D1, "Confirmed menu index 0 sets result $FD"),
            window(image, 2, 0x8300, 0x8336, "Check current slot against list; append on one path"),
            window(image, 2, 0x833E, 0x835A, "One battle-loop call to the stage-specific $9AA2 result routine"),
            window(image, 2, 0x8361, 0x838B, "After each action, add defeated player slots to the $6822 processed count; when the sum reaches $6413, branch to $8563 and advance the phase automatically"),
            window(image, 2, 0x84A4, 0x84D5, "Check $FD menu result; start whole-army slot loop"),
            window(image, 2, 0x8501, 0x8560, "Continue slot loop, list checks and appends"),
            window(image, 2, 0x8559, 0x8575, "Second battle-loop call to $9AA2 and immediate $05CC=$FF exit check"),
            window(image, 2, 0x8571, 0x8583, "Clear $6789 state 1 for one slot group"),
            window(image, 2, 0x8586, 0x85A1, "Run opponent phase, then inspect victory and first-slot defeat flags"),
            window(image, 2, 0x85A3, 0x85D5, "Update state, clear count, seek next live slot"),
            window(image, 2, 0x9312, 0x9339, "Set $6814 on first player death; set $6815 when group 2 is gone"),
            window(image, 2, 0x9AA2, 0x9AF0, "Stage 4 first player Y <15, stage 5 Y =29, stage 8 Y <13 with X >=12, and stage 11 first group-2 slot state $FF set the special exit flag"),
            window(image, 2, 0xA764, 0xA839, "Automatic processing of group 1 and handoff to group 2"),
            window(image, 2, 0xA7B7, 0xA818, "Group-1 low-HP frame rest and selector-table skill-versus-adjacent dispatch"),
            window(image, 2, 0xAA40, 0xAA44, "Group-1 graphic selector special table includes selector 3 for type 5"),
            window(image, 2, 0xAAC0, 0xAB3A, "Group-1 adjacent-target scan begins after player and group-1 slots, targeting group 2"),
            window(image, 2, 0xAC90, 0xACB0, "Group-1 range scan initializes its type-indexed range and area"),
            window(image, 2, 0xAE6F, 0xAEBE, "Group-1 technique dispatch uses range scan and skill packet variant"),
            window(image, 2, 0xAED4, 0xAEDA, "Group-1 ordinary attack dispatch scans group-2 targets"),
            window(image, 2, 0xB4F3, 0xB5B3, "Group-1 no-target movement seeks first available group-2 slot and compares coordinates"),
            window(image, 2, 0xA839, 0xAA36, "Group-2 decision tree; stages 0 and 1 both use this path"),
            window(image, 2, 0xA954, 0xA97A, "AI flag low nibble 2 compares player Y against $67D9 alert edge and can enter $A88B; $A970 separately sends types below $38 to $A9A4, including type 2"),
            window(image, 2, 0xA88B, 0xA8C0, "Low-nibble-1 units' one-third-HP rest gate; stage 0 has two such slots"),
            window(image, 2, 0xA8C0, 0xA955, "Low-nibble-1 units' high-HP target and movement/technique dispatch"),
            window(image, 2, 0xA8E8, 0xA918, "Stage-0 $67B1 flag $01 invokes $AD30 target scan; absent target invokes $AEDA movement"),
            window(image, 2, 0xAC02, 0xAC03, "Type-0 range table entry is zero"),
            window(image, 2, 0xAC49, 0xAC4A, "Type-0 area table entry is zero"),
            window(image, 2, 0xAE0C, 0xAE1B, "Technique executor immediately returns when type-0 skill ID is zero"),
            window(image, 3, 0xF630, 0xF639, "Frame routine increments $05D4, whose low bit steers some AI target scans"),
            window(image, 2, 0xA9A4, 0xAA1F, "Common group-2 branch in stages 0-2: one-third HP gate, adjacent target scan, ordinary attack"),
            window(image, 2, 0xA970, 0xA9A4, "Type >= $38 uses the friendly wounded-unit $AD30 scan when the high AI flag nibble is zero; otherwise NES frame parity chooses player/group-1 attack scans"),
            window(image, 2, 0xAD30, 0xADF6, "High-type friendly-target search scans group-2 slots, permits self, rejects full HP, and selects the lowest-HP in-range candidate"),
            window(image, 8, 0x96C7, 0x9796, "Healing area 5 selects center and same-faction orthogonal neighbors; damage uses opposing faction"),
            window(image, 8, 0x9796, 0x98AB, "Area 9 additionally includes four diagonal neighbors, with selected center first"),
            window(image, 8, 0x9A69, 0x9AC3, "Techniques 19-33 with variant zero add the effect magnitude to HP and clamp to maximum; technique 34 uses another path"),
            window(image, 2, 0xA9D3, 0xAA1F, "Common-branch skill user tries range cast on one frame parity, then adjacent basic attack or wounded rest"),
            window(image, 2, 0xAC07, 0xAC08, "Type-5 technique range table entry is two cells"),
            window(image, 2, 0xAC4E, 0xAC4F, "Type-5 technique area table entry is one target"),
            window(image, 8, 0x903F, 0x906F, "Technique packet loader selects a variant using $05CD and stores effect magnitude in $05EB"),
            window(image, 8, 0x9155, 0x9199, "Pointers to 34 technique packets"),
            window(image, 8, 0x9199, 0x919C, "Technique 1 packet: 20 effect magnitude, range two, area one"),
            window(image, 8, 0x91CF, 0x91D7, "Technique 19 variants: 20/25 effect magnitude, range 2, area 1"),
            window(image, 8, 0x9AC3, 0x9B57, "Damage iterates the selected list, subtracts $05EB independently, clamps underflow and retires exact-zero HP targets"),
            window(image, 2, 0xB5B3, 0xB5BA, "Enemy low-HP action calls the ordinary rest routine"),
            window(image, 2, 0xAA44, 0xAABE, "Collect orthogonally adjacent player/group-1 target slots"),
            window(image, 2, 0x9A24, 0x9A7B, "Choose lowest-current-HP candidate, preserving first slot on ties"),
            window(image, 2, 0xAEBE, 0xAED4, "Execute ordinary attack when adjacent target is available"),
            window(image, 2, 0xAEDA, 0xAF90, "Movement routine begins by locating a player slot and choosing direction"),
            window(image, 2, 0xAF90, 0xB020, "Movement attempts use terrain checks and scroll state"),
            window(image, 2, 0xB488, 0xB4AC, "Movement routine writes final X/Y unit coordinates"),
            window(image, 2, 0x8867, 0x88DC, "Rest: divide max HP by 8, add to current HP, cap at maximum"),
            window(image, 2, 0x9DE2, 0x9E1F, "Unsigned 16-bit integer division used by rest and damage"),
            window(image, 8, 0x9AC0, 0x9B04, "Write state 1 on one result path; write $FF when HP underflows"),
            window(image, 2, 0x8FF0, 0x9001, "Write $FF to defeated target state"),
            window(image, 2, 0xA2B8, 0xA2DF, "Check slot-list membership when writing unit state"),
        ],
        "unresolved": [
            "Full meaning and entry paths for temporary $6789 state 1",
            "Exact movement route and nearby-target behavior of the two stage-0 low-nibble-1 units",
            "Exact $AB3A target filtering, other technique branches, and complete frame-dependent phase timing",
            "Outcome transition and next-stage roster carryover after $839D",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
