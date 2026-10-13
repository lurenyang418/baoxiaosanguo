# ROM 逆向研究记录

> 本文按研究过程持续累积，包含代码地址、实验输出和历史判断。较早的技术记录仍有英文段落；后续整理时应以本文现有的中文结论和较新的勘误为准。

本文命令及相对项目路径均假设从项目根目录执行。

## 研究总览（中文）

这份日志按逆向过程记录 ROM 地址、实验步骤和阶段性判断。以下是目前较重要的结论；详细地址与实验记录见后续对应章节。

- **战场地图是纵向滚动的。** 19 关记录中的地图页按上下方向拼接，世界地图为 16×30 或 16×45 格；屏幕一次显示 256×240 区域。此前将地图理解为横向滚动的结论已由部署位置和原版截图推翻。
- **地图、部署和移动规则已有 ROM 派生数据。** `data/rom_battle_stage_records.json`、`data/rom_stage_unit_layouts.json` 与 `data/rom_stage_movement_rules.json` 保存关卡地图、初始单位及可通行格信息。游戏还要求目的地存在不穿墙、不穿过单位的路径；这部分逐格移动逻辑仍是复刻版近似实现。
- **玩家行动结束条件已查明。** ROM 维护已行动单位列表；所有存活玩家单位完成行动后自动进入下一阶段。“全军休息”会让剩余可行动单位休息并提前结束本方行动。
- **单位休息恢复 HP 的计算已解码。** 恢复量为最大 HP 的整数八分之一，结果不超过最大 HP。第一关普通 type-0 单位最大 HP 为 100 时恢复 12。
- **敌方 AI 仅部分还原。** 已定位友军与敌军处理循环、若干低 HP 休息/邻接攻击/治疗分支，并通过 FCEUX 轨迹观察第一关部分敌人移动。不同兵种、关卡和特殊技术的完整选择逻辑仍未全部解出。
- **战场和单位图形来自 ROM 解码。** 玩家/敌方调色板候选、PPU 数据流、CHR 图块及若干开场、战斗、回合和结局画面均有提取记录。部分地图背景、角色动作和动画仍为近似或不完整素材。
- **技术系统已提取部分参数。** `data/rom_technique_effects.json` 保存技术菜单边界和部分效果数据；治疗、单体/范围伤害的目标筛选与若干伤害分支已有实验轨迹。原版菜单语义、资源消耗、特殊状态与全部变体仍待验证。
- **经验与升阶规则已有数据和实现。** 经验门槛、奖励、升阶分支、当前 HP 保留及跨关队伍继承已记录；部分规则有静态解码或受控模拟器轨迹支撑，但不是完整自然通关录像。
- **第 19 关后的原版结局分支已通过受控流程采样。** 结局截图、制作人员名单和终幕来自 FCEUX 控制实验；实验直接设置关卡状态，不证明复刻版已自然通关 19 关。
- **证据目录与工具分工见** [研究资料目录说明](README.md)，按主题查找数据见[研究索引](../docs/RESEARCH.md)。原版 ROM 不存放在本仓库中；实验重放需要使用工作区中已有的 ROM 文件。


原版 ROM 文件名： `BaoXiaoSanGuo(ES1005)(ChS)(970261).nes`

## 勘误：纵向战场地图与连续 CHR 上传（2026-10-03）

### 地图滚动分页

Record byte 3 is 15 or 30 in the 19 battle records. Stage 0 uses 15, matching
live `$6801=$0F`. Each map pointer leads to contiguous 16×15 pages: two for a
15-cell vertical scroll limit, three for 30. Stage 0's first page occupies
`$B9BD–$BAAC` and its second `$BAAD–$BB9C`. The page bytes must be stacked
vertically. The resulting world grids are 16×30 or 16×45, and the generated
PNGs are 256×480 or 256×720. Godot draws a 256×240 window into them with a
vertical offset of 0–15 or 0–30.

The decisive cross-check is the stage-0 deployment stream. Its first position
byte is world Y and the second is world X. Group-2 entries `(raw 4,8)`,
`(13,7)`, `(9,8)`, and the rest become exactly the eight unit positions in
`image5.png` when read as `(X,Y)=(8,4),(7,13),(8,9),...`. The player entries
become `(7,25),(8,26),(7,27)` on the lower page. The old horizontal reading
put the players to the right and falsely treated the screenshot units as
unrelated to the ROM layout. All 19 layout exports and map previews have been
regenerated with the corrected axes. The earlier horizontal interpretations
later in this research log are superseded.

The default Godot scene now scrolls down to the ROM player deployments. Their
type-0 movement allowance is 2. Its 移动 command checks Manhattan distance,
the stage-0 passable map-code list, and occupancy. It now also requires a
shortest orthogonal path through passable, unoccupied cells within the unit's
movement budget, and paints only those reachable destinations green. That path
constraint is a Godot gameplay approximation; the ROM's exact stepwise cursor
and movement-cost behavior still need a runtime trace. Godot loads JSON numbers as
floating values, so scenes compare terrain-code integers explicitly.
The first player at (7,25) can advance along ROM-passable column 7 to (7,14)
using six moves of at most two cells, then attack the ROM enemy at (7,13).
Godot headless input replay confirms target HP 100→80. The canonical action
list is now partly traced from ROM code (details below). A separate Godot
path probe rejects stage-0 (7,0)→(9,0), whose intervening (8,0) is blocked,
while allowing (7,0)→(6,0); stage-1 (9,27)→(9,25) remains valid. The demo records
each acting player unit in an ordered list after movement, attack, or
individual rest; 全军休息 automatically rests living player units absent from
the list, clears it, and starts another demo player turn.
A seven-turn input replay reached (7,14) and dealt the first hit in the
earlier stationary prototype. The first-stage enemy movement branch is now
partly implemented as described below, so those exact turn coordinates are
historical rather than a current walkthrough.
The first battle's victory predicate is now identified in the ROM (details
below): all group-2 opponents removed. Godot displays a first-battle victory
panel after all eight reach zero HP. It does not yet perform the ROM's stage
transition screens; pressing A opens a second-battle Godot slice using its
ROM map and deployments. A headless check confirms the last kill sets the panel state and
the dead unit no longer occupies/selects its cell.
A passable-cell reachability check from (7,25), treating living units as
occupied, finds an adjacent attack tile for a remaining opponent at every
step when defeated opponents vacate their cells. Thus all eight can be
approached in the current demo map; this is a reachability result, not a
reconstruction of the original AI or turn scheduler.

The bank-2 `$B5D5` palette packet gives sprite palette 0 as
`[$10,$20,$11,$0E]` (blue) and palette 1 as `[$10,$20,$26,$0E]` (red).
The screenshot's red units match palette 1. Godot now renders player
deployments with palette 0 and opposing/screenshot units with palette 1,
using the same ROM CHR pixels. The faction-to-palette association for all
runtime states remains to be confirmed from an emulator capture.

### 原版 ROM 的已行动单位列表

Bank 2 `$8300–$8335` reads `$6822` as a count and compares the current unit
slot in `$6408` against `$6816,X` for each entry. On one path it writes that
slot to `$6816 + $6822` and increments `$6822`. Other append sites include
`$84C0`, `$84E2`, `$8509`, `$8547`, `$8852`, `$8B49`, and `$8D74`.
The list is therefore an action/processed-unit set, rather than a Boolean
stored separately for each unit. At `$85BD`, the original code zeroes
`$6822` during a phase transition. `$A2B8–$A2DE` also checks list membership
while drawing a unit state.

Bank 2 `$8361–$838A` also answers when a turn ends. After each action it
copies `$6822` to `$05C7`, adds one for each player slot whose `$6789` state
is `$FF`, and compares the result with the player count `$6413`. If the sum
reaches that count, `$8385` jumps to `$8563`, beginning the next phase;
otherwise `$8388` returns to the input loop. Thus a normal turn advances
automatically once all living player units have acted. `全军休息` is the
separate command for ending earlier and resting the remaining eligible
units. Godot now follows this boundary, checking after each successful
move, attack, technique, or rest; a first-stage three-unit probe advanced
on the third action, and a later-stage one-unit party advanced on its
first action.

The phase path is more specific than the earlier inference. Bank 10
`$81C0–$81CD` writes `$FD` to `$05CD` when the confirmed system-menu index
`$05CC` is zero, the first item (`全军休息`). Bank 2 `$84A4` tests that result.
On `$FD`, the
routine begins at slot zero (`$6408`), branches on the existing `$6822` count,
and loops through slots bounded by `$6413` (`$84B3–$8560`). It inspects each
slot's `$6789,X` state, calls `$998D` and `$8867` on one path, and appends
slots to the same `$6816` list. After the loop, `$8563–$85D4` invokes
additional handling, updates `$6789`, clears `$6822` at `$85BD`, seeks a
non-`$FF` slot, and returns to the input loop at `$8175`. The whole-army
processing path thus precedes the action-list reset. The meaning of `$6789`
states, decision routine, and timing of
opponent actions still need a live RAM trace; this static path does not yet
justify a particular enemy movement policy.

The slot-state array has additional independent evidence. Bank 8
`$8137–$8142` initializes `$6789,X` to `0` for all slots. Bank 2
`$8FF4–$8FFA` writes `$FF` to `$6789,Y` when a target is defeated; bank 8
`$9AFC–$9B01` does likewise when HP is reduced below zero on its result
path. Bank 2 `$8574–$857F` and `$85A7–$85B2` turn state `1` back to `0`
for two slot groups during the phase flow. Bank 8 `$9AC9–$9AD5` writes `1`
on one result path. This proves `0` is the initialized state, `$FF` marks
removed/defeated slots, and `1` is a temporary state that is cleared at a
phase boundary. It does not yet prove that every move, attack, or rest writes
`1`; the ordered `$6816` list remains the firmer evidence for action gating.

### 单个单位休息后的 HP 恢复

The bank-2 `$8867–$88DB` routine reads the selected slot's 16-bit maximum HP
from `$6557/$6558,X` into `$0604/$0605`, divides it by 8 via `$9DE2` (an
unsigned integer quotient), then adds that quotient to current HP
`$65A7/$65A8,X`. It clamps the result to maximum HP. For a type-0 unit with
100 max HP this heals 12 HP, or less near the cap. The Godot battle menu's
休息 command now applies this exact HP arithmetic, marks that unit acted, and
shows current/max HP when the unit is selected. In the confirmed `全军休息`
path, bank 2 `$8501–$855C` checks each unit against the acted list and calls
`$8867` for a unit that is still eligible. The demo now automatically applies
this HP recovery to its living, unacted player units before refreshing their
actions. The next step runs the decoded stage-0 adjacent-attack subset;
other opponent actions and secondary effects remain unimplemented.

The missing opponent phase has a concrete entry point. Bank 2 `$8586` calls
`$A764` after clearing temporary state `1` for the first slot group.
`$A764–$A838` processes group 1, starting at slot `$6413` for `$6415`
entries. `$A839–$AA35` then walks group 2 backward from `$6416 - 1` to
`$6413 + $6415`, skipping `$6789=$FF` slots and calling decision subroutines
according to `$67B1` flags, current/max HP, and stage-specific conditions.
Stage 0 has zero group-1 units and eight group-2 units, so its opponents use
the second loop. This identifies the correct AI branch to reverse engineer;
the stage-0 ordinary-attack path below is now decoded, while other branches
and movement policies remain open.

For six of stage 0's eight group-2 entries, the low nibble of the ROM
`$67B1` AI flag byte is `2`, and their type is 0 or 1. When the player is
outside their alert edge, the captured entries follow
`$A954 → $A970 → $A9A4`; inside that edge, type-0 guards can instead enter
the movement branch documented below. At `$A9A4`, maximum HP is divided by 3 and the
current HP is compared with that threshold. The low-HP branch invokes
`$B5B3`, which calls the same `$8867` max-HP/8 recovery routine used by
individual rest. The other two units' `$A88B` branch uses this same
one-third-HP check and rest call. For an otherwise eligible unit with technique ID 0, `$A9F1` calls
`$AA44`, which scans player slots in order for orthogonally adjacent units.
`$9A24` chooses the candidate with the lowest current 16-bit HP and keeps
the earlier slot when HP ties. `$AEBE` calls the ordinary attack at `$8DDC`
when `$6409` contains a target. When `$AA44` finds no adjacent target,
`$A9F1–$AA1A` compares current HP with maximum HP: a wounded unit calls
`$B5B3` to rest, while a full-health unit does nothing. The two remaining
enemies have AI flag low nibble `1` and take a separate `$A88B` branch.

Godot now runs this confirmed adjacent-attack subset after the
automatic player rests, in reverse ROM group-2 slot order. All eight enemies
use the confirmed low-HP rest branch when applicable; eligible common-branch
enemies also rest when wounded and without an adjacent target. The demo applies the
existing ROM damage formula, removes units at zero HP, and shows a demo defeat
panel if the first player slot falls. It approximates the low-nibble-1 units'
movement route when the ROM's no-adjacent-target condition guarantees a
movement call. Technique AI and other undecoded effects remain absent. This is a partial opponent
phase, not an exact simulation of every stage-0 enemy action.
The original first-stage enemy phase moves `(8,13)→(8,15)` and then
`(7,13)→(7,15)` in the captured replay. An earlier Godot prototype moved
`(8,9)→(8,11)` because it read the wrong layout auxiliary byte.
When the camera is following a player near world Y=25, those cells are above
the visible window. The Godot loop also applies actions in a single frame,
which made that movement invisible. The demo now briefly focuses the camera
on the last visible enemy move, attack, skill, or rest and then returns to
the player's former view. An older stage-1 camera probe observed scroll offset
13→5→13 around the incorrectly selected move. If no implemented enemy action occurs, the status
reports no visible enemy action. This does not fill the remaining later-stage
AI branches; a first-turn scan of all 19 demo stages found no enemy event
in stages 3–19 with the initial deployments and full HP.
The enemy phase now shares the ROM's type split more broadly: eligible
types at or above `$38` try their second skill packet, while ordinary
types below `$38` try a supported single-target first packet on the
alternating range-choice path, then fall back to an adjacent attack.
Packets with area code other than 1 or zero damage are not treated as
ordinary damage. A focused Godot probe placed a player two cells from a
type-62 stage-11 enemy and measured 65 HP damage; a stage-10 type-19 enemy
dealt 45 HP with skill 2 at the same distance. Timing, target filtering,
movement choices, and non-damage effects remain partial.
In a headless Godot input probe, moving the first player to (7,14) and choosing
全军休息 produced one adjacent enemy attack, reducing player HP 100→80;
choosing individual 休息 next restored it to 92. With two adjacent players
at different HP, the lower-HP slot was selected. These probes exercise the
Godot implementation of the decoded branch; they are not an emulator trace.
Another headless probe set the enemy at (8,9) to 20/100 HP. Two
successive 全军休息 commands restored it to 32/100 and then 44/100, matching
the shared low-HP rest call and its 12-HP integer recovery.
A separate probe left an ordinary enemy without an adjacent target at 80/100
HP; it rested to 92/100. The stage-1 type-3 enemy similarly rested from
130/150 to 148/150.

The special enemies' above-threshold branch is now located more precisely.
Their stage-0 second layout auxiliary byte is `$01`; the first bytes are
`$1E` and `$1F` and do not carry the `$67B1` AI flag. The type-0 graphic
selector is `0`. At `$A8C0–$A8E7`, selector `0` misses both special selector
tables. `$A8E8` then sees the zero high nibble and calls `$AD30` before
examining its chosen target at `$A905`; when no target is found, `$A912`
calls `$AEDA` to move. The behavior with nearby targets still needs a
runtime trace. The older interpretation of `$21` as the first stage's
special AI flag was incorrect; that is the first layout auxiliary byte of
the guard unit at `(8,9)`.

The movement routine itself is confirmed as such: `$AF00` seeks a player slot
whose X coordinate is not `$FF`, then compares that slot's X/Y coordinates
with the acting enemy at `$AF0E–$AF71`. Later branches repeatedly call the
terrain check `$8C2F` and movement-cost routine `$8B8A`. `$B498/$B4A2`
write the final X/Y values to `$648F/$64B7` for the acting unit. The exact
direction priority, retries, and stop condition remain to be decoded before
these units can move faithfully in the demo. Godot now moves them
only when the proven no-adjacent-target condition holds. It pursues the first
living player, using a shortest path through ROM-passable, unoccupied cells
and the type-0 two-tile movement budget. If their allies seal every complete
route, it takes local passable steps that reduce tile distance. Direction
priority and later coordinates remain gameplay approximations. A read-only
FCEUX playback of `research/evidence/movies/fceux_stage00_first_phase.fm2` recorded ROM slot 5 moving
`(8,13)→(8,15)` at frame 4024, then slot 4 moving `(7,13)→(7,15)` at
frame 4072. RAM `$67B1 + slot` is `$01` for both slots and `$02` for the
guard `(8,9)` slot. These values match layout auxiliary byte 1, not
byte 0. The capture is `research/evidence/traces/rom_stage00_enemy_phase_trace.tsv`, generated
by `research/tools/fceux/fceux_stage0_enemy_phase_trace.lua` while replaying the input movie
`research/evidence/movies/fceux_stage00_first_phase.fm2` from a clean ROM boot. The first five
columns are frame, selected slot, acted-slot count, input code, and NES
frame counter; positions are `slot:X,Y`; each trailing RAM tuple is
`slot:$67B1,$643F,$65A7,$66E7`. Regenerate from the project directory with:

```sh
FCEUX_TRACE_OUTPUT="$PWD/research/evidence/traces/rom_stage00_enemy_phase_trace.tsv" \
  fceux --sound 0 --no-config --loadstate 99 --savestate 99 \
    --playmov "$PWD/research/evidence/movies/fceux_stage00_first_phase.fm2" \
    --loadlua "$PWD/research/tools/fceux/fceux_stage0_enemy_phase_trace.lua" \
    "$PWD/../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes"
```

The extended replay `research/evidence/movies/fceux_stage00_four_phases.fm2` and trace
`research/evidence/traces/rom_stage00_four_phases_trace.tsv` cover four whole-army-rest enemy
phases with no player movement. The same slots advance on phase 2:
`(8,15)→(8,17)` at frame 6163 and `(7,15)→(7,17)` at 6211. On phase 3,
the right unit advances `(8,17)→(8,20)` at frame 8170, while the left moves
`(7,17)→(7,19)` at 8218. On phase 4, the right and left units advance to
`(8,23)` and `(7,21)` respectively. To regenerate the extended trace,
set `FCEUX_TRACE_FRAMES=11200`, point `FCEUX_TRACE_OUTPUT` to its TSV file,
and replay the extended FM2 with the same command shape.
An additional write trace in `research/evidence/traces/rom_stage00_move_budget_writes.tsv`
(generator: `research/tools/fceux/fceux_stage0_move_budget_writes.lua`) observed the type-0
class allowance `$66BF+5=2`. In all three phases, the routine tries a third
candidate: `$05E6` receives `03` and then `FF` after subtracting the class
allowance. The final Y remains 15 and 17 in phases 1 and 2, but becomes 20
in phase 3. A separate `research/evidence/traces/rom_stage00_scroll_writes.tsv` trace shows
`$6802` advancing from 5 to 7 while temporary screen Y `$0618` stays at
`$D0` (208) during the right unit's third move. The final world Y is
`208/16 + 7 = 20`. The fourth phase repeats this boundary behavior: the
right unit moves three cells, while the left, farther above the scroll
edge, moves two. Godot now keeps a first-stage enemy scroll state, grants
the observed extra cell when a pursuer starts at screen row 12 or lower,
and advances that state when it passes row 13. Other routes,
nearby-target decisions, and later scroll states still need comparison.
A headless Godot scene probe with the three player deployments stationary
produced pursuer positions `(7,15)/(8,15)`, `(7,17)/(8,17)`,
`(7,19)/(8,20)`, and `(7,21)/(8,23)` across four opponent phases, matching
the FCEUX replay. Its enemy scroll state was `5,5,7,10`. A separate probe
saved after phase 3, loaded the snapshot into a fresh battle scene, and
reached the same phase-4 positions and scroll state.

