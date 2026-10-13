# Bao Xiao San Guo Godot remake

This is a ROM-first playable prototype with all 19 battle scenes connected.
Winning stage 19 now opens a completion summary instead of replaying the last
battle. It first plays sampled frames from the original ROM ending, then opens
the completion summary. The summary shows the 20 roster slots, current class, and experience;
left/right changes pages. Select **保存通关记录** to replace the current demo save.
The title's load command then reopens the summary. The ending screen is remake
UI; the story, credits, and finale frames now come from a controlled original
ROM capture. Intermediate animation frames and the ending's soundtrack remain
incomplete.
The default scene now presents the supplied original publisher, title, menu,
difficulty, and opening story frames before battle one.
It targets a 256×240 logical game screen, supports keyboard and standard gamepad
input, and runs in landscape on Android. On wide touchscreens the game stays
centered with a direction pad on the left and A/B/menu on the right. Tap the map
to position the cursor or swipe vertically to scroll. Stage maps, deployments, unit stats,
movement allowances, and the later-stage roster caps come from the ROM.
Some combat rules, visuals, audio track assignments and later-stage
victory conditions are still approximations.
Godot can export this project to desktop, mobile, and web builds; pre-built
export presets and one-line build scripts now ship for **Apple Silicon macOS**,
**Windows x64**, **Android ARM64**, and an **iOS Xcode project**. The macOS
binary also includes Intel support. See [`docs/BUILD.md`](../../docs/BUILD.md) for prerequisites and the
quick build commands.
For the ROM reverse-engineering record, start with
[`research/ROM_RESEARCH.md`](../../research/ROM_RESEARCH.md), its
[`research/README.md`](../../research/README.md), and the [`docs/RESEARCH.md`](../../docs/RESEARCH.md) index of extracted evidence.
Opening-screen and NSF implementation notes are in
[`docs/INTRO_AUDIO.md`](../../docs/INTRO_AUDIO.md).

## Project layout

- `scenes/` contains the intro, playable battle and roster scenes, plus isolated ROM previews.
- `scripts/` contains Godot gameplay scripts and the export helpers.
- `data/` contains ROM-derived JSON used by the running demo.
- `assets/rom_reference/` contains ROM-derived images; some are loaded by the
  playable scenes, so this directory must remain visible to Godot. It also
  contains research previews that can be separated when their references are
  reviewed.
- `assets/branding/logo.png` is the generated title logo. `app_icon.png` is the
  full-bleed square icon source used by Windows, iOS, and Android;
  `app_icon_macos.png` has a transparent rounded-square silhouette for macOS.
  The `adaptive_*.png` files are Android launcher layers.
- `assets/intro/` holds copies of the supplied original 256×240 opening frames.
  `assets/audio/` holds 31 MP3 tracks rendered from the supplied NSF. Track
  assignments to game events remain provisional.
- `research/` contains the reverse-engineering log, evidence, and categorized
  utilities. `docs/` contains the build guide and research index;
  `docs/milestones/` keeps historical implementation reports.
- `research/.gdignore` and `docs/.gdignore` keep research material out of the
  Godot editor and exports while leaving it accessible from the filesystem.
- Godot's `.godot/` cache, Android export scaffolding, Python caches, and build
  outputs are ignored by Git. Exported packages are written to the repository's
  top-level `build/` directory.

## Package the project

Godot export presets for macOS, Windows, Android, and iOS live in
`export_presets.cfg`. One-line build scripts are:

```sh
./scripts/build_macos.sh           # macOS Debug .app
./scripts/build_macos.sh --release # macOS Release .dmg
./scripts/build_android.sh         # Android Debug .apk
./scripts/build_android.sh --release # Android Release .apk (sideload)
./scripts/build_windows.sh         # Windows x64 Debug .exe
./scripts/build_windows.sh --arm64 # Windows ARM64 Debug .exe
./scripts/build_ios.sh             # iPhone/iPad Xcode project (sign in Xcode)
```

Outputs land in `build/`. Full prerequisite checklist, troubleshooting,
and pre-publish edits are documented in [`docs/BUILD.md`](../../docs/BUILD.md).

## Run the demo

Open `project.godot` with Godot 4.7.2 and press F5, or run
`godot --path .` from this directory. The default scene opens the ROM intro.
Press A or Start for the original menu, select a difficulty, and advance the
opening story. The difficulty selection is stored in the session, while its
ROM combat modifiers await decoding. Arrow keys move the battle cursor; A
opens/confirms commands; Escape or B
cancels; Enter opens the system menu. A headless startup check is
`godot --headless --path . --quit-after 10`. On a fresh checkout, import PNG
assets first with `godot --headless --editor --import --path .`; opening the
project in the editor also performs that import. On Android, hold a direction
button to move the cursor repeatedly; the buttons sit outside the game image.
On narrower touchscreens a compact 十 button opens the direction pad. Battle system
menu → 音乐 toggles the background music and saves the setting. Android also
uses the phone's media volume; raise it if the title and battle are silent.
Press F8 to open an isolated
ROM stage-5 movement and attack slice; F8 returns. Press F7 to open the ROM
stage-6 movement slice; F7 returns there. Winning a battle and pressing A opens the next
battle demo. Before battles 11–19, A opens a roster selector; choose units
with A and press Start to deploy them. The ROM caps are 8, 6, 8, 8, 10, 10,
10, 10, and 12 units respectively.
You can open the selector directly with
`godot --path . res://scenes/roster_selection.tscn`; it defaults to stage 11.
Arrow keys or the gamepad D-pad browse the 20 startup roster slots. Touch
users can swipe the list and tap a slot to toggle it.

Start opens the system menu. Choose `储存进度` to save the current demo battle,
or `读取进度` to restore it, including HP, positions, actions, and round. A save
can be loaded from any of the 19 battle scenes; Godot opens its saved
stage automatically. The file lives at `user://bao_xiao_san_guo_demo_progress.json`
in Godot's per-app user data. This is a Godot demo save, not an NES save state.

Movement destinations are highlighted from the ROM's per-unit movement
allowance and stage passability list. The demo also requires a clear shortest
path through unoccupied cells, so a unit cannot jump across a wall or another
unit. This path check is a gameplay approximation pending a ROM movement trace.

## Run the second battle

After the first battle's victory panel, press A, or launch
`godot --path . res://scenes/battle_stage1.tscn` directly. This scene loads
the ROM's second 16×30 map, six opposing deployments, three player
deployments, unit stats, and movement passability. The background is a
ROM-derived color candidate and is not yet screenshot matched. Player
movement, ordinary attacks, and rest work as in the first battle. All six
opponents use the ROM-confirmed low-HP rest and adjacent basic attack branch.
They also rest when wounded and without an adjacent target. Other actions
and the original transition animation
remain pending; nonmatching unit
types display a small type badge on a ROM-derived placeholder pose.

