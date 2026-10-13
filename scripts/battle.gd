extends Node2D

## Nineteen ROM battle maps with prototype unit controls.

const TILE_SIZE := 16
const GRID_SIZE := Vector2i(16, 15)
const SCROLL_ANCHOR_Y := 6
const SCREEN_LAST_MOVABLE_Y := 12
const STAGE0_ENEMY_SCROLL_START_Y := 5 # FCEUX $6802 during the first enemy phase.
const ROM_ENEMY_SCROLL_EDGE_Y := 13 # $0618 stays at $D0 as $6802 advances.
const ROM_STAGE_RECORDS_PATH := "res://data/rom_battle_stage_records.json"
const ROM_UNIT_LAYOUTS_PATH := "res://data/rom_stage_unit_layouts.json"
const ROM_MOVEMENT_RULES_PATH := "res://data/rom_stage_movement_rules.json"
const ROM_CLASS_REFERENCE_PATH := "res://data/rom_class_reference.json"
const ROM_UNIT_RECORDS_PATH := "res://data/rom_unit_slot_records.json"
const ROM_TECHNIQUE_EFFECTS_PATH := "res://data/rom_technique_effects.json"
const ROM_ROSTER_SEED_PATH := "res://data/rom_campaign_roster_seed.json"
const STAGE0_BACKGROUND := preload("res://assets/rom_reference/rom_stage00_composed_stage_chr_candidate_color.png")
const STAGE1_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_01_color.png")
const STAGE2_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_02_color.png")
const STAGE3_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_03_color.png")
const STAGE4_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_04_color.png")
const STAGE5_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_05_color.png")
const STAGE6_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_06_color.png")
const STAGE7_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_07_color.png")
const STAGE8_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_08_color.png")
const STAGE9_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_09_color.png")
const STAGE10_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_10_color.png")
const STAGE11_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_11_color.png")
const STAGE12_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_12_color.png")
const STAGE13_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_13_color.png")
const STAGE14_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_14_color.png")
const STAGE15_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_15_color.png")
const STAGE16_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_16_color.png")
const STAGE17_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_17_color.png")
const STAGE18_BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_18_color.png")
const ROM_INFANTRY_POSE := preload("res://assets/rom_reference/rom_stage00_infantry_pose.png")
const ROM_MOUNTED_POSE := preload("res://assets/rom_reference/rom_stage00_mounted_pose.png")
const ROM_PLAYER_MOUNTED_POSE := preload("res://assets/rom_reference/rom_stage00_mounted_player_pose.png")
const ROM_PLAYER_INFANTRY_POSE := preload("res://assets/rom_reference/rom_stage00_infantry_player_pose.png")
const BATTLE_CINEMATICS := preload("res://scripts/battle_cinematics.gd")
const COMMANDS := ["移动", "攻击", "技术", "休息"]
const SYSTEM_COMMANDS := ["全军休息", "全军撤退", "战斗动画", "读取进度", "储存进度", "音乐"]

@export var stage_index := 0
var opponent_unit_count := 0
var group2_unit_count := 0
var player_unit_count := 0
var group1_unit_count := 0
var enemy_deployments: Array = []
var stage_background: Texture2D = STAGE0_BACKGROUND
var cursor := Vector2i(8, 4)
var world_height := GRID_SIZE.y
var max_scroll_y := 0
var view_offset_y := 0
var command_open := false
var command_index := 0
var system_menu_open := false
var system_menu_index := 0
var action_mode := "select"
var technique_attack_variant := 1
var technique_menu_open := false
var technique_menu_index := 0
var technique_effect_mode := "auto"
var selected_unit_index := -1
var inspected_unit_index := -1
var status_message := "向下滚动找蓝色己方部队 · A指令 B取消"
var touch_controls_enabled := false
var touch_pad_expanded := false
var touch_drag_origin := Vector2.ZERO
var touch_drag_active := false
var touch_press_consumed := false
var touch_pressed_button := ""
var touch_held_direction: Key = KEY_NONE
var touch_repeat_time := 0.0
var last_screen_touch_ms := -1000
var joy_axis_direction := {}
var show_rom_map := true
var show_rom_cell_debug := false
var show_rom_deployment_debug := false
var rom_stage_record: Dictionary = {}
var rom_layout_record: Dictionary = {}
var rom_movement_rules: Dictionary = {}
var rom_levels: Array = []
var rom_techniques: Array = []
var rom_unit_records: Dictionary = {}
var rom_technique_effects: Dictionary = {}
var rom_enemy_healing_targeting: Dictionary = {}
var roster_seed: Array = []
var selected_roster_indices: Array[int] = []
var unit_hp: Array[int] = []
var unit_experience: Array[int] = []
var player_roster_indices: Array[int] = []
var promotion_unit := -1
var promotion_choices: Array[int] = []
var promotion_index := 0
var progression_message := ""
var unit_type_ids: Array[int] = []
## ROM bank 2 keeps acted unit slots at $6816 and their count at $6822.
## This demo records its player-side slots in the same list shape.
var acted_unit_slots: Array[int] = []
var turn_number := 1
var demo_clear := false
var demo_defeat := false
var movement_type_ids: Array[int] = []
var movement_inspector := false
var inspector_type_id := 0
var inspector_origin := Vector2i(8, 7)
var enemy_action_focus := Vector2i(-1, -1)
var enemy_action_description := ""
var enemy_preview_active := false
var phase_recording := false
var phase_playback_active := false
var phase_skip := false
var phase_steps: Array[Dictionary] = []
var phase_display_units: Array[Vector2i] = []
var phase_display_hp: Array[int] = []
var phase_hp_changes: Dictionary = {}
var phase_actor := -1
var phase_return_cursor := Vector2i.ZERO
var phase_return_scroll := 0
var phase_summary := ""
var rom_enemy_scroll_y := -1
var battle_animations_enabled := true
var cinematics

var units: Array[Vector2i] = []

func _ready() -> void:
	DisplayServer.window_set_title("爆笑三国 · ROM第%d关演示" % (stage_index + 1))
	GameAudio.play_music("battle")
	RenderingServer.set_default_clear_color(Color("c7b6a0"))
	touch_controls_enabled = DisplayServer.is_touchscreen_available()
	var display_settings := ConfigFile.new()
	if display_settings.load("user://display_settings.cfg") == OK:
		battle_animations_enabled = bool(display_settings.get_value("display", "battle_animations_enabled", true))
	cinematics = BATTLE_CINEMATICS.new()
	cinematics.rom_stage0_enabled = stage_index == 0
	add_child(cinematics)
	match stage_index:
		1:
			stage_background = STAGE1_BACKGROUND
			cursor = Vector2i(8, 5)
		2:
			stage_background = STAGE2_BACKGROUND
			cursor = Vector2i(9, 9)
		3:
			stage_background = STAGE3_BACKGROUND
			cursor = Vector2i(8, 25)
		4:
			stage_background = STAGE4_BACKGROUND
			cursor = Vector2i(8, 25)
			status_message = "首位部队进入北部或清敌可过关"
		5:
			stage_background = STAGE5_BACKGROUND
			cursor = Vector2i(7, 6)
			status_message = "首位部队抵达南端或清敌可过关"
		6:
			stage_background = STAGE6_BACKGROUND
			status_message = "第七关：指挥己方部队消灭组2敌军"
		7:
			stage_background = STAGE7_BACKGROUND
			status_message = "第八关：指挥己方部队消灭组2敌军"
		8:
			stage_background = STAGE8_BACKGROUND
			status_message = "首位部队抵达东北区域或清敌可过关"
		9:
			stage_background = STAGE9_BACKGROUND
			status_message = "第十关：三屏高水战地图 · 清敌过关"
		10:
			stage_background = STAGE10_BACKGROUND
		11:
			stage_background = STAGE11_BACKGROUND
		12:
			stage_background = STAGE12_BACKGROUND
		13:
			stage_background = STAGE13_BACKGROUND
		14:
			stage_background = STAGE14_BACKGROUND
		15:
			stage_background = STAGE15_BACKGROUND
		16:
			stage_background = STAGE16_BACKGROUND
		17:
			stage_background = STAGE17_BACKGROUND
		18:
			stage_background = STAGE18_BACKGROUND
		_:
			stage_background = STAGE0_BACKGROUND
	_load_rom_stage_record()
	world_height = int(rom_stage_record.get("map_world_dimensions", [GRID_SIZE.x, GRID_SIZE.y])[1])
	max_scroll_y = int(rom_stage_record.get("vertical_scroll_limit_cells", 0))
	if stage_index == 0:
		rom_enemy_scroll_y = STAGE0_ENEMY_SCROLL_START_Y
	DemoSave.campaign_progress.ensure_loaded()
	_load_rom_layout_record()
	if stage_index >= 10:
		_load_roster_seed()
		if not DemoSave.pending_snapshot.is_empty() and int(DemoSave.pending_snapshot.get("stage", -1)) == stage_index:
			var saved_roster: Variant = DemoSave.pending_snapshot.get("roster_selection")
			if saved_roster is Array and DemoSave.valid_roster_selection(stage_index, saved_roster):
				DemoSave.roster_selection.assign(saved_roster)
		selected_roster_indices = DemoSave.selected_roster_for_stage(stage_index)
		status_message = "第%d关：选将%d/%d · 清敌过关" % [stage_index + 1, selected_roster_indices.size(), DemoSave.roster_limit(stage_index)]
	enemy_deployments = rom_layout_record.get("unit_group_2", []).duplicate()
	group2_unit_count = enemy_deployments.size()
	opponent_unit_count = group2_unit_count
	player_unit_count = selected_roster_indices.size() if stage_index >= 10 else rom_layout_record.get("player_deployments", []).size()
	group1_unit_count = rom_layout_record.get("unit_group_1", []).size()
	_build_rom_units()
	_load_rom_movement_rules()
	_load_rom_class_reference()
	_load_rom_unit_records()
	_load_rom_technique_effects()
	for type_id in unit_type_ids:
		var record: Dictionary = rom_unit_records.get(type_id, {})
		var raw: Array = record.get("raw_bytes", [])
		unit_hp.append(int(raw[0]) + int(raw[1]) * 256 if raw.size() >= 2 else 0)
		unit_experience.append(int(raw[4]) + int(raw[5]) * 256 if raw.size() >= 6 else 0)
	for slot in player_unit_count:
		unit_experience[opponent_unit_count + slot] = DemoSave.campaign_progress.experience[player_roster_indices[slot]]
	if stage_index >= 6 and player_unit_count > 0:
		cursor = units[opponent_unit_count]
	if stage_index in [3, 4] or stage_index >= 6:
		_update_view_offset()
	if not DemoSave.pending_snapshot.is_empty():
		var pending: Dictionary = DemoSave.pending_snapshot
		DemoSave.pending_snapshot = {}
		status_message = "已读取第%d关演示存档" % (stage_index + 1) if _apply_demo_snapshot(pending) else "存档与本关ROM数据不匹配"
	if battle_animations_enabled:
		cinematics.enqueue_turn(true)
	queue_redraw()

func _build_rom_units() -> void:
	units.clear()
	unit_type_ids.clear()
	player_roster_indices.clear()
	if enemy_deployments.is_empty():
		push_error("ROM stage %d has no opposing deployments" % stage_index)
	for entry in enemy_deployments:
		units.append(Vector2i(int(entry["position_x"]), int(entry["position_y"])))
		unit_type_ids.append(int(entry["unit_type_id"]))
	var player_entries: Array = rom_layout_record.get("player_deployments", [])
	for player_slot in range(player_unit_count):
		var entry: Dictionary = player_entries[player_slot]
		units.append(Vector2i(int(entry["position_x"]), int(entry["position_y"])))
		var roster_index := selected_roster_indices[player_slot] if stage_index >= 10 else int(entry.get("roster_index", -1))
		player_roster_indices.append(roster_index)
		unit_type_ids.append(DemoSave.campaign_progress.types[roster_index])
	for entry in rom_layout_record.get("unit_group_1", []):
		units.append(Vector2i(int(entry["position_x"]), int(entry["position_y"])))
		unit_type_ids.append(int(entry["unit_type_id"]))

func _load_roster_seed() -> void:
	var file := FileAccess.open(ROM_ROSTER_SEED_PATH, FileAccess.READ)
	if file == null:
		push_error("ROM campaign roster seed is missing")
		return
	var root: Variant = JSON.parse_string(file.get_as_text())
	if root is Dictionary:
		roster_seed = root.get("entries", [])