The longer input movie `research/evidence/movies/fceux_stage00_seven_phases.fm2` extends the
same all-army-rest sequence. Its read-only HP/position trace is
`research/evidence/traces/rom_stage00_seven_phase_hp_trace.tsv`, generated by
`research/tools/fceux/fceux_stage0_player_hp_trace.lua`. In phase 5, the right pursuer
stops at `(8,24)` and the left reaches `(7,23)`. In phase 6, the right
stays put; the left moves to `(7,24)` and then attacks the first player
in the same action, reducing HP `100→80` at frame 14608. At the start of
phase 7, whole-army rest restores that player's HP `80→92`; the adjacent
left pursuer attacks again for 20, leaving `72` at frame 17161. Godot now
caps stage-0 vertical pursuit at the row before the first player when that
player is below screen row 13, then
performs an ordinary attack if the mover ends adjacent. A headless Godot
probe using the actual `全军休息` command matched the seven ROM phase
endpoints, advanced the demo turn number from 1 to 8, and produced the
first-player HP sequence `100,100,100,100,100,80,72`. Other player
movements and combat choices still need ROM comparison.

To check whether that row cap was specific to the original deployment,
`research/tools/fceux/fceux_stage0_player_position_trace.lua` replays the same input movie
and changes only the first player's world Y at frame 3000. Set
`FCEUX_PLAYER_Y` to 18, 19, or 21 and `FCEUX_TRACE_OUTPUT` to a TSV path.
The recorded runs are `research/evidence/traces/rom_stage00_player_y18_trace.tsv`,
`research/evidence/traces/rom_stage00_player_y19_trace.tsv`, and
`research/evidence/traces/rom_stage00_player_y21_trace.tsv`. The second pursuer reaches
`(8,18)` when the first player is at `(7,18)`, then attacks in phase 3;
with the first player at `(7,19)` it stops at `(8,18)`, and with that
player at `(7,21)` it stops at `(8,20)`. At the relevant movement endpoint,
these three positions are at screen row 13 after subtracting `$6802`.
The first pursuer remains one world row above the player in all three
runs. Godot therefore lets the second pursuer enter the player's row when
the player is already within screen row 13, while keeping the earlier
row cap when the player is below it. This is an observed condition across
these four scenarios, not a complete reconstruction of the ROM's direction
retry and camera routines. Headless battle-scene probes of `全军休息` match
the observed endpoints and first-player HP through seven turns for the
default, Y=19, and Y=21 cases. For Y=18, they match through turn 5,
when the first player reaches 0 HP and Godot reports defeat.

The same movie was replayed with player slot 0 at `(6,21)` and `(9,21)`;
see `research/evidence/traces/rom_stage00_player_x6_y21_trace.tsv` and
`research/evidence/traces/rom_stage00_player_x9_y21_trace.tsv`. With `(6,21)`, the pursuers
reach `(7,21)/(8,21)` in phase 4 and the left one attacks for 20 HP.
With `(9,21)`, phase 4 ends at `(7,21)/(8,20)`; the left one advances
sideways to `(8,21)` and attacks in phase 5. The direct ROM execution
captures `research/evidence/traces/rom_stage00_player_x6_y21_route_pc.tsv` and
`research/evidence/traces/rom_stage00_player_x9_y21_route_pc.tsv` can be regenerated with
`research/tools/fceux/fceux_stage0_route_pc_trace.lua`. At the fourth-phase right-pursuer
move, both start with screen Y `$D0` and scroll `7`; the `(6,21)` run enters
the scrolling branch and advances `$6802` to `8`, while the `(9,21)` run
keeps it at `7`. The initial target-direction flag at `$05F4` is `$06`
versus `$05`. These traces establish that lateral target position affects
the scroll and movement branch, but they do not yet decode every condition
in `$AF90–$B4AC`. Godot's first-stage flank path now follows the observed
vertical lane and then closes the horizontal gap. Its special right-lane
stop for a player one row down and to the right is limited to this captured
castle path. Headless battle-scene probes match the ROM positions and first
player HP through seven phases for both lateral placements and preserve the
four earlier scenarios.

The earlier assumption that the remaining stage-0 type-0 units never move
was incorrect. `research/tools/fceux/fceux_stage0_guard_alert_trace.lua` records the first
opponent phase's AI entry points and acting coordinates after changing only
the first player's position. Its captures at `(7,11)`, `(7,12)`, `(9,14)`,
and `(9,15)` are `research/evidence/traces/rom_stage00_guard_alert_x7_y11.tsv`,
`research/evidence/traces/rom_stage00_guard_alert_x7_y12.tsv`,
`research/evidence/traces/rom_stage00_guard_alert_x9_y14.tsv`, and
`research/evidence/traces/rom_stage00_guard_alert_x9_y15.tsv`. The `(8,9)` and `(7,9)`
guards both call `$AEDA` and move when the first player is at world Y 14.
At Y 15 they instead enter `$A9A4` and remain at their original positions.
Their third layout auxiliary byte is 14; the farther Y=6 line has byte 10,
the Y=4 type-1 guard has byte 9, and the two Y=13 pursuers have byte 30.
This identifies the byte's role as
a southward alert edge in the captured first-stage path, inclusive of the
edge row for the type-0 lines. Godot now checks that value before permitting
a stage-0 flag-2 guard to pursue and attack.

At `(7,11)`, ROM slot 7 advances `(8,9)→(8,11)` and attacks, slot 6
advances `(7,9)→(7,10)` and attacks, then the two Y=13 pursuers stop at
`(8,12)/(7,12)` and the left one attacks. The first player's HP is
`100→40` during that opponent phase. At `(7,12)`, slot 7 reaches
`(8,11)` without attacking, slot 6 reaches `(7,11)` and attacks, and
the two pursuers also attack for a total of 60 HP. Godot's first
opponent phase matches the ROM positions and HP in both positions. The
input movie no longer follows the same menu sequence after the `(7,11)`
injection, so later phases in that trace are not used as evidence.
The pursuers' northward movement now tries vertical cells first; this
also prevents a shortest-path detour through a guard-occupied cell.

The same trace script captures player `(8,10)` and `(8,11)` in
`research/evidence/traces/rom_stage00_guard_alert_x8_y10.tsv` and
`research/evidence/traces/rom_stage00_guard_alert_x8_y11.tsv`. At Y 10, all three guards
initially on Y 6 call `$AEDA` and advance to Y 8. At Y 11, all three
enter `$A9A4` and stay at Y 6. The complete position/HP replay for Y 10
is `research/evidence/traces/rom_stage00_player_x8_y10_trace.tsv`: the first opponent phase
ends with pursuers `(7,11)/(8,11)` and first-player HP 40, matching the
Godot scene probe. The `FCEUX_TRACE_END_FRAME=6500` capture
`research/evidence/traces/rom_stage00_guard_alert_x7_y8.tsv` reaches the final Y=4 type-1
guard action. It calls `$AEDA` and moves `(8,4)→(8,7)` when the player is
at `(7,8)`; at player Y 11 it remained in `$A9A4`. Godot now lets the
type-1 guard use its layout alert edge as well. The first-stage guard
movement tries vertical cells before a lateral step, reproducing that
type-1 destination and the earlier type-0 guard destinations. Broader
routes beyond these first-phase captures remain approximate.

An extended replay with the first player at `(7,14)` is in
`research/evidence/traces/rom_stage00_guard_alert_x7_y14_multi.tsv`. The Y=9 pair advances to
`(8,11)/(7,11)` in its first opponent phase, then to `(8,13)/(7,12)`
in its second; the third phase leaves both in place because the approach is
occupied. A headless Godot scene probe matched these phase endpoints and the
first player's HP sequence `60, 32, 4, 0`. This comparison supports the
current guard route in that sustained engagement, without establishing a
general ROM pathfinding rule.

Continuing the same command in Godot reaches first-slot HP 0 and the defeat
state on opponent phase 16. An extended FCEUX replay reached HP 40 at phase
11, matching the intervening Godot HP values, then the emulator process
exited before the original defeat screen could be captured. The precise
original failure-screen timing is therefore still unverified dynamically;
the static `$9312–$9338` defeat predicate below remains the rule source.

The old headless `(8,9)→(8,11)` and stage-1 `(8,5)→(8,7)` probes exercised the
wrong flag mapping and no longer describe the intended AI.

### 第一关胜利与失败条件

Bank 2 `$9312–$9338` reads `$6789` without an index: this is the first
player slot's state. When it is `$FF`, the routine sets `$6814=$FF`. It then
starts at slot `$6413 + $6415` and checks every group-2 slot up to `$6416`;
only if all are `$FF` does it set `$6815=$FF`. Stage 0 has three player slots,
zero group-1 slots, and eight group-2 slots. The stage-specific check at
`$9AA2` has cases for other stage indices but none for stage 0. After the
opponent phase, `$8589–$859F` checks `$6815` and `$6814` and returns through
`$839D`, which calls `$9888` to copy roster data. Thus the first battle's
ordinary victory condition is all eight opposing slots removed; the first
player slot's removal triggers the defeat path even if other player units
survive. In the outer campaign loop, bank 0 `$8159–$817E` tests `$6814` for
failure and increments stage index `$6400` after a successful battle return.
Godot matches the predicates for its win/loss panels, shows the win panel
immediately after the final hit, and opens its second-battle scene on A.
The ROM's transition screens, roster updates, and full next-stage setup remain
to be reproduced.
Headless Godot probes confirmed the changed predicates: reducing the first
player to zero during the enemy phase sets defeat while the second player
remains at 100 HP; defeating the last group-2 unit sets victory with zero
opponents remaining. The probe first accounted for automatic full-army rest
healing before the enemy hit.

### 第二关 Godot 演示切片

The next stage record has a 16×30 vertically scrolling map, three initial
player deployments at (9,27), (8,28), and (10,28), no group-1 units, and six
group-2 opponents. The generated
`rom_battle_stage_candidate_01_color.png` combines this record's ROM map,
palette packet, and CHR uploads. Its color composition has not been matched
against a live screenshot; its inputs are recorded in
`rom_battle_stage_candidate_01_color_provenance.json`. The shared battle script now loads opponent count,
positions, types, movement passability, and map height by stage index. It
uses the ROM-derived red/blue pose palettes and badges for types without a
confirmed sprite mapping. Stage 1 retains the player's movement, ordinary
attack, individual rest, automatic whole-army rest, and generic group-2-clear
win and first-slot-defeat conditions. Its enemy phase now runs the confirmed
common group-2 subset. In ROM bank 2, `$A954` compares the AI flag's low
nibble with 2 and conditionally enters the alert branch; `$A970` then loads
the unit type and sends types below `$38` to `$A9A4`. Thus stage 1's
type-3 enemy, as well as its types 0 and 1, uses the same one-third-HP rest
gate, wounded-without-target rest, and skill-0 adjacent ordinary-attack path
as stage 0. All six stage-1 enemies have second layout auxiliary bytes
`$02` or `$03`, so none enters the low-nibble-1 movement branch. Three
flag-2 enemies do use the separate alert movement branch: their third
auxiliary byte is 12. The old `(8,5)` pursuit came from reading layout
auxiliary byte 0. This is still a partial enemy phase. A headless
Godot probe placed a player adjacent to the stage-1 type-3 enemy at (9,12):
one full-army-rest enemy phase reduced that player's HP from 100 to 75. A
second phase with the `(8,5)` enemy at 20/100 HP restored it to 32/100 HP.

`research/tools/fceux/fceux_stage1_alert_trace.lua` loads stage 1 by writing `$6400=1`
during a replay of `research/evidence/movies/fceux_stage00_seven_phases.fm2`, then places the
first player at a chosen coordinate in emulated RAM. This controlled load
does not capture the natural stage transition. At `(8,12)`, the ROM trace
`research/evidence/traces/rom_stage01_alert_x8_y12.tsv` shows slot 8 at `(8,11)` attacking for
20 HP, slot 7 moving `(9,8)→(9,10)`, slot 6 moving `(8,8)→(8,10)`, and
slot 4 at `(9,12)` attacking for 25 HP. Slot 6 stops behind the occupied
`(8,11)` cell; the other two enemies do not move. The phase ends with the
first player at 55 HP. At `(9,13)`,
`research/evidence/traces/rom_stage01_alert_x9_y13.tsv` records all three flag-2 guards entering
`$A9A4` and staying in place; slot 4 attacks for 25 HP, leaving 75 HP.
Headless Godot scene probes matched all six enemy endpoints and first-player
HP in both placements. This verifies the stage-1 alert edge and these two
first-phase cases; other routes and later phases remain approximate.

The extended capture `research/evidence/traces/rom_stage01_alert_x8_y12_multi.tsv` records two
opponent phases with the first player at `(8,12)`. Between phases the
player rests from 55 to 67 HP. Slot 8 then attacks for 20 HP, slot 7 moves
`(9,10)→(9,11)`, slot 6 remains blocked at `(8,10)`, and slot 4 attacks for
25 HP, leaving 22 HP. Godot matches both phase endpoints and HP values.
The reused stage-0 movie does not initiate another opponent phase within
this capture; Godot's subsequent defeat is not claimed as a ROM match.

### 修正 AI 标记与兵种类型的比较方式

The accumulator at bank 2 `$A954` still contains `$67B1,Y & $0F`, loaded
before the low-nibble-1 branch. Therefore `CMP #$02` compares the AI flag,
not the unit type. For flag 2, `$A958–$A96D` scans player Y coordinates
`$648F,X` against the acting unit's `$67D9,Y` alert edge; a coordinate less
than or equal to that edge jumps to `$A88B`. Only at `$A970` does the ROM
load `$643F,Y`, the unit type, and compare it with `$38`. There is no
type-2 exclusion in this common-branch dispatch. The old description and
Godot's `type_id != 2` eligibility check were incorrect and are corrected.
The actual stage-6 (seventh battle) layout includes a type-2 group-2 unit
at `(6,22)` with flag 3; it can now enter the same low-HP rest and adjacent
attack path as other common-branch units. Flag-1 units now also dispatch
ordinary attacks from the graphic-selector tables, including type 2;
their exact movement routes outside the captured cases remain incomplete.

A headless probe of this actual stage-6 deployment isolated its flag-3
enemy slot and placed the first player next to `(6,22)`. The corrected
common branch applied the ROM damage calculation of 30 HP, taking the
player from 100 to 70. With that enemy reduced to 1 HP, its next action
restored 25 HP to 26. This checks Godot's dispatch and arithmetic against
the decoded branch; it is not a live stage-6 ROM replay.

The exploratory `research/tools/fceux/fceux_stage2_alert_trace.lua` uses a controlled
stage-2 load. Stage 2 has three player slots and two group-1 slots, so its
group-2 coordinates occupy slots 5–14. Setup completes later than in stages
0 and 1; the initial `rom_stage02_alert_x8_y10.tsv` injection was overwritten
by setup and is not AI evidence. The later
`rom_stage02_alert_x8_y10_after_setup.tsv` attempt did not complete its input
override. `rom_stage02_alert_x8_y10_manual_input.tsv` releases movie playback
at frame 3800, injects the coordinate at frame 3900, and reaches frame 7500,
but captures no enemy-phase branch execution. These files are retained as
debugging records; none validates third-battle pursuit.

### 第三关警戒与常规追击演示切片

ROM screenshots from the corrected stage-2 loader showed the
`汜水关会战` title panel still present at frame 4000. The trace script now
stops movie playback at 3800, places player slot 0 after layout setup at
3900, dismisses the title with A at 4200, and sends Start at 6500 and A at
6700 to choose whole-army rest. `FCEUX_SCREENSHOT_PREFIX` optionally saves
GD-format frame captures; it is not needed for the position trace.

`research/evidence/traces/rom_stage02_alert_x9_y10_enemy_phase.tsv` places the first player on
the passable `(9,10)` tile. The ten group-2 endpoints, in ROM layout order,
are `(9,9), (9,8), (10,7), (9,11), (10,11), (9,6), (10,8), (10,10),
`(8,11), (11,11)`. Slots 12 and 8 each attack for 20 HP, and slot 5
(type 13, flag 1) attacks for 45 HP. The first player's HP ends at 15.
A full-army-rest Godot scene probe matches all ten endpoints and the HP
result. Flag-2 stage-2 entries now enter the `$A88B` action path when any
living player is at or north of their own `$67D9` edge, including the
type-56 entry whose edge is 14.

In this capture, movement chooses one direction and continues along it
until its allowance is consumed or a cell blocks it. For example, slot 11
at `(8,8)` cannot advance south through `(8,9)` and instead moves right to
`(10,8)`; slot 14 stops at `(11,11)` because `(11,10)` is blocked. The
Godot stage-2 movement approximation now follows this straight movement
and initial horizontal retry rather than taking a shortest-path detour.
This matches the captured phase, but the full ROM direction-retry routine,
other player placements, and consecutive stage-2 phases remain unverified.

The `$A88B` selector dispatch is also corrected: `$AA3A` lists selectors
19–24 for one technique path; `$AA40` lists 3, 8, 9, and 18 for another;
other selectors enter the adjacent ordinary-attack path at `$A93E`.
Godot had limited that ordinary path to type 0. It now accepts the actual
ordinary selectors, allowing stage 2's type-13 enemy and other matching
flag-1 classes to move and attack. The stage-2 high-selector alert path
also moves when no technique target is found. Its technique frame parity
remains approximated by demo turn parity, and the other special technique
selector paths remain incomplete.

`research/evidence/traces/rom_stage02_alert_x8_y10_enemy_phase.tsv` is an additional direction
probe with the player injected onto an impassable tile. It is not the
playable-position validation; use the `(9,10)` capture above for that.

The extended `research/evidence/traces/rom_stage02_alert_x9_y10_outcome.tsv` records a second
whole-army rest at 11000/11200 and logs NES frame parity and result flags.
The first player rests from 15 to 27 HP, then slot 12 attacks for 20 HP and
slot 8 removes its remaining 7 HP. At frame 13037 the first slot state
`$6789` is `$FF`; `$9312` sets failure `$6814=$FF` at frame 13227 while
victory `$6815` remains zero. Processing continues through the remaining
enemy slots, with type 13 moving `(9,9)→(9,10)` after the first player's
coordinate is invalidated. The final endpoints are `(9,10), (9,8), (10,7),
`(9,11), (10,11), (9,7), (10,9), (10,10), (8,11), (11,11)`. The
frame-15000 screenshot shows the original title screen.

Godot matches both phases' final positions and first-player HP (15, then
0), but not every intermediate action: its turn-parity approximation lets
the flag-$82 technique unit cast in the second phase, whereas this ROM
trace takes the adjacent scan and does not cast. Matching endpoints does
not establish matching technique timing. The remaining nonzero-high-flag
parity behavior still needs the ROM frame scheduler.