## Run the third battle

After the second battle's victory panel, press A, or launch
`godot --path . res://scenes/battle_stage2.tscn` directly. This scene loads
the ROM's third 16×30 map, three player deployments, two group-1 allies,
and ten group-2 opponents. Its color background is a ROM-derived candidate
that has not been compared with a live screenshot. Player movement, basic
attack, and rest work; the confirmed common group-2 enemy branch runs for
eligible unit types. Group-1 allies have a confirmed adjacent basic attack
against group 2 and cannot be commanded or attacked by the player. Their
no-target movement follows the ROM's first group-2 target choice with an
approximate route through passable cells. Exact movement direction and low-HP
timing remain pending. The type-56 flag-3 enemy heals a wounded unit on its
own side by 20 HP; the flag-$82 enemy can use the 25-HP attack variant.
For the attack variant, the ROM switches target scans by frame parity and
the demo approximates this by round. Victory follows the ROM's generic
group-2-clear condition.

## Run the fourth battle

After the third battle's victory panel, press A, or launch
`godot --path . res://scenes/battle_stage3.tscn` directly. This is a connected
16×30 vertical battle using the ROM's fourth map, three player deployments,
two group-1 allies, twelve group-2 enemies, passability list, unit types, and
maximum HP. The ROM-derived color background is a candidate composition and
has not been matched to an emulator screenshot. Player movement, ordinary
attacks, rest, turn changes, save/load, and the generic group-2 victory rule
work. Eligible skill-zero opponents use the decoded ordinary-attack/rest
branch. Of the two type-56 opponents, the flag-3 unit treats its wounded
allies and the flag-$83 unit uses the attack path.
The two allies currently use the same approximate pursuit path as in battle
three. A type-5 enemy can use its ROM skill-1 packet for a 20-HP hit within
two cells; its skill/basic-attack choice alternates by demo round instead of
the original frame parity. Exact allied decisions and other special enemy
actions remain to be decoded. After defeat, A returns to the title and
B retries this battle;
victory opens the fifth battle demo.

## Run the fifth battle

After the fourth battle's victory panel, press A, or launch
`godot --path . res://scenes/battle_stage4.tscn` directly. This connected
scene uses the ROM's fifth 16×30 vertical map, four player deployments,
one group-1 ally, six group-2 enemies, unit stats, and passability list.
Movement, basic attacks, rest, round changes, save/load, the confirmed
common enemy action subset, and allied skill-1 attacks work here. The ally's
no-target pursuit route remains an approximation.
The existing F8 scene remains an isolated attack tutorial on the same map.
The type-5 opponent uses the decoded skill-1 20-HP packet on alternating demo
rounds when it has a target within two cells; on other rounds it uses the
adjacent basic-attack or wounded-rest branch. The ROM's fifth-battle goal is
to move the first player unit into the northern map half (world Y<15); after
doing so, choose `全军休息` to finish the battle. Clearing all group-2 enemies
also wins. Victory opens the sixth battle demo. Other special actions still
require ROM tracing.

## Run the sixth battle

After the fifth battle's result panel, press A, or launch
`godot --path . res://scenes/battle_stage5.tscn` directly. The ROM reuses the
same 16×30 map but deploys five players in the north and thirteen group-2
enemies farther south. Its stage-specific goal is to move the first player
unit to the southern edge (world Y=29), then choose `全军休息`. Clearing all
group-2 enemies also wins. Movement, ordinary attacks, the decoded common
enemy branch, type-56 enemy single-target treatment, rounds, and demo save/load run in
this scene. The fifth blue player unit is type 56: select it, choose `技术`,
then select single attack (25 HP) or single treatment (20 HP) in the
technique submenu. Choose a red enemy for attack or a wounded blue/green
unit (including itself) for treatment within two cells. Both consume
its action. Green target outlines indicate healing, yellow indicate attacks;
cursor movement previews the actual HP change. Full HP and invalid targets
do not consume an action. The ROM skill packet is confirmed, while the player-side packet
variant and target filter are demo inferences. Type-2 and type-6 enemy
decisions, exact enemy movement, and the true runtime background tiles
still need ROM tracing. The F7 sixth-stage movement exercise remains a
separate tutorial; the sixth battle opens the seventh on victory.

## Run battles seven through ten

Win the preceding battle and press A, or directly launch
`res://scenes/battle_stage6.tscn` through `battle_stage9.tscn` with Godot.
These four connected scenes load the ROM's map, passability, unit groups,
player deployments, and per-type stats. Battles seven and eight are 16×30
vertical maps with eleven opponents each. Battle nine has eighteen opponents
and three group-1 allies; the first player can also win by reaching the
northeast region (world Y<13, X≥12) and ending the turn through `全军休息`.
Battle ten has eighteen opponents, three allies, and a 16×45 map that scrolls
through three vertically stacked screens. Its victory panel currently replays
the scene.

From battle seven, the fifth player unit is type 62. Its `技术` command uses
the ROM skill-25 packets: a 65-HP single attack or a 35-HP cross attack
within four cells, or variant-zero single-target healing of up to 65 HP
within four cells, consuming that unit's action. Q/E, controller shoulders,
or the mobile technique button reopen the variant submenu. The sixth player unit is type 56 and
uses the skill-19 demo described above. Their player-side target filters and
packet choices still need a ROM runtime trace. The enemy and allied branches
not decoded yet use the existing partial behavior; these scenes are playable
campaign prototypes rather than exact reproductions of every action.

## Run the ROM attack slice

The fifth battle (ROM index 4) uses its full two-page map and original
deployments. Open it from the default battle scene with F8, or run
`godot --path . res://scenes/rom_stage_skirmish.tscn`. The cursor begins on a
blue-marked player at world (8,25). Press A twice to choose 移动, go up two
cells to (8,23), and press A. Select that player again, move up one cell to
(8,22), and confirm. Select the player once more, choose 攻击, move the cursor
right to the red group-2 enemy at (9,22), and press A. The first hit
reduces its HP from 150 to 130 using the ROM's basic damage routine. B cancels;
F8 returns. The green-marked group-1 unit at (10,28) is an ally and cannot
be targeted. D-pad/A/B and touchscreen controls are also available.

The map and deployment/stat values come from ROM. Types 0–2 reuse the two
ROM-derived poses matched to the stage-0 screenshot; that type-to-pose mapping
is still inferred. Other types reuse the ROM infantry pose with a visible type
ID badge as a placeholder until their runtime sprite selection is traced.
All player poses use the ROM's blue `$3F10` sprite palette; opposing poses use
its red `$3F14` palette. The default battle's first eight screenshot units
remain red, while the three player deployments on the second map page are blue.
This slice omits AI turns, counterattacks, experience, action limits and
victory conditions. Its [ROM-derived vertical map](../../assets/rom_reference/rom_battle_stage_candidate_04_color.png)
shows the corrected two-page layout. An earlier horizontal Godot capture in
the asset directory is obsolete.