func _load_rom_class_reference() -> void:
	var file := FileAccess.open(ROM_CLASS_REFERENCE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to read ROM class reference: " + ROM_CLASS_REFERENCE_PATH)
		return
	var root: Variant = JSON.parse_string(file.get_as_text())
	if not (root is Dictionary) or not root.has("levels"):
		push_warning("ROM class reference JSON has an unexpected structure")
		return
	rom_levels = root["levels"]
	rom_techniques = root.get("techniques", [])

func _load_rom_unit_records() -> void:
	var file := FileAccess.open(ROM_UNIT_RECORDS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to read ROM unit records: " + ROM_UNIT_RECORDS_PATH)
		return
	var root: Variant = JSON.parse_string(file.get_as_text())
	if not (root is Dictionary) or not root.has("records"):
		push_warning("ROM unit records JSON has an unexpected structure")
		return
	for record in root["records"]:
		if not (record is Dictionary) or record.get("movement_allowance_points") == null:
			continue
		var type_id := int(record.get("unit_id", -1))
		if type_id < 0:
			continue
		rom_unit_records[type_id] = record
		movement_type_ids.append(type_id)
	movement_type_ids.sort()

func _load_rom_technique_effects() -> void:
	var file := FileAccess.open(ROM_TECHNIQUE_EFFECTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to read ROM technique effects: " + ROM_TECHNIQUE_EFFECTS_PATH)
		return
	var root: Variant = JSON.parse_string(file.get_as_text())
	if not (root is Dictionary) or not root.has("skills"):
		push_warning("ROM technique effects JSON has an unexpected structure")
		return
	for targeting in root.get("enemy_healing_targeting", {}).get("records", []):
		rom_enemy_healing_targeting[int(targeting.get("unit_type_id", -1))] = targeting
	for skill in root["skills"]:
		if skill is Dictionary:
			rom_technique_effects[int(skill.get("technique_id", -1))] = skill

func _load_rom_layout_record() -> void:
	var file := FileAccess.open(ROM_UNIT_LAYOUTS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to read ROM unit layouts: " + ROM_UNIT_LAYOUTS_PATH)
		return
	var root: Variant = JSON.parse_string(file.get_as_text())
	if not (root is Dictionary) or not root.has("records"):
		push_warning("ROM unit layout JSON has an unexpected structure")
		return
	var records: Array = root["records"]
	if stage_index < 0 or stage_index >= records.size() or not (records[stage_index] is Dictionary):
		push_warning("ROM stage layout is missing or malformed")
		return
	rom_layout_record = records[stage_index]

func _load_rom_movement_rules() -> void:
	var file := FileAccess.open(ROM_MOVEMENT_RULES_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to read ROM movement rules: " + ROM_MOVEMENT_RULES_PATH)
		return
	var root: Variant = JSON.parse_string(file.get_as_text())
	if not (root is Dictionary) or not root.has("stages"):
		push_warning("ROM movement rules JSON has an unexpected structure")
		return
	var stages: Array = root["stages"]
	if stage_index < 0 or stage_index >= stages.size() or not (stages[stage_index] is Dictionary):
		push_warning("ROM movement rule for this stage is missing or malformed")
		return
	rom_movement_rules = stages[stage_index]

func _load_rom_stage_record() -> void:
	var file := FileAccess.open(ROM_STAGE_RECORDS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to read ROM stage records: " + ROM_STAGE_RECORDS_PATH)
		return
	var root: Variant = JSON.parse_string(file.get_as_text())
	if not (root is Dictionary) or not root.has("records"):
		push_warning("ROM stage record JSON has an unexpected structure")
		return
	var records: Array = root["records"]
	if stage_index < 0 or stage_index >= records.size():
		push_warning("ROM stage index is outside the extracted record list")
		return
	var candidate: Variant = records[stage_index]
	if not (candidate is Dictionary):
		push_warning("ROM stage record is not an object")
		return
	rom_stage_record = candidate

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	_handle_key(event.keycode)

func _process(delta: float) -> void:
	if touch_held_direction == KEY_NONE:
		return
	touch_repeat_time -= delta
	while touch_repeat_time <= 0.0:
		_handle_key(touch_held_direction)
		touch_repeat_time += 0.11

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and touch_controls_enabled:
		if event.index != 0:
			return
		last_screen_touch_ms = Time.get_ticks_msec()
		if event.pressed:
			touch_drag_origin = event.position
			touch_drag_active = true
			touch_press_consumed = _handle_touch_control(event.position)
		elif touch_drag_active:
			touch_held_direction = KEY_NONE
			touch_pressed_button = ""
			touch_drag_active = false
			queue_redraw()
			if touch_press_consumed:
				touch_press_consumed = false
				return
			if absf(event.position.y - touch_drag_origin.y) >= 24.0 and _map_screen_rect().has_point(touch_drag_origin) and not command_open and not system_menu_open and not technique_menu_open:
				var steps := clampi(roundi(absf(event.position.y - touch_drag_origin.y) / 16.0), 1, 8)
				for step in range(steps):
					_handle_key(KEY_UP if event.position.y > touch_drag_origin.y else KEY_DOWN)
			else:
				_handle_touch(event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and touch_controls_enabled and Time.get_ticks_msec() - last_screen_touch_ms > 180:
		_handle_touch(event.position)
		return
	if event is InputEventJoypadMotion:
		var direction := 0
		if absf(event.axis_value) > 0.7:
			direction = 1 if event.axis_value > 0.0 else -1
		var previous_direction: int = joy_axis_direction.get(event.axis, 0)
		joy_axis_direction[event.axis] = direction
		if direction == 0 or direction == previous_direction:
			return
		var axis_to_key := {
			JOY_AXIS_LEFT_X: KEY_RIGHT if event.axis_value > 0.0 else KEY_LEFT,
			JOY_AXIS_LEFT_Y: KEY_DOWN if event.axis_value > 0.0 else KEY_UP,
		}
		if axis_to_key.has(event.axis):
			_handle_key(axis_to_key[event.axis])
		return
	if not event is InputEventJoypadButton or not event.pressed:
		return
	var joypad_to_key := {
		JOY_BUTTON_DPAD_UP: KEY_UP,
		JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
		JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
		JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
		JOY_BUTTON_A: KEY_A,
		JOY_BUTTON_X: KEY_C,
		JOY_BUTTON_Y: KEY_V,
		JOY_BUTTON_B: KEY_B,
		JOY_BUTTON_LEFT_SHOULDER: KEY_Q,
		JOY_BUTTON_RIGHT_SHOULDER: KEY_E,
		JOY_BUTTON_START: KEY_ENTER,
		JOY_BUTTON_BACK: KEY_I if _tactical_controls_available() or inspected_unit_index >= 0 else KEY_BACKSPACE,
	}
	if joypad_to_key.has(event.button_index):
		_handle_key(joypad_to_key[event.button_index])

func _handle_touch(position: Vector2) -> void:
	if _handle_touch_control(position):
		return
	if _cinematics_busy():
		return
	var map_position := position - Vector2(_game_origin_x(), 0)
	if not Rect2(0, 0, 256, 240).has_point(map_position):
		return
	if promotion_unit >= 0:
		if Rect2(24, 68, 208, promotion_choices.size() * 34).has_point(map_position):
			promotion_index = clampi(floori((map_position.y - 68) / 34), 0, promotion_choices.size() - 1)
			_confirm_promotion()
			queue_redraw()
		return
	if inspected_unit_index >= 0:
		if Rect2(18, 185, 220, 23).has_point(map_position):
			_handle_unit_details_key(KEY_B)
		return
	if movement_inspector and map_position.y < 20.0:
		_handle_movement_inspector_key(KEY_Q if map_position.x < 128.0 else KEY_E)
		return
	if technique_menu_open:
		var rows := _technique_menu_rows()
		if Rect2(34, 58, 188, rows.size() * 27).has_point(map_position):
			technique_menu_index = clampi(floori((map_position.y - 58) / 27), 0, rows.size() - 1)
			_choose_technique_variant()
			queue_redraw()
		return
	if command_open and Rect2(177, 114, 61, 91).has_point(map_position):
		command_index = clampi(floori((map_position.y - 121.0) / 17.0), 0, COMMANDS.size() - 1)
		_choose_command()
		queue_redraw()
		return
	if system_menu_open and Rect2(31, 38, 194, 164).has_point(map_position):
		system_menu_index = clampi(floori((map_position.y - 49.0) / 21.0), 0, SYSTEM_COMMANDS.size() - 1)
		_choose_system_command()
		queue_redraw()
		return
	if not command_open and not system_menu_open and not technique_menu_open:
		var touch_cell := Vector2i(
			clampi(floori(map_position.x / TILE_SIZE), 0, GRID_SIZE.x - 1),
			clampi(view_offset_y + floori(map_position.y / TILE_SIZE), 0, world_height - 1)
		)
		if movement_inspector:
			if _inspector_cell_passable(touch_cell) and _unit_at_cell(touch_cell) < 0:
				cursor = touch_cell
			else:
				status_message = "该格不可通行或已被占用"
		else:
			cursor = touch_cell
			if action_mode == "technique":
				status_message = _technique_target_prompt()
			elif action_mode == "attack":
				status_message = _attack_target_prompt()
		_update_view_offset()
		queue_redraw()

func _game_origin_x() -> float:
	return floorf((get_viewport_rect().size.x - 256.0) / 2.0)

func _map_screen_rect() -> Rect2:
	return Rect2(_game_origin_x(), 0, 256, 240)

func _side_controls_enabled() -> bool:
	return _game_origin_x() >= 95.0

func _touch_button_rects() -> Dictionary:
	if _side_controls_enabled():
		var left := _game_origin_x() / 2.0
		var right := (_game_origin_x() + 256.0 + get_viewport_rect().size.x) / 2.0
		var buttons := {
			"up": Rect2(left - 20, 105, 40, 40),
			"left": Rect2(left - 62, 148, 40, 40),
			"right": Rect2(left + 22, 148, 40, 40),
			"down": Rect2(left - 20, 191, 40, 40),
			"a": Rect2(right + 17, 148, 46, 46),
			"b": Rect2(right - 51, 178, 46, 46),
			"menu": Rect2(right - 30, 89, 60, 34),
		}
		if action_mode == "technique" and not command_open and not system_menu_open and not technique_menu_open:
			buttons["technique"] = Rect2(right - 38, 44, 76, 34)
			buttons["target"] = Rect2(left - 38, 44, 76, 34)
		if action_mode == "attack" and not command_open and not system_menu_open:
			buttons["target"] = Rect2(left - 38, 44, 76, 34)
		if _tactical_controls_available():
			buttons["info"] = Rect2(right - 38, 44, 76, 34)
			buttons["unit"] = Rect2(left - 38, 44, 76, 34)
		return buttons
	var origin := _game_origin_x()
	var buttons := {
		"pad": Rect2(origin + 4, 158, 29, 22),
		"a": Rect2(origin + 219, 186, 33, 33),
		"b": Rect2(origin + 183, 200, 31, 31),
		"menu": Rect2(origin + 209, 155, 43, 25),
	}
	if action_mode == "technique" and not command_open and not system_menu_open and not technique_menu_open:
		buttons["technique"] = Rect2(origin + 160, 155, 43, 25)
		buttons["target"] = Rect2(origin + 113, 155, 43, 25)
	if action_mode == "attack" and not command_open and not system_menu_open:
		buttons["target"] = Rect2(origin + 113, 155, 43, 25)
	if _tactical_controls_available():
		buttons["info"] = Rect2(origin + 160, 155, 43, 25)
		buttons["unit"] = Rect2(origin + 113, 155, 43, 25)
	if touch_pad_expanded:
		buttons.merge({
			"up": Rect2(origin + 38, 158, 24, 24),
			"left": Rect2(origin + 14, 182, 24, 24),
			"right": Rect2(origin + 62, 182, 24, 24),
			"down": Rect2(origin + 38, 206, 24, 24),
		})
	return buttons

func _handle_touch_control(position: Vector2) -> bool:
	if phase_playback_active:
		var phase_buttons := _touch_button_rects()
		if phase_buttons.has("a") and (phase_buttons["a"] as Rect2).has_point(position):
			_skip_phase_playback()
		return true
	if _cinematics_busy():
		return false
	var buttons := _touch_button_rects()
	for name in ["pad", "up", "left", "right", "down", "a", "b", "menu", "technique", "target", "unit", "info"]:
		if buttons.has(name) and (buttons[name] as Rect2).has_point(position):
			touch_pressed_button = name if touch_drag_active else ""
			if name == "pad":
				touch_pad_expanded = not touch_pad_expanded
				queue_redraw()
			else:
				var keys := {"up": KEY_UP, "left": KEY_LEFT, "right": KEY_RIGHT, "down": KEY_DOWN, "a": KEY_A, "b": KEY_B, "menu": KEY_ENTER, "technique": KEY_E, "target": KEY_C, "unit": KEY_C, "info": KEY_I}
				_handle_key(keys[name])
				if name in ["up", "left", "right", "down"]:
					touch_held_direction = keys[name]
					touch_repeat_time = 0.35
			queue_redraw()
			return true
	return false

func _update_view_offset() -> void:
	var screen_y := cursor.y - view_offset_y
	if screen_y < SCROLL_ANCHOR_Y:
		view_offset_y = maxi(0, cursor.y - SCROLL_ANCHOR_Y)
	elif screen_y > SCREEN_LAST_MOVABLE_Y:
		view_offset_y = mini(max_scroll_y, cursor.y - SCREEN_LAST_MOVABLE_Y)

func _handle_key(key: Key) -> void:
	if phase_playback_active:
		if key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_skip_phase_playback()
		return
	if _cinematics_busy():
		return
	if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		GameAudio.play_effect("cursor")
	elif key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		GameAudio.play_effect("confirm")
	elif key in [KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE]:
		GameAudio.play_effect("cancel")
	if promotion_unit >= 0:
		if key in [KEY_UP, KEY_LEFT, KEY_Q]: promotion_index = posmod(promotion_index - 1, promotion_choices.size())
		elif key in [KEY_DOWN, KEY_RIGHT, KEY_E]: promotion_index = posmod(promotion_index + 1, promotion_choices.size())
		elif key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]: _confirm_promotion()
		queue_redraw()
		return
	if inspected_unit_index >= 0:
		_handle_unit_details_key(key)
		return
	if demo_defeat:
		if key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			DemoSave.return_to_title = true
			get_tree().change_scene_to_file("res://scenes/intro.tscn")
		elif key in [KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE]:
			get_tree().reload_current_scene()
		return
	if demo_clear and key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_commit_campaign_progress()
		if stage_index == 18:
			DemoSave.completed_run = DemoSave.completion_snapshot()
			get_tree().change_scene_to_file("res://scenes/rom_ending.tscn")
		else:
			if stage_index >= 9:
				DemoSave.prebattle_stage = stage_index + 1
				get_tree().change_scene_to_file("res://scenes/roster_selection.tscn")
			else:
				get_tree().change_scene_to_file("res://scenes/battle_stage%d.tscn" % (stage_index + 1))
		return
	if demo_clear or demo_defeat:
		return
	if key == KEY_F8:
		get_tree().change_scene_to_file("res://scenes/rom_stage_skirmish.tscn")
		return
	if key == KEY_F7:
		get_tree().change_scene_to_file("res://scenes/rom_stage_movement_demo.tscn")
		return
	if key == KEY_F5:
		technique_menu_open = false
		movement_inspector = not movement_inspector
		command_open = false
		system_menu_open = false
		action_mode = "select"
		selected_unit_index = -1
		cursor = inspector_origin
		_update_view_offset()
		status_message = "ROM移动沙盒：Q/E换类型，方向键选位置，A移动，F5返回" if movement_inspector else "返回战斗演示"
		queue_redraw()
		return
	if movement_inspector:
		_handle_movement_inspector_key(key)
		return
	if technique_menu_open:
		var rows := _technique_menu_rows()
		if key in [KEY_UP, KEY_Q]:
			technique_menu_index = posmod(technique_menu_index - 1, rows.size())
		elif key in [KEY_DOWN, KEY_E, KEY_TAB]:
			technique_menu_index = posmod(technique_menu_index + 1, rows.size())
		elif key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_choose_technique_variant()
		elif key in [KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE]:
			technique_menu_open = false
			command_open = true
			action_mode = "select"
			command_index = 2
			status_message = "选择指令 · A确认 B取消"
		queue_redraw()
		return
	if action_mode == "select" and not command_open and not system_menu_open and key in [KEY_C, KEY_V, KEY_I]:
		if key == KEY_I:
			_open_unit_details(_unit_at_cursor())
		else:
			_cycle_available_player(-1 if key == KEY_V else 1)
		queue_redraw()
		return
	if action_mode in ["attack", "technique"] and not command_open and not system_menu_open and key in [KEY_C, KEY_V]:
		_cycle_legal_target(-1 if key == KEY_V else 1)
		queue_redraw()
		return
	if action_mode == "technique" and technique_effect_mode != "auto" and not command_open and not system_menu_open and key in [KEY_Q, KEY_E, KEY_TAB]:
		_open_technique_menu()
		queue_redraw()
		return
	if action_mode == "technique" and not command_open and not system_menu_open and key in [KEY_Q, KEY_E, KEY_TAB]:
		_cycle_attack_technique(-1 if key == KEY_Q else 1)
		queue_redraw()
		return
	if key == KEY_F3:
		show_rom_map = not show_rom_map
		status_message = "ROM 地图预览" if show_rom_map else "程序绘制预览"
		queue_redraw()
		return
	if key == KEY_F4:
		show_rom_cell_debug = not show_rom_cell_debug
		status_message = "ROM 格子检查开启" if show_rom_cell_debug else "ROM 格子检查关闭"
		queue_redraw()
		return
	if key == KEY_F6:
		show_rom_deployment_debug = not show_rom_deployment_debug
		status_message = "ROM第%d关单位部署层开启" % stage_index if show_rom_deployment_debug else "ROM部署层关闭"
		queue_redraw()
		return
	if system_menu_open:
		if key == KEY_UP:
			system_menu_index = posmod(system_menu_index - 1, SYSTEM_COMMANDS.size())
		elif key == KEY_DOWN:
			system_menu_index = posmod(system_menu_index + 1, SYSTEM_COMMANDS.size())
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_A, KEY_Z]:
			_choose_system_command()
		elif key in [KEY_ESCAPE, KEY_B, KEY_S, KEY_X, KEY_BACKSPACE]:
			system_menu_open = false
			status_message = ""
		else:
			return
		queue_redraw()
		return
	if command_open:
		if key == KEY_UP:
			command_index = posmod(command_index - 1, COMMANDS.size())
		elif key == KEY_DOWN:
			command_index = posmod(command_index + 1, COMMANDS.size())
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_A, KEY_Z]:
			_choose_command()
		elif key in [KEY_ESCAPE, KEY_B, KEY_S, KEY_X, KEY_BACKSPACE]:
			command_open = false
			selected_unit_index = -1
			action_mode = "select"
		else:
			return
		queue_redraw()
		return
	if action_mode == "technique" and key in [KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE]:
		_open_technique_menu()
		queue_redraw()
		return
	if key == KEY_UP:
		cursor.y = maxi(0, cursor.y - 1)
	elif key == KEY_DOWN:
		cursor.y = mini(world_height - 1, cursor.y + 1)
	elif key == KEY_LEFT:
		cursor.x = maxi(0, cursor.x - 1)
	elif key == KEY_RIGHT:
		cursor.x = mini(GRID_SIZE.x - 1, cursor.x + 1)
	elif key in [KEY_A, KEY_Z, KEY_SPACE]:
		if action_mode == "move":
			_commit_unit_move()
		elif action_mode == "attack":
			_commit_attack()
		elif action_mode == "technique":
			_commit_technique()
		elif action_mode == "select":
			selected_unit_index = _unit_at_cursor()
			if selected_unit_index < 0:
				status_message = "请将光标移到我方单位上，再按 A"
			elif not _is_player_unit(selected_unit_index) or acted_unit_slots.has(selected_unit_index):
				_open_unit_details(selected_unit_index)
			else:
				command_open = true
				command_index = 0
				status_message = "%s HP%d/%d · 移%d · EXP%d" % [_unit_class_name(unit_type_ids[selected_unit_index]), unit_hp[selected_unit_index], _unit_max_hp(selected_unit_index), _selected_movement_points(), unit_experience[selected_unit_index]]
		else:
			status_message = "当前指令的目标选择规则尚未解出"
	elif key in [KEY_ENTER, KEY_KP_ENTER]:
		system_menu_open = true
		system_menu_index = 0
		status_message = "方向键选择  A确认  B取消"
	elif key in [KEY_ESCAPE, KEY_S, KEY_X, KEY_BACKSPACE]:
		action_mode = "select"
		selected_unit_index = -1
		status_message = ""
	elif key == KEY_B:
		action_mode = "select"
		selected_unit_index = -1
		command_open = false
		system_menu_open = false
		status_message = "已取消"
	else:
		return
	if action_mode == "technique" and key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		status_message = _technique_target_prompt()
	elif action_mode == "attack" and key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		status_message = _attack_target_prompt()
	_update_view_offset()
	queue_redraw()

func _cinematics_busy() -> bool:
	return phase_playback_active or enemy_preview_active or (cinematics != null and cinematics.is_busy())

func _handle_movement_inspector_key(key: Key) -> void:
	if key in [KEY_Q, KEY_E]:
		if movement_type_ids.is_empty():
			status_message = "ROM类型数据未加载"
			queue_redraw()
			return
		var current_index := movement_type_ids.find(inspector_type_id)
		current_index = posmod(current_index + (-1 if key == KEY_Q else 1), movement_type_ids.size())
		inspector_type_id = movement_type_ids[current_index]
		status_message = _inspector_description()
	elif key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var step := Vector2i.ZERO
		match key:
			KEY_UP: step.y = -1
			KEY_DOWN: step.y = 1
			KEY_LEFT: step.x = -1
			KEY_RIGHT: step.x = 1
		var destination := Vector2i(
			clampi(cursor.x + step.x, 0, GRID_SIZE.x - 1),
			clampi(cursor.y + step.y, 0, world_height - 1)
		)
		if _inspector_cell_passable(destination) and (destination == inspector_origin or _unit_at_cell(destination) < 0):
			cursor = destination
			_update_view_offset()
		else:
			status_message = "ROM地形阻挡或单位占格"
	elif key in [KEY_A, KEY_Z, KEY_SPACE]:
		if cursor == inspector_origin:
			status_message = "方向键选择目的地；%s" % _inspector_description()
		elif not _inspector_cell_in_range(cursor):
			status_message = "移动失败：超出%d格移动预算" % _inspector_movement_points()
		elif not _inspector_cell_passable(cursor):
			status_message = "移动失败：ROM地形不在本关通行表中"
		elif _unit_at_cell(cursor) >= 0:
			status_message = "移动失败：该格已有演示单位"
		else:
			inspector_origin = cursor
			status_message = "测试单位已移动到 (%d,%d)；%s" % [cursor.x, cursor.y, _inspector_description()]
	elif key in [KEY_ESCAPE, KEY_B, KEY_S, KEY_X, KEY_BACKSPACE]:
		movement_inspector = false
		status_message = "返回战斗演示"
	else:
		return
	queue_redraw()

func _inspector_row() -> Dictionary:
	if inspector_type_id < 0 or inspector_type_id >= rom_levels.size():
		return {}
	return rom_levels[inspector_type_id]

func _inspector_movement_points() -> int:
	var record: Dictionary = rom_unit_records.get(inspector_type_id, {})
	return int(record.get("movement_allowance_points", -1))

func _inspector_description() -> String:
	var row := _inspector_row()
	var movement := _inspector_movement_points()
	if movement < 0:
		return "类型%d · 移动数据未解出" % inspector_type_id
	if row.is_empty():
		return "ROM单位类型%d · 移动%d" % [inspector_type_id, movement]
	var description := "类型%d %s Lv%d · 移动%d" % [inspector_type_id, str(row.get("class_name", "未知")), int(row.get("level", 0)), movement]
	var technique_id := int(row.get("technique_id", -1))
	for technique in rom_techniques:
		if int(technique.get("technique_id", -2)) == technique_id:
			description += " · 技:%s 距%s 面%s 效%s" % [
				str(technique.get("name", "?")),
				str(technique.get("range", "?")),
				str(technique.get("area", "?")),
				str(technique.get("effect", "?")),
			]
			break
	return description

func _inspector_cell_in_range(cell: Vector2i) -> bool:
	return absi(cell.x - inspector_origin.x) + absi(cell.y - inspector_origin.y) <= _inspector_movement_points()

func _inspector_cell_passable(cell: Vector2i) -> bool:
	var map_grid: Array = rom_stage_record.get("map_source_world_16x15_pages", [])
	var passable_codes: Array = rom_movement_rules.get("passable_map_codes", [])
	if cell.x < 0 or cell.x >= GRID_SIZE.x or cell.y < 0 or cell.y >= map_grid.size():
		return false
	var row: Array = map_grid[cell.y]
	if cell.x >= row.size():
		return false
	for code in passable_codes:
		if int(code) == int(row[cell.x]):
			return true
	return false

func _unit_at_cell(cell: Vector2i) -> int:
	for index in units.size():
		if units[index] == cell and index < unit_hp.size() and unit_hp[index] > 0:
			return index
	return -1

func _unit_movement_points(index: int) -> int:
	if index < 0 or index >= unit_type_ids.size(): return 0
	return int(rom_unit_records.get(unit_type_ids[index], {}).get("movement_allowance_points", 0))

func _selected_movement_points() -> int:
	return _unit_movement_points(selected_unit_index) if _is_player_unit(selected_unit_index) else 0

func _is_player_unit(index: int) -> bool:
	return index >= opponent_unit_count and index < opponent_unit_count + player_unit_count

func _reachable_move_cells() -> Dictionary:
	var distances := {}
	if not _is_player_unit(selected_unit_index):
		return distances
	var origin: Vector2i = units[selected_unit_index]
	var budget := _selected_movement_points()
	distances[origin] = 0
	var frontier: Array[Vector2i] = [origin]
	var head := 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		var steps: int = distances[cell]
		if steps >= budget:
			continue
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next_cell: Vector2i = cell + direction
			if distances.has(next_cell) or not _inspector_cell_passable(next_cell):
				continue
			if _unit_at_cell(next_cell) >= 0:
				continue
			distances[next_cell] = steps + 1
			frontier.append(next_cell)
	return distances

func _move_rejection(cell: Vector2i) -> String:
	if not _is_player_unit(selected_unit_index):
		return "未选择 ROM 己方单位"
	var origin: Vector2i = units[selected_unit_index]
	var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
	if distance > _selected_movement_points():
		return "超出移动范围：该单位可移动%d格" % _selected_movement_points()
	if not _inspector_cell_passable(cell):
		return "ROM 地形不可通行"
	var occupant := _unit_at_cell(cell)
	if occupant >= 0 and occupant != selected_unit_index:
		return "该格已有单位"
	if not _reachable_move_cells().has(cell):
		return "移动失败：路径被地形或单位阻挡"
	return ""

func _commit_unit_move() -> void:
	var rejection := _move_rejection(cursor)
	if rejection != "":
		status_message = rejection
		return
	var movement_points := _selected_movement_points()
	units[selected_unit_index] = cursor
	GameAudio.play_effect("move")
	_mark_selected_unit_acted()
	action_mode = "select"
	selected_unit_index = -1
	status_message = "已移动到 (%d,%d) · 移动预算%d格" % [cursor.x, cursor.y, movement_points]
	if _special_stage_goal_reached():
		status_message = "已抵达关卡目标 · 回合结束时结算"
	_maybe_auto_end_player_turn()

func _attack_rejection(cell: Vector2i) -> String:
	if not _is_player_unit(selected_unit_index):
		return "未选择 ROM 己方单位"
	var origin: Vector2i = units[selected_unit_index]
	if absi(cell.x - origin.x) + absi(cell.y - origin.y) != 1:
		return "普通攻击只能选择上下左右相邻格"
	var target := _unit_at_cell(cell)
	if target < 0 or target >= opponent_unit_count:
		return "该格没有可攻击的对方单位"
	return ""

func _rom_basic_damage(attacker_type: int, target_type: int) -> int:
	var attacker: Dictionary = rom_unit_records.get(attacker_type, {})
	var target: Dictionary = rom_unit_records.get(target_type, {})
	var a: Array = attacker.get("raw_bytes", [])
	var t: Array = target.get("raw_bytes", [])
	if a.size() < 4 or t.size() < 7:
		return 0
	var attack := int(a[2]) + int(a[3]) * 256
	var defense := int(t[6])
	var difference := attack - defense
	if difference < 0:
		return 16 if difference >= -16 else 8
	return (difference / 2 + 20) as int

func _commit_attack() -> void:
	var rejection := _attack_rejection(cursor)
	if rejection != "":
		status_message = rejection
		return
	progression_message = ""
	var caster := selected_unit_index
	var target := _unit_at_cell(cursor)
	var damage := _rom_basic_damage(unit_type_ids[selected_unit_index], unit_type_ids[target])
	var actual_damage := mini(damage, unit_hp[target])
	unit_hp[target] = maxi(0, unit_hp[target] - damage)
	GameAudio.play_effect("attack")
	if battle_animations_enabled:
		cinematics.enqueue_attack(true, unit_type_ids[selected_unit_index], unit_type_ids[target], actual_damage)
	_award_combat_experience(caster, false, 1 if unit_hp[target] == 0 else 0)
	_mark_selected_unit_acted()
	action_mode = "select"
	selected_unit_index = -1
	var remaining := _living_opponents()
	demo_clear = remaining == 0
	status_message = "演示目标完成：敌军全灭" if demo_clear else "伤害%d · 目标HP%d · 敌军剩余%d" % [actual_damage, unit_hp[target], remaining]
	if not demo_clear and stage_index == 11 and _special_stage_goal_reached():
		demo_clear = true
		status_message = "首位敌军已被击败 · 第十二关完成"
	_maybe_auto_end_player_turn()

func _unit_class_name(type_id: int) -> String:
	for row in rom_levels:
		if int(row.get("unit_type_id", -1)) == type_id:
			return str(row.get("class_name", "部队")) + (str(int(row.get("level", 0))) if int(row.get("level", 0)) > 0 else "")
	return "部队%d" % type_id

func _award_combat_experience(caster: int, technique: bool, defeats: int) -> void:
	if not _is_player_unit(caster): return
	var record: Dictionary = DemoSave.campaign_progress.records.get(unit_type_ids[caster], {})
	var gain := int(record.get("technique_experience" if technique else "attack_experience", 0)) + defeats * int(record.get("kill_experience", 0))
	unit_experience[caster] = (unit_experience[caster] + gain) & 0xFFFF
	progression_message = "EXP+%d" % gain
	var options: Array = record.get("promotion_choices", [])
	if options.is_empty() or unit_experience[caster] < int(record.get("next_experience_threshold", 65535)): return
	if int(record.get("branch_selector", 255)) == 255:
		_promote_unit(caster, int(options[0]))
	else:
		promotion_unit = caster
		promotion_choices.assign(options)
		promotion_index = 0

func _promote_unit(index: int, new_type: int) -> void:
	var missing := _unit_max_hp(index) - unit_hp[index]
	unit_type_ids[index] = new_type
	unit_hp[index] = maxi(1, _unit_max_hp(index) - missing)
	progression_message += " · 升为" + _unit_class_name(new_type)

func _confirm_promotion() -> void:
	if promotion_unit < 0: return
	var index := promotion_unit
	_promote_unit(index, promotion_choices[promotion_index])
	promotion_unit = -1
	promotion_choices.clear()
	status_message = "转职完成 · " + _unit_class_name(unit_type_ids[index])
	_maybe_auto_end_player_turn()

func _campaign_snapshot() -> Dictionary:
	var value: Dictionary = DemoSave.campaign_progress.snapshot()
	for slot in player_unit_count:
		var index := opponent_unit_count + slot
		value["types"][player_roster_indices[slot]] = unit_type_ids[index]
		value["experience"][player_roster_indices[slot]] = unit_experience[index]
	return value

func _commit_campaign_progress() -> void:
	DemoSave.campaign_progress.restore(_campaign_snapshot())

func _draw_promotion_menu() -> void:
	var height := 52 + promotion_choices.size() * 34
	draw_rect(Rect2(22, 31, 212, height), Color("171e21"))
	draw_rect(Rect2(22, 31, 212, height), Color("e2c48f"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(32, 48), "选择升级职业 · EXP%d" % unit_experience[promotion_unit], HORIZONTAL_ALIGNMENT_LEFT, 192, 12, Color("ffe65c"))
	draw_string(ThemeDB.fallback_font, Vector2(32, 61), "上下选择 · A确认 / 点击职业", HORIZONTAL_ALIGNMENT_LEFT, 192, 8, Color("d7d1bf"))
	for index in promotion_choices.size():
		var type_id := promotion_choices[index]
		var raw: Array = rom_unit_records[type_id]["raw_bytes"]
		var y := 68 + index * 34
		if index == promotion_index: draw_rect(Rect2(26, y, 204, 32), Color("36434b"))
		draw_string(ThemeDB.fallback_font, Vector2(32, y + 13), _unit_class_name(type_id), HORIZONTAL_ALIGNMENT_LEFT, 192, 11, Color("a5edb8"))
		draw_string(ThemeDB.fallback_font, Vector2(32, y + 26), "HP%d 攻%d 防%d 移%d" % [int(raw[0])+int(raw[1])*256, int(raw[2])+int(raw[3])*256, int(raw[6]), int(raw[7])], HORIZONTAL_ALIGNMENT_LEFT, 192, 8, Color("d7d1bf"))

func _selected_technique_id() -> int:
	if not _is_player_unit(selected_unit_index):
		return 0
	var record: Dictionary = rom_unit_records.get(unit_type_ids[selected_unit_index], {})
	var raw: Array = record.get("raw_bytes", [])
	if raw.size() <= 8:
		return 0
	var skill_id := int(raw[8])
	return skill_id if skill_id >= 1 and skill_id <= 34 else 0

func _technique_menu_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var skill_id := _selected_technique_id()
	if skill_id == 0: return result
	# Bank 8 $8F3C-$8F6D gives highest selectable variant, not packet count.
	var highest := 0
	if skill_id >= 19 and skill_id <= 33:
		highest = 1 + int(skill_id >= 24) + int(skill_id >= 30)
	for variant in range(highest + 1):
		var packet := _technique_packet(skill_id, variant)
		var healing := skill_id >= 19 and skill_id <= 33 and variant == 0
		var area := int(packet.get("area_code", 1))
		var shape := "十字" if area == 5 else "九宫" if area == 9 else "单体"
		var supported := not packet.is_empty() and (healing or variant in _selected_attack_variants())
		var label := "%s%s %d" % [shape, "治疗" if healing else "攻击", int(packet.get("effect_magnitude", 0))]
		if not supported: label = "技术变体%d · 尚未还原" % (variant + 1)
		result.append({"variant": variant, "healing": healing, "packet": packet, "supported": supported, "label": label})
	return result

func _open_technique_menu() -> void:
	var rows := _technique_menu_rows()
	if rows.is_empty():
		status_message = "该单位没有可用技术"
		return
	technique_menu_index = 0
	for index in rows.size():
		if technique_effect_mode == "attack" and int(rows[index]["variant"]) == technique_attack_variant:
			technique_menu_index = index
	technique_menu_open = true
	command_open = false
	status_message = "上下选技术 · A确认 B返回"

func _choose_technique_variant() -> void:
	var rows := _technique_menu_rows()
	if technique_menu_index < 0 or technique_menu_index >= rows.size(): return
	var row: Dictionary = rows[technique_menu_index]
	if not bool(row["supported"]):
		status_message = "该特殊效果尚未还原 · 请选择其他技术"
		return
	technique_effect_mode = "heal" if bool(row["healing"]) else "attack"
	technique_attack_variant = int(row["variant"])
	technique_menu_open = false
	action_mode = "technique"
	_cycle_legal_target(1, true)

func _legal_action_targets() -> Array[int]:
	var result: Array[int] = []
	for index in units.size():
		if unit_hp[index] <= 0: continue
		# A cell cursor selects its first living deployment slot.
		if _unit_at_cell(units[index]) != index: continue
		var rejection := _technique_rejection(units[index]) if action_mode == "technique" else _attack_rejection(units[index])
		if rejection.is_empty(): result.append(index)
	return result

func _cycle_legal_target(direction: int, nearest := false) -> void:
	var targets := _legal_action_targets()
	if targets.is_empty():
		status_message = "没有合法目标 · B返回技术" if action_mode == "technique" else "没有相邻敌军 · B取消"
		return
	var chosen := targets[0]
	if nearest and targets.has(_unit_at_cell(cursor)):
		chosen = _unit_at_cell(cursor)
	elif nearest:
		var distance := 100000
		for target in targets:
			var candidate := absi(units[target].x - units[selected_unit_index].x) + absi(units[target].y - units[selected_unit_index].y)
			if candidate < distance:
				chosen = target
				distance = candidate
	else:
		var current := targets.find(_unit_at_cell(cursor))
		chosen = targets[posmod(current + direction, targets.size())] if current >= 0 else targets[0 if direction > 0 else targets.size() - 1]
	cursor = units[chosen]
	_update_view_offset()
	status_message = _technique_target_prompt() if action_mode == "technique" else _attack_target_prompt()

func _draw_technique_menu() -> void:
	var rows := _technique_menu_rows()
	var height := 52 + rows.size() * 27
	draw_rect(Rect2(32, 29, 192, height), Color("171e21"))
	draw_rect(Rect2(32, 29, 192, height), Color("e2c48f"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(42, 47), "选择技术", HORIZONTAL_ALIGNMENT_LEFT, 172, 12, Color("ffe65c"))
	for index in rows.size():
		var row: Dictionary = rows[index]
		var y := 58 + index * 27
		if index == technique_menu_index:
			draw_rect(Rect2(36, y, 184, 25), Color("36434b"))
		var color := Color("a5edb8") if bool(row["healing"]) else Color("ffe0a3")
		if not bool(row["supported"]): color = Color("8c9395")
		draw_string(ThemeDB.fallback_font, Vector2(42, y + 11), str(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, 172, 10, color)
		if bool(row["supported"]):
			var packet: Dictionary = row["packet"]
			var minimum := 0 if bool(row["healing"]) else _technique_minimum_range(_selected_technique_id())
			draw_string(ThemeDB.fallback_font, Vector2(42, y + 22), "距离%d～%d格" % [minimum, int(packet.get("maximum_range_cells", 0))], HORIZONTAL_ALIGNMENT_LEFT, 172, 8, Color("c5cacf"))
	draw_string(ThemeDB.fallback_font, Vector2(42, height + 22), "A确认 · B返回 · 选目标后C切换", HORIZONTAL_ALIGNMENT_LEFT, 172, 8, Color("d7d1bf"))

func _technique_packet(skill_id: int, variant_index: int) -> Dictionary:
	var skill: Dictionary = rom_technique_effects.get(skill_id, {})
	var variants: Array = skill.get("variants", [])
	if variant_index < 0 or variant_index >= variants.size():
		return {}
	var packet: Dictionary = variants[variant_index]
	# Bank 8 $96C7–$98AA confirms cross (5) and square (9) target lists.
	# Damage uses the same geometric selector with the opposing faction.
	var area := int(packet.get("area_code", 0))
	var supported := area in [1, 5, 9]
	return packet if supported and int(packet.get("effect_magnitude", 0)) > 0 else {}

func _selected_attack_variants() -> Array[int]:
	var result: Array[int] = []
	var skill_id := _selected_technique_id()
	if skill_id >= 19 and skill_id <= 33:
		# Positive variant 2 uses the same damage routine; variants 3+
		# and zero-magnitude status effects remain outside this milestone.
		for variant in [1, 2]:
			if not _technique_packet(skill_id, variant).is_empty(): result.append(variant)
	elif not _technique_packet(skill_id, 0).is_empty():
		result.append(0)
	return result

func _cycle_attack_technique(direction: int) -> void:
	var variants := _selected_attack_variants()
	if variants.size() <= 1:
		return
	var position := variants.find(technique_attack_variant)
	technique_attack_variant = variants[posmod(position + direction, variants.size())]
	GameAudio.play_effect("cursor")
	status_message = _technique_target_prompt()

func _selected_technique_packet(target_index: int = -1) -> Dictionary:
	var skill_id := _selected_technique_id()
	if skill_id == 0:
		return {}
	var healing := target_index >= group2_unit_count and target_index < unit_hp.size()
	if target_index >= 0:
		if technique_effect_mode == "heal" and not healing: return {}
		if technique_effect_mode == "attack" and healing: return {}
	elif technique_effect_mode == "heal":
		return _technique_packet(skill_id, 0)

	if healing and (skill_id < 19 or skill_id == 34):
		return {}
	# Variant 0 heals for IDs 19–33; variant 1 damages. Target-side
	# selection is a demo interaction, pending the original player menu trace.
	if healing: return _technique_packet(skill_id, 0)
	var variants := _selected_attack_variants()
	if variants.is_empty(): return {}
	var variant := technique_attack_variant if variants.has(technique_attack_variant) else variants[0]
	return _technique_packet(skill_id, variant)

func _technique_minimum_range(skill_id: int) -> int:
	# The supplied technical chart specifies range 2 for shooting, and
	# 2–maximum for skills 2–10; original player UI still needs tracing.
	return 2 if skill_id >= 1 and skill_id <= 10 else 1

func _selected_technique_name() -> String:
	var skill_id := _selected_technique_id()
	for row in rom_techniques:
		if int(row.get("technique_id", -1)) == skill_id:
			return str(row.get("name", "技术"))
	return "技术"

func _technique_area_contains(center: Vector2i, cell: Vector2i, area: int) -> bool:
	var delta := cell - center
	match area:
		1: return delta == Vector2i.ZERO
		5: return absi(delta.x) + absi(delta.y) <= 1
		9: return absi(delta.x) <= 1 and absi(delta.y) <= 1
	return false

func _technique_affected_units(caster: int, target: int, area: int, healing: bool) -> Array[int]:
	var result: Array[int] = []
	if caster < 0 or target < 0 or target >= units.size():
		return result
	var caster_enemy := caster < group2_unit_count
	# The ROM preserves the selected center first, then scans its faction.
	var ordered: Array[int] = [target]
	for index in units.size():
		if index != target: ordered.append(index)
	for index in ordered:
		# The center is exactly the selected slot. ROM area scans append
		# neighbors, not additional deployment slots sharing the center cell.
		if index != target and (area == 1 or units[index] == units[target]):
			continue
		if unit_hp[index] <= 0:
			continue # No resurrection: defeated slots stay retired.
		var same_side := (index < group2_unit_count) == caster_enemy
		if same_side != healing or not _technique_area_contains(units[target], units[index], area):
			continue
		if not healing or unit_hp[index] < _unit_max_hp(index):
			result.append(index)
	return result

func _technique_rejection(cell: Vector2i) -> String:
	if not _is_player_unit(selected_unit_index):
		return "先选择我方单位"
	var target := _unit_at_cell(cell)
	if target < 0:
		return "请选择受伤友军 · C切换目标" if technique_effect_mode == "heal" else "请选择敌军 · C切换目标"
	var healing := target >= group2_unit_count
	var packet := _selected_technique_packet(target)
	if packet.is_empty():
		return "请选择友军治疗目标" if technique_effect_mode == "heal" else "请选择敌军攻击目标" if technique_effect_mode == "attack" else "该单位暂无可用的治疗" if healing else "该单位暂无可用的技术攻击"
	if unit_hp[target] <= 0:
		return "不能选择已退场的部队"
	if healing and _technique_affected_units(selected_unit_index, target, int(packet.get("area_code", 1)), true).is_empty():
		return "范围内HP已满 · 请选择受伤部队附近"
	var origin: Vector2i = units[selected_unit_index]
	var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
	var minimum_range := 0 if healing else _technique_minimum_range(_selected_technique_id())
	var maximum_range := int(packet.get("maximum_range_cells", 0))
	if distance < minimum_range or distance > maximum_range:
		return "治疗目标需在%d格内" % maximum_range if healing else "技术目标需要%d～%d格距离" % [minimum_range, maximum_range]
	return ""

func _recover_technique_hp(index: int, magnitude: int) -> int:
	if index < 0 or index >= unit_hp.size() or unit_hp[index] <= 0 or magnitude <= 0:
		return 0
	var recovered := maxi(0, mini(magnitude, _unit_max_hp(index) - unit_hp[index]))
	unit_hp[index] += recovered
	return recovered

func _damage_technique_hp(index: int, magnitude: int) -> int:
	if index < 0 or index >= unit_hp.size() or unit_hp[index] <= 0 or magnitude <= 0:
		return 0
	var actual := mini(magnitude, unit_hp[index])
	unit_hp[index] -= actual
	return actual

func _technique_target_prompt() -> String:
	var rejection := _technique_rejection(cursor)
	if rejection != "":
		return rejection
	var target := _unit_at_cell(cursor)
	var packet := _selected_technique_packet(target)
	var magnitude := int(packet.get("effect_magnitude", 0))
	if target >= group2_unit_count:
		var affected := _technique_affected_units(selected_unit_index, target, int(packet.get("area_code", 1)), true)
		var recovered := 0
		for index in affected:
			recovered += mini(magnitude, _unit_max_hp(index) - unit_hp[index])
		if int(packet.get("area_code", 1)) != 1:
			return "治疗%d人 · 总回复%d HP" % [affected.size(), recovered]
		return "治疗+%d · HP%d→%d/%d" % [recovered, unit_hp[target], unit_hp[target] + recovered, _unit_max_hp(target)]
	var affected := _technique_affected_units(selected_unit_index, target, int(packet.get("area_code", 1)), false)
	if int(packet.get("area_code", 1)) != 1:
		var damage := 0
		for index in affected: damage += mini(magnitude, unit_hp[index])
		return "%s%d人 · 总伤害%d" % [_selected_technique_name(), affected.size(), damage]
	return "技术伤害%d · HP%d→%d" % [mini(magnitude, unit_hp[target]), unit_hp[target], maxi(0, unit_hp[target] - magnitude)]

func _commit_technique() -> void:
	progression_message = ""
	var rejection := _technique_rejection(cursor)
	if rejection != "":
		status_message = rejection
		return
	var target := _unit_at_cell(cursor)
	var packet := _selected_technique_packet(target)
	var magnitude := int(packet.get("effect_magnitude", 0))
	var healing := target >= group2_unit_count
	var caster := selected_unit_index
	var affected := _technique_affected_units(caster, target, int(packet.get("area_code", 1)), healing)
	var defeated := 0
	var effect := 0
	for index in affected:
		if healing:
			effect += _recover_technique_hp(index, magnitude)
		else:
			effect += _damage_technique_hp(index, magnitude)
			if unit_hp[index] == 0: defeated += 1
	GameAudio.play_effect("confirm" if healing else "attack")
	if battle_animations_enabled:
		if healing:
			cinematics.enqueue_heal(true, unit_type_ids[selected_unit_index], unit_type_ids[target], effect, affected.size())
		else:
			cinematics.enqueue_attack(true, unit_type_ids[selected_unit_index], unit_type_ids[target], effect, true, affected.size())
	_award_combat_experience(caster, true, defeated)
	_mark_selected_unit_acted()
	action_mode = "select"
	selected_unit_index = -1
	var remaining := _living_opponents()
	demo_clear = remaining == 0
	status_message = "治疗回复%d HP · 目标%d/%d" % [effect, unit_hp[target], _unit_max_hp(target)] if healing else "技术伤害%d · 目标剩余%d HP" % [effect, unit_hp[target]]
	if int(packet.get("area_code", 1)) != 1:
		status_message = "群体治疗%d人 · 总回复%d HP" % [affected.size(), effect] if healing else "范围攻击%d人 · 总伤害%d HP" % [affected.size(), effect]
	if demo_clear:
		status_message = "敌军全灭 · 本关完成"
	elif stage_index == 11 and _special_stage_goal_reached():
		demo_clear = true
		status_message = "首位敌军已被击败 · 第十二关完成"
	_maybe_auto_end_player_turn()

func _living_opponents() -> int:
	var count := 0
	for index in mini(group2_unit_count, unit_hp.size()):
		if unit_hp[index] > 0:
			count += 1
	return count

func _special_stage_goal_reached() -> bool:
	if opponent_unit_count >= unit_hp.size() or unit_hp[opponent_unit_count] <= 0:
		return false
	var first_player_y: int = units[opponent_unit_count].y
	if stage_index == 4:
		return first_player_y < 15 # Bank 2 $9AA2-$9AB9, first slot $648F.
	if stage_index == 5:
		return first_player_y == 29 # Bank 2 $9ABB-$9AC9.
	if stage_index == 8:
		return first_player_y < 13 and units[opponent_unit_count].x >= 12 # $9ACB-$9ADF.
	if stage_index == 11:
		return unit_hp[0] <= 0 # $9AE1-$9AEF checks state $6789 + player count.
	return false

func _living_players() -> int:
	var count := 0
	for index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
		if unit_hp[index] > 0:
			count += 1
	return count

func _enemy_adjacent_target(enemy_index: int) -> int:
	var chosen := -1
	var enemy_cell: Vector2i = units[enemy_index]
	for index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
		if unit_hp[index] <= 0:
			continue
		var player_cell: Vector2i = units[index]
		if absi(player_cell.x - enemy_cell.x) + absi(player_cell.y - enemy_cell.y) != 1:
			continue
		# Bank 2 $9A24 chooses the adjacent slot with the lowest current HP.
		# Equal HP keeps the first player slot encountered by $AA44.
		if chosen < 0 or unit_hp[index] < unit_hp[chosen]:
			chosen = index
	return chosen

func _group2_technique_target(enemy_index: int, radius: int, include_allies: bool) -> int:
	var chosen := -1
	var origin: Vector2i = units[enemy_index]
	var last_slot := units.size() if include_allies else opponent_unit_count + player_unit_count
	for index in range(opponent_unit_count, last_slot):
		if unit_hp[index] <= 0:
			continue
		var cell: Vector2i = units[index]
		var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
		if distance < 1 or distance > radius:
			continue
		if chosen < 0 or unit_hp[index] < unit_hp[chosen]:
			chosen = index
	return chosen

func _use_high_level_enemy_technique(enemy_index: int) -> Vector2i:
	var flags := int(enemy_deployments[enemy_index].get("ai_flags", 0))
	if (flags & 0xF0) == 0:
		return Vector2i(0, _heal_group2_technique(enemy_index))
	return Vector2i(_cast_high_level_enemy_technique(enemy_index), 0)

func _heal_group2_technique(enemy_index: int) -> int:
	var record: Dictionary = rom_unit_records.get(unit_type_ids[enemy_index], {})
	var raw: Array = record.get("raw_bytes", [])
	if raw.size() <= 8 or int(raw[8]) < 19 or int(raw[8]) == 34:
		return 0
	var skill: Dictionary = rom_technique_effects.get(int(raw[8]), {})
	var variants: Array = skill.get("variants", [])
	if variants.is_empty():
		return 0
	var packet: Dictionary = variants[0]
	# AD30's targeting tables can override the bank-8 packet's area/range.
	# Type 59 has packet area 5 but actually heals one target within 3 cells.
	var targeting: Dictionary = rom_enemy_healing_targeting.get(unit_type_ids[enemy_index], packet)
	if int(targeting.get("area_code", 0)) not in [1, 5, 9] or int(packet.get("effect_magnitude", 0)) <= 0:
		return 0 # Other area and special effects remain unresolved.
	var radius := int(targeting.get("maximum_range_cells", 0))
	var target := -1
	var origin: Vector2i = units[enemy_index]
	# $AD30 starts at the first group-2 slot, allows self, rejects full HP,
	# and $9A24 selects the lowest current HP, keeping the first slot on ties.
	for index in group2_unit_count:
		if unit_hp[index] <= 0 or unit_hp[index] >= _unit_max_hp(index):
			continue
		var cell: Vector2i = units[index]
		if absi(cell.x - origin.x) + absi(cell.y - origin.y) > radius:
			continue
		if target < 0 or unit_hp[index] < unit_hp[target]:
			target = index
	if target < 0:
		return 0
	var affected := _technique_affected_units(enemy_index, target, int(targeting.get("area_code", 1)), true)
	var recovered := 0
	for index in affected:
		recovered += _recover_technique_hp(index, int(packet.get("effect_magnitude", 0)))
	if battle_animations_enabled:
		cinematics.enqueue_heal(false, unit_type_ids[enemy_index], unit_type_ids[target], recovered, affected.size())
	return recovered

func _cast_high_level_enemy_technique(enemy_index: int) -> int:
	var type_record: Dictionary = rom_unit_records.get(unit_type_ids[enemy_index], {})
	var raw: Array = type_record.get("raw_bytes", [])
	if raw.size() <= 8:
		return 0
	var skill: Dictionary = rom_technique_effects.get(int(raw[8]), {})
	var variants: Array = skill.get("variants", [])
	if variants.size() <= 1:
		return 0
	# Zero high flags use the separate friendly wounded-unit healing scan.
	# Nonzero high flags choose attack scans from NES frame parity;
	# alternating demo rounds still approximate that timing.
	var flags := int(enemy_deployments[enemy_index].get("ai_flags", 0))
	if (flags & 0xF0) == 0:
		return 0
	var use_range := turn_number % 2 == 1
	var packet: Dictionary = variants[1] # $AE38 sets $05CD=1 for type >= $38.
	if int(packet.get("area_code", 0)) != 1 or int(packet.get("effect_magnitude", 0)) <= 0:
		return 0
	var radius := int(packet.get("maximum_range_cells", 0)) if use_range else 1
	var target := _group2_technique_target(enemy_index, radius, use_range)
	if target < 0:
		return 0
	var damage := int(packet.get("effect_magnitude", 0))
	if damage <= 0:
		return 0
	var actual_damage := mini(damage, unit_hp[target])
	unit_hp[target] = maxi(0, unit_hp[target] - damage)
	if battle_animations_enabled:
		cinematics.enqueue_attack(false, unit_type_ids[enemy_index], unit_type_ids[target], actual_damage, true)
	return actual_damage

func _cast_type5_technique(enemy_index: int) -> int:
	var type_record: Dictionary = rom_unit_records.get(unit_type_ids[enemy_index], {})
	var raw: Array = type_record.get("raw_bytes", [])
	if raw.size() <= 8 or int(raw[8]) != 1:
		return 0
	var skill: Dictionary = rom_technique_effects.get(1, {})
	var variants: Array = skill.get("variants", [])
	if variants.is_empty():
		return 0
	var packet: Dictionary = variants[0] # $AE1B initializes $05CD=0 for skill 1.
	var target := _group2_technique_target(enemy_index, int(packet.get("maximum_range_cells", 0)), true)
	if target < 0:
		return 0
	var damage := int(packet.get("effect_magnitude", 0))
	if damage <= 0:
		return 0
	var actual_damage := mini(damage, unit_hp[target])
	unit_hp[target] = maxi(0, unit_hp[target] - damage)
	if battle_animations_enabled:
		cinematics.enqueue_attack(false, unit_type_ids[enemy_index], unit_type_ids[target], actual_damage, true)
	return actual_damage

func _cast_common_enemy_technique(enemy_index: int, skill_id: int) -> int:
	if skill_id >= 19 and skill_id <= 33:
		return 0 # Healing and high-class variants use their own dispatch.
	var packet := _technique_packet(skill_id, 0)
	if packet.is_empty():
		return 0
	var radius := int(packet.get("maximum_range_cells", 0))
	var minimum_range := _technique_minimum_range(skill_id)
	var origin: Vector2i = units[enemy_index]
	var target := -1
	for index in range(opponent_unit_count, units.size()):
		if unit_hp[index] <= 0:
			continue
		var cell: Vector2i = units[index]
		var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
		if distance < minimum_range or distance > radius:
			continue
		if target < 0 or unit_hp[index] < unit_hp[target]:
			target = index
	if target < 0:
		return 0
	var damage := int(packet.get("effect_magnitude", 0))
	var affected := _technique_affected_units(enemy_index, target, int(packet.get("area_code", 1)), false)
	var actual_damage := 0
	for index in affected:
		actual_damage += _damage_technique_hp(index, damage)
	if battle_animations_enabled:
		cinematics.enqueue_attack(false, unit_type_ids[enemy_index], unit_type_ids[target], actual_damage, true, affected.size())
	return actual_damage

func _ally_adjacent_target(ally_index: int) -> int:
	var chosen := -1
	var ally_cell: Vector2i = units[ally_index]
	for index in group2_unit_count:
		if unit_hp[index] <= 0:
			continue
		var enemy_cell: Vector2i = units[index]
		if absi(enemy_cell.x - ally_cell.x) + absi(enemy_cell.y - ally_cell.y) != 1:
			continue
		if chosen < 0 or unit_hp[index] < unit_hp[chosen]:
			chosen = index
	return chosen

func _cast_type5_ally_technique(ally_index: int) -> int:
	var skill: Dictionary = rom_technique_effects.get(1, {})
	var variants: Array = skill.get("variants", [])
	if variants.is_empty():
		return 0
	var packet: Dictionary = variants[0]
	var radius := int(packet.get("maximum_range_cells", 0))
	var target := -1
	var origin: Vector2i = units[ally_index]
	for index in group2_unit_count:
		if unit_hp[index] <= 0:
			continue
		var cell: Vector2i = units[index]
		var distance := absi(cell.x - origin.x) + absi(cell.y - origin.y)
		if distance < 1 or distance > radius:
			continue
		if target < 0 or unit_hp[index] < unit_hp[target]:
			target = index
	if target < 0:
		return 0
	var damage := int(packet.get("effect_magnitude", 0))
	if damage <= 0:
		return 0
	var actual_damage := mini(damage, unit_hp[target])
	unit_hp[target] = maxi(0, unit_hp[target] - damage)
	if battle_animations_enabled:
		cinematics.enqueue_attack(true, unit_type_ids[ally_index], unit_type_ids[target], actual_damage, true)
	return actual_damage

func _run_group1_ally_phase() -> Array[int]:
	var attacks := 0
	var total_damage := 0
	var moves := 0
	var techniques := 0
	var technique_damage := 0
	var rests := 0
	var recovered_hp := 0
	# $A764-$A838 processes group 1 before group 2. Stage 2's type-1/3
	# adjacent target branch is traced; stage 3's type-2/4 choices use
	# this same prototype action path pending their exact ROM branch trace.
	for ally_index in range(opponent_unit_count + player_unit_count, units.size()):
		if unit_hp[ally_index] <= 0:
			continue
		if unit_hp[ally_index] < floori(float(_unit_max_hp(ally_index)) / 3.0) and turn_number % 2 == 1:
			# $A7B9-$A7C7 rests on one NES frame parity.
			var recovered := _recover_rest_hp(ally_index)
			recovered_hp += recovered
			rests += 1
			_record_phase_action(ally_index, "友军休息 · 回复%d HP" % recovered)
			continue
		if unit_type_ids[ally_index] == 5:
			# Graphic selector 3 matches $AA40; $A7F1 dispatches the
			# group-1 range scan and $AE6F executes skill 1 on a target.
			var skill_damage := _cast_type5_ally_technique(ally_index)
			if skill_damage > 0:
				techniques += 1
				technique_damage += skill_damage
				_record_phase_action(ally_index, "友军技术 · 造成%d HP" % skill_damage)
			elif _move_ally_toward_first_enemy(ally_index):
				moves += 1
				_record_phase_action(ally_index, "友军移动")
			continue
		var target := _ally_adjacent_target(ally_index)
		if target < 0:
			if _move_ally_toward_first_enemy(ally_index):
				moves += 1
				_record_phase_action(ally_index, "友军移动")
			continue
		var damage := _rom_basic_damage(unit_type_ids[ally_index], unit_type_ids[target])
		var actual_damage := mini(damage, unit_hp[target])
		unit_hp[target] = maxi(0, unit_hp[target] - damage)
		attacks += 1
		total_damage += actual_damage
		if battle_animations_enabled:
			cinematics.enqueue_attack(true, unit_type_ids[ally_index], unit_type_ids[target], actual_damage)
		_record_phase_action(ally_index, "友军攻击 · 造成%d HP" % actual_damage)
	return [attacks, total_damage, moves, techniques, technique_damage, rests, recovered_hp]

func _move_ally_toward_first_enemy(ally_index: int) -> bool:
	# $B51A seeks the first available group-2 coordinate.
	for target_index in group2_unit_count:
		if unit_hp[target_index] > 0:
			return _move_unit_toward_target(ally_index, target_index)
	return false

func _move_special_enemy_toward_first_player(enemy_index: int) -> bool:
	# $AF00 seeks the first live player. Exact ROM direction retries are pending;
	# use the extracted terrain whitelist and class movement allowance here.
	var target_index := -1
	for index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
		if unit_hp[index] > 0:
			target_index = index
			break
	if target_index < 0:
		return false
	if stage_index == 2:
		return _move_stage2_enemy_straight(enemy_index, target_index)
	var extra_step := 0
	if stage_index == 0 and rom_enemy_scroll_y >= 0:
		# In the captured first-stage replay, a type-0 pursuer at screen row
		# 12 or 13 can advance one extra world cell while $6802 scrolls.
		# The other pursuer then acts against the updated scroll value.
		extra_step = 1 if units[enemy_index].y - rom_enemy_scroll_y >= SCREEN_LAST_MOVABLE_Y else 0
	if stage_index == 0 and units[target_index].y < units[enemy_index].y:
		# When the player is north of the castle-lane pursuers, the ROM
		# attempts vertical cells first. A guard at (8,11) blocks the
		# right pursuer's second northward step in the Y=11 replay.
		var north_moved := _move_stage0_north_enemy(enemy_index, target_index, extra_step)
		return north_moved
	if stage_index == 0 and (units[target_index].x < 7 or units[target_index].x > 8):
		# The captured castle lane is vertical until a pursuer reaches the
		# player's row. The right-lane unit at (8,20), screen row 13, does
		# not scroll toward a player at (9,21); it does for (6,21).
		# Keep this observed branch local to the first battle's flank route.
		var flank_moved := _move_stage0_flank_enemy(enemy_index, target_index, extra_step)
		if flank_moved:
			rom_enemy_scroll_y = mini(max_scroll_y, maxi(rom_enemy_scroll_y, units[enemy_index].y - ROM_ENEMY_SCROLL_EDGE_Y))
		return flank_moved
	# The stage-0 replay shows pursuit stopping one row short when the
	# player is below screen row 13. With player (7,18) at scroll 5,
	# the right pursuer can instead reach (8,18) and attack. The row
	# decision still needs the ROM movement routine's exact conditions.
	var player_below_pursuit_edge := units[target_index].y - rom_enemy_scroll_y > ROM_ENEMY_SCROLL_EDGE_Y
	var stop_before_player_row := stage_index == 0 and player_below_pursuit_edge and units[enemy_index].y < units[target_index].y
	var moved := _move_unit_toward_target(enemy_index, target_index, extra_step, stop_before_player_row)
	if moved and stage_index == 0:
		rom_enemy_scroll_y = mini(max_scroll_y, maxi(rom_enemy_scroll_y, units[enemy_index].y - ROM_ENEMY_SCROLL_EDGE_Y))
	return moved

func _move_stage0_north_enemy(enemy_index: int, target_index: int, extra_step: int) -> bool:
	var origin: Vector2i = units[enemy_index]
	var target: Vector2i = units[target_index]
	var record: Dictionary = rom_unit_records.get(unit_type_ids[enemy_index], {})
	var budget := int(record.get("movement_allowance_points", 0)) + extra_step
	var stop_y := target.y + (1 if origin.x == target.x else 0)
	for step in budget:
		if units[enemy_index].y <= stop_y:
			break
		var next_cell := units[enemy_index] + Vector2i.UP
		if not _inspector_cell_passable(next_cell) or _unit_at_cell(next_cell) >= 0:
			break
		units[enemy_index] = next_cell
	return units[enemy_index] != origin

func _move_alert_guard(enemy_index: int, target_index: int) -> bool:
	var origin: Vector2i = units[enemy_index]
	var target: Vector2i = units[target_index]
	var record: Dictionary = rom_unit_records.get(unit_type_ids[enemy_index], {})
	var budget := int(record.get("movement_allowance_points", 0))
	for step in budget:
		var direction := Vector2i.ZERO
		if units[enemy_index].y != target.y:
			direction = Vector2i.DOWN if units[enemy_index].y < target.y else Vector2i.UP
		elif absi(units[enemy_index].x - target.x) > 1:
			direction = Vector2i.RIGHT if units[enemy_index].x < target.x else Vector2i.LEFT
		if direction == Vector2i.ZERO:
			break
		var next_cell: Vector2i = units[enemy_index] + direction
		if not _inspector_cell_passable(next_cell) or _unit_at_cell(next_cell) >= 0:
			break
		units[enemy_index] = next_cell
	return units[enemy_index] != origin

func _move_stage2_enemy_straight(enemy_index: int, target_index: int) -> bool:
	# The stage-2 (9,10) ROM trace chooses a direction once per movement.
	# If the first vertical cell is blocked, try the horizontal direction;
	# after moving, stop at a blocker instead of finding a detour.
	var origin: Vector2i = units[enemy_index]
	var target: Vector2i = units[target_index]
	var directions: Array[Vector2i] = []
	if origin.y != target.y:
		directions.append(Vector2i.DOWN if origin.y < target.y else Vector2i.UP)
	directions.append(Vector2i.RIGHT if origin.x <= target.x else Vector2i.LEFT)
	var direction := Vector2i.ZERO
	for candidate_direction in directions:
		var candidate: Vector2i = origin + candidate_direction
		if _inspector_cell_passable(candidate) and _unit_at_cell(candidate) < 0:
			direction = candidate_direction
			break
	if direction == Vector2i.ZERO:
		return false
	var record: Dictionary = rom_unit_records.get(unit_type_ids[enemy_index], {})
	for movement_step in int(record.get("movement_allowance_points", 0)):
		var candidate: Vector2i = units[enemy_index] + direction
		if not _inspector_cell_passable(candidate) or _unit_at_cell(candidate) >= 0:
			break
		units[enemy_index] = candidate
	return units[enemy_index] != origin

func _move_stage0_flank_enemy(enemy_index: int, target_index: int, extra_step: int) -> bool:
	var origin: Vector2i = units[enemy_index]
	var target: Vector2i = units[target_index]
	var record: Dictionary = rom_unit_records.get(unit_type_ids[enemy_index], {})
	var budget := int(record.get("movement_allowance_points", 0)) + extra_step
	if budget <= 0:
		return false
	if origin.y < target.y:
		if target.x > origin.x and origin.x == 8 and target.y - origin.y == 1:
			return false
		for step in mini(budget, target.y - origin.y):
			var next_cell := units[enemy_index] + Vector2i.DOWN
			if not _inspector_cell_passable(next_cell) or _unit_at_cell(next_cell) >= 0:
				break
			units[enemy_index] = next_cell
	elif origin.y == target.y:
		for step in budget:
			if absi(units[enemy_index].x - target.x) <= 1:
				break
			var next_cell := units[enemy_index] + (Vector2i.RIGHT if units[enemy_index].x < target.x else Vector2i.LEFT)
			if not _inspector_cell_passable(next_cell) or _unit_at_cell(next_cell) >= 0:
				break
			units[enemy_index] = next_cell
	return units[enemy_index] != origin

func _move_unit_toward_target(mover_index: int, target_index: int, extra_step: int = 0, stop_before_target_row: bool = false) -> bool:
	var origin: Vector2i = units[mover_index]
	var target: Vector2i = units[target_index]
	var record: Dictionary = rom_unit_records.get(unit_type_ids[mover_index], {})
	var budget := int(record.get("movement_allowance_points", 0)) + extra_step
	if stop_before_target_row:
		budget = mini(budget, target.y - origin.y - 1)
	if budget <= 0:
		return false
	var previous := {}
	previous[origin] = origin
	var frontier: Array[Vector2i] = [origin]
	var head := 0
	var destination := Vector2i(-1, -1)
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		if absi(cell.x - target.x) + absi(cell.y - target.y) == 1:
			destination = cell
			break
		var directions: Array[Vector2i] = []
		if cell.y != target.y:
			directions.append(Vector2i.DOWN if cell.y < target.y else Vector2i.UP)
		if cell.x != target.x:
			directions.append(Vector2i.RIGHT if cell.x < target.x else Vector2i.LEFT)
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not directions.has(direction):
				directions.append(direction)
		for direction in directions:
			var next_cell: Vector2i = cell + direction
			if previous.has(next_cell) or not _inspector_cell_passable(next_cell):
				continue
			if _unit_at_cell(next_cell) >= 0:
				continue
			previous[next_cell] = cell
			frontier.append(next_cell)
	if destination.x < 0:
		if mover_index >= opponent_unit_count + player_unit_count:
			# Friendly units must be able to take a sideways step around a wall.
			# The Manhattan fallback below can otherwise strand an ally in a
			# one-tile passage even when a terrain route remains open.
			var terrain_distance := _terrain_distances_from(target)
			var best_distance: int = int(terrain_distance.get(origin, 999999))
			for candidate in previous:
				var candidate_distance: int = int(terrain_distance.get(candidate, 999999))
				if candidate_distance < best_distance:
					best_distance = candidate_distance
					destination = candidate
			if destination != Vector2i(-1, -1):
				var terrain_path: Array[Vector2i] = []
				var terrain_step: Vector2i = destination
				while terrain_step != origin:
					terrain_path.append(terrain_step)
					terrain_step = previous[terrain_step]
				units[mover_index] = terrain_path[maxi(0, terrain_path.size() - budget)]
				return true
		# Allied units can temporarily seal the route. Approximate the ROM's
		# local direction attempts with steps that close the tile distance.
		var local_cell := origin
		for movement_step in budget:
			var next_step := local_cell
			var nearest := absi(local_cell.x - target.x) + absi(local_cell.y - target.y)
			for direction in [Vector2i.DOWN, Vector2i.UP, Vector2i.RIGHT, Vector2i.LEFT]:
				var candidate: Vector2i = local_cell + direction
				var distance := absi(candidate.x - target.x) + absi(candidate.y - target.y)
				if distance < nearest and _inspector_cell_passable(candidate) and _unit_at_cell(candidate) < 0:
					nearest = distance
					next_step = candidate
			if next_step == local_cell:
				break
			local_cell = next_step
			units[mover_index] = local_cell
		return local_cell != origin
	var reverse_path: Array[Vector2i] = []
	var step := destination
	while step != origin:
		reverse_path.append(step)
		step = previous[step]
	if reverse_path.is_empty():
		return false
	units[mover_index] = reverse_path[maxi(0, reverse_path.size() - budget)]
	return true

func _terrain_distances_from(origin: Vector2i) -> Dictionary:
	var distances := {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var head := 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next_cell: Vector2i = cell + direction
			if not distances.has(next_cell) and _inspector_cell_passable(next_cell):
				distances[next_cell] = distances[cell] + 1
				frontier.append(next_cell)
	return distances

func _run_common_group2_enemy_phase() -> Array[int]:
	enemy_action_focus = Vector2i(-1, -1)
	enemy_action_description = ""
	var attacks := 0
	var total_damage := 0
	var rests := 0
	var recovered_hp := 0
	var moves := 0
	var techniques := 0
	var technique_damage := 0
	var technique_healing := 0
	var deployments: Array = rom_layout_record.get("unit_group_2", [])
	# Bank 2 $A839-$AA35 processes group 2 in reverse ROM slot order.
	for enemy_index in range(mini(group2_unit_count, deployments.size()) - 1, -1, -1):
		if unit_hp[enemy_index] <= 0 or _living_players() == 0 or _is_pending_enemy_stack(enemy_index):
			continue
		var entry: Dictionary = deployments[enemy_index]
		if not entry.has("ai_flags"):
			continue
		var type_id := unit_type_ids[enemy_index]
		# The layout loader puts auxiliary byte 1 in $67B1 + ROM slot.
		# Byte 0 is a separate stage marker; using it selected the wrong
		# stage-0 pursuer and left the actual two mobile enemies stationary.
		var ai_flags := int(entry["ai_flags"])
		var special := (ai_flags & 0x0F) == 1
		if stage_index == 2 and (ai_flags & 0x0F) == 2:
			var auxiliary: Array = entry.get("auxiliary_bytes", [])
			if auxiliary.size() >= 3:
				for player_index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
					if unit_hp[player_index] > 0 and units[player_index].y <= int(auxiliary[2]):
						special = true # $A954-$A96D jumps back into $A88B.
						break
		var common := not special and type_id < 0x38
		# $A970 enters the high-type branch for every type >= $38. Its
		# high flag nibble chooses a target-search path, not eligibility.
		var caster := not special and type_id >= 0x38
		if not special and not common and not caster:
			continue # Other group-2 decision branches are not decoded yet.
		if caster:
			var skill_effect := _use_high_level_enemy_technique(enemy_index)
			if skill_effect != Vector2i.ZERO:
				techniques += 1
				technique_damage += skill_effect.x
				technique_healing += skill_effect.y
				_record_enemy_action(enemy_index, "敌军治疗 · 回复%d HP" % skill_effect.y if skill_effect.y > 0 else "敌军施放技术 · 造成%d HP" % skill_effect.x)
			continue
		var maximum_hp := _unit_max_hp(enemy_index)
		if unit_hp[enemy_index] < floori(float(maximum_hp) / 3.0):
			# Both the $A88B and $A9A4 branches call $B5B3 -> $8867.
			var recovered := _recover_rest_hp(enemy_index)
			recovered_hp += recovered
			rests += 1
			_record_enemy_action(enemy_index, "敌军休息 · 回复%d HP" % recovered)
			continue
		if special:
			# $AA3A/$AA40 dispatch by graphic selector. Other selectors use
			# ordinary attacks at $A93E, including types 0, 1, 2, and 13.
			# Stage 0's two flag-1 pursuers can move and attack in one action.
			var special_record: Dictionary = rom_unit_records.get(type_id, {})
			var special_raw: Array = special_record.get("raw_bytes", [])
			var selector := int(special_raw[9]) if special_raw.size() > 9 else -1
			var ordinary_selector := selector >= 0 and selector not in [3, 8, 9, 18, 19, 20, 21, 22, 23, 24]
			if ordinary_selector:
				var special_target := _enemy_adjacent_target(enemy_index)
				if special_target < 0:
					var before: Vector2i = units[enemy_index]
					if _move_special_enemy_toward_first_player(enemy_index):
						moves += 1
						_record_enemy_action(enemy_index, "敌军移动 (%d,%d)→(%d,%d)" % [before.x, before.y, units[enemy_index].x, units[enemy_index].y])
					special_target = _enemy_adjacent_target(enemy_index)
				if special_target >= 0:
					var special_damage := _rom_basic_damage(unit_type_ids[enemy_index], unit_type_ids[special_target])
					var special_actual_damage := mini(special_damage, unit_hp[special_target])
					unit_hp[special_target] = maxi(0, unit_hp[special_target] - special_damage)
					attacks += 1
					total_damage += special_actual_damage
					if battle_animations_enabled:
						cinematics.enqueue_attack(false, unit_type_ids[enemy_index], unit_type_ids[special_target], special_actual_damage)
					_record_enemy_action(enemy_index, "敌军攻击 · 造成%d HP" % special_actual_damage)
			elif selector in [19, 20, 21, 22, 23, 24] and (stage_index == 2 or (ai_flags & 0xF0) == 0):
				var special_skill_effect := _use_high_level_enemy_technique(enemy_index)
				if special_skill_effect == Vector2i.ZERO:
					var before: Vector2i = units[enemy_index]
					if _move_special_enemy_toward_first_player(enemy_index):
						moves += 1
						_record_enemy_action(enemy_index, "敌军移动 (%d,%d)→(%d,%d)" % [before.x, before.y, units[enemy_index].x, units[enemy_index].y])
					if _enemy_adjacent_target(enemy_index) >= 0:
						special_skill_effect = _use_high_level_enemy_technique(enemy_index)
				if special_skill_effect != Vector2i.ZERO:
					techniques += 1
					technique_damage += special_skill_effect.x
					technique_healing += special_skill_effect.y
					_record_enemy_action(enemy_index, "敌军治疗 · 回复%d HP" % special_skill_effect.y if special_skill_effect.y > 0 else "敌军施放技术 · 造成%d HP" % special_skill_effect.x)
			continue
		# $A954 compares the AI flag nibble, not the unit type. Flag-2 guards can
		# enter the alert movement path before their $A9A4 fallback.
		var type_record: Dictionary = rom_unit_records.get(type_id, {})
		var raw: Array = type_record.get("raw_bytes", [])
		if raw.size() <= 8:
			continue
		var skill_id := int(raw[8])
		if skill_id > 0 and turn_number % 2 == 1:
			# $A9D6-$A9EF tries a range target on one NES frame parity;
			# alternating demo turns remain an approximation of that timing.
			var skill_damage := _cast_common_enemy_technique(enemy_index, skill_id)
			if skill_damage > 0:
				techniques += 1
				technique_damage += skill_damage
				_record_enemy_action(enemy_index, "敌军施放技术 · 造成%d HP" % skill_damage)
				continue
		var target := _enemy_adjacent_target(enemy_index)
		if target < 0 and stage_index <= 1 and (ai_flags & 0x0F) == 2:
			# Layout auxiliary byte 2 is the southward alert edge in the
			# captured first two stages. Stage 0's Y=9 guards use 14; stage
			# 1's Y=8 guards use 12. One row farther south enters $A9A4.
			var auxiliary: Array = entry.get("auxiliary_bytes", [])
			if auxiliary.size() >= 3:
				var alert_edge := int(auxiliary[2])
				for player_index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
					if unit_hp[player_index] > 0 and units[player_index].y <= alert_edge:
						var before: Vector2i = units[enemy_index]
						if _move_alert_guard(enemy_index, player_index):
							moves += 1
							_record_enemy_action(enemy_index, "敌军移动 (%d,%d)→(%d,%d)" % [before.x, before.y, units[enemy_index].x, units[enemy_index].y])
						target = _enemy_adjacent_target(enemy_index)
					break
		if target < 0:
			# $A9F1-$AA1A: no adjacent target -> rest if HP is not full.
			if unit_hp[enemy_index] < maximum_hp:
				var recovered := _recover_rest_hp(enemy_index)
				recovered_hp += recovered
				rests += 1
				_record_enemy_action(enemy_index, "敌军休息 · 回复%d HP" % recovered)
			continue
		var damage := _rom_basic_damage(unit_type_ids[enemy_index], unit_type_ids[target])
		var actual_damage := mini(damage, unit_hp[target])
		unit_hp[target] = maxi(0, unit_hp[target] - damage)
		total_damage += actual_damage
		attacks += 1
		if battle_animations_enabled:
			cinematics.enqueue_attack(false, unit_type_ids[enemy_index], unit_type_ids[target], actual_damage)
		_record_enemy_action(enemy_index, "敌军攻击 · 造成%d HP" % actual_damage)
	return [attacks, total_damage, rests, recovered_hp, moves, techniques, technique_damage, technique_healing]

func _record_enemy_action(enemy_index: int, description: String) -> void:
	enemy_action_focus = units[enemy_index]
	enemy_action_description = description
	_record_phase_action(enemy_index, description)

func _begin_phase_recording() -> void:
	phase_steps.clear()
	phase_display_units.assign(units)
	phase_display_hp.assign(unit_hp)
	phase_hp_changes.clear()
	phase_return_cursor = cursor
	phase_return_scroll = view_offset_y
	phase_recording = true
	cinematics.capture_mode = true
	cinematics.take_captured_events()

func _record_phase_action(actor: int, description: String) -> void:
	if not phase_recording:
		return
	phase_steps.append({"actor": actor, "description": description,
		"positions": units.duplicate(), "hp": unit_hp.duplicate(),
		"movies": cinematics.take_captured_events()})

func _skip_phase_playback() -> void:
	phase_skip = true
	cinematics.finish_all()

func _play_phase_sequence() -> void:
	if cinematics.is_busy():
		await cinematics.queue_finished
	if not is_inside_tree(): return
	if battle_animations_enabled and not phase_skip:
		cinematics.enqueue_turn(false)
		await cinematics.queue_finished
	for step_index in phase_steps.size():
		if not is_inside_tree(): return
		if phase_skip: break
		var step: Dictionary = phase_steps[step_index]
		phase_actor = int(step["actor"])
		phase_hp_changes.clear()
		cursor = phase_display_units[phase_actor]
		_update_view_offset()
		status_message = "%d/%d %s · A快进" % [step_index + 1, phase_steps.size(), step["description"]]
		queue_redraw()
		await get_tree().create_timer(0.12).timeout
		if not is_inside_tree(): return
		if not phase_skip and battle_animations_enabled and not step["movies"].is_empty():
			cinematics.play_events(step["movies"])
			await cinematics.queue_finished
		if not is_inside_tree(): return
		for index in phase_display_hp.size():
			var change := int(step["hp"][index]) - phase_display_hp[index]
			if change != 0: phase_hp_changes[index] = change
		phase_display_units.assign(step["positions"])
		phase_display_hp.assign(step["hp"])
		cursor = phase_display_units[phase_actor]
		_update_view_offset()
		queue_redraw()
		if not phase_skip:
			await get_tree().create_timer(0.38).timeout
	if not is_inside_tree(): return
	# Authoritative state was resolved once; playback never changes combat/save data.
	phase_display_units.assign(units)
	phase_display_hp.assign(unit_hp)
	phase_hp_changes.clear()
	phase_actor = -1
	if not phase_skip and battle_animations_enabled and not demo_clear and not demo_defeat:
		cinematics.enqueue_turn(true)
		await cinematics.queue_finished
	if not is_inside_tree(): return
	cursor = phase_return_cursor
	view_offset_y = phase_return_scroll
	status_message = phase_summary
	phase_playback_active = false
	phase_skip = false
	phase_display_units.clear()
	phase_display_hp.clear()
	queue_redraw()

func _mark_selected_unit_acted() -> void:
	if _is_player_unit(selected_unit_index) and not acted_unit_slots.has(selected_unit_index):
		acted_unit_slots.append(selected_unit_index)

func _maybe_auto_end_player_turn() -> void:
	if progression_message != "":
		status_message += " · " + progression_message
		progression_message = ""
	if promotion_unit >= 0: return
	if demo_clear or demo_defeat or player_unit_count <= 0:
		return
	for index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
		if unit_hp[index] > 0 and not acted_unit_slots.has(index):
			return
	# Bank 2 $8361-$838A enters $8563 after the processed-list count
	# plus defeated player slots reaches the player deployment count.
	system_menu_index = 0
	_choose_system_command()

func _unit_max_hp(index: int) -> int:
	if index < 0 or index >= unit_type_ids.size():
		return 0
	return _max_hp_for_type(unit_type_ids[index])

func _max_hp_for_type(type_id: int) -> int:
	var raw: Array = rom_unit_records.get(type_id, {}).get("raw_bytes", [])
	return int(raw[0]) + int(raw[1]) * 256 if raw.size() >= 2 else 0

func _recover_rest_hp(index: int) -> int:
	var maximum_hp := _unit_max_hp(index)
	if maximum_hp <= 0 or index < 0 or index >= unit_hp.size() or unit_hp[index] <= 0:
		return 0
	var before := unit_hp[index]
	# Bank 2 $8867 divides maximum HP by 8, adds the quotient, and caps it.
	unit_hp[index] = mini(maximum_hp, before + floori(float(maximum_hp) / 8.0))
	return unit_hp[index] - before

func _rest_selected_unit() -> void:
	if not _is_player_unit(selected_unit_index):
		status_message = "先选择我方单位"
		return
	var maximum_hp := _unit_max_hp(selected_unit_index)
	if maximum_hp <= 0:
		status_message = "ROM最大HP数据未加载"
		return
	var recovered := _recover_rest_hp(selected_unit_index)
	var current_hp := unit_hp[selected_unit_index]
	_mark_selected_unit_acted()
	selected_unit_index = -1
	action_mode = "select"
	status_message = "休息回复%d HP · 当前%d/%d" % [recovered, current_hp, maximum_hp]
	_maybe_auto_end_player_turn()

func _choose_command() -> void:
	command_open = false
	match command_index:
		0:
			if selected_unit_index >= 0:
				action_mode = "move"
				status_message = "选择目的地，A确认；移动%d格" % _selected_movement_points()
			else:
				status_message = "先选择我方单位"
		1:
			action_mode = "attack"
			_cycle_legal_target(1, true)
		2:
			_open_technique_menu()
		3:
			_rest_selected_unit()

func _demo_snapshot() -> Dictionary:
	var positions := []
	for cell in units:
		positions.append([cell.x, cell.y])
	return {
		"version": DemoSave.SAVE_VERSION,
		"stage": stage_index,
		"types": Array(unit_type_ids),
		"roster_selection": Array(selected_roster_indices),
		"positions": positions,
		"hp": Array(unit_hp),
		"experience": Array(unit_experience),
		"campaign": _campaign_snapshot(),
		"acted": Array(acted_unit_slots),
		"turn": turn_number,
		"cursor": [cursor.x, cursor.y],
		"scroll": view_offset_y,
		"rom_enemy_scroll": rom_enemy_scroll_y,
		"clear": demo_clear,
		"defeat": demo_defeat,
	}

func _is_snapshot_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and float(value) == float(int(value))

func _apply_demo_snapshot(snapshot: Dictionary) -> bool:
	if not _is_snapshot_integer(snapshot.get("version")) or not _is_snapshot_integer(snapshot.get("stage")):
		return false
	if int(snapshot["version"]) != DemoSave.SAVE_VERSION or int(snapshot["stage"]) != stage_index:
		return false
	if stage_index >= 10:
		var saved_roster: Variant = snapshot.get("roster_selection")
		if not (saved_roster is Array) or not DemoSave.valid_roster_selection(stage_index, saved_roster):
			return false
		if not _snapshot_roster_matches(saved_roster):
			return false
	var types: Variant = snapshot.get("types")
	var positions: Variant = snapshot.get("positions")
	var hp_values: Variant = snapshot.get("hp")
	var acted: Variant = snapshot.get("acted")
	var saved_cursor: Variant = snapshot.get("cursor")
	if not _is_snapshot_integer(snapshot.get("turn")) or not _is_snapshot_integer(snapshot.get("scroll")):
		return false
	if not (snapshot.get("clear") is bool) or not (snapshot.get("defeat") is bool):
		return false
	if not (types is Array) or not (positions is Array) or not (hp_values is Array) or not (acted is Array) or not (saved_cursor is Array):
		return false
	if types.size() != units.size() or positions.size() != units.size() or hp_values.size() != units.size() or saved_cursor.size() != 2:
		return false
	var restored_campaign: Dictionary = DemoSave.campaign_progress.seed_snapshot()
	var xp_values: Variant = snapshot.get("experience")
	var has_progress := snapshot.has("campaign") or snapshot.has("experience")
	if has_progress:
		if not DemoSave.campaign_progress.valid_snapshot(snapshot.get("campaign")) or not xp_values is Array or xp_values.size() != units.size(): return false
		restored_campaign = snapshot["campaign"].duplicate(true)
	var restored_types: Array[int] = []
	var restored_experience: Array[int] = unit_experience.duplicate()
	for index in units.size():
		if not _is_snapshot_integer(types[index]): return false
		var type_id := int(types[index])
		if not rom_unit_records.has(type_id): return false
		if _is_player_unit(index):
			var roster := player_roster_indices[index - opponent_unit_count]
			if type_id != int(restored_campaign["types"][roster]): return false
			restored_experience[index] = int(restored_campaign["experience"][roster])
		elif type_id != unit_type_ids[index]: return false
		if has_progress:
			if not _is_snapshot_integer(xp_values[index]) or int(xp_values[index]) < 0 or int(xp_values[index]) > 65535: return false
			if _is_player_unit(index) and int(xp_values[index]) != restored_experience[index]: return false
			restored_experience[index] = int(xp_values[index])
		restored_types.append(type_id)
	var restored_positions: Array[Vector2i] = []
	var restored_hp: Array[int] = []
	var occupied := {}
	for index in units.size():
		if not _is_snapshot_integer(types[index]) or not _is_snapshot_integer(hp_values[index]):
			return false
		var pair: Variant = positions[index]
		if not (pair is Array) or pair.size() != 2:
			return false
		if not _is_snapshot_integer(pair[0]) or not _is_snapshot_integer(pair[1]):
			return false
		var cell := Vector2i(int(pair[0]), int(pair[1]))
		var hp := int(hp_values[index])
		if cell.x < 0 or cell.x >= GRID_SIZE.x or cell.y < 0 or cell.y >= world_height or hp < 0 or hp > _max_hp_for_type(restored_types[index]):
			return false
		if hp > 0 and occupied.has(cell):
			var previous_index: int = occupied[cell]
			if not _rom_enemy_slots_share_initial_cell(previous_index, index, cell):
				return false
		if hp > 0:
			occupied[cell] = index
		restored_positions.append(cell)
		restored_hp.append(hp)
	var restored_acted: Array[int] = []
	for slot in acted:
		if not _is_snapshot_integer(slot):
			return false
		var index := int(slot)
		if not _is_player_unit(index) or restored_acted.has(index):
			return false
		restored_acted.append(index)
	if not _is_snapshot_integer(saved_cursor[0]) or not _is_snapshot_integer(saved_cursor[1]):
		return false
	var restored_cursor := Vector2i(int(saved_cursor[0]), int(saved_cursor[1]))
	var restored_scroll := int(snapshot.get("scroll", -1))
	var saved_enemy_scroll: Variant = snapshot.get("rom_enemy_scroll", STAGE0_ENEMY_SCROLL_START_Y if stage_index == 0 else -1)
	var restored_turn := int(snapshot.get("turn", 0))
	if not _is_snapshot_integer(saved_enemy_scroll):
		return false
	if restored_cursor.x < 0 or restored_cursor.x >= GRID_SIZE.x or restored_cursor.y < 0 or restored_cursor.y >= world_height:
		return false
	if restored_scroll < 0 or restored_scroll > max_scroll_y or int(saved_enemy_scroll) < -1 or int(saved_enemy_scroll) > max_scroll_y or restored_turn < 1:
		return false
	var claimed_clear: bool = snapshot["clear"]
	var claimed_defeat: bool = snapshot["defeat"]
	if claimed_defeat and restored_hp[opponent_unit_count] > 0:
		return false
	if claimed_clear:
		var living_enemy := 0
		for index in opponent_unit_count:
			if restored_hp[index] > 0:
				living_enemy += 1
		var special_goal := false
		var first_player: Vector2i = restored_positions[opponent_unit_count]
		match stage_index:
			4: special_goal = restored_hp[opponent_unit_count] > 0 and first_player.y < 15
			5: special_goal = restored_hp[opponent_unit_count] > 0 and first_player.y == 29
			8: special_goal = restored_hp[opponent_unit_count] > 0 and first_player.y < 13 and first_player.x >= 12
			11: special_goal = restored_hp[0] <= 0
		if living_enemy > 0 and not special_goal:
			return false
	DemoSave.campaign_progress.restore(restored_campaign)
	unit_type_ids = restored_types
	unit_experience = restored_experience
	inspected_unit_index = -1
	promotion_unit = -1
	promotion_choices.clear()
	progression_message = ""
	technique_menu_open = false
	technique_effect_mode = "auto"
	units = restored_positions
	unit_hp = restored_hp
	acted_unit_slots = restored_acted
	cursor = restored_cursor
	view_offset_y = restored_scroll
	rom_enemy_scroll_y = int(saved_enemy_scroll)
	turn_number = restored_turn
	demo_clear = bool(snapshot.get("clear", false))
	demo_defeat = bool(snapshot.get("defeat", false))
	selected_unit_index = -1
	action_mode = "select"
	command_open = false
	system_menu_open = false
	queue_redraw()
	return true

func _rom_enemy_slots_share_initial_cell(first: int, second: int, cell: Vector2i) -> bool:
	if first < 0 or first >= opponent_unit_count or second >= opponent_unit_count:
		return false
	var deployments: Array = rom_layout_record.get("unit_group_2", [])
	if first >= deployments.size() or second >= deployments.size():
		return false
	for slot in [first, second]:
		var entry: Dictionary = deployments[slot]
		if Vector2i(int(entry["position_x"]), int(entry["position_y"])) != cell:
			return false
	return true

func _is_pending_enemy_stack(enemy_index: int) -> bool:
	return _is_pending_enemy_stack_for_hp(enemy_index, unit_hp)

func _is_pending_enemy_stack_for_hp(enemy_index: int, hp: Array[int]) -> bool:
	if enemy_index < 0 or enemy_index >= opponent_unit_count or hp[enemy_index] <= 0:
		return false
	var deployments: Array = rom_layout_record.get("unit_group_2", [])
	if enemy_index >= deployments.size():
		return false
	var entry: Dictionary = deployments[enemy_index]
	var initial_cell := Vector2i(int(entry["position_x"]), int(entry["position_y"]))
	for earlier_index in enemy_index:
		if hp[earlier_index] > 0 and _rom_enemy_slots_share_initial_cell(earlier_index, enemy_index, initial_cell):
			return true
	return false

func _snapshot_roster_matches(saved_roster: Variant) -> bool:
	if not (saved_roster is Array) or saved_roster.size() != selected_roster_indices.size():
		return false
	for slot in selected_roster_indices.size():
		if not _is_snapshot_integer(saved_roster[slot]) or int(saved_roster[slot]) != selected_roster_indices[slot]:
			return false
	return true

func _save_demo_progress() -> void:
	status_message = "已储存第%d关演示进度" % (stage_index + 1) if DemoSave.write_snapshot(_demo_snapshot()) else DemoSave.last_error

func _load_demo_progress() -> void:
	var snapshot: Dictionary = DemoSave.read_snapshot()
	if snapshot.is_empty():
		status_message = DemoSave.last_error
		return
	if snapshot.get("completed") == true:
		if not DemoSave.valid_completion_snapshot(snapshot):
			status_message = "通关记录无效"
			return
		DemoSave.completed_run = snapshot
		get_tree().change_scene_to_file("res://scenes/campaign_ending.tscn")
		return
	var saved_stage := int(snapshot.get("stage", -1))
	var scene_path: String = DemoSave.scene_for_stage(saved_stage)
	if scene_path == "":
		status_message = "存档关卡不受当前演示支持"
		return
	if saved_stage == stage_index and (stage_index < 10 or _snapshot_roster_matches(snapshot.get("roster_selection", []))):
		status_message = "已读取第%d关演示进度" % (stage_index + 1) if _apply_demo_snapshot(snapshot) else "存档与本关ROM数据不匹配"
		return
	DemoSave.pending_snapshot = snapshot
	var result := get_tree().change_scene_to_file(scene_path)
	if result != OK:
		DemoSave.pending_snapshot = {}
		status_message = "无法打开存档关卡"

func _choose_system_command() -> void:
	system_menu_open = false
	if system_menu_index == 0:
		GameAudio.play_effect("turn")
		var auto_rested := 0
		var recovered_hp := 0
		for index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
			if unit_hp[index] > 0 and not acted_unit_slots.has(index):
				recovered_hp += _recover_rest_hp(index)
				acted_unit_slots.append(index)
				auto_rested += 1
		# $8563 calls the stage-specific result check before the opponent phase.
		if _special_stage_goal_reached():
			demo_clear = true
			selected_unit_index = -1
			action_mode = "select"
			if stage_index == 4:
				status_message = "首位部队已进入北部 · 第五关完成"
			elif stage_index == 5:
				status_message = "首位部队已抵达南端 · 第六关完成"
			elif stage_index == 11:
				status_message = "首位敌军已被击败 · 第十二关完成"
			else:
				status_message = "首位部队已抵达东北区域 · 第九关完成"
			queue_redraw()
			return
		_begin_phase_recording()
		var ally_result: Array[int] = [0, 0, 0, 0, 0, 0, 0]
		if group1_unit_count > 0:
			ally_result = _run_group1_ally_phase()
		var enemy_result: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
		if stage_index <= 18:
			enemy_result = _run_common_group2_enemy_phase()
		demo_clear = _living_opponents() == 0
		# Bank 2 $9312 flags defeat when the first player slot is removed.
		demo_defeat = unit_hp[opponent_unit_count] <= 0
		acted_unit_slots.clear()
		turn_number += 1
		selected_unit_index = -1
		action_mode = "select"
		if group1_unit_count > 0:
			status_message = "友技%d-%d/移%d 敌攻%d-%d/技%d-%d" % [ally_result[3], ally_result[4], ally_result[2], enemy_result[0], enemy_result[1], enemy_result[5], enemy_result[6]] if ally_result[3] > 0 else "友%d-%d/移%d 敌攻%d-%d/技%d-%d" % [ally_result[0], ally_result[1], ally_result[2], enemy_result[0], enemy_result[1], enemy_result[5], enemy_result[6]]
		else:
			status_message = "己休%d+%d 敌攻%d-%d 敌技%d-%d" % [auto_rested, recovered_hp, enemy_result[0], enemy_result[1], enemy_result[5], enemy_result[6]] if enemy_result[5] > 0 else "己休%d+%d 敌攻%d-%d 敌休%d+%d 敌移%d" % [auto_rested, recovered_hp, enemy_result[0], enemy_result[1], enemy_result[2], enemy_result[3], enemy_result[4]]
		if enemy_result[7] > 0:
			status_message += " · 敌疗%d" % enemy_result[7]
		phase_recording = false
		cinematics.capture_mode = false
		phase_summary = status_message
		if phase_steps.is_empty() and not demo_clear and not demo_defeat:
			phase_summary = "敌军据守 · 向北推进接战" if stage_index == 0 else "敌方本回合待机 · 尚无可用目标"
		phase_playback_active = true
		phase_skip = false
		call_deferred("_play_phase_sequence")
	elif system_menu_index == 2:
		battle_animations_enabled = not battle_animations_enabled
		var display_settings := ConfigFile.new()
		display_settings.set_value("display", "battle_animations_enabled", battle_animations_enabled)
		display_settings.save("user://display_settings.cfg")
		status_message = "战斗动画已开启" if battle_animations_enabled else "战斗动画已关闭"
	elif system_menu_index == 3:
		_load_demo_progress()
	elif system_menu_index == 4:
		_save_demo_progress()
	elif system_menu_index == 5:
		status_message = "音乐已开启" if GameAudio.toggle_music() else "音乐已关闭"
	else:
		status_message = SYSTEM_COMMANDS[system_menu_index] + "：效果尚待ROM规则确认"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("11171d"))
	var game_origin := Vector2(_game_origin_x(), 0)
	draw_set_transform(game_origin + Vector2(0, -view_offset_y * TILE_SIZE))
	if show_rom_map:
		draw_texture(stage_background, Vector2.ZERO)
	else:
		draw_texture(stage_background, Vector2.ZERO)
		for y in range(GRID_SIZE.y):
			for x in range(GRID_SIZE.x):
				_draw_terrain(Vector2i(x, y))
		_draw_castle_towers()
	_draw_units()
	if action_mode == "move":
		_draw_movement_range()
	elif action_mode == "attack":
		_draw_attack_targets()
	elif action_mode == "technique":
		_draw_technique_targets()
	if movement_inspector:
		_draw_movement_inspector()
	_draw_cursor()
	draw_set_transform(game_origin)
	if not phase_playback_active and not _cinematics_busy() and not demo_clear and not demo_defeat and promotion_unit < 0 and not movement_inspector:
		if not command_open and not system_menu_open and not technique_menu_open and inspected_unit_index < 0:
			_draw_round_status()
			if action_mode == "attack": _draw_attack_preview()
	if show_rom_deployment_debug:
		_draw_rom_deployment_debug()
	if show_rom_cell_debug:
		_draw_rom_cell_debug()
	if command_open:
		_draw_command_menu()
	if system_menu_open:
		_draw_system_menu()
	if technique_menu_open:
		_draw_technique_menu()
	if status_message != "":
		draw_rect(Rect2i(0, 225, 256, 15), Color(0.08, 0.07, 0.07, 0.82))
		draw_string(ThemeDB.fallback_font, Vector2(4, 236), status_message, HORIZONTAL_ALIGNMENT_LEFT, 248, 8, Color.WHITE)
	if movement_inspector:
		draw_rect(Rect2i(0, 0, 256, 20), Color(0.04, 0.04, 0.05, 0.88))
		draw_string(ThemeDB.fallback_font, Vector2(4, 9), "ROM移动检视  Q/E类型  %s" % _inspector_description(), HORIZONTAL_ALIGNMENT_LEFT, 248, 8, Color("fff0a8"))
		draw_string(ThemeDB.fallback_font, Vector2(4, 18), "测试单位(%d,%d)  A移动 · Q/E换等级 · F5返回" % [inspector_origin.x, inspector_origin.y], HORIZONTAL_ALIGNMENT_LEFT, 248, 8, Color.WHITE)
	if demo_clear and not phase_playback_active:
		draw_rect(Rect2i(30, 83, 196, 70), Color("171414"))
		draw_rect(Rect2i(30, 83, 196, 70), Color("f2eee2"), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(55, 112), "第%d关胜利" % (stage_index + 1), HORIZONTAL_ALIGNMENT_CENTER, 146, 13, Color("ffe65c"))
		var result_detail := "组2敌军全灭"
		if _living_opponents() > 0 and stage_index == 4:
			result_detail = "首位部队已进入北部"
		elif _living_opponents() > 0 and stage_index == 5:
			result_detail = "首位部队已抵达南端"
		elif _living_opponents() > 0 and stage_index == 8:
			result_detail = "首位部队已抵达东北区域"
		elif _living_opponents() > 0 and stage_index == 11:
			result_detail = "首位敌军已被击败"
		draw_string(ThemeDB.fallback_font, Vector2(43, 128), result_detail, HORIZONTAL_ALIGNMENT_CENTER, 170, 8, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(43, 143), "按 A 观看胜利庆祝" if stage_index == 18 else ("按 A 选将进入第%d关" if stage_index >= 9 else "按 A 进入第%d关") % (stage_index + 2), HORIZONTAL_ALIGNMENT_CENTER, 170, 8, Color.WHITE)
	elif demo_defeat and not phase_playback_active:
		draw_rect(Rect2i(30, 83, 196, 70), Color("171414"))
		draw_rect(Rect2i(30, 83, 196, 70), Color("f2eee2"), false, 2.0)
		draw_string(ThemeDB.fallback_font, Vector2(55, 112), "第%d关战败" % (stage_index + 1), HORIZONTAL_ALIGNMENT_CENTER, 146, 13, Color("ff8777"))
		draw_string(ThemeDB.fallback_font, Vector2(43, 125), "首位出战单位阵亡", HORIZONTAL_ALIGNMENT_CENTER, 170, 8, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(43, 141), "A 返回标题 · B 重试本关", HORIZONTAL_ALIGNMENT_CENTER, 170, 8, Color("fff0a8"))
	if inspected_unit_index >= 0:
		_draw_unit_details()
	if promotion_unit >= 0:
		_draw_promotion_menu()
	draw_set_transform(Vector2.ZERO)
	if touch_controls_enabled:
		_draw_touch_controls()

func _draw_movement_inspector() -> void:
	for y in range(view_offset_y, mini(world_height, view_offset_y + GRID_SIZE.y)):
		for x in range(GRID_SIZE.x):
			var cell := Vector2i(x, y)
			if _inspector_cell_in_range(cell):
				var tint := Color(0.1, 0.9, 0.35, 0.26) if _inspector_cell_passable(cell) and (cell == inspector_origin or _unit_at_cell(cell) < 0) else Color(0.95, 0.16, 0.12, 0.3)
				draw_rect(Rect2i(cell * TILE_SIZE + Vector2i(1, 1), Vector2i(14, 14)), tint)
	var origin := inspector_origin * TILE_SIZE
	draw_circle(Vector2(origin) + Vector2(8, 8), 7.0, Color(0.05, 0.68, 1.0, 0.46))
	draw_circle(Vector2(origin) + Vector2(8, 8), 7.0, Color("65edff"), false, 1.5)
	draw_rect(Rect2i(origin + Vector2i(2, 2), Vector2i(12, 12)), Color("fff0a8"), false, 2.0)

func _draw_movement_range() -> void:
	if not _is_player_unit(selected_unit_index):
		return
	var origin: Vector2i = units[selected_unit_index]
	var radius := _selected_movement_points()
	var reachable := _reachable_move_cells()
	for y in range(maxi(0, origin.y - radius), mini(world_height - 1, origin.y + radius) + 1):
		for x in range(maxi(0, origin.x - radius), mini(GRID_SIZE.x - 1, origin.x + radius) + 1):
			var cell := Vector2i(x, y)
			if absi(x - origin.x) + absi(y - origin.y) > radius:
				continue
			var tint := Color(0.1, 0.9, 0.35, 0.28) if reachable.has(cell) else Color(0.95, 0.16, 0.12, 0.27)
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i.ONE, Vector2i(14, 14)), tint)

func _draw_attack_targets() -> void:
	if not _is_player_unit(selected_unit_index):
		return
	var origin: Vector2i = units[selected_unit_index]
	for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = origin + step
		if _attack_rejection(cell) == "":
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i.ONE, Vector2i(14, 14)), Color("ff6057"), false, 2.0)

func _draw_technique_targets() -> void:
	if not _is_player_unit(selected_unit_index):
		return
	for index in unit_hp.size():
		if unit_hp[index] <= 0:
			continue
		var cell: Vector2i = units[index]
		if _technique_rejection(cell) == "":
			var tint := Color("8fe6a0") if index >= group2_unit_count else Color("ffdc53")
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i.ONE, Vector2i(14, 14)), tint, false, 2.0)

	if _technique_rejection(cursor) == "":
		var target := _unit_at_cell(cursor)
		var packet := _selected_technique_packet(target)
		if int(packet.get("area_code", 1)) != 1:
			var center: Vector2i = units[target]
			for y in range(maxi(0, center.y - 1), mini(world_height - 1, center.y + 1) + 1):
				for x in range(maxi(0, center.x - 1), mini(GRID_SIZE.x - 1, center.x + 1) + 1):
					var cell := Vector2i(x, y)
					if _technique_area_contains(center, cell, int(packet["area_code"])):
						var tint := Color(0.35, 0.9, 0.55, 0.25) if target >= group2_unit_count else Color(1.0, 0.45, 0.25, 0.28)
						draw_rect(Rect2i(cell * TILE_SIZE + Vector2i.ONE, Vector2i(14, 14)), tint)

func _draw_rom_deployment_debug() -> void:
	var players: Array = rom_layout_record.get("player_deployments", [])
	var group_one: Array = rom_layout_record.get("unit_group_1", [])
	var group_two: Array = rom_layout_record.get("unit_group_2", [])
	for entry in players:
		_draw_rom_deployment_marker(entry, Color("64d9ff"))
	for entry in group_one:
		_draw_rom_deployment_marker(entry, Color("ffc857"))
	for entry in group_two:
		_draw_rom_deployment_marker(entry, Color("ff5964"))
	var player_types := PackedStringArray()
	for entry in players:
		var type_id := str(entry.get("unit_type_id", "?"))
		var movement := str(entry.get("movement_allowance_points", "?"))
		player_types.append("%s/%s" % [type_id, movement])
	draw_rect(Rect2i(2, 2, 252, 22), Color(0.04, 0.04, 0.05, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(5, 11), "ROM部署 P:%s G1:%d G2:%d" % [",".join(player_types), group_one.size(), group_two.size()], HORIZONTAL_ALIGNMENT_LEFT, 246, 8, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(5, 20), "青=玩家初始类型/移动点  金=组1  红=组2；坐标可能在视窗外", HORIZONTAL_ALIGNMENT_LEFT, 246, 8, Color("ffe3a1"))

func _draw_rom_deployment_marker(entry: Dictionary, color: Color) -> void:
	var x := int(entry.get("position_x", -1))
	var y := int(entry.get("position_y", -1))
	if x < 0 or x >= GRID_SIZE.x or y < 0 or y >= world_height:
		return
	var center := Vector2(x * TILE_SIZE + 8, y * TILE_SIZE + 8)
	draw_circle(center, 5.0, Color(0.03, 0.03, 0.03, 0.9))
	draw_circle(center, 4.0, color)
	draw_string(ThemeDB.fallback_font, center + Vector2(-2, 3), str(entry.get("unit_type_id", "?")), HORIZONTAL_ALIGNMENT_LEFT, 8, 6, Color.BLACK)

func _draw_rom_cell_debug() -> void:
	var map_grid: Array = rom_stage_record.get("map_source_world_16x15_pages", [])
	var palette_grid: Array = rom_stage_record.get("palette_index_grid_world_16x15_pages", [])
	var compositions: Array = rom_stage_record.get("tile_compositions_2x2", [])
	if map_grid.size() != world_height or palette_grid.size() != world_height:
		return
	if cursor.x >= map_grid[cursor.y].size() or cursor.x >= palette_grid[cursor.y].size():
		return
	var code: int = map_grid[cursor.y][cursor.x]
	var palette_index: int = palette_grid[cursor.y][cursor.x]
	if code < 0 or code >= compositions.size():
		return
	var tiles: Array = compositions[code]
	draw_rect(Rect2i(2, 2, 151, 34), Color(0.04, 0.04, 0.05, 0.9))
	draw_rect(Rect2i(2, 2, 151, 34), Color("e8dfc9"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(6, 14), "ROM格(%02d,%02d) 码%02d 调色板%d" % [cursor.x, cursor.y, code, palette_index], HORIZONTAL_ALIGNMENT_LEFT, 145, 8, Color.WHITE)
	var tile_text := "CHR %s" % (str(tiles) if not tiles.is_empty() else "无")
	draw_string(ThemeDB.fallback_font, Vector2(6, 27), tile_text, HORIZONTAL_ALIGNMENT_LEFT, 145, 8, Color("ffe65c"))

func _draw_terrain(cell: Vector2i) -> void:
	var origin := cell * TILE_SIZE
	draw_rect(Rect2i(origin, Vector2i(16, 16)), Color("e4d5bb"))
	var castle_interior := cell.x >= 2 and cell.x <= 13 and cell.y >= 2 and cell.y <= 9
	var horizontal_wall := cell.y in [1, 10] and cell.x >= 1 and cell.x <= 14
	var vertical_wall := cell.x in [1, 14] and cell.y >= 1 and cell.y <= 10
	if cell.y in [11, 12]:
		_draw_river_tile(origin, cell)
	elif (horizontal_wall or vertical_wall) and not (cell.y == 10 and cell.x in [7, 8]):
		_draw_wall_tile(origin, cell)
	elif castle_interior:
		_draw_courtyard_tile(origin, cell)
	else:
		_draw_tree_patch(origin, cell)
	if cell.x in [7, 8] and cell.y in [10, 11, 12, 13]:
		_draw_bridge_tile(origin, cell)

func _draw_wall_tile(origin: Vector2i, cell: Vector2i) -> void:
	draw_rect(Rect2i(origin, Vector2i(16, 16)), Color("b8aa91"))
	var mortar := Color("f1e3cb")
	if cell.y in [1, 10]:
		draw_rect(Rect2i(origin, Vector2i(16, 3)), Color("f5e7d0"))
		draw_rect(Rect2i(origin + Vector2i(0, 4), Vector2i(16, 3)), Color("3b332c"))
		draw_rect(Rect2i(origin + Vector2i(0, 7), Vector2i(16, 5)), Color("e6d7bf"))
		draw_rect(Rect2i(origin + Vector2i(0, 12), Vector2i(16, 3)), Color("3b332c"))
		draw_rect(Rect2i(origin + Vector2i(0, 15), Vector2i(16, 1)), Color("fff0d8"))
		for x in [0, 8]:
			draw_rect(Rect2i(origin + Vector2i(x, 0), Vector2i(2, 4)), mortar)
	else:
		draw_rect(Rect2i(origin + Vector2i(2, 0), Vector2i(12, 16)), Color("eee0c9"))
		draw_rect(Rect2i(origin + Vector2i(4, 1), Vector2i(8, 14)), Color("3b332c"))
		draw_rect(Rect2i(origin + Vector2i(6, 2), Vector2i(4, 12)), Color("d7c8af"))
		draw_rect(Rect2i(origin + Vector2i(7, 3), Vector2i(2, 10)), Color("8a4c2e"))

func _draw_courtyard_tile(origin: Vector2i, cell: Vector2i) -> void:
	var base := Color("c6c0b0") if (cell.x + cell.y) % 2 == 0 else Color("d2c9b7")
	draw_rect(Rect2i(origin, Vector2i(16, 16)), base)
	for x in [0, 8]:
		draw_rect(Rect2i(origin + Vector2i(x, 0), Vector2i(1, 16)), Color("f4e5cd"))
	for y in [0, 8]:
		draw_rect(Rect2i(origin + Vector2i(0, y), Vector2i(16, 1)), Color("f4e5cd"))
	if (cell.x + cell.y) % 3 == 0:
		draw_rect(Rect2i(origin + Vector2i(3, 3), Vector2i(2, 2)), Color("f3e4cc"))

func _draw_river_tile(origin: Vector2i, cell: Vector2i) -> void:
	draw_rect(Rect2i(origin, Vector2i(16, 16)), Color("2873d0"))
	var phase := (cell.x * 3 + cell.y) % 6
	draw_rect(Rect2i(origin + Vector2i(phase, 2), Vector2i(3, 2)), Color("70a9ed"))
	draw_rect(Rect2i(origin + Vector2i((phase + 7) % 13, 11), Vector2i(2, 2)), Color("0b1b2d"))
	if cell.y == 11:
		draw_rect(Rect2i(origin + Vector2i(0, 0), Vector2i(16, 2)), Color("d9e2dd"))
	elif cell.y == 12:
		draw_rect(Rect2i(origin + Vector2i(0, 14), Vector2i(16, 2)), Color("d9e2dd"))

func _draw_bridge_tile(origin: Vector2i, cell: Vector2i) -> void:
	draw_rect(Rect2i(origin, Vector2i(16, 16)), Color("99502b"))
	for y in [1, 7, 13]:
		draw_rect(Rect2i(origin + Vector2i(0, y), Vector2i(16, 2)), Color("d8d2c3"))
	for x in [2, 12]:
		draw_rect(Rect2i(origin + Vector2i(x, 0), Vector2i(2, 16)), Color("b17735"))

func _draw_castle_towers() -> void:
	for cell in [Vector2i(2, 3), Vector2i(13, 3), Vector2i(2, 7), Vector2i(13, 7)]:
		var o: Vector2i = cell * TILE_SIZE
		draw_rect(Rect2i(o + Vector2i(1, 1), Vector2i(14, 24)), Color("332d2a"))
		draw_rect(Rect2i(o + Vector2i(3, 3), Vector2i(10, 19)), Color("a4542b"))
		draw_rect(Rect2i(o + Vector2i(5, 4), Vector2i(6, 14)), Color("d2a66a"))
		draw_rect(Rect2i(o + Vector2i(4, 8), Vector2i(8, 2)), Color("342b27"))
		draw_rect(Rect2i(o + Vector2i(5, 19), Vector2i(6, 3)), Color("342b27"))
		draw_rect(Rect2i(o + Vector2i(0, 22), Vector2i(16, 3)), Color("5b4030"))

func _draw_tree_patch(origin: Vector2i, cell: Vector2i) -> void:
	var tx := 2 + (cell.x * 3 + cell.y) % 7
	draw_rect(Rect2i(origin + Vector2i(tx + 3, 3), Vector2i(2, 9)), Color("3c342c"))
	draw_rect(Rect2i(origin + Vector2i(tx, 2), Vector2i(8, 10)), Color("315f3b"))
	draw_rect(Rect2i(origin + Vector2i(tx + 1, 0), Vector2i(6, 12)), Color("47764a"))
	draw_rect(Rect2i(origin + Vector2i(tx + 2, 1), Vector2i(3, 8)), Color("59814e"))
	if cell.y in [0, 14] or cell.x in [0, 15]:
		draw_rect(Rect2i(origin + Vector2i(0, 14), Vector2i(16, 2)), Color("b79c73"))

func _draw_units() -> void:
	var visible_units: Array[Vector2i] = phase_display_units if phase_playback_active else units
	var visible_hp: Array[int] = phase_display_hp if phase_playback_active else unit_hp
	for index in visible_units.size():
		if index >= visible_hp.size() or visible_hp[index] <= 0:
			continue
		if _is_pending_enemy_stack_for_hp(index, visible_hp):
			continue
		var cell: Vector2i = visible_units[index]
		# The captured unit tile replaces its terrain cell: zero pixels show
		# the universal background, not the stone/brick texture underneath.
		draw_rect(Rect2i(cell * TILE_SIZE, Vector2i(TILE_SIZE, TILE_SIZE)), Color8(190, 190, 190))
		var pose: Texture2D = (ROM_PLAYER_MOUNTED_POSE if unit_type_ids[index] == 1 else ROM_PLAYER_INFANTRY_POSE) if index >= opponent_unit_count else (ROM_MOUNTED_POSE if unit_type_ids[index] == 1 else ROM_INFANTRY_POSE)
		var spent := not phase_playback_active and _is_player_unit(index) and acted_unit_slots.has(index)
		draw_texture(pose, Vector2(cell * TILE_SIZE), Color(0.65, 0.65, 0.65) if spent else Color.WHITE)
		if spent:
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i(11, 11), Vector2i(5, 5)), Color("171414"))
			draw_line(Vector2(cell * TILE_SIZE + Vector2i(11, 13)), Vector2(cell * TILE_SIZE + Vector2i(13, 15)), Color("c5cacf"), 1)
			draw_line(Vector2(cell * TILE_SIZE + Vector2i(13, 15)), Vector2(cell * TILE_SIZE + Vector2i(15, 11)), Color("c5cacf"), 1)
		if index < opponent_unit_count and unit_type_ids[index] > 1:
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i(9, 0), Vector2i(7, 7)), Color("171414"))
			draw_string(ThemeDB.fallback_font, Vector2(cell * TILE_SIZE + Vector2i(9, 6)), str(unit_type_ids[index]), HORIZONTAL_ALIGNMENT_LEFT, 7, 6, Color("ffe65c"))
		if index >= opponent_unit_count + player_unit_count:
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i.ONE, Vector2i(14, 14)), Color("7aff8c"), false, 1.0)
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i(9, 0), Vector2i(7, 7)), Color("171414"))
			draw_string(ThemeDB.fallback_font, Vector2(cell * TILE_SIZE + Vector2i(9, 6)), str(unit_type_ids[index]), HORIZONTAL_ALIGNMENT_LEFT, 7, 6, Color("9dffab"))
		if index == selected_unit_index:
			var origin := cell * TILE_SIZE
			draw_rect(Rect2i(origin + Vector2i(1, 1), Vector2i(14, 14)), Color("65edff"), false, 1.0)

	if phase_playback_active:
		if phase_actor >= 0:
			draw_rect(Rect2i(visible_units[phase_actor] * TILE_SIZE, Vector2i(16, 16)), Color("ffe65c"), false, 1.0)
		for index in phase_hp_changes:
			var change := int(phase_hp_changes[index])
			var cell: Vector2i = visible_units[index]
			draw_rect(Rect2i(cell * TILE_SIZE + Vector2i(0, -9), Vector2i(28, 9)), Color("171414"))
			draw_string(ThemeDB.fallback_font, Vector2(cell * TILE_SIZE + Vector2i(0, -1)), "%+d" % change, HORIZONTAL_ALIGNMENT_LEFT, 28, 8, Color("9dffab") if change > 0 else Color("ff8777"))