The failure panel's A action now returns directly to the title screen,
skipping the cold-start publisher and character screens. B offers a
prototype convenience to retry the current battle; the result panel and
explicit confirmation are presentation additions to the ROM flow.
A scene-transition probe exercised actual first-slot defeat, A→title,
title→start/load menu, and B→fresh stage-2 battle with 100 HP.

High-type technique dispatch respects the high AI flag nibble: zero
selects `$AD30` without checking frame parity at `$A97A` (and the analogous
`$A8E8` special path). This is a friendly wounded-unit scan, not the
player/group-1 attack scan. An earlier Godot probe that applied a 25-HP
attack to a player for a flag-3 type-56 unit exercised an incorrect
implementation and is superseded by the healing capture below. Nonzero
high flags still use the parity-dependent attack-scan approximation.

### 敌方单体治疗

`$AD30–$ADF5` starts its target index at `$6413 + $6415` and stops at
`$6416`, scanning group 2's own units. It checks Manhattan distance against
the high-type range table at `$ADF6`, rejects candidates whose current HP
equals maximum HP, and passes candidates to `$9A24`. That selector chooses
the lowest current HP and keeps the earlier slot on a tie. The scan does
not exclude the acting unit, so self healing is possible. The bank-8
`$9A69–$9AC2` effect branch adds `$05EB` and clamps to maximum HP for
techniques 19–33 with variant `$05CD=0`; technique 34 takes another path.

`research/evidence/traces/rom_stage02_wounded_slot6.tsv` keeps the first player at its actual
deployment `(6,27)` and injects 50 HP into ROM slot 6 (type 1 at `(9,7)`).
The type-56 flag-3 unit in slot 7 at `(10,7)` calls `$AD30` and selects
slot 6, then calls `$AE0C`. Slot 6 increases from 50 to 70 HP during that
action; the effect executes with variant 0, using skill 19's
`[20,2,1,0]` packet. Slot 6 subsequently follows the wounded/no-target
ordinary branch and rests by 18 HP to 88. The player's HP remains 100.
The Godot whole-army-rest probe now matches all ten enemy endpoints and
this HP sequence's phase result. The tracer's `group2_hp`, `target`, and
`technique_variant` columns expose the friendly target and positive effect.

Godot's high-flag-zero caster dispatch now searches its own living,
wounded group-2 slots and applies the variant-0 healing magnitude. It
supports positive, single-target packets; area healing and zero-magnitude
special effects remain unresolved. Focused probes also check lowest-HP
selection, ties, self healing, full-health idle, and maximum-HP clamping
(`149→150` rather than exceeding 150). Those edge cases check the decoded
rules in Godot; only the 50-HP stage-2 placement above has a live ROM replay.
The common-branch healing is available in other stages using these same
supported packet shapes; special high-selector units can heal before
their approximate movement fallback.

Healing cinematics use a prototype comic panel with both figures on the
same faction, a green positive HP value, and a treatment label. These
visuals are not a capture of the original healing animation. Enemy-phase
summaries track technique healing separately from damage and ordinary rest.

### 多目标治疗阶段

Bank 8 `$96C7–$9795` dispatches area 5 to the selected center plus
orthogonal neighbors. `$9796–$98AA` dispatches area 9 to the center plus
all eight neighbors. Both keep the selected center first and scan the
caster's faction when technique ID is 19–33 and variant is zero: player
plus group 1, or group 2. The same selected target list is processed by
`$9A69–$9AC2`, adding the magnitude separately and capping each target.

`research/tools/fceux/fceux_area_healing_effect_trace.lua` replaces slot 7 with the full
type-60 definition (skill 23), then establishes known positions/HP just
before `$96C7` builds the list. This controlled arrangement avoids earlier
AI movements obscuring the shape. `research/evidence/traces/rom_area5_healing_effect.tsv` records
variant 0, magnitude 40, range 3, area 5, and ordered slots `[6,5,7,8,9]`.
The corresponding HP result for slots 5–11 is
`[220,50,90,90,90,50,50]`, from
`[215,10,50,50,50,50,50]`: 165 total recovered, including a 5-HP cap,
and neither diagonal is healed. The trace stops after effect completion
at frame 8002, before later ordinary rest actions.

`research/evidence/traces/rom_area9_healing_effect.tsv` repeats this setup but forces `$6710=9`
at the selector entry. It records ordered slots `[6,5,7,8,9,10,11]`, with
HP `[220,50,90,90,90,90,90]` and 245 total recovered, completing at frame
8070. This verifies execution of the ROM's area-9 branch, not a natural
AI choice of area 9 for type 60. These controlled experiments and static
branches establish the shapes; original player-menu selection remains
untraced. Dead slots are excluded in Godot and no resurrection is enabled.

Godot now supports variant-zero positive healing areas 1/5/9 for IDs 19–33.
Enemy casters continue choosing a wounded center by lowest HP and their
separate targeting table, then recover all living wounded units in that
area. Player treatment draws the footprint around the selected friendly
center and previews affected count and summed actual recovery. A full-health
center is valid if a neighbor is wounded; an entirely full area is rejected
without consuming an action. Each area cast spends only the caster's action.
A single comic panel reports target count and total healing rather than
queuing a separate panel for every target. Keyboard, gamepad and map touch
selection update the preview. Other area codes and multi-target attacks
remain unsupported.

A Godot comparison reproduces all seven HP values in both effect traces.
A scene probe uses real roster indices `[7,11,0,1,2,3]` in stage 11:
type 65 (skill 28, healing magnitude 45, area 5) heals five units by 185
in total, leaves a diagonal unit unchanged, caps one near-full target,
queues one group animation and spends one action. A JSON save restored
into a new stage-11 scene preserves all those HP values and the acted caster.
A final-caster probe also verifies that group treatment automatically enters
the enemy phase, increments the turn and clears acted slots. The earlier
self/single-target/next-round/scene-transition milestone continues to pass.
A rendered Godot window screenshot confirms the cross footprint and total
recovery preview. Package rebuilding and Android device verification have
not been performed for this milestone.

### 敌方独立目标表与玩家治疗阶段

`research/tools/fceux/fceux_stage2_area_heal_trace.lua` is a controlled stage-2 experiment:
it replaces ROM slot 7 with the complete type-59 definition and wounds seven
group-2 slots. It is not an unmodified campaign roster. At frame 7832,
`$9A69` sees `$05CD=0`, `$05EB=30`, `$670F=3`, `$6710=1`, and
`$6412=1`, with affected slot 6 only. That target goes from 10 to 40 HP,
then rests to 58. Bank 8's skill-22 packet is `[30,2,5,0]`, so its range
and area do not describe this enemy action: bank 2's `$ADF6`/`$AE01`
targeting tables override them. The extractor now records the 11 entries
for types 56–66 in `rom_technique_effects.json`; entries beyond 66 overlap
code and are not presented as additional table entries. Godot now uses
these targeting records independently of healing magnitude, enabling the
type-59 single-target action. A comparison gives the same HP for all ten
enemies after the observed actions. Eight movement endpoints match; slot 8
is `(8,8)` in Godot versus `(7,8)` in ROM, and slot 10 is `(6,6)` versus
`(8,6)`. Movement fallback in this artificial wounded arrangement remains
approximate. One longer capture exited FCEUX after the useful effect data;
the retained capture stops at frame 7950. This experiment does not establish
player multi-target treatment or the shapes of areas 5/9.

Player `技术` now chooses variant zero when targeting a living wounded
player/group-1 unit, including the caster, and variant one for group 2.
Positive area-1 packets are supported across technique IDs 19–33; area and
special packets remain rejected. The heal amount is capped by the target's
max HP. Green outlines identify valid treatment targets, yellow outlines
identify attacks, and the cursor status previews actual HP changes.
Invalid/full-health targets do not spend an action. Successful treatment
marks the caster as acted and participates in automatic turn completion.
The selection interaction is a demo convenience, not a verified original
player menu; original technique costs and selection variants remain open.
The shared recovery helper also drives enemy treatment.

A runnable stage-5 input/scene probe checks full-health rejection, a self
heal capped to 5 HP, friendly 50→70 HP, writing a JSON save to a temporary
path and restoring it into a new scene with the caster still acted, end-turn
reset and reuse, a positive same-faction healing animation, and victory A
advancing to stage 6. The original stage-2 type-56 enemy healing probe still
matches 50→70→88 and all ten enemy endpoints. These are headless checks;
this milestone has not had a new Android-device session or package rebuild.

The first stage's victory A action opens `battle_stage1.tscn`; direct launch
is also possible. Headless Godot loading confirmed stage index 1, six
opponents, three players, 16×30 world, and a 256×480 texture; an actual scene
transition probe confirmed stage 0→1. A passability/occupancy reachability
check found a sequence of adjacent attack tiles for all six enemies as
defeated units vacate their cells. The exact ROM stage transition animation,
roster carryover, remaining enemy AI branches, and later stages remain open.

The Godot battle scene has timed turn transitions and combat cutscenes.
The turn transitions now use the ROM-captured blue and red runners described
below. The ordinary attacks and single-target damage techniques outside the
captured stage-0 case still use a presentation approximation built from map
poses. The 战斗动画 system command controls these sequences and persists in
`user://display_settings.cfg`.

An FCEUX 2.6.6 arm64 replay of the supplied simplified-Chinese ROM reached
stage 0 and captured a level-0 infantry ordinary attack. To make an adjacent
enemy attack occur in this isolated capture, player slot 0's emulator RAM
position was set to world Y=14 at `$648F` and X=7 at `$64B7`; the ROM and
saved game were not modified. The captured frame sequence shows a full black
combat screen with orange roof scenery along the top, a roughly 35×48-pixel
purple/yellow figure on the right, a thrown shoe, a scene shift to a figure
on the left, and green damage text. Reference frames are
`research/evidence/images/combat_capture_{4200,4240,4280,4320,4360}.png`.
`research/tools/extract/extract_combat_capture_assets.py` crops the exact pixels into the
Godot combat layers. The first-battle level-0 infantry ordinary enemy attack
now uses these layers. Its timing is compressed for play; other classes and
techniques still use the approximate duel panel.

The first player ordinary attack was then captured independently. Holding
Down in the stage-0 map scrolled `$6802` from 0 to 15 and moved the cursor
from screen Y `$60` to `$E0`. Four Up steps placed it at screen Y `$A0`, world
Y=25, on the first player unit at X=7. In this isolated RAM setup, group-2
slot 4 was placed adjacent at world (7,24). A opened the unit menu, Down
selected 攻击, and A/Up/A chose that target. FCEUX frames 3700–3900 then
showed the player attack: the actor begins on the left, throws a shoe right,
the roof sweeps across, and the defender appears on the right with green
damage text. Source frames are
`research/evidence/images/combat_capture_player_{3700,3740,3760,3780,3800,3840,3880,3900}.png`.
`research/tools/extract/extract_combat_capture_assets.py` crops their roof, figure and shoe
pixels into separate Godot layers. This replaces the earlier mirrored player
animation for stage-0 type-0 ordinary attacks. Frame timing and numerical
damage typography remain approximated.

A separate first-battle capture placed player slot 0 at world (8,5), beside
the original type-1 group-2 commander at (8,4), then ended the player turn.
The enemy scheduler's `$6408` selector identified a type-0 attack from slot 9
first; only the later combat sequence at frames 4680–4840 had selector 3,
the type-1 commander. That sequence shows a mounted pink-haired actor on the
right throwing a projectile, followed by the infantry defender on the left
and green `-25` text. Its source frames are
`research/evidence/images/combat_capture_mounted_{4680,4700,4720,4760,4800,4840}.png`.
The extractor creates separate mounted actor, roof, projectile, and defender
layers; Godot now uses them for the first battle's type-1 enemy ordinary
attack against a type-0 unit. Other mounted matchups are not yet observed.
Changing three candidate type bytes for a player in an isolated RAM probe
left its combat frames unchanged, so that probe was not treated as evidence
for mounted-player artwork selection.

The same FCEUX replay captured the first enemy-turn transition at frames
3860–4000 and the following player-turn transition at frames 4900–5040.
The battlefield stays visible: one large red runner crosses left to right,
then a blue runner crosses right to left after enemy actions. Source frames
`research/evidence/images/turn_capture_{3860,3880,3900,3920,3940,3960,3980,4000}.png`
and `turn_capture_player_{4900,4920,4940,4960,4980,5000,5020,5040}.png`
are kept with the project. `research/tools/extract/extract_turn_runner_assets.py` subtracts
stable frames 3860 and 4900 to isolate seven poses for each side. Godot draws
them over its live battle map at the captured coordinates and roughly the
observed two-second duration.

### 第三关 Godot 演示切片

ROM stage index 2 has a 16×30 vertical map, three player deployments at
(6,27), (7,27), and (8,27), two group-1 allied units at (4,24) and (12,24),
and ten group-2 opponents. Godot stores group-2 units first, then players,
then group-1 allies in its own arrays while retaining the ROM group counts.
The stage-2 scene uses the extracted map, class records, deployment positions,
and stage passability. Its background
`rom_battle_stage_candidate_02_color.png` is a ROM-derived composition with
inputs recorded in the matching provenance JSON; it is not screenshot
matched. The second-battle victory A action opens this scene.

The bank-2 group-2 common branch covers its type-0 and type-1
skill-zero enemies whose second layout auxiliary byte has low nibble other
than 1. The stage-2 type-13 unit has AI flag `$01` and follows the separate
`$A88B` branch, which remains only partly reconstructed. The two type-56
group-2 enemies take the `$A970` alternate branch. Their skill ID is 19.
Bank 8 `$903F–$906E` indexes a 34-entry pointer table at `$9155`, selects a
four-byte packet variant using `$05CD`, and writes its first byte to `$05EB`.
Skill 19 has a variant-1 packet `[25,2,1,0]` at `$91D3` for a 25-HP
attack and a variant-0 packet `[20,2,1,0]` at `$91CF` for healing; both
have maximum Manhattan range 2 and one target. Bank 8's damage branch
subtracts `$05EB`, while its variant-0 healing branch adds it and clamps
to maximum HP. The live flag-3 friendly-target capture above confirms
variant 0 for that action, correcting the earlier assumption that every
type-56 action uses variant 1. The first
18 skill packets cross-check the supplied technical-parameters chart transcription.
`research/tools/extract/extract_rom_technique_effects.py` exports all 34 packets to
`data/rom_technique_effects.json`.

With nonzero high AI flag bits, a bit of NES frame counter `$05D4` chooses the adjacent-player
scan `$AA44` or range scan `$AB3A`; the latter can include group-1 allies.
Godot alternates these attack scans by demo round for reproducibility;
the captured parity at two stage-2 actions differs from that approximation.
Zero high flag bits instead use the friendly wounded-unit healing search
documented above. Earlier attack probes of the flag-3 unit do not validate
that healing branch.

Bank 2 `$AAC0–$AB39` scans slots starting at player count plus group-1 count,
so group-1 AI targets group 2. For these type-1 and type-3 allies, the
above-threshold adjacent basic-attack path is now active. Their low-HP choice
depends on frame parity. When no adjacent target exists, `$B4F3–$B5B2`
seeks the first group-2 slot with a valid X coordinate, compares positions,
and enters the movement routine. Godot now approximates that route using the
same shortest-path/local-step model as the first-stage pursuers, with each ally's
ROM movement allowance. The ROM's exact direction retries remain to be traced.
Player attacks target only group 2; group-1 allies are drawn in
blue with a green outline and act automatically.

The generic outcome check `$9312–$9338` declares victory when all group-2
slots are removed. The stage-specific checks at `$9AA2–$9AEF` branch for
indices 4, 5, 8, and 11, but not index 2. Godot now uses the generic rule,
so group-1 allies can survive without delaying victory.

Headless Godot probes confirmed stage index 2, 16×30 world, ten group-2 enemy
slots, three player slots, and two group-1 allied slots. A player cannot
attack a group-1 ally; placing the type-1 ally beside a group-2 enemy made
the ally attack for 16 HP. A scene transition probe confirmed stage 1→2.
Another probe placed a player adjacent to the type-13 group-2 unit and
observed 100→55 HP after its ordinary attack. On the first enemy phase,
the two allies moved (4,24)→(4,21) and (12,24)→(12,22), with no occupied-cell
overlap. A ten-phase probe showed no occupied-cell overlap and an allied
25-HP basic attack after it reached a group-2 unit. Exact group-1 movement
routing, low-HP timing, type-56 frame timing, roster carryover, and the
original transition remain open.

### 第四关 Godot 演示切片

ROM stage index 3 is another 16×30 vertically scrolling map. Its extracted
deployment record contains three player units at (7,25), (8,25), and (8,26),
two group-1 allies (types 2 and 4) at (2,24) and (13,24), and twelve group-2
enemies. The map, stage passability list, unit definitions, and deployment
coordinates now feed `scenes/battle_stage3.tscn`. The rendered 256×480 color
background uses the same provisional CHR overlay method as stage 2; its
inputs are recorded in `assets/rom_reference/rom_battle_stage_candidate_03_color_provenance.json`.
No live fourth-battle screenshot has yet validated its graphics.

The fourth scene is linked from the third victory panel. Player movement,
basic attack, rest, generic group-2 victory, and the first-player-slot defeat
rule run through the shared battle code. Skill-zero group-2 units use the
decoded common adjacent attack/rest branch where eligible. The two type-56
group-2 units have skill 19: the flag-3 unit heals friendly wounded targets
by 20 HP, while the flag-$83 unit uses the 25-HP attack variant with
approximate frame timing. The type-2 and type-4 group-1 allies currently use the
existing approximate pursuit path and basic attack. A type-5 group-2 enemy
now uses the skill-1 branch described below. Exact allied decisions and
other special enemy choices still need ROM traces. No campaign roster/HP
carryover is implemented between scenes.

A headless Godot probe confirmed third-victory → fourth-battle transition,
16×30 world, twelve enemies, three players, two allies, and an initial lower
page view. With a player placed at (6,7), the corrected first fourth-battle
phase deals one 20-HP adjacent basic hit (100→80 HP); the flag-3 healer has
no wounded friendly target and does not attack the player. The earlier
55-HP probe used the incorrect friendly-technique targeting. The earlier
save/load check at 55 HP and final-enemy victory check remain persistence
and outcome checks, independent of that old damage result. This is a connected fourth-battle
prototype; the F8 fifth-battle attack tutorial remains a separate scene.

### 已串联的第五关 Godot 演示切片

ROM stage index 4 has a 16×30 vertically scrolling map with four player
deployments at (7,27), (8,27), (7,26), and (8,25), one group-1 type-5 ally
at (10,28), and six group-2 enemies. `scenes/battle_stage4.tscn` now loads
these ROM map, passability, unit, and deployment records using the shared
battle code. It opens after the fourth battle's result panel. The separate
F8 `rom_stage_skirmish.tscn` remains an isolated attack tutorial.