## Run the ROM movement slice

The sixth-stage (`守卫徐州`) movement slice uses five decoded player
deployment slots, their startup unit types and movement points, the stage
passability list, and enemy/group occupancy. The stage's 13 opposing units span
world Y=17–23. Arrow keys move the cursor through the reconstructed world.
Recovered terrain covers two vertically stacked 16×15 map pages
(world Y=0–29).
Run it from this directory with:

```sh
godot --path . res://scenes/rom_stage_movement_demo.tscn
```

It is also available from the default battle scene with F7; F7 returns there.
On touchscreens, use the `STAGE 6` and `F7返回` badges. A gamepad's Back button
also returns to the battle scene.

Move the cursor onto a blue player, press A, press A again to start moving,
then choose a destination with the D-pad or arrow keys and press A to commit.
Move down to see the decoded enemy positions and up to return to the first
screen.
Green cells are valid; red cells are outside the movement range, blocked by
terrain, or occupied. B cancels. The same inputs work with a standard gamepad;
touch devices get on-screen D-pad/A/B buttons and tap-to-place the cursor. This
slice demonstrates movement only; it does not yet implement turn flow, attack,
skills, or combat resolution. The background is the extracted stage CHR
candidate; its exact runtime tile composition is still under study. Blue player
and red opponent figures use the two ROM-derived stage-0 poses. Types above 2
carry a visible ID badge because their original pose mapping remains unknown.

## Current state

The 2026-10-03 visual correction fixes a CHR stream decoder bug: the writer
reads the first block length once, then copies contiguous 256-byte blocks.
Reading another length between blocks shifted the graphics and made trees,
stone paths and bridges incorrect. All 19 stage CHR streams and map candidates
have been regenerated. The 19 stage maps now include two vertically stacked
ROM map pages, or three when the scroll limit is 30 cells. Stage 0 is a
16×30 world and scrolls down up to 15 cells. The ROM deployment record stores
Y before X; after correcting that order, its eight opposing units exactly
match the supplied screenshot and its three player units appear below the
first screen. The scene uses these ROM positions directly, with
two transparent 16×16 poses extracted from ROM. RGB display colors were measured
from `../image5.png`; terrain and unit pixel patterns come from ROM. Animation,
unit identities and complete combat remain unfinished. Rebuild these visuals:

```sh
python3 research/tools/render/rebuild_stage0_visuals.py --reference ../image5.png \
  --rgb-palette /opt/homebrew/Cellar/fceux/2.6.6_12/share/fceux/palettes/FCEUX.pal
```

`scenes/battle.tscn` starts a stage-0 battle prototype whose default terrain is
composed from the decoded ROM map, stage CHR stream, and FCEUX palette. The
battle script also loads stage 0's map-code grid, tile compositions, and
per-cell palette indices from `data/rom_battle_stage_records.json`; press F4 to
inspect those ROM values under the cursor. Press F3 to compare the ROM map with
the earlier hand-drawn terrain. The scene shows eight ROM opposing units on
the first page and three ROM player deployments on the lower page. Move the
cursor down to world Y=25–27, select a player with A, then choose 移动 (the
default command) with A. Green cells are valid destinations; red cells are
blocked by terrain or another unit. A commits a destination within that
unit's ROM movement allowance; B cancels. Touchscreen and gamepad controls use
the same rules. The 攻击 command accepts an adjacent screenshot-matched opposing
unit, applies the ROM's attack/defense damage calculation to its current HP,
and removes it at zero HP. From the unit menu press Down once, then A, choose
an adjacent target and press A. The canonical ROM's acted-unit list is traced.
The default scene also reproduces the first battle's ordinary adjacent enemy
attack path for six of its eight opponents. Those guards enter pursuit when
the player crosses their ROM alert edge; the other two pursue from farther
south using an approximate route. Full phase timing remains under study. Turn changes now show
ROM-captured red and blue runners over the map, moving in opposite directions.
In the first battle, ordinary level-0 infantry
attacks use separate enemy and player black combat scenes with roof scenery,
large figures, and thrown-shoe pixels captured independently from the supplied
ROM. The first battle's type-1 enemy ordinary attack against a type-0 unit
also uses independently captured mounted artwork. The exact attack timing
and other classes remain incomplete; unsupported attacks use a
short comic duel panel. The system menu's 战斗动画 entry switches these
sequences on or off.
The live OpenEmu intro reaches `宛城之战`. The local `2b.png` shows
that title over the same castle layout, while FCEUX `image2.png` shows the layout labeled
`守城之战`; why the labels differ is unresolved. Unit animation selection and
combat effects remain approximate. The first-page and lower-page positions
come from the decoded campaign deployment.