func _unit_at_cursor() -> int:
	return _unit_at_cell(cursor)

func _draw_unit(cell: Vector2i, body: Color, trim: Color) -> void:
	var o := cell * TILE_SIZE
	# Small 8x14 figure approximating the live sprite silhouette and palette.
	draw_rect(Rect2i(o + Vector2i(5, 1), Vector2i(6, 4)), trim)
	draw_rect(Rect2i(o + Vector2i(4, 2), Vector2i(2, 2)), body)
	draw_rect(Rect2i(o + Vector2i(10, 2), Vector2i(2, 2)), body)
	draw_rect(Rect2i(o + Vector2i(5, 5), Vector2i(6, 3)), Color("27242a"))
	draw_rect(Rect2i(o + Vector2i(4, 8), Vector2i(8, 4)), body)
	draw_rect(Rect2i(o + Vector2i(3, 9), Vector2i(2, 3)), trim)
	draw_rect(Rect2i(o + Vector2i(10, 9), Vector2i(3, 3)), trim)
	draw_rect(Rect2i(o + Vector2i(4, 12), Vector2i(3, 2)), Color("29252a"))
	draw_rect(Rect2i(o + Vector2i(9, 12), Vector2i(3, 2)), Color("29252a"))

func _draw_cursor() -> void:
	var color := Color("ffe653") if action_mode == "select" else Color("65edff")
	var o := cursor * TILE_SIZE
	draw_rect(Rect2i(o + Vector2i(1, 1), Vector2i(14, 1)), color)
	draw_rect(Rect2i(o + Vector2i(1, 14), Vector2i(14, 1)), color)
	draw_rect(Rect2i(o + Vector2i(1, 1), Vector2i(1, 14)), color)
	draw_rect(Rect2i(o + Vector2i(14, 1), Vector2i(1, 14)), color)