The fifth connected scene supports player movement, basic attack, rest,
turn changes, demo save/load, the known skill-zero common enemy subset, and
approximate allied pursuit. ROM bank 2 `$A9D3–$A9EF` tests nonzero skill ID
and frame parity, scans within the per-type range at `$AC02`, and calls the
skill executor at `$AE0C` when it finds a target. Type 5 has skill ID 1,
range-table byte 2 at `$AC07`, and area-table byte 1 at `$AC4E`. Bank 8
packet `$9199` is `[20,2,1]`, which yields a 20-HP single-target hit within
two cells. The fallback `$A9F2–$AA1A` scans adjacent players for a basic
attack, rests if wounded without an adjacent target, or idles at full HP.
The demo alternates skill and basic-scan rounds; the ROM uses NES frame parity.
A headless probe confirmed range-two skill damage 100→80, no hit at two
cells on the alternate round, an adjacent 20-HP basic hit, and low-HP rest
40→58. The fourth-battle type-5 enemy also dealt 20 HP through skill 1.
The exact `$AB3A` target filtering still needs an emulator trace.

The group-1 type-5 ally has graphic selector 3, which matches the four-byte
special table at `$AA40`. Bank 2 `$A7F1` sends that ally through the
group-1 range scan `$AC90`; with a target, `$AE6F` dispatches its skill-1
packet. With no target, `$A7FE–$A807` calls its pursuit movement. The
low-HP branch at `$A7B9–$A7C7` rests on one NES frame parity and continues
to action on the other. The demo alternates these choices by round, uses
the packet's two-cell range and 20-HP effect, and approximates the exact
range scan's target filtering. A headless probe placed the ally two cells
from the type-5 opponent: skill 1 reduced enemy HP 150→130. At 40/150 HP,
the ally rested to 58 on one round and cast while still at 40 HP on the
alternate round. The no-target pursuit route remains approximate.

Bank 8 `$806C–$8077` copies the stage-layout's first coordinate byte into
`$648F` and the second into `$64B7`. The layout stores world Y before X;
bank 2 `$886C–$8881` subtracts the vertical scroll from `$648F` when
rendering. At stage index 4, `$9AA2–$9AB9` tests the first player slot's
`$648F` against 15 and sets `$05CC=$FF` when Y<15. The battle-loop call
at `$8563–$8570` exits through `$839D` on that flag, and the outer campaign
loop increments the stage index after return unless its defeat flag is set.
Thus the static ROM path supports a fifth-battle north-crossing victory.
The generic group-2-clear victory path remains available. Godot checks the
crossing before the opponent phase when the turn is ended through
`全军休息`; its exact input/phase timing may differ from the cartridge.
The provisional color map was already used by the F8 tutorial and has not
been matched to a live fifth-battle screenshot.

A headless flow probe confirmed fourth victory → fifth scene, six enemy
slots, four player slots, one allied slot, and two player moves
(8,25)→(8,23)→(8,22) under the ROM type-0 movement allowance. The demo save
restored (8,22), and the adjacent attack against the type-5 enemy at (9,22)
dealt 20 HP (150→130). Clearing the last group-2 slot triggered the win
panel while the ally remained alive. All six enemy deployment
cells are reachable in the stage passability graph from player deployment.
Ten consecutive demo rounds completed without living-unit cell overlap.
A save made in the fifth scene with player HP 77 and round 4 was loaded from
the first scene and reopened the fifth scene with both values intact. All
five connected battle scenes independently loaded in Godot 4.7.2 headless.

### 第六关由北向南的目标

ROM stage index 5 reuses the fifth stage's map pointer `$C22A`, stage CHR
upload, and palette packet. It deploys five player slots from Y=6 to Y=15,
including a type-56 fifth slot, and thirteen group-2 opponents across the
lower map. Bank 2 `$9ABB–$9AC9` checks the first player slot's world Y at
`$648F` for exactly `$1D` (29), sets `$05CC=$FF`, and reaches the same battle
exit as the fifth-stage crossing branch. Godot now opens
`scenes/battle_stage5.tscn` after fifth-battle victory and implements this
south-edge goal when the player ends the turn. The generic group-2-clear
path also remains. The F7 sixth-stage scene is still a separate movement
exercise.

The connected sixth battle uses the ROM's 16×30 map, stage passability,
deployment types and positions, unit HP and movement allowances, the decoded
ordinary enemy branch, type-56 skill-19 enemy action, and demo save/load.
Type-2 and type-6 enemy decisions, exact movement timing, and runtime CHR
residency remain unresolved. Its color
background is a ROM-derived candidate, rendered with the same inputs as
the fifth stage; the two output PNGs are byte-identical. Inputs are listed
in `assets/rom_reference/rom_battle_stage_candidate_05_color_provenance.json`.

The fifth player deployment in stage index 5 has unit type 56 and raw skill
ID 19. Skill 19's second packet `[25,2,1,0]` in bank 8 is its attack
variant, giving 25 HP, two-cell range, and one target. Its first packet
is the healing variant documented above.
The sixth-battle player `技术` command now uses that packet for a playable
single-target attack against group 2, marks the player slot as acted, and
can trigger the generic clear result. The player-side menu's original
variant selection, resource cost, and exact target filter are not yet
traced; the packet choice and Manhattan target check are demo inferences.
A headless input probe rejected a target three cells away, then applied
25 HP to a target two cells away (120→95). A separate probe used the skill
to remove the last enemy and confirmed that victory, the target's zero HP,
and the acted-slot state survived demo save/load.

A headless scene-transition probe put the first fifth-battle player at Y=15
and then Y=14: only Y=14 satisfied the special goal, and ending the turn
exited with all six enemies alive. It opened stage index 5 with five players
and thirteen enemies. The first sixth-battle player at Y=28 did not satisfy
the goal; Y=29 did, and ending the turn exited with all thirteen enemies
alive. The sixth-stage demo state saved successfully.
An earlier probe that produced two 25-HP skill-19 hits from the two
type-56 opponents used incorrect targeting: both have zero high AI flags
and now use the friendly wounded-unit healing branch. That old 100→50
damage result is superseded. A sixth-stage save with player HP 66 and round 3
loaded from the first scene and returned to stage index 5 with both values
intact.

Movement-path probes exercised the regular Godot move command in both
directions. With five of six fifth-battle enemies removed and one retained,
the first player traveled a 15-cell passable route from (7,27) to (7,14)
in two-cell turn budgets and triggered the north goal with one enemy alive.
For the sixth battle, twelve of thirteen enemies were removed and the two
friendly bridge blockers were moved aside through regular commands; the
first player then followed a 41-cell passable route from (7,6) to (7,29),
ending at 10 HP and triggering the south goal while one enemy remained.
These are implementation probes, not emulator captures or claims that the
same long route is optimal in the original game.

### 已串联的第七至第十关

The ROM's stage indices 6–9 have extracted player and opponent deployments,
unit-type definitions, passability, and complete vertical map grids. Indices
6 and 7 each have a 16×30 map and eleven group-2 opponents. Index 8 has a
16×30 ship map, eighteen group-2 opponents, and three group-1 allies.
Index 9 has another ship map with eighteen opponents and three allies; its
16×45 world and 30-cell vertical scroll limit require three 16×15 screens.
The Godot scenes `battle_stage6.tscn` through `battle_stage9.tscn` are now
linked after the sixth scene and use these records. The color backgrounds
are ROM-derived CHR/palette candidates, not live screenshot matches; each
has a `_color_provenance.json` file beside it. The stage-9 background is
256×720 pixels. Every opponent deployment cell in indices 6–9 is connected
to the first player deployment by ROM-passable terrain when living-unit
occupancy is ignored.

At ROM stage index 8, bank 2 `$9ACB–$9ADF` reads first-player world Y
`$648F` and X `$64B7`; Y<13 and X≥12 set the same special exit flag used by
the fifth and sixth battles. Godot checks this northeast goal before the
opponent phase on `全军休息`. A probe confirmed that (12,13) and (11,12) do not
qualify, while (12,12) does with all eighteen enemies still alive. The
generic group-2-clear result also remains available.

The type-62 fifth player deployment in each of these stages carries skill
ID 25. Its ROM packet at bank 8 `$9203` has variant 1 `[65,4,1,0]`, meaning
65 HP, four-cell range, and one target. The player `技术` command now uses
this packet as a demo action and marks the player acted. A probe rejected a
target at distance five, then dealt 65 HP at distance four (200→135).
As with the type-56 player skill, original player-side variant selection and
target filtering remain untraced; the packet choice is an inference from
the type-≥56 AI loader.

A headless chain probe advanced indices 6→7→8→9, confirmed 11/11/18/18
opposing slots, the northeast goal, and the final scene's 16×45 world,
30-cell scroll limit, and 720-pixel background. Stage 9 saved and restored
73 HP and round 5. Ten consecutive demo rounds in each new scene completed
without overlapping living-unit positions or HP above unit maximum.
Special enemy types and allied pursuit remain partial approximations.

### 已串联的第十一至第十九关

Godot now has scenes for all 19 ROM stage records. Stages 10–18 use the
stage-layout Y/X deployment cells, but draw player unit types from the
user-editable `$6807` roster order and the 20-entry startup `$651B` seed.
Bank 10's extracted per-stage selection caps are 8, 6, 8, 8, 10, 10, 10,
10, and 12. The prebattle selector supports keyboard, gamepad, and touch;
the selected indices are included in the Godot save. Directly opening a later
battle scene chooses the first permitted seed entries as a demo default.

The nine later maps have world heights of 45, 30, 30, 45, 45, 45, 30, 45,
and 45 cells. Each background was composed from the stage's ROM map,
stage-specific CHR upload, common CHR overlays, and extracted palette. These
are color candidates, not live screenshot matches. Stages 13 and 14 (ROM
indices 12 and 13) contain four group-2 records apiece with the same initial
cell, `(7,3)` and `(7,11)`. The demo preserves these ROM deployment coordinates
and permits the corresponding overlap when restoring a save. It displays
and activates only the first living unit in each same-cell group, then reveals
the next when that unit falls. This is a demo queue for coherent target
selection; the original spawn/occupancy behavior still requires an emulator
trace.

The stage-12 (index 11) branch at bank 2 `$9ADF–$9AEF` reads the state byte
`$6789 + $6413`. With zero group-1 units in this stage, that is the first
group-2 unit after the player slots. State `$FF` branches to the special
victory flag. The battle loop invokes this check immediately after a player
action for index 11, so the demo clears stage 12 as soon as its first enemy
is defeated. This opponent is type 63 at
`(14,3)` in the ROM layout.

Four later-roster types have additional positive single-target packets that
the demo can use: type 19 / skill 2 (45 HP, range 2–3), type 23 / skill 6
(80 HP, range 2–4), type 37 / skill 15 (60 HP, range 1–2), and type 58 /
skill 21 (45 HP, range 1–3), alongside the existing types 56 and 62.
The minimum ranges for skills 2 and 6 come from the supplied technique
chart; packet selection for the player command remains an inference. A
headless probe checked all four damage values and rejected distance one for
skills 2 and 6. Positive single-target healing is now supported as described above.
Area effects and other non-damage packets still need their separate ROM
routines before they can be used as player commands.

A headless probe loaded all nine scenes and checked background height,
player/enemy counts, and HP. A campaign chain probe visited all 19 scenes,
entered each later battle through the selector, ran three demo rounds per
scene, and restored saves in the two stages with coincident enemy positions.
Another probe selected roster indices `[2,3,4,5,6,7]` for stage 11, saved
39 HP and round 4, then restored the roster and battle state after changing
the global selection. The later battles use the existing partial group-2 AI
and enemy-clear objective, plus stage 12's first-enemy condition. Other stage-specific exit conditions,
promotion carryover, and techniques beyond the currently implemented IDs
remain open work.

### Godot 演示进度存档

All 19 battle scenes now use the system menu's `储存进度` and
`读取进度` entries. A versioned JSON snapshot in Godot `user://` records stage,
ROM unit-type IDs, selected roster indices, positions, HP, acted player slots, round, cursor, scroll,
and outcome flags. Restore validates stage, unit types, array lengths, map
bounds, HP limits, and living-unit occupancy before changing the battle; the
two ROM stages with overlapping initial enemy slots are recognized. A
save from another supported stage opens that scene and then applies the
snapshot. This is a new prototype persistence format; the original cartridge
save layout and roster carryover remain to be decoded. A headless Godot probe
saved stage 1 with a player at (9,25), 70 HP, and round 4, restored those
values in the same scene, then loaded the save from stage 2 and returned to
stage 1 with the same values.

An end-to-end headless milestone probe advanced from stage 1 to stage 2,
ran a stage-2 phase in which both allies moved, saved and reloaded a 75-HP
state, then defeated the
last group-2 enemy while group-1 allies remained alive. Invalid HP types and
overlapping living-unit positions were rejected without mutating the active
battle. Its old flag-3 type-56 damage assumption is superseded by the
friendly-healing trace; the persistence checks do not validate that damage.
All first-ten-battle scenes load after the new scenes, save, and
skill changes.

The supplied Traditional Chinese `[t2] (SELECT Infinite Move)` ROM is almost
identical to its unmodified ChT parent. At bank 2 `$8183`, it replaces
`STA $05D1` with `JMP $FFD1`; 15 inserted bytes at bank 3 `$FFD1` perform
the original store, compare the controller byte with `$20` (SELECT), zero
`$6822` on equality, then jump back to `$8186`. The other 160 changed bytes
form a separate credit string at file offset `$0F7DD0`. Its accompanying note says SELECT allows
another move or attack after acting. Thus the patch confirms that clearing
the action-list count is enough to bypass the original re-selection gate.
Godot does not implement this hack; its player-side ordered list models the
canonical membership rule, while 全军休息 currently shortcuts the unimplemented
parts of the enemy phase.

### 普通攻击演示切片

Bank 2 `$8CF0–$8D56` enumerates opposing unit slots and checks four direct
neighbors using `$648F` (Y) and `$64B7` (X): same X with Y±1, or same Y
with X±1. `$8DE0–$8E2B` subtracts target defense `$6697,Y` from attacker
attack `$6647/$6648,X`. For a nonnegative result it divides the 16-bit
difference by 2 via `$9DE2` and adds 20. A negative difference gives 16
damage when it is at least -16, otherwise 8. `$8FA7–$8FCD` subtracts the
one-byte damage value `$05E9` from current target HP `$65A7/$65A8,Y`,
clamping it to zero. These paths now drive ordinary attack in the default
Godot scene. The screenshot's eight first-page positions and type IDs are
loaded directly from the corrected stage-0 group-2 deployment. A partial
stage-0 adjacent-attack AI is reproduced, and its two pursuers move under
the confirmed no-adjacent-target condition using an approximate route.
Exact movement, other special actions, experience, and the complete canonical
turn scheduler are not yet reproduced. The old Godot attack capture
used the superseded horizontal layout and should not be used as a current
visual reference.

### 独立的第五关攻击演示切片

Stage 4 (the fifth battle) has ROM player units at (7,27), (8,27), (7,26),
and (8,25), a group-1 type-5 ally at (10,28), and group-2 enemies including
a type-5 unit at (9,22). The isolated `rom_stage_skirmish.tscn` now marks
group 1 as friendly and only permits player attacks on group 2. The type-0
player at (8,25) can move to (8,23), then (8,22), then attack (9,22).
`rom_stage_skirmish.tscn` is a separate mechanics slice with those original
map/deployment/stat values. Its color background is a CHR composition
candidate; type 0–2 static poses are reused from stage 0 with inferred type
mapping. Other types display a ROM-derived infantry pose and a type ID badge
as a visible placeholder. Godot headless execution confirmed both moves,
rejection of the group-1 ally as a target, and a group-2 attack for
150→130 HP. F8 enters and returns from the slice.

The previous length-prefixed-segment interpretation was wrong. Bank 4's
writer `$8094` and bank 10's `$941C` read block count and initial X once.
The branch at `$80D6` goes back to `$80C5`, skipping the length read at
`$80BC`. X is zero after each block, so all remaining blocks copy 256 bytes.
Payload size is `(initial_length or 256) + (block_count - 1) * 256`.
Stage 0 `$859A` therefore uploads 768 bytes, not 514. Its source tile 39
is at `$87FE`; screenshot `image5.png` matches its exact two-plane bytes.
Tree tiles 36/37 and bridge tiles 32/33 also match ROM exactly.

The general and battle-stage extractors are corrected, battle setup streams
and all 19 stage streams/maps regenerated. Older diagnostic manifests outside
this regenerated set still contain obsolete sizes and must be rebuilt before
use. Historical claims below about lengths, segment boundaries, wrapping,
missing CHR coverage, and selector overreads are superseded pending re-audit.
Stage 0's referenced tile range is now fully covered by its actual upload.
The seven unique bank-12 `$05ED` streams have also been re-exported with the
corrected decoder. They occupy background pattern memory starting at `$1010`;
their tile sheet forms larger artwork, not an established battle-unit sprite
set. The bank-18 OAM records and runtime sprite CHR association remain open.
Background color zero uses universal palette entry `$3F00` (NES index `$10`),
not RGB palette index zero.

Two static 16×16 unit poses were assembled from bank 4 `$8322`'s upload:
infantry tile sources `$8326,$8336,$83A6,$83B6`; mounted pose sources
`$8426,$8436,$8486,$8496`. Each matches screenshot pixels exactly, treating
color zero as transparent. Runtime OAM selection, character identity and
animation timing still need tracing. The eight screenshot positions exactly
match the corrected ROM group-2 deployments.
The screenshot is a 4× capture starting at logical x=1,y=8, so direct scaling
to 256×240 would misalign it. The measured RGB palette and provenance are in
`assets/rom_reference/rom_stage00_visual_provenance.json`; all drawn pixel
patterns remain ROM-derived.

Godot's actual rendered frame is `research/evidence/images/stage00_godot_runtime.png`.
After aligning the 4× crop, all 54,862 compared pixels match `image5.png`.
This excludes the 16×16 cursor cell, demo status area from y=225 downward,
and crop boundaries; it validates this static frame only. Unit cells use the
universal background color for zero pixels, replacing their underlying terrain
as observed in the screenshot. A full runtime trace is still needed to decide
whether those poses are drawn through nametable updates or another mechanism.
Comparison bounds and counts are recorded in `rom_stage00_visual_comparison.json`.

## 卡带结构与布局

- File size: 1,048,592 bytes: a 16-byte iNES header plus 1 MiB PRG data.
- Header: `4e 45 53 1a 40 00 f2 00 00 00 00 00 00 00 00 00`.
- iNES mapper 15, 64 banks of 16 KiB PRG, no CHR ROM, 8 KiB CHR RAM.
- PRG bank offsets below are relative to the start of PRG (file offset is `+0x10`).
- Banks 48–59 and 62–63 are all zero. The other 50 banks contain data.
- FCEUX 2.6.6 displays the title screen from this ROM (confirmed in
  `../image1.png`).

## 通过读取机器码定位启动流程

With Mapper 15's reset value, the first 32 KiB of PRG is visible at CPU
`$8000–$FFFF`. The reset vector at PRG offset `$7FFC` is `$C003`. At `$C003`,
the code jumps to `$C025`; that routine writes `$3C` to `$8000` and calls
`$8000`. For Mapper 15 mode 0, `$3C` selects the 32 KiB PRG window made from
16 KiB banks 60 and 61. The initial code therefore hands execution to the
high PRG banks, consistent with the active program code residing there.

The first bytes at bank 60's `$8000` entry are calls to `$801B`, `$804D`,
`$8072`, and `$8033`, followed by PPU initialization writes. Tracing those
calls found a concrete boot-screen asset format:

- `$804D` copies 4 KiB of CHR data from CPU `$82BC–$92BB` into PPU `$1000–$1FFF`.
- It then reads a screen stream at CPU `$8165`. `FE count tile` repeats a tile
  ID, ordinary bytes are literal tile IDs, and `FF` ends the 32×30 nametable.
- The stream expands to exactly 960 tile IDs and ends at CPU `$826B`; the next
  64 bytes are the attribute table, followed by 16 palette entries at
  `$82AC–$82BB`. The raw CHR block begins immediately afterward at `$82BC`.
- The extracted 256×240 preview is a publisher splash containing
  “外星电脑科技有限公司 / WAXING COMPUTER SCIENCE & TECHNOLOGY CO., LTD.”
  and build number `970261`.

`research/tools/extract/extract_boot_screen.py` reproduces the extraction without third-party
Python packages. It writes its PNG/JSON outputs to a caller-selected directory;
the ROM and extracted art are not copied into the game project by default.
The generated 256×240 publisher splash is included locally at
`assets/rom_reference/publisher_splash_970261.png` and shown by
`scenes/rom_publisher_splash.tscn`. This makes the first byte-verified ROM
screen viewable inside the Godot project without presenting it as the actual
title menu. To regenerate the PNG, pass the local ROM, an output directory, and
the 192-byte FCEUX palette to the extractor; for example:

```sh
python3 research/tools/extract/extract_boot_screen.py \
  ../BaoXiaoSanGuo/BaoXiaoSanGuo\(ES1005\)\(ChS\)\(970261\).nes \
  /tmp/bxsg-extract \
--palette /opt/homebrew/Cellar/fceux/2.6.6_12/share/fceux/palettes/FCEUX.pal
```

The CHR block at `$82BC` is now also extracted independently as a 256-tile
grayscale sheet, with its PPU base address and source bank recorded in JSON.
It is the exact boot-time pattern-table upload, so its tile indices can be
compared directly with the boot nametable. This is a boot asset; the game later
uploads other graphics states, and this block has not been matched to the
battle OAM templates. Regenerate it with:

```sh
python3 research/tools/extract/extract_boot_chr.py \
  ../BaoXiaoSanGuo/BaoXiaoSanGuo\(ES1005\)\(ChS\)\(970261\).nes \
  assets/rom_reference
```

The new sheet is included in `scenes/rom_asset_catalog.tscn` alongside the
callback uploads and indexed sprite palettes.

## 画面数据流的进一步线索

A ROM-wide byte-pattern scan found a sequence beginning at PRG bank 13, CPU
`$A61C`, that a permissive `FE`/`FF` decoder expands to 960 tile IDs. This is
not enough to identify it as a screen: the stream has no confirmed loader or
CHR source, and the `1C A6` bytes at bank 18 CPU `$8642` were only a coincidental
pointer-like match. Those bytes sit at offset 7 inside record 9, rather than on
one of its 16-bit field boundaries. Do not treat this sequence as a title,
battle map, or confirmed graphics asset.

## Bank 18 索引记录

Bank 18 CPU `$8543` contains 25 little-endian pointers to records at `$8575`,
`$858B`, `$85A1`, and so on through `$8785`. The records are 22 bytes apart and
each is 22 bytes long. Routines at `$8030`, `$81A0`, and `$8430` select records
using indices in RAM around `$6467`, then read words at selected record offsets
before calling shared routines in the `$Fxxx` window. This establishes an
indexed fixed-record structure. The meanings of fields beyond the first word
are still unknown.

The first word of each record points to a 16-entry OAM template. In bank 18's
`$8030` path, the template pointer is first passed to bank 19's `$F307`, then
later to `$F072`. `$F072` takes the first byte as an entry count, then consumes
four bytes per entry; it adds the configured Y and X offsets to the first and
fourth byte and writes the tuples to the OAM shadow buffer. All 25 templates
declare 16 entries. The corresponding pointer data is in bank 18 for indices
0–16 and bank 19 for indices 17–24. Each 4-byte tuple is preserved as Y
offset, tile number, attributes, and X offset.

The OAM lookup has two additional effective selectors beyond the 25-entry
primary pointer table. Selector 25 reads `$8575`, which aliases record 0's
first word and points to `$89A8` (another valid 16-entry OAM layout). Selector
26 reads `$8577`, aliasing record 0's second word, and points to `$BA0F`; its
header `$38,$28` declares 56 OAM entries and a 40-byte palette upload to PPU
`$3F38`; `$F072` consumes 56 four-byte tuples. This fits within the 256-byte
OAM shadow buffer. Thus the unit record ID 71's graphic
selector 26 is not out of range for the OAM path; it selects a larger layout.
The alias may be intentional, but the code/data overlap alone does not prove
the original author's intent.

The `$F307` path reveals a packed header: for the 25 primary templates the
first two bytes are `$10,$10`; `$F307` uses them as PPU destination low byte
`$10` (so `$3F10`) and a 16-byte palette payload length. The first two bytes
also declare 16 OAM entries to `$F072`. For selector 26, the same header format
is `$38,$28`: OAM count 56, palette destination `$3F38`, payload length 40.
The palette bytes overlap the initial OAM tuple data. The extractor records
these packets separately as
`palette_packet_from_oam_template`. This confirms the same ROM bytes feed both
the palette-update preparation and OAM-template processing; it does not yet
identify the pixel graphics behind their tile numbers.

Field 8 independently supplies an 8-byte `$3F10` packet. Comparing it against
the first eight bytes of the OAM-derived packet gives an exact match in 23 of
25 records; record 6 and record 24 each differ at one byte. The four-palette
OAM packet chart is `assets/rom_reference/rom_bank18_oam_palette_packets.png`,
and its renderer is `research/tools/render/render_oam_palette_packets.py`. It is included in
the Godot asset catalog alongside the existing field-8 palette chart.

The word at record offset `$10` is read by bank 18's `$81A0` routine and passed
to bank 19's `$F0E4`. `$F0E4` sets the PPU update address high byte to `$3F`,
uses header byte 0 as the low byte, header byte 1 as the payload length, copies
the payload from offset 2 into `$0400`, then signals the PPU update worker.
Across all 25 records, the headers are `$10, $08`; therefore these are eight
NES palette values uploaded at PPU `$3F10`, the sprite palette 0/1 range. The
payload is two four-color palettes per record. Palette values are now decoded
as NES color indices and rendered with the local FCEUX 64-color palette in
`assets/rom_reference/rom_bank18_sprite_palettes.png`; the indices and palette
groups are also in `assets/rom_reference/rom_bank18_sprite_palettes.json`.
Open `scenes/rom_palette_preview.tscn` and press F6 to browse all 25 palette
pairs in a scrollable Godot view.

`research/tools/extract/extract_bank18_records.py` exports the fixed records, decoded OAM tuples,
and the two sprite palettes referenced at offset `$10` to
`research/evidence/records/rom_bank18_records.json`. Other record fields remain raw values because
their meanings are not known. Rebuild it from the workspace root with:

```sh
python3 research/tools/extract/extract_bank18_records.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  research/evidence/records/rom_bank18_records.json
```

Render the palette swatch sheet with the local FCEUX 64-color `.pal` file:

```sh
python3 research/tools/render/render_sprite_palette_sheet.py \
  research/evidence/records/rom_bank18_records.json \
  /opt/homebrew/Cellar/fceux/2.6.6_12/share/fceux/palettes/FCEUX.pal \
  assets/rom_reference/rom_bank18_sprite_palettes.png \
  assets/rom_reference/rom_bank18_sprite_palettes.json
```

## 图形数据与回调机制

The shared upper-bank code in PRG bank 19 has a callable banked-callback wrapper
at CPU `$FF50`. It saves registers, selects the lower PRG bank through `$FF85`
(which writes mapper register `$8000`), then dispatches through `$FF71` using a
small callback table at `$FFAF`, before restoring the previous bank. Its exact
timing and relationship to vblank have not yet been established.

The callback wrapper's parameters are `$60DC` (requested callback bank),
`$60DE` (callback index), and `$60DD` (bank value saved for restoration).
`$FF71` indexes 16-bit targets at `$FFAF`; only the first nine entries are
valid CPU addresses. They resolve to `$8000`, `$8003`, and `$8006` (the latter
repeated). The bytes at PRG bank 10's `$8000` are a jump table whose first three
targets are `$800F`, `$868B`, and `$8E17`, consistent with bank 10 being the
callback code bank requested by the game. `research/tools/extract/extract_mapper15_callbacks.py`
exports these vectors and candidate callback bytes to
`research/evidence/records/rom_mapper15_callbacks.json`. This is static evidence for the dispatch
path; the mapper-hack's exact runtime mapping still needs emulator tracing.

In the bank-18 record path, the caller sets `$60DC=$0A`, `$60DE=0`, and
`$60DD=09` before invoking `$FF50`; it later requests other indices while
keeping the same bank values. This shows that OAM setup and associated callback
work are coordinated through the banked dispatcher. Do not infer PRG bank
selection from `$60DC` alone: `$FF85` transforms the value before writing the
mapper register, and this ROM is an iNES Mapper 15 hack whose runtime behavior
has not been confirmed against hardware.