For a connected first-battle attack, move the cursor down to the blue unit
at (7,25). Select it with A, choose 移动 with A, and advance north in hops of
at most two cells. Re-select the unit after each new turn: press Start/Enter,
choose 全军休息 with A, then select it again. Two red units advance south during
the opponent phase, so their positions change as you approach. Select 攻击
when a red unit is next to your unit. The original
ROM checks an acted-unit list, and the local infinite-move variant confirms
that clearing its count permits re-selection. This demo uses the same list
idea for player actions. The 休息 command uses the ROM's integer rule:
recover floor(maximum HP / 8), capped at maximum HP, and consume that unit's
action. Selecting a player or enemy unit displays its current/max HP. Eligible
enemies scan adjacent players, choose the one with the lowest current HP (ties
favor the first player slot), and use the ROM's ordinary damage formula during
全军休息. They act in reverse ROM group-2 slot order. All eight enemies use
the ROM's low-HP rule: below floor(maximum HP / 3), they rest and recover
floor(maximum HP / 8). First-stage enemy movement uses a ROM terrain and
movement allowance based route approximation. Other decisions remain
incomplete. The demo briefly focuses the camera on a visible enemy action
before returning to the player's view.
Supported single-target enemy skills now include more ROM unit types; area
effects and many stage-specific AI choices still need reconstruction. In the
first battle, the two red units initially at `(7,13)` and `(8,13)` advance
south; a FCEUX replay captured both moving to Y=15 in the first opponent
phase and Y=17 in the second. The ROM's third and fourth phases include
three-cell moves when the right unit reaches the lower screen edge; the
Godot first-stage pursuit now accounts for this observed scroll behavior.
With the players stationary, a seven-phase FCEUX replay also confirms the
right pursuer stopping diagonally at `(8,24)` and the left pursuer moving to
`(7,24)` before attacking in the same action. The demo now matches those
seven phase endpoints and the first player's `100→80→92→72` HP sequence.
Player positions at world Y=18, 19, and 21 were also compared with ROM
replays. The Y=18 case exposed a same-row attack by the right pursuer;
the demo now reproduces that attack and the resulting first-player defeat.
First-stage flank placements at `(6,21)` and `(9,21)` now reproduce the
observed vertical approach, sideways move, and attack timing as well.
The Y=9 guard pair also advances when the player reaches Y=14 or farther
north; the pair stays in its original row when the player is at Y=15.
The Y=6 guard line responds at player Y=10, while the northern type-1 guard
responds when the player reaches its Y=9 alert area.
The second battle also uses a ROM alert edge: its three flag-2 guards begin
moving when the first player reaches world Y=12. ROM and Godot first-phase
comparisons at `(8,12)` and `(9,13)` match all enemy positions and the first
player's HP. Other second-battle routes remain approximate; the captures and
their controlled stage-load method are described in `research/ROM_RESEARCH.md`.
The second-battle `(8,12)` comparison also matches the next enemy phase:
the first player's HP is 55 after phase one and 22 after phase two.
The common enemy branch includes type 2; its flag-3 deployment in the
seventh battle can rest and attack adjacent players. Flag-1 ordinary
attack dispatch now uses the ROM graphic-selector tables, including
classes that were previously skipped. Movement routes outside the captured
cases remain approximate.
The third battle's first enemy phase was compared with the player at the
passable `(9,10)` tile: all ten enemy endpoints match the ROM, and attacks
of 20, 20, and 45 HP leave the player at 15 HP. Its flag-2 alert activation
and straight movement with an initial direction retry are supported;
other routes, later phases, and technique timing still need comparison.
High AI flags also distinguish attack and treatment: the third battle's
flag-3 type-56 unit heals wounded units on its own side. A live ROM capture
and Godot phase probe both take a nearby type-1 unit from 50 HP to 70 through
treatment, then to 88 through rest, leaving the player unharmed. Positive
single-target healing now supports wounded-target selection, self healing,
maximum-HP clamping, and a same-faction comic panel with green +HP text.
Cross-shaped and square healing now use the decoded area selector; the
original treatment animation remains unfinished.
The status
bar describes a stationary enemy phase as defending.
The original ROM's first-battle victory predicate is all eight group-2 enemy
slots removed; the first player slot's death triggers defeat even if allies
remain. The demo uses these predicates for its result panels. After a first
battle victory, press A to enter the second-battle slice; after defeat, A
returns directly to the title and B retries the current battle. The win panel appears immediately after the
final hit rather than at the original phase boundary. The second battle's
victory panel opens the third battle; the third opens the fourth battle; the
fourth opens the fifth battle; the fifth opens the sixth. Battles six through
nine continue in sequence; all 19 battles are linked, with roster selection
before battles 11–19.
Start opens the system menu
(`全军休息`, `全军撤退`, `战斗动画`, `读取进度`, `储存进度`, `音乐`).
全军休息 automatically applies the same HP recovery to living player units
that have not acted, then starts another demo player turn and refreshes unit
actions. When all living player units have acted, the turn ends automatically;
`全军休息` can end it early. `读取进度` and `储存进度` use the Godot demo save described above; the
remaining system-command effects are demonstration stubs. The
system menu shows the demo round and how many player units have acted. The
demo runs the confirmed adjacent-attack subset of the opponent phase; the
extracted code windows are in `research/evidence/records/rom_action_scheduler_evidence.json`.
Regenerate them from the canonical cartridge with
`python3 research/tools/extract/extract_action_scheduler_evidence.py '../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes'`.

Press F5 in the battle scene to open the ROM movement sandbox. Q/E cycles
through unit IDs 0–71 (Q/E, gamepad shoulder buttons, or tap the left/right
half of the top header; touchscreen users can enter it with the `MOVE TEST`
badge). Movement points come from all 72 valid ROM unit records;
`data/rom_class_reference.json` adds chart class and level labels for IDs 0–55.
For charted units, the status line also shows the recorded technique, range,
area, and effect. Arrow keys or touch select a destination; green cells are
valid Manhattan-range destinations, while red
cells inside the range are blocked by terrain or occupancy. A
moves the test unit when the destination is within its movement budget, on a
ROM-passable tile, and not occupied by a visible demo unit. The ROM
movement helper confirms Manhattan distance; a per-stage whitelist confirms
passable map codes, and the sandbox applies both plus occupancy blocking.
Press F5 or B to return to the battle prototype. Its eight first-page units
match the ROM group-2 deployments; the three lower-page player deployments
use the ROM movement rules.

Press F6 to overlay decoded ROM unit placements: cyan marks players, gold marks
group 1, and red marks group 2; markers show the known ROM type ID. The overlay
also lists player movement points. Move down to see the player positions in
the second page. On
touchscreens, tap `DEPLOY` in the upper-left corner; the `MOVE TEST` badge opens
F5's sandbox.
The stage layout exporter parses all 19 records into player deployment triples
and two unit groups while preserving their raw bytes. Stage 0's three player
positions have Y coordinates 25–27, on the lower map page;
the 8 group-2 positions exactly match the supplied first-screen screenshot.

`scenes/rom_publisher_splash.tscn` displays a 256×240 publisher splash decoded
from the Simplified Chinese 970261 ROM. It is a verified ROM screen, but it is
not the player-facing title screen. To view it in the Godot editor, open that
scene and press F6 (Run Current Scene). Its extracted PNG is kept under
`assets/rom_reference/`; the extractor and ROM remain the source of truth.
The actual `爆笑三国` title screen with its animated `START` prompt has now
been observed running in OpenEmu-Silicon's FCEU core; its ROM graphics stream
and assets still need to be decoded. The following menu has two options,
`开始游戏` and `读取进度`. Starting a new game reaches a difficulty page with
`容易级`, `熟练级`, and `高手级`; the cursor starts on `容易级`. A advances
through the opening story and into the live `宛城之战` battle, now confirmed in
OpenEmu-Silicon. The `2.png`, `2a.png`, and `2b.png` references match parts of
that opening, but are kept as research material rather than game assets.

## Reference ROM

Primary reference: `../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes`.
The original files remain outside this project. Do not bundle ROM data or copied
assets into a distributable build without confirming the rights to do so.

## Verified from the included manual

- Campaign has 19 stages; the first is 宛城之战.
- Battle commands are 移动, 攻击, 技术, 休息.
- The player can command all allied units; the selected first unit becomes the
  commander in stages after the first ten.