func _draw_command_menu() -> void:
	var menu := Rect2i(177, 114, 61, 91)
	draw_rect(menu, Color("171414"))
	draw_rect(menu, Color("f2eee2"), false, 2.0)
	for i in range(COMMANDS.size()):
		var y := 137 + i * 17
		if i == command_index:
			draw_string(ThemeDB.fallback_font, Vector2(179, y), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("ffe65c"))
		draw_string(ThemeDB.fallback_font, Vector2(190, y), COMMANDS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_system_menu() -> void:
	var menu := Rect2i(31, 38, 194, 164)
	draw_rect(menu, Color("171414"))
	draw_rect(menu, Color("f2eee2"), false, 2.0)
	for i in range(SYSTEM_COMMANDS.size()):
		var y := 64 + i * 21
		if i == system_menu_index:
			draw_string(ThemeDB.fallback_font, Vector2(40, y), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("ffe65c"))
		draw_string(ThemeDB.fallback_font, Vector2(58, y), SYSTEM_COMMANDS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(44, 190), "演示回合%d  已行动%d/%d" % [turn_number, acted_unit_slots.size(), player_unit_count], HORIZONTAL_ALIGNMENT_LEFT, 174, 9, Color("a8dfff"))

func _draw_touch_controls() -> void:
	var button_rects := _touch_button_rects()
	if _side_controls_enabled():
		_draw_side_panels()
		_draw_pixel_pad(button_rects)
		_draw_pixel_button(button_rects["a"], "A", true, touch_pressed_button == "a")
		_draw_pixel_button(button_rects["b"], "B", false, touch_pressed_button == "b")
		_draw_pixel_button(button_rects["menu"], "菜单", false, touch_pressed_button == "menu")
		if button_rects.has("technique"):
			var packet := _selected_technique_packet()
			var label := "治疗 / 技术" if technique_effect_mode == "heal" else "攻击 / 技术"
			_draw_pixel_button(button_rects["technique"], label, false, touch_pressed_button == "technique")
		if button_rects.has("info"):
			_draw_pixel_button(button_rects["info"], "返回战场" if inspected_unit_index >= 0 else "单位详情", false, touch_pressed_button == "info")
		if button_rects.has("unit"):
			_draw_pixel_button(button_rects["unit"], "下一单位" if inspected_unit_index >= 0 else "待行动", false, touch_pressed_button == "unit")
		if button_rects.has("target"):
			_draw_pixel_button(button_rects["target"], "下一目标", false, touch_pressed_button == "target")
		return
	var labels := {"pad": "十" if not touch_pad_expanded else "×", "up": "▲", "left": "◀", "right": "▶", "down": "▼", "a": "A", "b": "B", "menu": "菜单", "technique": "技术", "target": "目标", "info": "返回" if inspected_unit_index >= 0 else "详情", "unit": "切换"}
	for name in button_rects:
		_draw_pixel_button(button_rects[name], labels[name], name == "a", touch_pressed_button == name)

func _draw_side_panels() -> void:
	var origin := _game_origin_x()
	var width := get_viewport_rect().size.x
	var panel := Color("263032")
	var trim := Color("b18a59")
	draw_rect(Rect2(0, 0, origin, 240), panel)
	draw_rect(Rect2(origin + 256, 0, width - origin - 256, 240), panel)
	for edge_x in [origin - 5.0, origin + 258.0]:
		draw_rect(Rect2(edge_x, 0, 3, 240), trim)
		draw_rect(Rect2(edge_x + 1, 0, 1, 240), Color("ead2a3"))
	for y in [17.0, 222.0]:
		draw_rect(Rect2(10, y, origin - 20, 2), Color("435153"))
		draw_rect(Rect2(origin + 266, y, origin - 20, 2), Color("435153"))
	for x in [14.0, origin - 16.0, origin + 270.0, width - 16.0]:
		for y in [24.0, 214.0]:
			draw_rect(Rect2(x, y, 3, 3), trim)

func _draw_pixel_pad(buttons: Dictionary) -> void:
	var up: Rect2 = buttons["up"]
	var left: Rect2 = buttons["left"]
	var right: Rect2 = buttons["right"]
	var down: Rect2 = buttons["down"]
	var center_x := up.get_center().x
	var vertical := Rect2(center_x - 22, up.position.y - 3, 44, down.end.y - up.position.y + 6)
	var horizontal := Rect2(left.position.x - 3, left.position.y - 2, right.end.x - left.position.x + 6, 44)
	for shape in [vertical, horizontal]:
		draw_rect(Rect2(shape.position + Vector2(3, 4), shape.size), Color("111819"))
	for shape in [vertical, horizontal]:
		draw_rect(shape, Color("b18a59"))
	for shape in [vertical.grow(-3), horizontal.grow(-3)]:
		draw_rect(shape, Color("343d3d"))
	for name in ["up", "left", "right", "down"]:
		var rect: Rect2 = buttons[name]
		if touch_pressed_button == name:
			draw_rect(rect.grow(-3), Color("8c6843"))
		var center := rect.get_center()
		var points := PackedVector2Array()
		match name:
			"up": points = PackedVector2Array([center + Vector2(0, -8), center + Vector2(-7, 4), center + Vector2(7, 4)])
			"down": points = PackedVector2Array([center + Vector2(0, 8), center + Vector2(-7, -4), center + Vector2(7, -4)])
			"left": points = PackedVector2Array([center + Vector2(-8, 0), center + Vector2(4, -7), center + Vector2(4, 7)])
			"right": points = PackedVector2Array([center + Vector2(8, 0), center + Vector2(-4, -7), center + Vector2(-4, 7)])
		draw_colored_polygon(points, Color("ffe4ac") if touch_pressed_button == name else Color("e2d4b9"))
	draw_rect(Rect2(center_x - 6, 164, 12, 12), Color("202b2d"))
	draw_rect(Rect2(center_x - 6, 164, 12, 12), Color("8a7558"), false, 1)

func _button_shape(rect: Rect2, corner: float) -> PackedVector2Array:
	var end := rect.end
	return PackedVector2Array([
		Vector2(rect.position.x + corner, rect.position.y), Vector2(end.x - corner, rect.position.y),
		Vector2(end.x, rect.position.y + corner), Vector2(end.x, end.y - corner),
		Vector2(end.x - corner, end.y), Vector2(rect.position.x + corner, end.y),
		Vector2(rect.position.x, end.y - corner), Vector2(rect.position.x, rect.position.y + corner),
	])

func _draw_pixel_button(hitbox: Rect2, label: String, primary: bool, pressed: bool) -> void:
	var rect := hitbox.grow(-2)
	draw_colored_polygon(_button_shape(Rect2(rect.position + Vector2(2, 3), rect.size), 7), Color("111819"))
	draw_colored_polygon(_button_shape(rect, 7), Color("e7ad5f") if primary else Color("b18a59"))
	var face := rect.grow(-3)
	draw_colored_polygon(_button_shape(face, 5), Color("945b2e") if primary and pressed else Color("c58342") if primary else Color("3f4947") if pressed else Color("58615b"))
	var shine := Color("f7d99c") if primary else Color("a9b3aa")
	draw_rect(Rect2(face.position.x + 9, face.position.y + 3, face.size.x - 18, 2), shine)
	var text_y := face.position.y + face.size.y / 2.0 + (6.0 if label in ["A", "B"] else 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(face.position.x, text_y), label, HORIZONTAL_ALIGNMENT_CENTER, face.size.x, 17 if label in ["A", "B"] else 10, Color("fff2d0"))

func _tactical_controls_available() -> bool:
	return action_mode == "select" and not command_open and not system_menu_open and not technique_menu_open and not movement_inspector and promotion_unit < 0 and not demo_clear and not demo_defeat and not _cinematics_busy()

func _available_player_units() -> Array[int]:
	var result: Array[int] = []
	for index in range(opponent_unit_count, opponent_unit_count + player_unit_count):
		if unit_hp[index] > 0 and not acted_unit_slots.has(index): result.append(index)
	return result

func _cycle_available_player(direction: int) -> void:
	var candidates := _available_player_units()
	if candidates.is_empty():
		status_message = "本回合行动已完成"
		return
	var current := candidates.find(_unit_at_cursor())
	var chosen := candidates[posmod(current + direction, candidates.size())] if current >= 0 else candidates[0 if direction > 0 else candidates.size() - 1]
	cursor = units[chosen]
	selected_unit_index = -1
	_update_view_offset()
	status_message = "%s · 移%d · A指令 I详情" % [_unit_class_name(unit_type_ids[chosen]), _unit_movement_points(chosen)]

func _open_unit_details(index: int) -> void:
	if index < 0 or index >= units.size() or unit_hp[index] <= 0:
		status_message = "先将光标移到单位上"
		return
	inspected_unit_index = index
	selected_unit_index = -1
	cursor = units[index]
	_update_view_offset()
	queue_redraw()

func _handle_unit_details_key(key: Key) -> void:
	if key in [KEY_I, KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE]:
		inspected_unit_index = -1
		status_message = "A指令 · C待行动 · I详情"
	elif key in [KEY_UP, KEY_LEFT, KEY_V, KEY_DOWN, KEY_RIGHT, KEY_C]:
		var candidates: Array[int] = []
		for index in units.size():
			if unit_hp[index] > 0 and not _is_pending_enemy_stack(index): candidates.append(index)
		if not candidates.is_empty():
			var direction := -1 if key in [KEY_UP, KEY_LEFT, KEY_V] else 1
			inspected_unit_index = candidates[posmod(candidates.find(inspected_unit_index) + direction, candidates.size())]
			cursor = units[inspected_unit_index]
			_update_view_offset()
	queue_redraw()

func _unit_details(index: int) -> Dictionary:
	var type_id := unit_type_ids[index]
	var record: Dictionary = rom_unit_records.get(type_id, {})
	var raw: Array = record.get("raw_bytes", [])
	var growth: Dictionary = DemoSave.campaign_progress.records.get(type_id, {})
	return {"class": _unit_class_name(type_id), "type": type_id,
		"side": "己方" if _is_player_unit(index) else ("敌军" if index < opponent_unit_count else "友军"),
		"state": ("已行动" if acted_unit_slots.has(index) else "待行动") if _is_player_unit(index) else "自动行动",
		"hp": unit_hp[index], "max_hp": _unit_max_hp(index), "movement": _unit_movement_points(index),
		"attack": int(raw[2]) + int(raw[3]) * 256 if raw.size() >= 4 else 0,
		"defense": int(raw[6]) if raw.size() > 6 else 0,
		"skill": int(raw[8]) if raw.size() > 8 else 0,
		"experience": unit_experience[index], "threshold": int(growth.get("next_experience_threshold", 65535)),
		"can_grow": not growth.get("promotion_choices", []).is_empty()}

func _draw_unit_details() -> void:
	var info := _unit_details(inspected_unit_index)
	var side_color := Color("89b7ff") if bool(_is_player_unit(inspected_unit_index)) else (Color("ff8777") if inspected_unit_index < opponent_unit_count else Color("9dffab"))
	draw_rect(Rect2(18, 31, 220, 177), Color("171e21"))
	draw_rect(Rect2(18, 31, 220, 177), Color("e2c48f"), false, 2)
	draw_string(ThemeDB.fallback_font, Vector2(28, 48), "%s · %s  %s" % [info.side, info["class"], info.state], HORIZONTAL_ALIGNMENT_LEFT, 200, 11, side_color)
	draw_string(ThemeDB.fallback_font, Vector2(28, 66), "HP %d / %d" % [info.hp, info.max_hp], HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color.WHITE)
	draw_rect(Rect2(28, 71, 198, 4), Color("3b4349"))
	draw_rect(Rect2(28, 71, 198.0 * float(info.hp) / maxi(1, int(info.max_hp)), 4), side_color)
	draw_string(ThemeDB.fallback_font, Vector2(28, 91), "攻击%d  防御%d  移动%d格" % [info.attack, info.defense, info.movement], HORIZONTAL_ALIGNMENT_LEFT, 200, 10, Color.WHITE)
	if _is_player_unit(inspected_unit_index):
		var growth := "EXP %d / %d" % [info.experience, info.threshold] if bool(info.can_grow) else "EXP %d · 已达最终兵种" % info.experience
		draw_string(ThemeDB.fallback_font, Vector2(28, 108), growth, HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("ffe65c"))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(28, 108), "位置 (%d,%d)" % [cursor.x, cursor.y], HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("d7d1bf"))
	var skill: Dictionary = rom_technique_effects.get(int(info.skill), {})
	var variants: Array = skill.get("variants", [])
	var count := 1 if int(info.skill) <= 18 or int(info.skill) == 34 else (2 if int(info.skill) <= 23 else (3 if int(info.skill) <= 29 else 4))
	if int(info.skill) == 0 or variants.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(28, 130), "技术：无", HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("c5cacf"))
	else:
		for variant in mini(count, variants.size()):
			var packet: Dictionary = variants[variant].duplicate()
			var healing := int(info.skill) in range(19, 34) and variant == 0
			if healing and inspected_unit_index < opponent_unit_count:
				packet.merge(rom_enemy_healing_targeting.get(int(info.type), {}), true)
			var magnitude := int(packet.get("effect_magnitude", 0))
			var area := int(packet.get("area_code", 0))
			var label := "特殊技术 · 暂不可用"
			if magnitude > 0 and area in [1, 5, 9] and (healing or variant <= 2):
				label = "%s%d · %s · 距%d格" % ["治疗" if healing else "伤害", magnitude, "单体" if area == 1 else ("十字" if area == 5 else "九宫"), int(packet.get("maximum_range_cells", 0))]
			draw_string(ThemeDB.fallback_font, Vector2(28, 130 + variant * 14), label, HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("a5edb8") if healing else Color("ffe0a3"))
	draw_string(ThemeDB.fallback_font, Vector2(28, 200), "方向键切换单位 · A/B返回", HORIZONTAL_ALIGNMENT_LEFT, 200, 9, Color("d7d1bf"))

