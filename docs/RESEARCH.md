# ROM 逆向研究索引

主要研究日志是[《ROM 研究记录》](../research/ROM_RESEARCH.md)，其中记录 ROM 偏移、已解码程序、原版实机观察、复现实验方法和仍待确认的问题。阅读时也请参考[项目首页](../README.md)中的可玩版本状态：ROM 已确认的事实不一定都已在 Godot 中实现。

## 按主题查找

| 主题 | 主要资料 |
|---|---|
| 卡带结构、启动、PPU/CHR 加载、调色板和精灵解码 | [研究日志](../research/ROM_RESEARCH.md)、[研究工具](../research/tools/) |
| 战场地图与滚屏 | [19 关地图数据](../data/rom_battle_stage_records.json)、[ROM 参考素材](../assets/rom_reference/)、[19 关地图图集](map-gallery/) |
| 初始部署与武将记录 | [部署数据](../data/rom_stage_unit_layouts.json)、[武将槽位数据](../data/rom_unit_slot_records.json) |
| 经验、升阶和战役继承 | [成长数据](../data/rom_progression.json)、[经验实验轨迹](../research/evidence/traces/rom_experience_effect.tsv)、[成长提取脚本](../research/tools/extract/extract_rom_progression.py)、[FCEUX 实验脚本](../research/tools/fceux/fceux_experience_effect_trace.lua)、[战役成长逻辑](../scripts/campaign_progress.gd) |
| 移动力规则 | [关卡移动规则](../data/rom_stage_movement_rules.json)、[兵种数据](../data/rom_class_reference.json) |
| 回合调度、敌方决策和战斗结果 | [调度证据](../research/evidence/records/rom_action_scheduler_evidence.json)、[研究日志](../research/ROM_RESEARCH.md) |
| 治疗目标与范围 1/5/9 的执行 | [技术效果数据](../data/rom_technique_effects.json)、[治疗实验脚本](../research/tools/fceux/fceux_area_healing_effect_trace.lua)、[范围 5 轨迹](../research/evidence/traces/rom_area5_healing_effect.tsv)、[范围 9 轨迹](../research/evidence/traces/rom_area9_healing_effect.tsv) |
| 范围伤害与 25 号技能变体 2 | [伤害实验脚本](../research/tools/fceux/fceux_area_damage_effect_trace.lua)、[范围 5 轨迹](../research/evidence/traces/rom_area5_damage_effect.tsv)、[范围 9 轨迹](../research/evidence/traces/rom_area9_damage_effect.tsv)、[25 号技能轨迹](../research/evidence/traces/rom_skill25_variant2_damage_effect.tsv) |
| 玩家技术子菜单边界和输入 | [技术效果数据](../data/rom_technique_effects.json)（`player_variant_menu`）、[数据提取脚本](../research/tools/extract/extract_rom_technique_effects.py)、[研究日志](../research/ROM_RESEARCH.md) |
| 技术参数 | [技术效果数据](../data/rom_technique_effects.json) |
| 玩法、兵种成长和 ROM 技术解释 | [玩法与战役系统](GAMEPLAY_SYSTEMS.md)、[ROM 技术细节](ROM_TECHNICAL_DETAILS.md)、[兵种与技术参考](CLASS_AND_TECHNIQUE_REFERENCE.md) |
| PPU 数据流和回调证据 | [PPU 调用点](../research/evidence/records/rom_ppu_stream_call_sites.json)、[Mapper 15 回调](../research/evidence/records/rom_mapper15_callbacks.json) |
| 模拟器 RAM 截取 | [FCEUX 战斗 RAM 快照](../research/evidence/traces/fceux_battle_ram_snapshot.txt) |
| 最终关分支与复刻版通关流程 | [研究日志](../research/ROM_RESEARCH.md)（2026-10-06 最终关章节）、[通关逻辑](../scripts/campaign_ending.gd)、[通关阶段记录](milestones/BUILD_CAMPAIGN_COMPLETION_MILESTONE.md) |
| 原版结局回调、故事、制作人员名单和终幕 | [结局截取记录](../research/evidence/records/rom_ending_capture.json)、[FCEUX 追踪脚本](../research/tools/fceux/fceux_final_victory_trace.lua)、[结局画面](../assets/rom_reference/ending/)、[结局阶段记录](milestones/BUILD_ROM_ENDING_MILESTONE.md) |

JSON 文件是机器可读的提取结果；`research/tools/` 下的 Python 脚本记录数据来源，并可从原版 ROM 重建其中许多数据。`assets/rom_reference/` 保留游戏运行素材和 Godot 调试预览场景使用的 ROM 图集；单纯用于比对的模拟器截帧与运行截图已移到 `research/evidence/images/`，不会被 Godot 导入。

原版中文 ROM、说明书和转职流程表仍放在本 Git 仓库之外；说明书和 ROM 证据已综合整理为本仓库内的玩法、职业及技术细节文档。19 关地图候选图集也已收录，克隆仓库后可直接浏览。当前复刻版的限制请查看[项目首页](../README.md)及[研究日志](../research/ROM_RESEARCH.md)对应章节，不要将尚未验证的 Godot 行为当成原版逻辑。

自动回合逐步播放、原版调度证据和显示状态分离见[研究日志](../research/ROM_RESEARCH.md)（2026-10-05 章节），实际构建和设备验收见[逐步回合阶段记录](milestones/BUILD_TURN_PLAYBACK_MILESTONE.md)。当前兵种移动力、实时属性与伤害预览的数据关系见研究日志（2026-10-06 章节）和[战术操作阶段记录](milestones/BUILD_TACTICS_MILESTONE.md)。
