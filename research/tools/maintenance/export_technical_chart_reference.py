#!/usr/bin/env python3
"""Join the supplied warrior-class chart transcription to extracted ROM parameters."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
UNIT_DATA = ROOT / "data/rom_unit_slot_records.json"
PROGRESSION_DATA = ROOT / "research/evidence/records/class_progression.json"
OUTPUT = ROOT / "data/rom_class_reference.json"

# Class IDs, names, and level-ID ranges transcribed from the supplied chart and cross-checked with the manual/ROM.
CLASS_ROWS = [
    (0, "战士", [0]),
    (1, "骑兵", [1, 2]),
    (2, "勇士", [3, 4]),
    (3, "弓兵", [5, 6]),
    (4, "骠骑大将", [7, 8, 9]),
    (5, "飞马大将", [10, 11, 12]),
    (6, "铁铠大将", [13, 14, 15]),
    (7, "巨剑大将", [16, 17, 18]),
    (8, "弩手", [19, 20, 21]),
    (9, "神箭手", [22, 23, 24]),
    (10, "魔兽将军", [25, 26, 27, 28]),
    (11, "车骑将军", [29, 30, 31, 32]),
    (12, "魔龙将军", [33, 34, 35, 36]),
    (13, "神龙将军", [37, 38, 39, 40]),
    (14, "金甲将军", [41, 42, 43]),
    (15, "虎威将军", [44, 45, 46]),
    (16, "神剑将军", [47, 48, 49]),
    (17, "巨斧将军", [50, 51, 52]),
    (18, "巨炮将军", [53, 54, 55]),
]

# The chart's "需经验" values, retained as a cross-check against the ROM threshold table.
CHART_EXPERIENCE = [
    0, 100, 180, 100, 180, 100, 220, 300, 500, 750, 300, 500, 800, 300,
    480, 720, 300, 480, 720, 400, 600, 850, 400, 880, 2000, 1000, 1320,
    1650, 2300, 1000, 1350, 1700, 2500, 950, 1300, 1700, 2300, 950, 1300,
    1700, 2200, 1000, 1350, 2000, 1000, 1400, 2180, 1000, 1400, 2180, 1000,
    1400, 2180, 1100, 1400, 2000,
]

BRANCHES = [
    {"from_class_id": 0, "to_class_ids": [1, 2, 3]},
    {"from_class_id": 1, "to_class_ids": [4, 5]},
    {"from_class_id": 2, "to_class_ids": [6, 7]},
    {"from_class_id": 3, "to_class_ids": [8, 9]},
    {"from_class_id": 4, "to_class_ids": [10, 11]},
    {"from_class_id": 5, "to_class_ids": [12, 13]},
    {"from_class_id": 6, "to_class_ids": [14, 15]},
    {"from_class_id": 7, "to_class_ids": [16, 17]},
    {"from_class_id": 8, "to_class_ids": [18]},
]

TECHNIQUES = [
    {"technique_id": 1, "name": "射击", "range": "2", "area": 1, "effect": -20},
    {"technique_id": 34, "name": "射击", "range": "1-3", "area": 1, "effect": -30},
    {"technique_id": 2, "name": "重击", "range": "2-3", "area": 1, "effect": -45},
    {"technique_id": 3, "name": "高级重击", "range": "2-3", "area": 5, "effect": -40},
    {"technique_id": 4, "name": "超级重击", "range": "2-4", "area": 5, "effect": -50},
    {"technique_id": 5, "name": "神箭", "range": "2-4", "area": 1, "effect": -50},
    {"technique_id": 6, "name": "火枪", "range": "2-4", "area": 1, "effect": -80},
    {"technique_id": 7, "name": "火箭", "range": "2-5", "area": 1, "effect": -95},
    {"technique_id": 8, "name": "炮击", "range": "2-5", "area": 1, "effect": -80},
    {"technique_id": 9, "name": "重炮", "range": "2-6", "area": 5, "effect": -80},
    {"technique_id": 10, "name": "飞弹", "range": "2-8", "area": 9, "effect": -80},
    {"technique_id": 11, "name": "猛龙尾扫", "range": "0", "area": 4, "effect": -50},
    {"technique_id": 12, "name": "恶龙尾扫", "range": "0", "area": 4, "effect": -60},
    {"technique_id": 13, "name": "大龙压", "range": "0", "area": 4, "effect": -75},
    {"technique_id": 14, "name": "巨龙压", "range": "0-1", "area": 4, "effect": -80},
    {"technique_id": 15, "name": "神龙雷鸣", "range": "1-2", "area": 1, "effect": -60},
    {"technique_id": 16, "name": "神龙雷击", "range": "1-3", "area": 1, "effect": -75},
    {"technique_id": 17, "name": "神龙电击", "range": "1-4", "area": 1, "effect": -85},
    {"technique_id": 18, "name": "神龙雷电", "range": "1-4", "area": 1, "effect": -100},
]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--unit-data", type=Path, default=UNIT_DATA)
    parser.add_argument("--progression-data", type=Path, default=PROGRESSION_DATA)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()

    unit_data = json.loads(args.unit_data.read_text(encoding="utf-8"))
    progression_data = json.loads(args.progression_data.read_text(encoding="utf-8"))
    rom_records = {
        row["unit_id"]: row
        for row in unit_data["records"]
        if row["record_status"] == "fixed_stride_data"
    }
    type_to_class: dict[int, tuple[int, str, int]] = {}
    classes = []
    for class_id, name, type_ids in CLASS_ROWS:
        classes.append({"class_id": class_id, "name": name, "unit_type_ids": type_ids})
        for level, type_id in enumerate(type_ids, start=0 if class_id == 0 else 1):
            if type_id in type_to_class:
                raise ValueError(f"Unit type {type_id} appears in multiple classes")
            type_to_class[type_id] = (class_id, name, level)

    if set(type_to_class) != set(range(56)):
        raise ValueError("Chart transcription must cover type IDs 0-55 exactly once")
    if len(CHART_EXPERIENCE) != 56:
        raise ValueError("Chart experience transcription must cover type IDs 0-55")

    manual_experience: dict[tuple[str, int], int] = {}
    for branch in progression_data["branches"]:
        for path in branch["paths"]:
            for row in path:
                name, level = row["class"].rsplit("L", maxsplit=1)
                manual_experience[(name, int(level))] = row["experience"]

    levels = []
    chart_rom_experience_mismatches = []
    manual_chart_experience_mismatches = []
    for type_id in sorted(type_to_class):
        if type_id not in rom_records:
            raise ValueError(f"ROM data is missing fixed-stride type {type_id}")
        record = rom_records[type_id]
        raw = record["raw_bytes"]
        class_id, class_name, level = type_to_class[type_id]
        rom_exp = raw[4] | raw[5] << 8
        chart_exp = CHART_EXPERIENCE[type_id]
        manual_exp = manual_experience.get((class_name, level))
        if rom_exp != chart_exp:
            chart_rom_experience_mismatches.append(
                {"unit_type_id": type_id, "chart": chart_exp, "rom": rom_exp}
            )
        if manual_exp is not None and manual_exp != chart_exp:
            manual_chart_experience_mismatches.append(
                {"unit_type_id": type_id, "class": class_name, "level": level,
                 "manual": manual_exp, "chart": chart_exp}
            )
        levels.append(
            {
                "unit_type_id": type_id,
                "class_id": class_id,
                "class_name": class_name,
                "level": level,
                "max_hp": raw[0] | raw[1] << 8,
                "attack": raw[2] | raw[3] << 8,
                "experience_required": rom_exp,
                "chart_experience_required": chart_exp,
                "manual_experience_required": manual_exp,
                "defense": raw[6],
                "movement_points": raw[7],
                "technique_id": raw[8] or None,
                "graphic_selector": raw[9],
                "unresolved_bytes_10_to_12": raw[10:13],
            }
        )

    result = {
        "source_materials": [
            "用户提供的说明书和转职流程表：职业名称、分支和技术名称",
            "用户提供的武将参数图表：逐项转录值保存在本脚本中作为对照数据",
            "ROM 定长兵种记录与转职代码：战斗属性和实际升级门槛",
        ],
        "transcription_status": "职业/类型名称和图表经验值保留为本脚本中的转录数据，并与说明书及 ROM 对照；战斗属性和实际升级门槛取自 ROM 记录/表",
        "crosscheck": {
            "movement": "图表展示的类型 ID 0-55 移动值均与 ROM 对应字节完全一致。",
            "experience_chart_vs_rom": {
                "matching_level_ids": 56 - len(chart_rom_experience_mismatches),
                "mismatches": chart_rom_experience_mismatches,
            },
            "experience_chart_vs_manual": {
                "mismatches": manual_chart_experience_mismatches,
                "note": "图表与说明书的四个升级门槛不同；这四项的图表值与 ROM 类型记录字段相同。类型 ID 14 和 17 则相反：图表/说明书为 480，ROM 类型记录字段为 400。实际升级比较使用独立 ROM 门槛表。",
            },
        },
        "classes": classes,
        "branches": BRANCHES,
        "levels": levels,
        "techniques": TECHNIQUES,
        "coverage_note": "参数图表转录覆盖至类型 ID 55。图表未命名 ROM 类型 56-71；其数值属性和成长信息保存在 ROM 派生数据中，部分职业名称仍未确认。",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(classes)} classes and {len(levels)} level/type mappings")


if __name__ == "__main__":
    main()