NESdev documents Mapper 15 as a multicart mapper and notes that most other ROMs
carrying that iNES number are mapper hacks. This is why runtime bank mapping is
an open verification item rather than something inferred from the header alone
([NESdev: INES Mapper 015](https://www.nesdev.org/wiki/INES_Mapper_015)). The
local header establishes the declared mapper number, not that this ROM uses the
original board's exact behavior.

Regenerate the callback table from the Simplified Chinese ROM with:

```sh
python3 research/tools/extract/extract_mapper15_callbacks.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  research/evidence/records/rom_mapper15_callbacks.json
```

Bank 19's `$F0E4` helper copies a length-prefixed data list from a pointer into
RAM buffer `$0400`, sets update flag `$05C6` to 1, and waits for the flag to
clear. The actual PPU transfer helper begins at `$F028` (the two bytes at
`$F026` are a preceding `PLA; RTS` tail): it reads a command through `$18/$19`,
writes the first two command bytes to `$2006`, then streams the payload to
`$2007`. The routine beginning at `$F342` branches on `$05C6`; its value-3
branch starts OAM DMA from page `$02` by writing 2 to `$4014`, matching the
buffer built by `$F072`. Its other branches perform separate scroll, nametable,
or PPU-control work; they are not a generic `$0400` palette-copy path. The
relationship between `$F307`'s palette work buffer and the `$F028` byte-stream
helper still needs an indirect-caller trace, and the source of character tile
pixels remains unresolved.

A ROM-wide scan for direct `JSR $F0E4` calls finds two sites, both in bank 18
(`$81C1` and `$8452`). Both paths read the selector-indexed `$6467` entry,
resolve an OAM template pointer, and pass a pointer into that template to the
bank-19 worker. These calls explain the character/sprite update path; they do
not expose the stage nametable or terrain upload. The stage callback's
map-specific CHR stream and map-code-to-metatile lookup are now traced below;
the runtime source for any CHR bytes not overwritten by that stream remains to
be confirmed.

The terrain search also surfaced PRG bank 6's pointer table at `$8586`. Its
four pointers (`$8590`, `$8D90`, `$9590`, `$9D90`) each address 128 raw 2bpp
tiles. A preview shows dense Chinese glyphs rather than castle terrain. The
bank-6 routines index these pages and stage tile bytes for PPU pattern-table
uploads, so this is a dynamic text font path, not the map nametable. The atlas
is `assets/rom_reference/rom_bank6_glyph_pages.png`, with source pointers and
page ranges in the adjacent JSON manifest; rebuild it with
`research/tools/extract/extract_chinese_font.py`. The glyphs are not yet indexed to the title or
battle text strings.

A ROM-wide static scan finds eight direct calls to bank 10's `$941C` stream
writer, all in bank 10: at `$8061`, `$86C1`, `$86CC`, `$86D7`, `$86E2`, `$8E35`,
`$9072`, and `$907D`. Their immediate source pointers are `$99A6`, `$C64A`,
`$CA2E`, `$CEB0`, `$CF64`, `$F4C8`, `$99A6`, and `$9DBA`, respectively. These
are the seven already extracted streams, with `$99A6` used twice. This is a
complete inventory of direct `$941C` call sites in the static ROM scan, not a
complete inventory of all PPU writes: the `$F028` command helper and mapper
callbacks may have indirect callers. The connection between these uploads and
the indexed OAM templates remains unconfirmed; the OAM tile numbers alone do
not contain the tile pixels.

The bank-10 setup around `$869D` sets PPUCTRL to `$90` and then calls the
`$C64A`, `$CA2E`, `$CEB0`, and `$CF64` streams in sequence. `$CF64` is therefore
part of this setup path and writes 256 bytes at PPU `$0010`, covering tile IDs
1–16 in the sprite pattern table. Its tile preview is mostly numerals and
symbols; the separate `$F4C8` upload also targets `$0010` but is called from
`$8E35`. Neither stream currently reconstructs the unit sprites represented
by the bank-18 templates.

The byte scan and immediate source-pointer annotations are reproducible with
`research/tools/maintenance/audit_ppu_stream_refs.py`; its output is checked into
`research/evidence/records/rom_ppu_stream_call_sites.json`. The scan is intentionally labeled as
static call-site candidates because byte-pattern searches can match data and
cannot see indirect dispatch.

Bank 4 also has a second callback vector at `$8003`, which jumps to handler
`$8071`. That handler uses RAM `$05ED` as an index into six little-endian
pointers at `$8088`, then calls the shared PPU stream writer at `$8094`.
Static extraction resolves all six streams to uploads beginning at PPU `$1010`,
with payloads of 825, 996, 886, 677, 680, and 892 bytes. This is separate from
the stage-indexed 19-stream table beginning at `$804B`, which is read by
handler `$8006`. The selector's game meaning and the precise runtime moments
when this second set is used are still unknown. The PPU address overlap means
these streams may replace part of the same background pattern range; do not
combine them with stage assets without confirming callback order.

The six stream files and metadata are in `assets/rom_reference/`, summarized by
`rom_bank4_callback1_streams.json`. Browse their PPU `$1010` tile previews in
`scenes/rom_bank4_callback1_streams.tscn` (F6). Re-extract them with:

```sh
python3 research/tools/extract/extract_bank4_callback1_streams.py \
  '../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference
```

## NMI 回调选择的索引式 PPU 数据流

The NMI routine at bank 60 `$E8E0` requests callback bank `$16` (decimal 22),
index 0. Bank 22's callback jumps from `$8000` to `$8003`; that routine loads
`$6409` into Y, reads record ID `$6467,Y`, doubles that ID, and uses it to
select a pointer from the 25-entry table at `$8028`. It sends the selected
source to its `$805A` PPU byte-stream writer, then processes a second shared
source at `$D8E3`. The indexed streams align by record ID with the 25 bank-18
records, but the callback does not read the ID selected by the OAM path
directly.

The bank-18 OAM setup at `$802E` instead loads `$6408` into X, reads
`$6467,X`, and selects the corresponding OAM template. `$6408` and `$6409` are
separate selector bytes: ROM code sometimes copies `$6408` to `$6409`, and
other paths load `$6409` from `$60C8` or write `$FF`. Thus the two paths can be
related, but a same-index OAM-template/CHR-stream pairing has not been
established. The active use of the indexed `$0800` streams must be traced with
both selectors and the callback-enable state in view.

Bank 12 callback index 1 (vector `$8003` → `$804E`) reads `$05ED`, indexes 13
pointers at `$8065`, and passes the selected stream to the PPU writer at
`$807F`. Bank 8 copies the active unit type ID from `$05E8` into `$643F`; bank 2
`$9684` uses that ID to index a table at `$983F` and writes the result to
`$05ED`. Thus this is a unit-type-to-graphics-stream lookup, separate from the
bank-18 OAM graphic selector at `$6467`. The lookup maps IDs 0, 2, 4, 6, 9,
12, 15, 18, 21, 56, 58, 60, 63, and 66 to selectors 0–12. The corresponding
unit definitions' byte 9 supplies separate OAM graphic selectors:
`0–8 → 0–8`, `56 → 19`, `58 → 20`, `60 → 21`, and `63/66 → 22/23`. This
cross-link is exported in `rom_bank12_selector_streams.json`. The 13 pointers
resolve to seven unique streams: selectors 0–5 and 7 alias `$D751`, selector 6
uses `$D0FD`, and selectors 8–12 use five distinct sources. Each stream starts
at PPU `$1010`, overlapping the stage background pattern range.

A diagnostic composition was made for each mapped unit by applying its bank-12
stream to the associated bank-18 OAM layout with a `$1000` sprite pattern-table
assumption. The OAM tile IDs mostly fall inside the uploaded byte ranges, but
the resulting composites do not form recognizable whole unit sprites. This
means the unit-type association is confirmed while a direct pixel-source match
is not. The callback may instead load other unit-specific visuals, or the OAM
pattern-table state/order differs from this candidate. Runtime PPUCTRL and CHR
captures are needed before using these streams as unit sprites in Godot.

The live dispatch from bank 10 `$8E17` reads `$05ED` and sends values 0–5 to
callback bank 2, index 1, while values 6–12 go to callback bank 6, index 1,
through the shared `$FF50` dispatcher. This branch does not call bank 12 index
1, so the caller of that 13-entry `$05ED` table remains unknown. Bank 2's
callback begins at `$9205` and performs battle-slot/state work before requesting
callback bank 3, index 1. Bank 6's callback begins at `$80E8` and enters `$81DE`,
which indexes a separate pointer table using `$05FE` and stages PPU transfer
data. Bank 6's source table starts at `$80F4` and contains 14 little-endian
pointers. Thus `$05ED` chooses whether this callback branch runs, while `$05FE`
selects data inside the bank-6 routine. The existing Chinese glyph atlas makes
a text/glyph role plausible, but this dispatch alone does not establish which
screen or string uses it.

Bank 12 callback index 0 is a distinct path: bank 18's routines at `$8285` and
`$8529` set callback bank 12, index 0, then invoke `$FF50` (restore bank `$09`).
The target at bank 12 `$8000` jumps to `$8006`; that handler loads the slot
selector from `$6408`, reads that slot's graphic ID from `$6467,X`, indexes the
table at `$801C`, and sends the selected stream to `$807F`. This directly links
the bank-12 selector stream to the primary OAM lookup: bank 18 `$802E` also
uses `$6408` to read `$6467,X` and index the OAM pointer table at `$8543`.
Therefore both the OAM template and CHR stream use the same slot and graphic ID
on this path; selector 26's complete tile coverage is a direct static asset
pairing. Bank 18 also has a secondary OAM path at `$81A2/$8433` that reads
`$6409`. Bank 2 `$AA48` builds a list of slots adjacent to `$6408` by comparing
paired fields `$64B7/$648F`, and `$9A24` writes the selected candidate into
`$6409` (using `$65A8:$65A7` to choose among multiple candidates). Other paths
copy `$6408` to `$6409` when `$670F == 0`, or explicitly write `$FF` to
`$6409`. So `$6409` can mean a neighboring unit, a mirrored slot, or no slot;
that secondary path is state-dependent. Static references confirm the bank-12
index-0 callback is invoked after this OAM setup; precise frame-time CHR
residency remains unverified. The primary pairing and secondary slot-state
sites are exported in `data/rom_unit_slot_records.json`, alongside the more
detailed [`evidence/traces/rom_sprite_selector_trace.json`](evidence/traces/rom_sprite_selector_trace.json).

A ROM-wide byte scan finds no direct immediate-parameter callsite for bank 12,
callback index 1 (`LDA #$0C; STA $60DC; LDA #$01; STA $60DE; JSR $FF50`). The
index-1 vector and `$05ED` pointer table exist in bank 12, but this direct-call
search does not locate their caller. Split or computed callback parameters are
not ruled out; the scan result and its limitation are recorded with the unit
selector data.

The manifest is `assets/rom_reference/rom_bank12_selector_streams.json`; its
seven unique tile views appear in `scenes/rom_bank12_selector_streams.tscn`.
Rebuild the set with:

```sh
python3 research/tools/extract/extract_bank12_selector_streams.py \
  '../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference
```

The NMI callback gate is RAM `$6805` (not `$6405`): bank 60 `$E8E0` checks
`$6805` and requests the bank-22 callback when it is zero; a nonzero value
skips it. The inspected bank-2 paths set `$6409` from `$6408`, from `$60C8`, or
to `$FF` before list rebuilds. These selector instructions and representative write sites are
captured in [`evidence/traces/rom_sprite_selector_trace.json`](evidence/traces/rom_sprite_selector_trace.json).

One list-building path at bank 2 `$AA48` compares paired per-slot fields at
`$64B7` and `$648F` against the slot selected by `$6408`. It accepts entries
whose one field is equal and whose other field differs by exactly one, appends
those slot indices to `$60C8`, then calls `$9A24`. This is a four-neighbor
adjacency predicate if the two fields are grid coordinates. The selector
returns for an empty list, copies the first slot into `$6409` for a one-entry
list, and for multiple entries compares `$65A8:$65A7` as a little-endian
16-bit value; it keeps the smallest value and writes that slot to `$6409`.
The parameter chart shows `$65A7/$65A8` derive from HP fields, so this path
appears to select the adjacent unit with the lowest current HP.
The paired fields are world Y at `$648F` and world X at `$64B7`. Bank 2
`$886C–$8881` scales `$64B7,X` by 16 into screen X `$0616`; it subtracts
vertical scroll `$6802` from `$648F,X` and scales the result by 16 into
screen Y `$0618`. Bank 8 `$806C–$8077` loads the two stage-layout bytes
through `$1E/$1F` into `$648F,X` and `$64B7,X`. The
adjacency check at bank 2 `$AA48` compares these fields and accepts orthogonal
neighbors, confirming that this pair is the unit position.

The supplied technical-parameters chart corrects the earlier
interpretation of other arrays. For the IDs shown in the chart, the 13-byte
records match its level IDs and parameter values: bytes 0–1 are HP, 2–3 attack,
4–5 an experience-related value, 6 defense, 7 movement allowance, and 8
technique ID. For example, ROM type 1 contains
`150 HP / 110 attack / 100 experience / 105 defense / 3 move`, exactly as the
chart's level ID 1 row; type 6's technique ID 34 also matches. The visible
movement values for level IDs 0–55 all match ROM bytes exactly. The chart's
experience values match the type-record field for 54 of 56 rows; level IDs 14
and 17 show 480 in the chart and manual, while their ROM type records contain
400. This is a field-value mismatch, not the promotion comparison source:
promotion code reads the separate threshold table at `$97AD`.
Byte 9 remains the separate graphic selector consumed by OAM/PPU lookups.
Bytes 10–12 are copied into RAM but still need field-by-field interpretation.

The chart transcription also provides the warrior progression's class-ID/type-ID crosswalk:
class 0 is the level-0 warrior, classes 1–3 are the three first branches, and
classes 4–18 are their upgrades. This mapping and its branch edges are exported
in `data/rom_class_reference.json`, alongside ROM-derived stats for all 56
displayed levels. The image lists 19 technique IDs (including the special
ID 34) with names, range, area, and effect; those values are transcribed into
the same file as reference data and are not yet verified against executable
combat code. ROM types 56–71 are outside this warrior chart.

Bank 8 `$81E8–$81FF` copies record bytes 0–1 into `$6557/$6558` and derives
`$65A7/$65A8` by subtracting `$05F1/$05F2`. These values therefore derive from
HP data, not stage positions. Bank 2 `$88A0–$88D8` adjusts `$65A7/$65A8` and
checks the result against `$6557/$6558`, consistent with a current-HP value
bounded by maximum HP. The exact role of the global offsets remains open.

The loader at bank 8 `$817E–$81FF` calculates `$8B7C + index × 13` using the
shared multiply helper at `$9BCA`, so `$8B7C` is the base of a 13-byte
fixed-stride record array. The index comes from `$05E8`; the preceding lookup
at `$8149` checks that value against seven counted ID lists rooted at the
pointer table `$8B1E` and records the matching list number in `$05E7`. Those
list memberships and record bytes provide useful raw data, but their higher
level game meanings have not been decoded yet.
The 13-byte record loader copies offsets 0–12 into RAM arrays in this order:
`$6557`, `$6558`, `$6647`, `$6648`, `$65F7`, `$65F8`, `$6697`, `$66BF`,
`$66E7`, `$6467`, `$6711`, `$6739`, `$6761`. Offset 9 is especially useful:
the resulting `$6467` value is consumed by both the OAM template lookup and
the indexed PPU stream lookup. This establishes the direct data path from a
13-byte unit definition to the graphic selector value. The OAM path includes
the two aliases described above; the NMI PPU stream table has 25 primary
entries, with its selector-26 overread still unresolved.
The extractor `research/tools/extract/extract_unit_slot_records.py` exports those seven lists
and their 73 referenced IDs to `data/rom_unit_slot_records.json`. The group
counts total 73, and the IDs cover 0–72 exactly once. IDs 0–71 index the
13-byte data records ending at `$8F23`; ID 72 computes to `$8F24`, the bank-8
code entry reached by the jump at `$8003`, so it is marked as a special
overlapping index and is not decoded as a unit record. The supplied technical
parameters chart identifies the stat fields in IDs 0–55; byte 9 feeds the
graphic selector array. Remaining fields are preserved raw with their loader
destinations.
Auditing byte 9 finds that record ID 71 stores selector 26. Bank 12 has a
separate selector-indexed stream table at `$801C`; its callback uses slot
selector `$6408`, reads the graphic ID from `$6467,X`, and its selector-26
lookup reads `$EDAD`. This stream decodes to 28 segments / 3,802 bytes starting
at PPU `$3C9C`. The PPU address wraps at `$4000`, leaving 2,934 bytes at
`$0000–$0B75`. Those bytes
cover all 28 distinct tile IDs referenced by selector 26's 56-entry OAM
template at `$BA0F` (tile IDs 0–65, including 65). This is strong static
evidence that the bank-12 upload supplies the extended sprite layout's pixels;
emulator capture is still needed to confirm when it is resident.
`research/tools/render/render_selector26_oam_preview.py` composites the 56 OAM entries against
the post-wrap CHR upload and writes `assets/rom_reference/rom_selector26_oam_composite.png`
with a JSON manifest. The result is a 49×64 logical-pixel grayscale debug view.
It normalizes the minimum OAM x/y offsets to the image origin and applies the
OAM flip bits. It does not reconstruct palette colors, priority, runtime
position, or prove that the CHR data is resident at the same time. Browse the
image in `scenes/rom_asset_catalog.tscn`.
The selector-26 pointer is read from `$8050`, overlapping the first two opcode
bytes of the bank-12 callback body; those bytes form `$EDAD`. The source target
contains a structurally valid PPU stream, but the table/code overlap does not
by itself prove whether this layout was deliberate.
The wrapped stream and its post-wrap CHR-region tile preview are recorded in
`assets/rom_reference/rom_prg13_src_edad_ppu_3c9c.{bin,json}` and
`assets/rom_reference/rom_prg13_src_edad_ppu_3c9c_ppu_0000_tiles.png`. Recreate
them with:

```sh
python3 research/tools/extract/extract_ppu_stream.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference \
  --bank 13 --low-bank 12 --high-bank 13 --pointer 0xedad
```

The extractor now records PPU address-space wrap regions, and the OAM tile
candidate renderer includes tiles found after a `$3FFF → $0000` wrap.

The separate bank-22 NMI table remains 25 primary entries. Its selector-26
overread reads `$9848` from bytes overlapping the callback code and yields
header `$0000, $80` (destination `$0000`, 128 segments), unlike the canonical
uploads to `$0800` with 4–6 segments. Do not treat that overread as the
selector-26 asset. Whether the `$6805` gate prevents this NMI callback or a
separate caller handles the extended selector is unresolved.

The following older axis interpretation was superseded by the stage-0
deployment-to-screenshot match above. Bank 2 `$8102` initializes `$6802` to
zero; `$886C–$8881` subtracts it from the first position field before
multiplying by 16 pixels. The input handler at `$81A5–$827A` compares `$6802`
with `$6801` and tests the value in `$0618` against `$60` and `$E0`. Depending on these values,
the handler moves `$0618` or changes `$6802`, then refreshes display state.
`$6801` is the comparison/bound value in this handler; its broader role is not
yet confirmed. The battle record's fourth byte gives a 15- or 30-cell scroll
limit. The map pointer supplies the corresponding two or three contiguous
16×15 terrain pages. These pages stack vertically in the corrected map.

A live FCEUX capture adds a useful constraint. On stage 0, at frame 1,329,
`$6801/$6802` read `$0F/$02`; after the user pressed Right, a later capture at
frame 10,117 read `$0F/$01`. The three player and eight opposing unit position
bytes remained unchanged, while `$0616/$0618` changed from `$00/$50` to
`$70/$60`. After a subsequent Left press, frame 16,215 still read `$0F/$01`,
while `$0616/$0618` changed to `$60/$60`. These input-separated samples show
display-related RAM can change without rewriting deployment coordinates, but
do not by themselves distinguish cursor updates from rendering temporaries or
scrolling. The captures were separated
by many emulated frames, so they do not prove a one-to-one response to either
button. A third
capture after another Right press, at frame 19,595, kept `$6801/$6802` at
`$0F/$01` and `$0618` at `$60`, while `$0616` returned to `$70`. After two more
Right presses, frame 89,807 still had `$6801/$6802 = $0F/$01` and unchanged unit
deployment coordinates, while `$0616` advanced from `$70` to `$90` and `$0618`
remained `$60`. This does not establish a rightward cursor displacement:
static code at `$886C–$8881` writes a unit's render Y pixel to `$0616` and X
pixel to `$0618`, while the right-input path also updates `$0618`. These RAM
locations are reused as drawing and movement temporaries, and the end-of-frame
snapshot can miss input-time values. The Lua helper has been extended to
capture `$0617/$0619`, `$05CF`, and `$6408` as well; reload it before the next
input sample. It now records writes to `$0616–$0619` during active input and
every write to `$6802`, so the next sample can distinguish transient cursor
updates from end-of-frame drawing state. A correlated screenshot is still
needed to map the trace to the visible cursor and confirm terrain scrolling.

The indexed PPU stream selected by `$6409` is therefore
associated with a slot adjacent to `$6408` on this path, rather than directly
with the OAM template selected by `$6408`.

All 25 selected streams decode successfully to PPU `$0800`, with 4–6 segments
and 444–1326 payload bytes. Entry 16 begins at `$BE94` and crosses the CPU
`$BFFF/$C000` window boundary; its payload continues from the adjacent PRG bank.
`research/tools/extract/extract_ppu_stream.py` now supports reading across paired low/high PRG
windows, and `research/tools/extract/extract_bank22_indexed_streams.py` extracts the whole table
plus a manifest at `assets/rom_reference/rom_bank22_indexed_ppu_streams.json`.
Open `scenes/rom_indexed_ppu_streams.tscn` and press F6 to browse the 25 tile
sheets.

## PPU 图样表选择与 OAM 图块查找

The PPUCTRL shadow at `$6401` is initialized to `$90` in the startup/scene
initializers. The common dynamic updates mask off the low two nametable bits
and OR in a new nametable number; they preserve bit 3. The only writes found
to `$6406` copy the current `$6401` value there, and the corresponding restore
copies it back, so this is not an alternate sprite-pattern-table setting.
Routine epilogues write `$6401` back to `$2000`. In the examined gameplay
paths, PPUCTRL therefore selects sprite patterns from `$0000–$0FFF` and
background patterns from `$1000–$1FFF` (bit 4 set). Direct `$90` and `$94`
writes likewise leave sprite-table bit 3 clear; `$94` changes the VRAM
address increment bit only. The PPU `$1000` streams previously compared with
OAM IDs are background-side candidates, not evidence of the battle sprites.

The indexed NMI callback's 25 primary streams write at `$0800`, which is also outside the ordinary
8x8 sprite tile range `$0000–$03FF`. Two direct bank-10 uploads target PPU
`$0010`; each carries 256 bytes (16 tiles), so they populate sprite tile IDs
1–16. The extracted candidate chart confirms these two sources contain the
OAM-referenced IDs 14 and 15. This is the first concrete lower-page match.
The OAM templates also reference IDs 22–56. A new bank-12 selector-26 stream
wraps through PPU `$4000` and supplies CHR bytes for tile IDs 0–182, including
all tiles used by its 56-entry OAM template. This is a strong static pairing
for selector 26 and is now included in the candidate coverage chart. It does
not yet establish which other selectors use that CHR upload or whether the
assets are resident together. The extracted `$1000` graphics remain
background-side data, and the boot CHR sheet does not establish battle usage.

The NMI staged-transfer mechanism uses `$05C0/$05C1` as the PPU address and
`$05C4` as byte count for data staged at `$0400`. Static searches found many
callers, but the immediate destinations inspected so far resolve to palette
space (`$3Fxx`) or nametable space (`$20xx`, `$23xx`, `$2Fxx`). A few direct
`$0000` PPU writes in the repeated `$A500` code clear a small region; they do
not provide the missing sprite pixels. This does not rule out a computed or
mapper-dispatched graphics upload elsewhere, but it rules out treating the
currently identified generic staged transfers as proof of the higher tiles.

This conclusion is based on static ROM byte scans and call-path inspection;
the custom Mapper 15 bank mapping and frame-time writes have not been traced
in an emulator. Do not promote the current `$1000` sprite montage to an
in-game battle reconstruction.

These indexed streams write the upper half of pattern table 0 (tile slots
128+), so they do not directly explain the low OAM tile IDs 14–56. Their
per-record selection is nevertheless a confirmed additional graphics update
path. The OAM candidate sheet also now includes the initial bank-60 CHR block:
it contains IDs 48 and 56, but those pixels belong to the boot splash and are
not evidence that the battle uses them.

The OAM tile IDs are cross-indexed against every extracted stream at both
possible 8×8 sprite pattern-table bases, `$0000` and `$1000`. The `$0010`
streams provide byte matches for OAM IDs 14 and 15 in the statically selected
sprite table. `$1000` streams and the boot-splash CHR block provide visual
byte matches for some other IDs, but the PPUCTRL trace places them on the
background side on examined paths. The bank-12 `$EDAD` stream provides a
direct selector-26 association: after the PPU address wraps from `$3FFF` to
`$0000`, its CHR region contains every tile used by the 56-entry selector-26
OAM layout. This also gives byte-range coverage for IDs 22–56, but does not
prove those bytes are resident for the other OAM templates. The candidate
sheet and source/table mapping are
`assets/rom_reference/rom_oam_tile_candidates.png` and
`assets/rom_reference/rom_oam_tile_candidates.json`. Rebuild them with
`research/tools/render/render_oam_tile_candidates.py`; the sheet is also included in the Godot
asset catalog.

Visual inspection of the two `$0010` sheets suggests small status or interface
symbols (including heart-like shapes), rather than a complete character set.
That is only a visual interpretation of the grayscale pixels. The stream
destination and tile-number overlap establish a possible OAM source for IDs 14
and 15, but the runtime record-to-upload association is still unconfirmed.

One concrete PPU pattern upload is now traced through the callback path: bank
10's callback-0 routine at `$800F` sets source pointer `$99A6` and calls its
`$941C` PPU stream writer. That routine writes `$99A6`'s stream to `$2006/$2007`.
The stream starts at PPU `$1010`, declares five length-prefixed segments, and
expands to 538 bytes ending at `$122A`. A segment length byte of zero means 256
bytes here: the 6502 loop loads X with zero, then `DEX/BNE` emits 256 bytes.
Interpreting the result as NES 2bpp tiles yields a visible sheet of numeral and
small scene/object graphics. The final ten bytes form a partial tile, so the
preview preserves them but does not imply a complete tile there.

`research/tools/extract/extract_ppu_stream.py` reproduces this extraction, writing the raw PPU
payload, JSON boundaries, and a grayscale 2bpp tile sheet to
`assets/rom_reference/`. The Godot preview scene is
`scenes/rom_chr_preview.tscn`. This is the first direct pixel-graphics asset
recovered from a player-facing callback; it is not yet linked to one of the
bank-18 OAM templates, and its palette/use in a complete screen remain unknown.
Regenerate it with:

```sh
python3 research/tools/extract/extract_ppu_stream.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference --bank 10 --pointer 0x99A6
```

Callback 1 also provides a larger graphics upload. Bank 10's `$868B` routine
sets source pointer `$C64A` and calls `$941C`; in the upper PRG window this
stream is at physical bank 11. It starts at PPU `$1000`, has four segments, and
expands to 716 bytes ending at `$12CC`. The grayscale 2bpp preview shows
character and object-like tiles. Since it writes the same general PPU pattern
area as callback 0, these are separate callback graphics states, not proof that
both sheets are resident together. The Godot preview scene shows each with its
callback and PPU address labeled.

Extract callback 1 with:

```sh
python3 research/tools/extract/extract_ppu_stream.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference --bank 11 --pointer 0xC64A
```

The same `$868B` routine continues with three more streams at `$CA2E`, `$CEB0`,
and `$CF64` in the bank-11 upper window. They write 256 bytes each to PPU
`$1400`, `$1A00`, and `$0010`, respectively. `$CF64` and callback-2's `$F4C8`
both write to `$0010` but contain different pixels; the extractor now includes
the source pointer in each filename so these assets cannot overwrite each
other. The complete seven-stream catalog is viewable in
`scenes/rom_asset_catalog.tscn`.

```sh
python3 research/tools/extract/extract_ppu_stream.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference --bank 11 --pointer 0xCA2E
```

Callback 2's `$8E17` routine performs a pre-upload from upper-window pointer
`$F4C8`, which resolves to physical bank 11. It writes one 256-byte segment at
PPU `$0010` (tile slots 1–16). The resulting preview contains compact icon-like
tiles. This is a separate upload state; although some OAM templates use tile
IDs in that range, their actual association is not yet established.

Extract this stream with:

```sh
python3 research/tools/extract/extract_ppu_stream.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference --bank 11 --pointer 0xF4C8
```

The bank-10 routine at `$9050` first reuses the `$99A6` upload, then sends
another stream at `$9DBA` to PPU `$1420`. The second stream expands
to 256 bytes and previews as a compact numeral/symbol strip. The new PNG and raw
bytes use the same extractor; `scenes/rom_chr_preview.tscn` now includes this
view. The `$9050` address appears in bank 10's local jump table, but is not one
of the three distinct targets in the `$FFAF` callback dispatch table. Bank 10's
`$93F7` target is a coordinate calculation loop, not another PPU stream entry.

```sh
python3 research/tools/extract/extract_ppu_stream.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference --bank 10 --pointer 0x9DBA
```

## 不同地区 ROM 对比

The simplified and traditional `970261` ROMs have identical 16-byte headers
and differ in 26,391 PRG bytes. Every changed byte is in 16 KiB banks 6, 28,
or 29 (6,319 / 10,278 / 9,794 changed bytes respectively). This makes those
banks the first places to inspect for translated text and related graphics;
it also suggests the two builds share most executable/data banks.

## 战场关卡表与地图数据线索

The stage loader at bank 2 `$8046` requests callback bank `$04`, callback
index 0, through the shared `$FF50` dispatcher before building the map. Bank 4
`$8000` jumps to callback entry `$8006`; that routine uploads three shared PPU
streams and then selects a fourth stream from a 19-entry pointer table at
`$804B` using the current stage index in `$6400`. The stream writer at `$8094`
consumes a PPU address, a segment count, and length-prefixed data. This links
the stage table to stage-specific CHR uploads, independently of the bank-10
sprite callback streams.

`research/tools/extract/extract_battle_stage_graphics.py` extracts the three shared uploads and
each selected stage upload to raw binaries and grayscale tile sheets. In call
order, the shared streams start at `$8322` (PPU `$1700`), `$8506` (PPU `$1910`),
and `$80DE` (PPU `$0010`); the third is in the sprite pattern-table range. All
19 selected stage uploads target PPU `$1010`;
the first stage uses source `$859A`, expands to 514 bytes, and ends at `$1212`.
The manifest is `assets/rom_reference/rom_battle_stage_graphics.json`.
Visual inspection of the shared tile sheets shows numerals and symbols in the
`$0010` upload, glyph-like shapes in the `$1700` upload, and window-border
shapes in the `$1910` upload. These look like interface graphics and do not
match the stage-map tile IDs; their exact users are not yet traced. In
particular, the `$0010` stream should not be treated as the missing unit-sprite
sheet solely because it is in the sprite pattern-table address range.
Rebuild the set with:

```sh
python3 research/tools/extract/extract_battle_stage_graphics.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference
```

PRG bank 2 contains 19 consecutive 12-byte records beginning at CPU `$8610`.
Code at `$8046` indexes the table with `$6400`. It checks `$05CD`: values
`$01–$FE` set Y to 3 before reading the record, while `$00` and `$FF` use Y=0.
The battle-map path uses the Y=3 layout, which aligns the record's four pointers
at offsets 4, 6, 8, and 10 as map base, 2×2 tile-composition table, display-map
start, and palette packet, respectively. The Y=0 path is a separate loader
state and has not been fully characterized.

For the first record (`03 00 08 0F 9D B9 25 B9 BD B9 1B B9`), the four pointers
are `$B99D`, `$B925`, `$B9BD`, and `$B91B`. The tile table at `$B925` ends exactly
where the base map-code data begins at `$B99D`: the 120-byte span is 30
four-byte entries, and the displayed map codes range from 0 to 29. The display
pointer `$B9BD` starts 32 bytes (two 16-cell rows) into that map data. The
palette packet at `$B91B` has header `$08,$08`, followed by eight bytes for
PPU `$3F08`; it ends exactly at the tile table start.

The display map is **16×15 cells**. `$A15B–$A1BB` calls `$A06B` once for each
of 15 rows; the worker reads 16 map codes per row from `($14),Y`. Each code
indexes four bytes from `($10),Y` at `code * 4`, then writes those tile IDs
into a 2×2 block in the nametable staging buffer. Codes at or above `$40` take
a separate path that increments the high byte of the ROM table pointer before
reading the four tile IDs. This supports tables longer than 256 bytes; stage
17 has 69 entries and uses code `$44`.

The same worker also builds the nametable attribute table. `$12/$13` points to
the map base, whose prefix before the display-map pointer is a palette lookup
indexed by map code. For each cell, `$A06B` reads `map_base[map_code]`, places
its two palette bits in the correct quadrant of an attribute byte, and stages
the packed bytes at `$0440`. The cell position selects shifts 0, 2, 4, or 6;
thus the 16×15 metatile grid produces an 8×8 byte attribute table. The table
prefix is long enough for the largest map code in every record, including
stage 17's 68. Every value referenced by a displayed map code is a valid
palette index from 0 to 3.

`research/tools/extract/extract_battle_stage_records.py` now exports all 19 displayed 16×15
grids, each record's actual four-tile compositions, the palette lookup by map
code, the resulting 16×15 palette-index grid, the packed
8×8 nametable attribute table, the shared battle palette packet, and each
stage's eight-byte palette override to
`data/rom_battle_stage_records.json`. Its default
window mapping reads physical
bank 2 at `$8000–$BFFF` and bank 3 at `$C000–$FFFF`, matching the adjacent
bank-pair layout; both bank numbers are command-line overrides because the
Mapper 15 runtime mapping has not yet been debugger-verified. Regenerate with:

```sh
python3 research/tools/extract/extract_battle_stage_records.py \
  'BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  data/rom_battle_stage_records.json
```

The colorized, hexadecimal-labeled code grids for all 19 records are shown in
`assets/rom_reference/rom_battle_stage_code_atlas.png` and in the Godot asset
catalog. Colors are diagnostic labels for map-code values, not recovered NES
art. Rebuild the sheet with:

```sh
python3 research/tools/render/render_battle_stage_code_atlas.py \
  data/rom_battle_stage_records.json \
  assets/rom_reference/rom_battle_stage_code_atlas.png
```

The record's map, composition, and palette data now decode directly from ROM.
The stage-0 composition over the PPU `$1000` graphics candidate, with its
stage-specific `$859A` upload overlaid at `$1010`, renders the same wall,
courtyard, south gate, river, and bridge layout as `2b.png`. The preview is
`assets/rom_reference/rom_stage00_composed_stage_chr_candidate_grayscale.png`.
This strongly links the recovered metatile table to the captured battle art.
The battle loader first sends packet `$B5D5` to PPU `$3F00` (32 bytes), then
sends the selected stage packet to `$3F08` (8 bytes), replacing the background
palette entries for palettes 2 and 3. Both ROM packets are included in the
stage-record JSON. The color preview uses an external FCEUX `.pal` file to map
the ROM's NES palette indices to RGB; that RGB mapping is an emulator display
choice. The bank-10 battle setup at `$869D` sets PPUCTRL to `$90`, then uploads
`$C64A` (716 bytes at `$1000`), `$CA2E` (256 bytes at `$1400`), and `$CEB0`
(256 bytes at `$1A00`), followed by `$CF64` at `$0010`. The first three writes
affect background tile IDs 0–44, 64–79, and 160–175 respectively. The 19
recovered maps reference background tile IDs up to 89, so `$CA2E` supplies a
previously missing portion of the tile range used by maps. `$C64A` and the
per-stage `$1010` stream cover stage 0's referenced IDs up to 40; other maps
also use tiles outside those writes.

For a full diagnostic set, the 4 KiB boot CHR page from bank 60 `$82BC` is
used as a provisional background page, then the known battle uploads are
applied in callback order, and the selected stage `$1010` upload is applied
last. All 19 map records can then be drawn as grayscale 256×240 candidates.
The gallery is `scenes/rom_battle_stage_reconstruction.tscn`; open it and press
F6. Rebuild its source images with `research/tools/render/render_all_battle_stage_candidates.py`.
This shows that the recovered map and metatile records form coherent battle
layouts across all 19 records. It does not establish that the boot CHR page is
the page present during battle: the remaining tile sources and Mapper 15
runtime mapping still need an emulator debugger trace. Treat maps whose tiles
come from the provisional boot page as visual candidates pending that trace.
Recreate the diagnostic composition with:

```sh
python3 research/tools/render/render_battle_stage_preview.py \
  data/rom_battle_stage_records.json \
  assets/rom_reference/rom_prg11_src_c64a_ppu_1000.bin \
  assets/rom_reference/rom_stage00_composed_stage_chr_candidate_grayscale.png \
  --stage 0 \
  --overlay-chr assets/rom_reference/rom_battle_stage_00_chr_ppu_1010.bin \
  --overlay-ppu-address 0x1010 \
  --overlay-chr assets/rom_reference/rom_battle_shared_chr_00_ppu_1700.bin \
  --overlay-ppu-address 0x1700 \
  --overlay-chr assets/rom_reference/rom_battle_shared_chr_01_ppu_1910.bin \
  --overlay-ppu-address 0x1910 \
  --rgb-palette /path/to/FCEUX.pal
```

## 尚待解码内容

- Decode the ROM assets and control flow that produce the observed player-facing title and following menu.
- Trace the bank-18 record consumers and identify what each field loads.
- Confirm runtime order and the source of CHR bytes not overwritten by each
  stage-specific `$1010` stream; compare the palette-index render against the
  live battle with the same emulator palette.
- Trace additional callback streams and map extracted tile IDs to the OAM templates.
- Confirm Mapper 15 hack bank-window behavior for the callback and data pointers
  in an emulator debugger before assigning runtime PRG bank IDs to all fields.
- Capture the live `$6807` list for a later-stage party; trace the earlier
  stages' roster-menu cap; decode the remaining auxiliary bytes in stage layout
  records. Stage-0 roster slots 0–2 resolve to type 0 in the startup table.
- Validate the recovered tile compositions against runtime CHR and nametable
  state.
- Trace command effects, damage, AI, turn order, and stage exits.
- Compare decoded records against the manual and the `3.png` battle reference.

These notes record binary evidence, not a completed disassembly. The 19
recorded 16×15 map windows, their tile-composition tables, and palette packets
are extracted. The Godot battle board remains a visual prototype until the
corresponding background CHR patterns and gameplay rules are reconstructed.

OpenEmu-Silicon was observed running the Simplified Chinese ROM in its FCEU
core on 2026-10-02. The live output reached the player-facing `爆笑三国` title
screen with the animated `START` prompt, then the main menu with `开始游戏`
(selected by default) and `读取进度`. Starting a new game reached a difficulty
page showing `容易级`, `熟练级`, and `高手级`; the live screenshot shows the
cursor on `容易级` (the easiest setting).
The A button advanced through the opening story and reached the live first
battle in OpenEmu-Silicon. The observed story cards include a caption about
Liu Bei selling straw sandals, a card describing a hero as exceptionally brave,
and a Three Sworn Brothers / Peach Garden card. The sequence reaches the
`宛城之战` title card and then a walled courtyard beside a river, with a bridge
through the south gate. The live battle view shows six units: one toward the
north of the courtyard, three in its center, and two just south of the bridge.
The local `2.png`, `2a.png`, and `2b.png` references agree with the opening
story and title card. This confirms the publisher splash extracted above is an
earlier screen, not the player-facing title screen.

The courtyard-and-river view is a 16×15 board with a castle wall, south gate,
bridge, river, and six units. Local `2b.png` shows the title card `宛城之战`
over the same castle layout as `image2.png`, which is labeled `守城之战`; the
live OpenEmu intro also says `宛城之战`. Stage-0 map codes, tile compositions,
and palette attributes are decoded from ROM; Godot displays a pre-rendered
stage-0 composition by default, with F3 switching to the earlier hand-drawn
comparison. F4 shows the ROM map code, palette index, and four tile IDs beneath
the cursor. Runtime CHR order is not fully captured. Unit positions and artwork
remain approximate, and command effects are not implemented.

The included Chinese manual specifies the controls: the D-pad moves the cursor,
A opens the battle-command menu, B cancels the previous command, and START opens
the status menu. It says the player can command all allied units and use the
directional pad to move them or select an attack target. Godot now requires the
cursor to be on a prototype allied unit before opening its A-button menu, and B
cancels. The manual does not give movement range or terrain costs. ROM tracing
confirms that the normal movement path uses a per-unit movement allowance and
Manhattan tile distance. The Godot ROM movement sandbox applies the allowance
for all 72 valid unit records; chart labels are available for IDs 0–55. The
first ten stages' deployment export now joins player roster slots to type IDs
and movement values, and F6 displays them. The six screenshot-transcribed mock
units in the regular battle view remain unrestricted until their identities
and screen-to-stage mapping are resolved. Per-stage passability and occupancy
checks are now exported and applied in the movement sandbox. Pressing Start in the live battle opens
`全军休息`, `全军撤退`, `战斗动画`, `读取进度`, `储存进度`, and `音乐`.
The separate `3.png` reference shows a wooded battle screen and is not yet
identified as a specific campaign stage.

## 在 FCEUX 中截取的运行画面

The root-level `../image2.png` is a live FCEUX 2.6.6 game capture. It shows a
fortified river crossing and the Chinese scene label `守城之战`. The
`../BaoXiaoSanGuo/2b.png` image is a native 256×240 view of the same basic
castle/river layout labeled `宛城之战`. Treat both as layout references; the
different labels need to be reconciled against the live ROM state.
This capture contains the stage title and six visible sprites, so it does not
establish the battle's active `$6807` deployment list or the selected types.

The root-level `../image3.png` is FCEUX's live Sprite Viewer for the same run.
It reports Sprite RAM, sprite index `$00`, tile index `$01`, tile address
`$0010`, palette address `$3F10`, and screen position `(112, 96)`. This is a
runtime confirmation that the selected sprite uses tile 1 in the `$0000`
pattern-table path and the sprite palette at `$3F10`. It does not identify the
sprite as selector 26; that selector's 56-entry layout and `$EDAD` upload still
need to be observed together in the emulator.

Cross-checking the available static templates narrows this further: tile `$01`
does not occur in any of the 25 decoded bank-18 OAM templates or selector 26's
56-entry template. The screenshot palette `[10,18,28,30]` also does not match
the exported bank-18 sprite palettes. This sprite viewer capture therefore
records a runtime graphics state not represented by those templates and cannot
identify one of the battle unit classes. The active CHR/palette uploads at the
captured frame still need to be traced before using this sprite as art evidence.

The 13-byte unit records' byte offset 7 is the per-unit movement allowance.
The loader copies it into `$66BF,X`. Bank 2 `$8B8A` selects the active unit with
`$6408`; when `$05CC` is zero, it reads `$66BF,X`, subtracts `$05E6`, and stores
the remainder back to `$05E6`. Callers check the remaining value and reject
negative movement budgets. When `$05CC` is nonzero, the same routine uses
`$670F` instead. The preceding helper at `$8BC9–$8C2B` calculates Manhattan
distance by summing the absolute horizontal and vertical deltas after converting
each axis to 16-pixel tiles. Across 72 valid definitions, movement allowance
values range from 2 to 8 and vary with unit class/promotion. The extracted
values are available as `movement_allowance_points` in
`data/rom_unit_slot_records.json`. The limit therefore uses movement points
against Manhattan tile distance in this path. Occupancy and passability checks
still need tracing. The Godot movement sandbox now uses that allowance and
distance rule for a separate movable test unit; it does not assign guessed
types to the six mock battle units.

The remaining Godot linkage is the active battle slot's class ID. Bank 10
`$8F73–$8F8B` indexes a table at `$901F` using `$05ED` and `$05CC`, then writes
the selected byte to `$643F,X` and `$05E8`. The meaning of this lookup in that
caller is not established; `$05ED` is independently confirmed as a graphics
selector in bank 2 `$9684` and bank 12's callback. Do not treat this `$8F73`
path as a class-promotion list until its caller and state are traced. Bank 2
`$9673–$9682` maps the selected slot's current type through `$983F` to
`$05ED`.

Startup code in bank 0 `$80C6–$80F4` copies 20 three-byte records from bank 0
`$C195` into RAM arrays `$651B`, `$652F`, and `$6530`. The first byte of each
record is a valid unit-definition ID (the observed values are
`0,0,0,0,56,8,62,65,4,19,58,60,37,23,29,41,18,65,23,45`); the other two
bytes form a 16-bit value whose meaning has not been confirmed. This is the
campaign roster seed. Bank 10 `$8BA0–$8BCF` appends `$05C7` to `$6807` if it is
not already present and increments the count at `$6813`; `$8D0E–$8D30` removes
a matching entry by shifting later entries down and decrementing the count.
Bank 10 `$87FF` clears that count before rebuilding the selectable list. The
bank-8 `$800F–$813F` initializer branches on `$6400 < 10`: for the first ten
stages it copies the battle header's player count (`$6413`) to `$6813` and
reads roster slots from the stage-layout stream. In the stage-10-and-later
branch, bank 8 `$8035` reads `$6807,X` and `$8038` jumps directly to `$8043`.
That jump skips `$8041: B1 1E`, the stage-layout roster byte load used by
stages 0–9. `$8043: 9D DF 64` stores the selected roster index, `$8046: AA`
places it in X, and `$8048: BD 1B 65` resolves its current unit type from
`$651B`. Thus the later-stage selected list directly determines player types
and their order; the stage layout supplies their Y/X positions. `$6813` is a
selection count in the roster menu but
is repurposed as the deployment count for stages 0–9. The startup seed alone
does not reveal the later-stage selected list; mapping the six visible
screenshot sprites to later roster slots would still be a guess.

The list is player-edited rather than a fixed three-person ROM roster: bank 10
`$87FF` enters the roster selection flow and clears `$6813`; `$8BA0–$8BCF`
appends selected roster-slot indices to `$6807`, while `$8D0E–$8D30` removes
one and compacts the list. Before appending, `$8BD1` compares `$6813` with
`$05EF` and refuses the addition at the cap. Setup at `$8783–$87A3` loads
`$05EF` from the second byte of a stage-indexed record. The pointer table at
`$8D3E` covers stages 10–18 and yields caps `8, 6, 8, 8, 10, 10, 10, 10, 12`.
These values are exported in `data/rom_roster_selection_limits.json` by
`research/tools/extract/extract_roster_selection_limits.py`. This table does not cover stages
0–9, so their roster-menu cap remains unresolved. This is separate from the
number deployed in those battles: stage 0 has three layout entries, roster
slots 0, 1, and 2 at `(25,7)`, `(26,8)`, and `(27,7)`. The startup seed maps
each of these slots to initial unit type 0. Bank 2 `$9894` writes a unit's
current type from `$643F,X` back into `$651B,X`, so promotions can make these
startup joins differ from a later save's current type. For stages 10–18,
capturing `$6807` and the current `$651B` roster types is necessary to
reproduce a particular save's deployed party. The demo's later-stage roster
selector uses the initial `$651B` seed because promotions are not yet carried
across stages.

The roster seed and movement values are joined in
`data/rom_campaign_roster_seed.json`, generated by
`research/tools/extract/extract_campaign_roster_seed.py`. In seed order, the known movement
points are `2, 2, 2, 2, 2, 5, 4, 4, 2, 3, 3, 3, 7, 4, 5, 3, 3, 4, 4, 4`.
The two-byte value stored beside each type is exported as
`unknown_value_16bit`; its meaning is intentionally not guessed. This improves
the roster-level data but does not yet justify enabling class-specific limits
for the six mock battle units.

The local FCEUX executable at `/opt/homebrew/Cellar/fceux/2.6.6_12/libexec/fceux`
is a native arm64 Mach-O and supports `--loadlua`; this installation can be used
without Rosetta. `research/tools/fceux/fceux_dump_battle_ram.lua` is a read-only RAM snapshot
helper for recording `$6807/$6813`, resolved roster types, battle counts, unit
positions, `$6801/$6802`, movement mode/budget, and cursor/render coordinates
while playing. The latter fields are included to distinguish cursor movement,
unit animation, and horizontal viewport changes. It writes only to
`research/evidence/traces/fceux_battle_ram_snapshot.txt` when tracked values change. Example:

```sh
fceux --no-config 1 --loadlua /absolute/path/to/research/tools/fceux/fceux_dump_battle_ram.lua /absolute/path/to/BaoXiaoSanGuo.nes
```

The snapshot is runtime evidence for the current playthrough; it does not
replace the static campaign seed or establish a universal party-size rule.

Bank 8 `$800F–$813F` provides the stage-table link. It indexes a 19-pointer
unit-layout table at `$8241` with current stage `$6400`. At stages 0–9, it
copies the player deployment count from the battle header and resolves each
roster slot in the stage layout through `$651B`; their unit type IDs are joined
to the startup roster seed in the exported JSON. The stage-10-and-later branch
reads `$6807,X` and jumps over the stage-layout byte load to the shared type
lookup at `$8048`, so the selection's effect on deployed identities is direct.
The loop reads two position bytes into that slot's
`$648F/$64B7` position fields. It then adds the stage-specific opposing-unit
records. The paired battle record in bank 2 has its first three header bytes
copied to `$6413`, `$6415`, and `$6414` by `$8046`; later bank-8 code uses these
as player, unit-group-1, and unit-group-2 counts. The loops at `$8043`,
`$80B2`, and `$80F5` consume respectively 3, 4, and 6 bytes per entry. The
bank-8 code masks bit 7 from the group-2 type byte before resolving the unit
definition; that bit is retained in the export as `encoded_type_id`. Bank 2
`$A250–$A263` also reads bit 7 from the unit's `$6417` slot value and sets a
side/palette selector. The group-2 side flag is confirmed; its player-facing
faction label is not. All 19 streams parse to exactly their pointer-bounded
lengths using these counts.

The position fields' render transform is partly resolved in bank 2
`$886C–$8881`: `$648F - $6802` is multiplied by 16 into `$0618`, while
`$64B7` is multiplied by 16 into `$0616`. The supplied screenshot proves the
first raw position byte is world Y and the second is world X; the old axis
labels for those temporaries were incorrect. The movement helper
`$8BC9–$8C2B` subtracts the cursor and unit pixel coordinates per axis, takes
the absolute deltas, then shifts each delta right by four before summing. It
does not convert each coordinate to an integer tile first. Both decoded axes
index full 16-pixel cells. The sixth-stage movement slice uses the same
pixel-delta ordering for its budget check. Stage 0's three player entries
are at world Y=25, 26, and 27, so they appear when the viewport scrolls down.

This screen/world boundary also limits the sixth-stage movement slice. Stage
index 5 has five player deployments at Y=6, 11, 15, 15, and 11, while the 13
opposing deployments span Y=17 through Y=23. Its exported terrain spans two
16×15 pages, Y=0–29. The Godot slice reveals the opponents over their
decoded terrain as the viewport pans down to the record's 15-cell limit.

All 19 pointer-bounded layout streams, raw bytes, and parsed entries are in
`data/rom_stage_unit_layouts.json`. Use `research/tools/extract/extract_stage_unit_layouts.py`
to regenerate the export. Stage 0 points to `$8267`, has header bytes
`03 00 08 0F`, and parses to 3 player entries, no group-1 entries, and 8
group-2 entries. Auxiliary bytes in unit records remain uninterpreted. The
Godot battle view can display the known ROM positions with F6.

Bank 2 `$8C2F–$8CCB` validates a movement-cursor destination. It reads the
current map code, indexes a 19-entry stage pointer table at `$8CD0`, and searches
the pointed-to length-prefixed whitelist. A code absent from the list sets the
blocked result. If `$05CC` is zero, the routine also compares the destination
tile against every active slot's `$648F/$64B7` pair and marks occupied tiles;
nonzero `$05CC` bypasses that occupancy pass. The stage lists are extracted to
`data/rom_stage_movement_rules.json` by
`research/tools/extract/extract_stage_movement_rules.py`. Stage 0's whitelist is
`[2, 10, 11, 15, 16, 19]`; the Godot movement sandbox now uses the decoded map
codes and blocks the prototype units' occupied cells.

## 范围攻击结算与玩家技术切换（2026-10-05）

### 原版 ROM 证据

新增 `research/tools/fceux/fceux_area_damage_effect_trace.lua` 与三个 TSV。实验重放已有
录像后固定单位阵型，在 `$96C7` 将原有治疗动作改为指定伤害包。
这些是受控效果分支实验，不是自然 AI 决策或原版玩家菜单录像。

- `research/evidence/traces/rom_area5_damage_effect.tsv`：技能 3、40 伤害、十字，目标槽
  `[0,1,2,3]`；初始 HP `[10,40,50,100,50]` 变为
  `[0,0,10,60,50]`，对角目标未命中；同阵营施术者不受伤。
- `research/evidence/traces/rom_area9_damage_effect.tsv`：强制九宫格分支，同一初始值变为
  `[0,0,10,60,10]`。它确认九宫结算，不证明技能 3 自然使用九宫。
- `research/evidence/traces/rom_skill25_variant2_damage_effect.tsv`：技能 25、变体 2，
  十字每人 35，结果 `[0,5,15,65,50]`。

Bank 8 `$96C7–$9795` 为十字、`$9796–$98AA` 为九宫选区。
治疗按施术方筛选，伤害按对方筛选。中心先放入选定槽，其他槽仅扫描
邻格，因此同中心坐标的其他部署槽不额外命中。`$9AC3–$9B57`
依次扣血；扣至零和下溢均将单位状态置为 `$FF`。

技能 19–33 的变体 0 是治疗；本轮接入其正数伤害变体 1/2。
低编号技能的单体、十字和九宫正数包也已接入。射击类技能 1–10
采用技术参数图的最小距离 2；原版玩家距离菜单仍需运行追踪。

### Godot 阶段进展

第七战默认 type 62 的技能 25 可选择单体 65 或十字 35。选目标时
Q/E/Tab、手柄肩键、移动端侧栏按钮切换；绿色仍表示治疗。
范围伤害统一预览人数/实际总伤害，并处理阵营过滤、HP 下限、退场、
一次行动、一段结算动画、存读档、回合衔接和击杀后的过关切换。
普通敌军范围包使用同一选区逻辑；高阶敌军完整变体选择仍未还原。

临时可运行场景检查覆盖十字/九宫、同格部署、默认 type 62 的键盘
与触控切换、多目标退场、取消、存档恢复、末单位行动后敌方回合、
范围清敌后的下一关。已有群疗检查再次通过。
玩家切换界面为 demo 实现；不能据此声称原版菜单、费用或全体 AI
已完整复刻。当前漫画结算也不是全部原版技术动画。

## 技术子菜单边界与控制流（2026-10-05，静态解码）

Bank 8 `$8F24` 是技术菜单入口。`$8F3C–$8F6D` 读取选中单位
`$66E7,X` 的技术 ID，设置最高变体索引 `$05EA`：

| 技术 ID | 最高变体索引 | 菜单行数 |
|---|---:|---:|
| 1–18、34 | 0 | 1 |
| 19–23 | 1 | 2 |
| 24–29 | 2 | 3 |
| 30–33 | 3 | 4 |

`$8FAD–$8FAF` 将当前变体 `$05CD` 清零。输入循环
`$8FB2–$903F`：Down 掩码 `$04` 增加变体但不超过 `$05EA`，
Up 掩码 `$08` 减少变体但不低于零；B 掩码 `$40` 返回 `$FF`，
A 掩码 `$80` 调用 `$903F` 装载当前变体包。
因此技术变体先由菜单确定，再进入目标选取。旧 demo 根据目标阵营
自动选择治疗/伤害，是交互近似，本轮正常游玩入口已经替换。

提取脚本 `research/tools/extract/extract_rom_technique_effects.py` 将菜单原始指令字节、
地址、34 个技术的最高变体索引写入 `data/rom_technique_effects.json`
的 `player_variant_menu`。这属于静态控制流证据，不声称完成原版菜单
输入的运行追踪；原版选项文本、第四字节含义、是否另有资源费用未解。

Godot 按该边界列出菜单：已确认的正数单体/十字/九宫治疗或伤害可用；
尚未还原的特殊包显示不可用，不消耗行动。目标模式锁定为治疗或攻击，
不会因光标移到另一阵营而改变效果。目标选取 B 返回技术菜单，再 B
返回四指令菜单，再 B 取消选择。菜单本身的排版和语义名称为 demo UI。

新增 C/V、手柄 X/Y、触屏“下一目标”是复刻版便捷操作，非原版键位。
它按部署槽顺序遍历可选目标，过滤死亡/阵营/距离/满血无受益治疗，
并保持竖向滚屏。打开目标模式时保留合法光标，否则找最近合法目标；
无合法目标不花行动。重叠部署仍按光标能选中的首个活槽处理。

可运行场景检查已覆盖菜单行数、取消、锁定阵营、实际默认 type62 的
65 治疗/65 单攻/35 十字选择、触屏行选择、目标正反循环、不可用特殊
项、无目标、存档恢复；范围攻击的多目标结算/退场/回合/过关流程回归
通过。存档版本未改变，菜单及光标选择模式不持久化。

## 经验奖励、升级门槛与跨关成长（2026-10-05）

战斗经验是 `$65F7/$65F8` 的按槽 16 位值，队伍经验是
`$652F/$6530`。启动种子的原“未知 16 位值”现可确认属于累计经验。
Bank 8 `$8054–$8083` 将队伍经验装入战斗槽；bank 2
`$9888–$98B6` 将类型 `$643F` 和经验按 `$64DF` 队伍索引写回。

13 字节定义的偏移 10/11/12 分别装入 `$6711/$6739/$6761`，用于
攻击基础经验、技术基础经验、击杀附加经验。bank 2 `$8F86–$8FA1`
在普通攻击扣血前加基础经验，`$8FD4–$8FEF` 在击杀后再加附加值；
bank 8 `$9A41–$9A5E` 为非空技术目标列表只加一次基础经验，
`$9B16–$9B33` 为每个退场目标加击杀值。ADC 低字节加高字节，
不按目标伤害比例计算，也不在升级时减去门槛；会按 16 位溢出。

新增 `research/tools/fceux/fceux_experience_effect_trace.lua` 与
`research/evidence/traces/rom_experience_effect.tsv`：沿用受控 type60/十字效果实验，
真实经验从 280→285（技术 +5），随后两个击杀分别到 288、291
（每个 +3）。FCEUX Lua 不能跨 dofile 调用进行 frameadvance，
所以该工具将重放体内联。此实验没有证明自然玩家升级流程。

Bank 2 `$9657–$9675` 对照 **`$97AD` 的独立门槛表** 检查累计经验，
而非用新类型定义字段直接判断。`$983F` 的按类型字节为分支选择器：
`$FF` 自动类型 +1；其他值进入分支。bank 10 `$901F` 指针表
给出分支目的类型，菜单数量来自 `$8FB7` 每八字节记录的偏移 6。

| 分支 | 目的类型 |
|---|---|
| 0 | 1 / 3 / 5 |
| 1 | 7 / 10 |
| 2 | 13 / 16 |
| 3 | 19 / 22 |
| 4 | 25 / 29 |
| 5 | 33 / 37 |
| 6 | 41 / 44 |
| 7 | 47 / 50 |
| 8 | 53 |
| 9 | 57 / 59 |
| 10 | 61 |
| 11 | 64 |
| 12 | 67 |

类型0门槛100、类型1门槛180、类型2门槛300；类型62门槛1200。
`$FFFF` 项视为最高级停点。有效 13 字节定义至类型71；旧提取器
类型72对应 `$8F24` 起的指令字节，新成长表不将它当有效定义。
bank 2 `$8820/$884C` 在玩家攻击/技术后检查一次升级，没有逐级
循环；移动/休息不调用该比较。分支菜单 bank10 `$8F6A–$8FAD`
只有 A 确认，写入新类型并计算旧最大 HP 减当前 HP；自动升级
bank2 `$9694–$96A7` 同样计算损血量。bank8 `$81E9–$8200`
用新最大 HP 减旧损血量，重新装入属性时跳过经验字段。

Godot 新增 `scripts/campaign_progress.gd`。玩家战斗按上述奖励和
门槛成长、选择分支，并动态更新属性、移动和技术；过关将部署成员
的类型/经验提交到20人队伍，下一关/选将沿用；失败重试回到本关
进入时或读档恢复的队伍状态。新版本存档仍为版本1：旧格式缺失
经验时恢复种子，新格式在原位置/HP/行动验证之外验证全队成长路径
及部署经验一致性，全部通过后才写入运行状态。

场景检查覆盖初始95→101转职、损血保留、自动1→2、五目标击杀
技术基础经验一次加逐个击杀、治疗奖励、跨关/后期选将、JSON恢复、
旧安卓存档、错误成长字段原子拒绝、末单位转职后敌军回合、最后
击杀先选职业后过关、战败重试回滚。原版转职画面、自然升级输入
录像及自动友军/敌军经验仍未完整复刻。

## 2026-10-05：自动回合逐步呈现与结算分离

既有 bank2 `$A764–$A838` 组1友军调度先于 `$A839–$AA35` 组2敌军调度，
组2保留既有倒序槽位遍历。此次沿用已解码的 AI，不修改决策、伤害、治疗、
休息或目标分支。旧版本先完成全部 AI 结算、播放所有战斗动画，最后只定位
最后一名敌军，导致中间行动在地图上不可见。

现为每次实际行动记录行动者、说明、位置/HP快照及本次动画；战斗状态一次结算，
显示状态按事件顺序推进，输入锁立即生效。记录友军休息、移动、技术与攻击；
敌军保留既有逐动作记录入口。按 A 跳过仅终止播放，不再次运行 AI，也不改变
经验与最终存档值。相同敌军的移动、攻击保持两个相邻事件。

19关初始局面以临时可运行场景比较直接执行旧调度与新播放入口的最终位置/HP，
全部一致；另外核对治疗、休息、最终击杀、战败、完整播放与触控快进。真机旧存档
回合17→18快进、18→19完整播放已观察，旧存档文件校验值保持不变。
这些是 remake 运行证据，不是新增的原版完整 AI 输入回放。事件停留时长、
高亮、HP数值与快进属于复刻界面；逐格原版行走动画尚未还原。

相关实现：`scripts/battle.gd`、`scripts/battle_cinematics.gd`；构建、截图及实际覆盖见
[BUILD_TURN_PLAYBACK_MILESTONE.md](../docs/milestones/BUILD_TURN_PLAYBACK_MILESTONE.md)。

## 2026-10-06：当前兵种移动预算与战场信息

复核成长接入后发现玩家 `_selected_movement_points()` 仍读取关卡初始部署记录。
这会使转职、跨关成长和后期自选兵种继续使用部署种子的旧移动值。现直接按
`unit_type_ids[index]` 读取既有单位定义 `movement_allowance_points`，即 byte7
被原版载入 `$66BF,X` 的数值；路径、占用与地形检查不变。实际源码场景验证
0→1 转职后2→3、三格移动、读档后3，以及1→2升级后4。19关玩家部署均核对
当前类型的 ROM 值；后期选将不再依赖初始位置记录的兵种预算。

详情面板的攻击读 raw2/3、防御读 raw6、HP读当前槽位和 raw0/1，移动使用上述
公共入口。EXP升级目标来自实际比较表 `$97AD`，而不是图表或 raw4/5。技术
展示使用已提取的 packet；敌方治疗另合并 `$ADF6/$AE01` 等既有目标表的覆盖。
这些面板、HP条、行动标记和切换按钮是 remake UI，不代表原版菜单像素复刻。

普通攻击预览复用 `_rom_basic_damage()`，显示 `min(公式伤害, 当前HP)` 和剩余HP；
确认后的电影及文字使用同一实际损失。HP结算、死亡和EXP奖励规则不变。
控制场景中原公式伤害16、敌军剩10，预览/电影/实际损失均为10，剩余0。

既有蓝色 mounted 图已用于类型1的地图与通用战斗显示，沿用当前类型1映射。
这是既有 ROM 像素的接入，不是新增自然运行的职业/画面关联证据；高阶兵种图像
仍不完整，类型56–71名称仍用部队ID。详情浏览、待行动切换、保存恢复和输入
检查记录在 [BUILD_TACTICS_MILESTONE.md](../docs/milestones/BUILD_TACTICS_MILESTONE.md)。
本轮没有新增原版模拟器 trace，也没有完成安卓真机或全19关通关验证。

## 2026-10-06：第十九关胜利后的原版分支

ROM bank 0 `$8178–$8181` 先 `INC $6400`，再 `LDA $6400`、`CMP #$13`。
若索引尚未达到十进制 19，`BNE` 回到下一关流程；达到 19 时，
`$8182–$8194` 设置 bank `$15`、回调索引 0，调用 `$FF50` 后跳到
`$C05A`。这证实末关胜利应走单独结束流程，而不是再加载第十九关。
失败路径附近使用同一 bank 的回调索引 1。关卡数据总数也为 19。

Godot 现在将末关胜利转到独立通关记录场景，展示 20 人最终类型/经验；
玩家选择保存才将通关记录写到原版本 1 Demo 存档。标题或战场读取
已保存的通关记录会返回该场景，读取前验证成长路径。临时场景流程
已覆盖胜利、保存、重载与损坏队伍拒绝。当时原版回调画面尚未动态
确认；下节记录后续采样。通关记录画面仍属于 remake UI。

## 2026-10-06：原版结局回调的受控运行与画面

对 bank 19 `$FF85` 的换银行代码再次核查：它将 `$60DF` 左移一位
并写入 Mapper 15 的 `$8000`。请求值 `$15` 时，FCEUX 运行中映射到
`$8000` 的前三字节是 `4C 06 80`，与物理 PRG bank 42 完全一致；
该 bank 的 callback 0 从 `$8006` 开始。此前只看物理 bank 21 的
开头会误把图像数据当回调，不能用来否定结局代码。其它请求值的
完整映射还需要分别实测，旧候选 bank 10 说明不等于运行证据。

`research/tools/fceux/fceux_final_victory_trace.lua` 从已记录的第一关启动输入继续，
在帧 3900 控制地把 `$6400` 置为18、清除组2敌军，并在帧 4012
记录到 `$6400=19` 和上述 callback 0 入口。此操作仅改变到达分支的
条件；后续图文、制作名单和终幕由原版 ROM 自己绘制。它**不是**自然
打通第十九关的录像。

从帧 4100–6300 每100帧截图，确认五段自动推进的结局图文；
另一次完全不按故事阶段 A 的对照采样，在帧 6500 捕获“完”过渡画面，
确认五段无需按键自动播放。
帧 6500 起是按 A 逐页推进的七页制作名单；继续按 A 后，帧
13000–15000 出现三人动画和闪烁的“爆笑三国 / START”终幕。
原始 FCEUX GD 截图用 `research/tools/maintenance/convert_fceux_gd.py` 转为 256×240 PNG。
已用的帧索引、输入时刻和控制条件保存在
`research/evidence/records/rom_ending_capture.json`，截图位于 `assets/rom_reference/ending/`。

Godot 的 `rom_ending.tscn` 按采样间隔播放图文帧，制作名单用 A/触摸
逐页推进，B 可跳到通关记录，后者能重看结局。静态帧和文字均来自
模拟器画面；采样之间的实际逐帧动画、闪烁周期与音乐调用尚未完全
还原，播放器的提示字和跳过操作是重制版辅助界面。