- Commander death or retreat causes a game over.
- Units gain experience and can promote through branching warrior and scholar
  classes; the source manual lists the class thresholds and many skill effects.
- `research/evidence/records/class_progression.json` holds the class branches and thresholds
  transcribed from the manual; it is not yet checked against live gameplay.
- The ROM's 13-byte unit definitions now expose confirmed movement allowances
  of 2–8 points; bank-2 code compares them with Manhattan tile distance. The
  first ten stages resolve player roster slots from their stage layouts. Later
  stages use the chosen `$6807` roster indices to resolve current types from
  `$651B`. The demo now carries current types and accumulated experience between
  battles, using the ROM progression tables. The eight screenshot-transcribed units are drawn
  as type 1 for the mounted pose and type 0 for the other seven; this visual
  type assignment is inferred and their stage-layout coordinates differ.
- The supplied warrior-parameter chart was transcribed into
  [`data/rom_class_reference.json`](../../data/rom_class_reference.json) and
  cross-checked against the ROM unit records and promotion code.
  Its visible movement values for IDs 0–55 all match the ROM, and sample HP,
  attack, defense, experience, and technique fields also line up with the
  13-byte records. The chart and ROM experience values differ for IDs 14 and
  17; both show 480 in the chart/manual and 400 in the ROM record.
  `data/rom_class_reference.json` joins its 19 warrior class IDs, 56 level/type
  IDs, branches, and listed techniques to ROM-derived stats. Rebuild it with
  `python3 research/tools/maintenance/export_technical_chart_reference.py`.
- The startup campaign roster seed is decoded in
  `data/rom_campaign_roster_seed.json`. Its 20 type IDs join to confirmed
  movement points. Stages 0–9 deploy the roster slots listed in their stage
  layout; later stages deploy the selected `$6807` entries in chosen order.
  Rebuild it with `python3 research/tools/extract/extract_campaign_roster_seed.py <rom.nes>`.
- Roster-selection caps for stages 10–18 are decoded in
  `data/rom_roster_selection_limits.json`; the earlier-stage cap is unresolved.
  Rebuild with `python3 research/tools/extract/extract_roster_selection_limits.py <rom.nes>`.
- Stage-indexed unit layout streams for all 19 battles are exported in
  `data/rom_stage_unit_layouts.json`, with their battle-record header bytes
  and parsed player/unit-group entries. Stage 0–9 player types and movement
  points join to startup roster values; promotion can change current types, so
  these exports describe initial values. Later-stage types depend on the
  chosen roster and its current class, not the layout's zero bytes.
  Bank-8 initialization reads slots from the stage streams for stages 0–9;
  later stages read `$6807,X`, skip the layout roster byte, and resolve the
  selected slot's type through `$651B`.
  Layout position bytes are stored Y then X; after decoding, both axes are
  scaled at 16 pixels per unit. Group type IDs and positions are decoded,
  while auxiliary bytes remain unknown. Rebuild with
  `python3 research/tools/extract/extract_stage_unit_layouts.py <rom.nes>`.
- Per-stage movement passability lists are exported in
  `data/rom_stage_movement_rules.json`; bank-2 movement code checks the
  cursor's map code against this whitelist and rejects occupied slots.
  Regenerate them with `python3 research/tools/extract/extract_stage_movement_rules.py <rom.nes>`.
- A ten-image reference set contains NES-resolution (256×240) images, including
  a battle screen showing the command menu.

## Research needed before claiming faithful gameplay

- Match the recovered stage-one tile IDs to the battle-time CHR contents and
  nametable palette attributes; reconcile the `宛城之战` intro / `2b.png`
  title with the `守城之战` title in `image2.png`.
- Capture a later-stage live `$6807` selection and its promoted `$651B` types;
  trace passability, terrain effects, attack range and damage rules.
- Record turn order, AI behavior, victory/defeat triggers, and stage transitions.
- Transcribe all unit stats, skills, class branches, and save behavior.
- Capture original animations, UI states, and audio references.

The 19 ROM stage records, their two or three 16×15 map pages, four-tile compositions,
per-cell palette indices, packed 8×8 attribute tables, and palette packets are
exported in
[`data/rom_battle_stage_records.json`](../../data/rom_battle_stage_records.json).
The 19 stage-specific CHR streams and their extraction details are listed in
[`assets/rom_reference/rom_battle_stage_graphics.json`](../../assets/rom_reference/rom_battle_stage_graphics.json).
Rebuild the map records with [`research/tools/extract/extract_battle_stage_records.py`](../../research/tools/extract/extract_battle_stage_records.py)
and the stage graphics with [`research/tools/extract/extract_battle_stage_graphics.py`](../../research/tools/extract/extract_battle_stage_graphics.py).
The 2×2 tile expansion and address-window bank assumptions are documented in
[`research/ROM_RESEARCH.md`](../../research/ROM_RESEARCH.md).
The code values are viewable in the diagnostic
[`stage-code atlas`](../../assets/rom_reference/rom_battle_stage_code_atlas.png) or
at the bottom of `scenes/rom_asset_catalog.tscn`.

## Runtime check

The Simplified Chinese 970261 ROM runs in FCEUX 2.6.6; the title screen is
confirmed from `../image1.png`. Its 16-byte iNES header is
`4e 45 53 1a 40 00 f2 00 00 00 00 00 00 00 00 00`: mapper 15, 1 MiB PRG,
CHR RAM. The ROM can be analyzed directly; mapper bank switching and graphics
stored in PRG data need to be accounted for when extracting assets and tables.

FCEUX can also capture the live party and deployment state with the included
read-only Lua helper. From the repository root:

```sh
fceux --no-config 1 --loadlua "$PWD/research/tools/fceux/fceux_dump_battle_ram.lua" "$PWD/../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes"
```

It writes snapshots to `research/evidence/traces/fceux_battle_ram_snapshot.txt` when
the tracked values change, including `$6801/$6802`, movement mode/budget,
selected slot, input code, and `$0616–$0619`. These last bytes are reused by
rendering and movement code, so compare them with a live screenshot before
assigning them to a visible cursor. It also records input-time writes to those
coordinates and writes to `$6802`; reload the helper after changing it. The
installed FCEUX binary is native arm64. To reload the updated helper in the
current emulator, stop the old Lua script, open the Lua script window from
`File > Lua > New Lua Script Window`, browse to the helper above, and run it.