func _draw_round_status() -> void:
	var living := _living_players()
	var available := _available_player_units().size()
	draw_rect(Rect2(0, 0, 256, 14), Color(0.08, 0.10, 0.11, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(4, 11), "第%d关 回合%d 待行动%d/%d 敌军%d" % [stage_index + 1, turn_number, available, living, _living_opponents()], HORIZONTAL_ALIGNMENT_LEFT, 248, 9, Color("d7d1bf"))

func _attack_preview() -> Dictionary:
	if not _attack_rejection(cursor).is_empty(): return {}
	var target := _unit_at_cursor()
	var damage := _rom_basic_damage(unit_type_ids[selected_unit_index], unit_type_ids[target])
	var actual := mini(damage, unit_hp[target])
	return {"target": target, "damage": damage, "actual": actual, "remaining": unit_hp[target] - actual}

func _attack_target_prompt() -> String:
	var preview := _attack_preview()
	if preview.is_empty(): return "选择相邻敌军 · C切换 B取消"
	return "预计伤害%d · 剩余HP%d · A攻击" % [preview.actual, preview.remaining]

func _draw_attack_preview() -> void:
	var preview := _attack_preview()
	if preview.is_empty(): return
	draw_rect(Rect2(5, 19, 246, 35), Color(0.08, 0.10, 0.11, 0.94))
	draw_string(ThemeDB.fallback_font, Vector2(12, 33), "攻击 %s · HP%d/%d" % [_unit_class_name(unit_type_ids[preview.target]), unit_hp[preview.target], _unit_max_hp(preview.target)], HORIZONTAL_ALIGNMENT_LEFT, 232, 10, Color("ffad9d"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 47), "预计 -%d HP → %d%s" % [preview.actual, preview.remaining, " · 击败" if int(preview.remaining) == 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, 232, 10, Color("ffe65c"))