The included `../BaoXiaoSanGuo/3.png` gives a 256×240 reference battle screen.
Static ROM analysis has recovered all 19 battle-stage records, metatile maps,
palette attributes, and per-stage CHR uploads. A stage-0 composition matches
the castle and river layout in the reference screenshot. Its ROM palette
indices are decoded; RGB comes from an emulator palette file. The included
color preview uses FCEUX's `FCEUX.pal`, while the source and runtime order of
CHR outside the stage upload are still candidates. Open
[`scenes/rom_battle_stage_graphics.tscn`](../../scenes/rom_battle_stage_graphics.tscn)
and press F6 to browse the map composition, 3 shared callback streams, and all
19 stage streams. The candidate composition now applies the known `$1000`,
`$1400`, `$1A00`, and per-stage `$1010` uploads over the boot-time 4 KiB CHR
page. Browse grayscale candidates for all 19 maps in
[`scenes/rom_battle_stage_reconstruction.tscn`](../../scenes/rom_battle_stage_reconstruction.tscn)
with F6. Battle-time mapping for CHR bytes outside known uploads is still
unverified; regenerate the diagnostic images with
[`research/tools/render/render_all_battle_stage_candidates.py`](../../research/tools/render/render_all_battle_stage_candidates.py).
The separate six-entry bank-4 callback stream set can be browsed in
[`scenes/rom_bank4_callback1_streams.tscn`](../../scenes/rom_bank4_callback1_streams.tscn);
its selector meaning and relationship to stage graphics remain unverified.
Bank 12 callback index 1 has a separate `$05ED`-indexed stream table with 13
entries and 7 unique uploads to the same PPU range. `$05ED` is derived from
each unit type ID through the lookup at `$983F`; the manifest cross-references the separate OAM
selector for each unit type. Browse them in
[`scenes/rom_bank12_selector_streams.tscn`](../../scenes/rom_bank12_selector_streams.tscn);
which on-screen elements they draw and when they load remain open.
Bank 12 index 0 is called by bank 18 and selects CHR from `$6408/$6467`, the
same slot and graphic ID used by the primary OAM-template lookup at bank 18
`$802E`; selector 26 has full static tile coverage for that template.
The separate bank-12 index-1 `$05ED` table is not called by the live bank-10
dispatch, which routes values 0–5 to bank 2 callback 1 and 6–12 to bank 6
callback 1; a ROM-wide scan found no direct immediate-parameter callsite for
bank 12 index 1. See the callback trace notes in
[`research/ROM_RESEARCH.md`](../../research/ROM_RESEARCH.md).
Bank 2 also builds `$6409` by selecting a slot adjacent to `$6408` in the paired
position fields; bank 18 has a separate OAM path for this slot. Runtime CHR
residency still needs capture.
Initial static findings and the boot-screen extraction tool are in
[`research/ROM_RESEARCH.md`](../../research/ROM_RESEARCH.md) and
[`research/tools/extract/extract_boot_screen.py`](../../research/tools/extract/extract_boot_screen.py). The decoded
publisher splash is now included as a standalone Godot scene. The title, menu,
difficulty screen, opening story, and first battle have been observed in the
ARM-native OpenEmu-Silicon/FCEU setup; exact ROM asset and gameplay recovery
remains in progress.

The bank-18 fixed-record index is exported to
[`research/evidence/records/rom_bank18_records.json`](../../research/evidence/records/rom_bank18_records.json) by
[`research/tools/extract/extract_bank18_records.py`](../../research/tools/extract/extract_bank18_records.py). It
includes the first field's 16-entry OAM templates and two four-color sprite
palettes from record offset `$10` for all 25 records. The palette upload to PPU
`$3F10` is confirmed by the `$F0E4` routine. A FCEUX-color preview is at
[`rom_bank18_sprite_palettes.png`](../../assets/rom_reference/rom_bank18_sprite_palettes.png).
Open [`scenes/rom_palette_preview.tscn`](../../scenes/rom_palette_preview.tscn) and
press F6 to browse the 25 rows in a scrollable Godot view.
[`research/tools/render/render_sprite_palette_sheet.py`](../../research/tools/render/render_sprite_palette_sheet.py)
rebuilds the chart from the record JSON and FCEUX palette file.
Other record fields remain raw. The OAM tile IDs are decoded, but their bitmap
graphics are not yet associated with these templates, so this data does not
drive gameplay yet.

Bank 8 also contains seven counted groups covering 73 referenced IDs. IDs
0–71 index 13-byte definition records; ID 72 overlaps an executable entrypoint
and is preserved as a special case. The records, group lists, and their
loader destinations are exported, with unknown fields preserved as raw bytes, in
[`data/rom_unit_slot_records.json`](../../data/rom_unit_slot_records.json) by
[`research/tools/extract/extract_unit_slot_records.py`](../../research/tools/extract/extract_unit_slot_records.py).
The export also audits byte 9 against the graphics selectors: unit ID 71's
selector value 26 reaches an aliased 56-entry OAM template, while the matching
bank-12 PPU upload wraps into CHR RAM and contains all 28 tile IDs used by that
template. Its runtime residency and the separate bank-22 NMI path remain to
be confirmed.

The field-0 OAM template is also passed to bank19 `$F307`, which stages its
first four OAM tuples as a 16-byte palette packet at `$3F10`. The separate
field-8 palette matches the first eight packet bytes for 23 of 25 records. Both
forms are now recorded in the JSON, and the full four-palette packet chart is
available in the asset catalog.

The asset catalog also has a byte-match sheet for every OAM tile ID, with a
JSON source map. Static inspection of the `$6401` PPUCTRL shadow selects sprite
patterns from `$0000`; `$1000` streams and boot CHR matches are background-side
references on examined paths. Two 256-byte uploads to `$0010` populate sprite
tiles 1–16 and include OAM-referenced tiles 14 and 15. Pixel data for higher
OAM IDs has a strong static match for selector 26: the bank-12 upload contains
all 28 tile IDs in its extended template. Residency and bindings for the other
OAM templates remain unresolved.

The NMI callback's 25-entry PPU stream table is now extracted to
[`assets/rom_reference/rom_bank22_indexed_ppu_streams.json`](../../assets/rom_reference/rom_bank22_indexed_ppu_streams.json).
Those per-record streams write pattern-table data at PPU `$0800`; browse their
tile sheets by opening [`scenes/rom_indexed_ppu_streams.tscn`](../../scenes/rom_indexed_ppu_streams.tscn)
and pressing F6. [`research/tools/extract/extract_bank22_indexed_streams.py`](../../research/tools/extract/extract_bank22_indexed_streams.py)
rebuilds the extracted set and manifest.

The static PPUCTRL trace and remaining OAM-to-pixel gap are documented in
[`research/ROM_RESEARCH.md`](../../research/ROM_RESEARCH.md). The Godot project now has a runnable,
interactive battle prototype; it does not yet reproduce the full campaign or
verified combat rules.

The OAM and indexed graphics selectors are mapped in
[`research/evidence/traces/rom_sprite_selector_trace.json`](../../research/evidence/traces/rom_sprite_selector_trace.json):
both resolve through `$6467`, but use separate selector bytes and the bank-22
NMI callback is gated by `$6805`.

The shared `$FF50` banked-callback wrapper and its nine valid dispatch entries
are now exported to [`research/evidence/records/rom_mapper15_callbacks.json`](../../research/evidence/records/rom_mapper15_callbacks.json)
by [`research/tools/extract/extract_mapper15_callbacks.py`](../../research/tools/extract/extract_mapper15_callbacks.py).
This narrows the path used by the ROM's OAM setup, but the callback bank's exact
runtime mapping and the OAM-to-CHR association still need emulator-level
confirmation.

FCEUX runtime captures are available at `../image2.png` (battle/scene view) and
`../image3.png` (Sprite Viewer). The latter confirms one live sprite at tile
index `$01` / PPU `$0010`, palette `$3F10`, position `(112, 96)`; it is not yet
matched to selector 26.

Seven PPU pattern streams are now extracted from the ROM. They cover uploads at
`$0010`, `$1000`, `$1010`, `$1400`, `$1420`, and `$1A00`; two distinct sources
write different data to `$0010`. Each stream has a source-address-based
filename, raw bytes, JSON boundaries, and a grayscale 2bpp tile sheet. Open
[`scenes/rom_asset_catalog.tscn`](../../scenes/rom_asset_catalog.tscn) and press F6
to browse the streams and per-record sprite palettes in one scrollable Godot
scene. [`research/tools/extract/extract_ppu_stream.py`](../../research/tools/extract/extract_ppu_stream.py) rebuilds a
stream from its PRG bank and CPU source pointer.

[`research/evidence/records/rom_ppu_stream_call_sites.json`](../../research/evidence/records/rom_ppu_stream_call_sites.json)
records all eight statically found calls to the `$941C` stream writer;
[`research/tools/maintenance/audit_ppu_stream_refs.py`](../../research/tools/maintenance/audit_ppu_stream_refs.py) regenerates
that inventory. The generic PPU command helper may have indirect callers, so
this list does not claim to include every PPU write in the ROM.

The catalog now also includes the boot initialization's full 4 KiB CHR upload
(256 tiles from PRG bank 60 `$82BC` to PPU `$1000`). Rebuild it with
[`research/tools/extract/extract_boot_chr.py`](../../research/tools/extract/extract_boot_chr.py). It is tied to the
boot screen; its relationship to battle sprites is still unconfirmed.

Godot 4.7.2 is installed. The project has previously been imported and launched
from the editor. `scripts/battle.gd` now renders an approximate pixel-art board
based on the included battle screenshot and supports keyboard cursor/menu
interaction plus standard joypad D-pad/A/B/Start/Back buttons. Unit positions
and combat rules remain unverified against a live battle. The manual documents
directional movement, A to confirm/open the battle command menu, B to cancel,
Start for the in-game menu, and no stock-game action for Select.

The asset catalog also displays a grayscale composite of selector 26's 56 OAM
entries over that CHR upload. It is a normalized debug view: palette colors,
priority, and runtime position are not reconstructed. The standalone image and
metadata are `assets/rom_reference/rom_selector26_oam_composite.png` and
`.json`; regenerate them with `research/tools/render/render_selector26_oam_preview.py`.

The asset catalog now also includes four ROM-derived 8×8 glyph pages from PRG
bank 6. The pointer table at `$8586` resolves to `$8590`, `$8D90`, `$9590`, and
`$9D90`; each page has 128 2bpp tiles. Browse the 2×2 atlas in the catalog or
rebuild it with:

```sh
python3 research/tools/extract/extract_chinese_font.py \
  '../BaoXiaoSanGuo/BaoXiaoSanGuo(ES1005)(ChS)(970261).nes' \
  assets/rom_reference
```

Their contents look like the game's dynamic text glyphs, but individual glyph
IDs have not yet been matched to strings.

## Treatment milestone

Player `技术` supports confirmed positive healing packets for IDs
19–33: select treatment (variant zero) in the submenu, then a wounded
friendly unit. Select a supported positive attack variant (one or two)
before choosing an enemy.
Healing areas 1/5/9 are available: single target, center plus orthogonal
neighbors, and a 3×3 square. Other area and special packets stay unavailable. Self treatment, automatic allied
units, HP caps, cancellation, acted-unit persistence and next-turn reuse
are covered by the playable flow. Submenu variant counts and up/down/A/B
control flow are now decoded statically from the ROM; original labels,
resource costs and a runtime menu-input recording remain unverified.

Enemy healing now uses bank 2's targeting tables for unit types 56–66,
separate from the bank-8 effect packet. Controlled original-ROM evidence
confirms type 59 heals one target by 30 within three cells despite its
bank-8 packet having area code 5. See `research/ROM_RESEARCH.md` and
`research/evidence/traces/rom_stage02_area_heal.tsv`. Enemy group healing uses the separate
targeting table, then applies recovery to its own living wounded units.
`research/evidence/traces/rom_area5_healing_effect.tsv` and `research/evidence/traces/rom_area9_healing_effect.tsv`
record original-ROM area execution; the area-9 experiment forces that
branch and does not claim a natural AI decision.

From the later roster selector, type 65 (roster index 7) and type 60
(roster index 11) provide cross-shaped treatment. Select `技术` then treatment, move or
touch the cursor onto a friendly center, review the green footprint and
total HP preview, then press A. The center may be full if a neighbor is
wounded. One cast spends one action and plays one group animation.
The treatment build remains in `build/healing-milestone/`. The newer
area-attack build is in `build/area-attack-milestone-final/`; earlier
packages are retained. See `docs/milestones/BUILD_AREA_ATTACK_MILESTONE.md`.

## Area attack milestone

Positive damage packets with area codes 1/5/9 now apply to the selected
opponent, a cross, or a 3×3 square. The preview marks affected cells and
shows target count and actual total damage, clamped by each target's HP.
One cast spends one action, plays one combat panel, retires zero-HP units,
and participates in normal round and victory transitions. Other units
sharing the selected center cell are excluded, matching the ROM selector.

Battle seven's default type-62 unit can switch skill 25 between 65 damage
to one opponent and 35 damage per cross target. Use Q/E or Tab on keyboard,
controller shoulders, or the mobile technique button to reopen its submenu
while choosing a target. B returns to the submenu, B again returns to unit
commands, and B again cancels. No cancel spends an action. The explicitly
chosen treatment or attack rejects a target from the wrong faction. Original
menu labels, resource costs, zero-magnitude special effects, variants 3+, and complete
enemy variant selection remain unfinished. Ordinary enemy area packets
now use the same damage geometry; enemy target selection remains partial.

## Technique submenu and target selection milestone

`技术` now opens a submenu before selecting a target. Entries follow the
ROM menu bounds: skills 1–18/34 have one entry, 19–23 two, 24–29 three,
and 30–33 four. Supported entries show treatment/damage magnitude, shape
and distance. Unrestored status entries are visible but cannot be cast.
Semantic labels are supplied by the demo; original text is not decoded.

Choose a row with up/down and A, or tap it on mobile. Selection preserves
a valid cursor target; otherwise it focuses the nearest legal target and
scrolls vertically to it. C/V cycle legal targets forward/backward; gamepad
X/Y do the same. Mobile has a `下一目标` button for technique and ordinary
attack targeting. Healing can select a full center if wounded neighbors
benefit. Dead units, wrong factions and out-of-range targets are skipped.
No-target situations keep the cast unspent and allow returning to the menu.

Current runnable packages: `build/technique-menu-milestone/`.
See `docs/milestones/BUILD_TECHNIQUE_MENU_MILESTONE.md` for the completed checks and
remaining limitations. Existing saves remain version 1 compatible; target
selection and open menus are transient and reset when loading.

## Experience and promotion milestone

Player attack and technique actions now award experience from the caster's
ROM definition. A technique awards its base experience once, including
recovery; each defeated opponent adds a kill reward. Movement, rest, cancel
and rejected targets award none. Accumulated experience is retained on
upgrade and wraps as an unsigned 16-bit value, matching the ROM writes.

`data/rom_progression.json` contains the actual promotion comparison table
(bank 2 `$97AD`) and branch destinations (bank 10 `$901F`). This is separate
from the class record's experience field and the transcribed manual. One
level check occurs after a player attack/technique, as in the ROM dispatcher.
Same-class levels apply automatically. Branch points open a mandatory
selection panel with class, HP, attack, defense and movement; up/down/A,
controller input and touching a row select the destination. New HP preserves
the previous missing HP. Stats, movement and techniques use the new type.

First-battle roster slot 1 starts at 95 EXP: an attack (3) plus a kill (3)
reaches 101 and opens cavalry/warrior/archer selection. A last-unit branch
choice resolves before the enemy turn; a final-kill branch resolves before
advancing to the next stage. Victory carries all deployed player types and
EXP to their campaign roster slots. Later roster selection shows current
type, movement and EXP. New battles restore full HP; a retry discards battle
growth not saved or committed through victory. New Game resets campaign
growth in memory and retains the existing save file.

Save version 1 remains readable: older saves without progression fields
restore startup types/EXP. New saves include both battle EXP and all twenty
campaign members, validating reachable class paths, integer values, HP and
consistent deployed EXP before applying any changes. Original-ROM runtime
evidence confirms technique EXP 280→285 and two kill bonuses 285→288→291
in `research/evidence/traces/rom_experience_effect.tsv`; this is a controlled effect experiment,
not a natural player promotion recording. Original promotion art and
non-player experience behavior are still incomplete.

Current packages: `build/progression-milestone-final/`. See
`docs/milestones/BUILD_PROGRESSION_MILESTONE.md` for verification and device coverage.

## 自动回合逐步播放（2026-10-05）

友军、敌军现在按现有 AI 的实际行动顺序逐个展示，镜头纵向跟随行动单位，
攻击和治疗动画与本次行动对应，随后显示扣血或回复数值。关闭战斗动画后仍会
简短展示地图行动；播放期间按 A（键盘、手柄、手机按钮）可快进剩余回合。
播放只使用显示快照，不会重复结算行动、经验或回合。胜败面板等待自动回合播放完成。

新包在 `build/turn-playback-milestone/`。已核对19关初始状态的结算一致性，
并在安卓真机读取旧存档，检查连续两次敌方回合与快进。完整说明和覆盖限制见
[逐步回合构建说明](../../docs/milestones/BUILD_TURN_PLAYBACK_MILESTONE.md)。
现有 AI 仍有近似分支，本次不代表19关全部通关或100%原版动画复刻。

## 战场信息与成长后的移动（2026-10-06）

修正转职、读档和后期自选部队仍使用关卡初始移动值的问题。现在移动范围、
目的地校验和指令提示统一读取当前兵种的 ROM 移动字节：骑兵1为3格，骑兵2为4格。

战场上 I／手机“单位详情”／手柄 Back/View 可查看光标单位的 HP、攻防、移动、
行动状态、EXP 和技术。敌军、友军或已行动单位按 A 也能查看。方向键可浏览单位，
A/B 返回，不消耗行动。C/V／手柄 X/Y／手机“待行动”可切换尚未行动的存活己方单位；
已行动单位变暗并带标记。攻击目标预览显示实际扣血、剩余 HP 和能否击败。

最终包：`build/tactics-milestone-final/`。源码检查、画面和两平台导出已完成；
本次手机未连接，尚未安装此 APK 做真机检查。详见
[战场信息构建说明](../../docs/milestones/BUILD_TACTICS_MILESTONE.md)。

## 末关通关流程（2026-10-06）

第十九关胜利后按 A 进入通关记录，不再重载末关。左右切换两页队伍，
上下选择返回标题或保存；手机可直接点击。保存会覆盖当前 Demo 存档，
以后从标题的“读取进度”可回到通关记录。旧版本 1 战斗存档仍可读取。
现在先播放从原版 ROM 控制运行中截取的五段结局图文，再按 A 逐页
查看制作名单与终幕。按 B 可跳到通关记录；记录里按 R 或点击可重看。
原版中间帧尚未完整提取，当前按采样帧播放；通关记录仍是重制版界面。

新包在 `build/campaign-completion-milestone/`：macOS Universal 2 Debug App
与 Android ARM64 Debug APK。流程、签名与设备覆盖见
[通关流程构建说明](../../docs/milestones/BUILD_CAMPAIGN_COMPLETION_MILESTONE.md)。
更新的原版结局包与证据见
[原版结局构建说明](../../docs/milestones/BUILD_ROM_ENDING_MILESTONE.md)。
新包：`build/rom-ending-milestone-final/`，包含 macOS 双架构 Debug App 和
Android ARM64 Debug APK；本轮没有连接的安卓设备可做真机检查。

## Windows 导出与结局触屏操作（2026-10-06）

增加 Windows x64、ARM64 的独立可执行文件导出。结局画面右下角新增
可触摸的“B 跳过”，点画面其它位置仍可继续制作名单。最新四份包在
`build/platform-expansion-milestone/`；Windows 文件已核对 PE 架构，
但尚未在 Windows 设备上启动。细节见
[平台扩展构建说明](../../docs/milestones/BUILD_PLATFORM_EXPANSION_MILESTONE.md)。
