extends Node2D

## Stage 5 (ROM index 4): a connected deployment slice for movement and attack.

const STAGE_INDEX := 4
const TILE := 16
const SCREEN := Vector2i(16, 15)
const TOP_SCROLL_THRESHOLD := 6
const BOTTOM_SCROLL_THRESHOLD := 12
const LAYOUTS_PATH := "res://data/rom_stage_unit_layouts.json"
const MAPS_PATH := "res://data/rom_battle_stage_records.json"
const RULES_PATH := "res://data/rom_stage_movement_rules.json"
const TYPES_PATH := "res://data/rom_unit_slot_records.json"
const BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_04_color.png")
const INFANTRY := preload("res://assets/rom_reference/rom_stage00_infantry_pose.png")
const MOUNTED := preload("res://assets/rom_reference/rom_stage00_mounted_pose.png")
const PLAYER_INFANTRY := preload("res://assets/rom_reference/rom_stage00_infantry_player_pose.png")
const PLAYER_MOUNTED := preload("res://assets/rom_reference/rom_stage00_mounted_player_pose.png")
const COMMANDS := ["移动", "攻击", "休息"]

var map_grid: Array = []
var passable_codes: Array = []
var definitions: Dictionary = {}
var units: Array[Dictionary] = []
var cursor := Vector2i.ZERO
var view_offset_y := 0
var max_scroll_y := 0
var world_height := SCREEN.y
var selected_index := -1
var menu_open := false
var menu_index := 0
var action_mode := "select"
var status_message := ""
var touch_enabled := false
var axis_state := {}


func _ready() -> void:
	DisplayServer.window_set_title("爆笑三国 · ROM第五战攻防切片")
	touch_enabled = DisplayServer.is_touchscreen_available()
	if not _load_rom_data():
		return
	cursor = units[3]["cell"] if units.size() > 3 else units[0]["cell"]
	view_offset_y = clampi(cursor.y - BOTTOM_SCROLL_THRESHOLD, 0, max_scroll_y)
	status_message = "A选择己方单位 · 移动后可再选攻击 · F8返回"
	queue_redraw()


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing ROM data: " + path)
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}


func _load_rom_data() -> bool:
	var maps := _read_json(MAPS_PATH)
	var layouts := _read_json(LAYOUTS_PATH)
	var rules := _read_json(RULES_PATH)
	var types := _read_json(TYPES_PATH)
	if maps.is_empty() or layouts.is_empty() or rules.is_empty() or types.is_empty():
		return false
	var stage: Dictionary = maps["records"][STAGE_INDEX]
	var layout: Dictionary = layouts["records"][STAGE_INDEX]
	map_grid = stage["map_source_world_16x15_pages"]
	world_height = int(stage["map_world_dimensions"][1])
	max_scroll_y = int(stage["vertical_scroll_limit_cells"])
	passable_codes = rules["stages"][STAGE_INDEX]["passable_map_codes"]
	for row in types["records"]:
		if row is Dictionary and row.get("movement_allowance_points") != null:
			definitions[int(row["unit_id"])] = row
	for entry in layout["player_deployments"]:
		_add_unit(entry, true, false)
	for entry in layout["unit_group_1"]:
		_add_unit(entry, false, true)
	for entry in layout["unit_group_2"]:
		_add_unit(entry, false, false)
	if units.is_empty():
		push_error("ROM stage has no player deployments")
		return false
	return true


func _add_unit(entry: Dictionary, is_player: bool, is_ally: bool) -> void:
	var type_id := int(entry.get("unit_type_id", -1))
	var definition: Dictionary = definitions.get(type_id, {})
	var raw: Array = definition.get("raw_bytes", [])
	if raw.size() < 8:
		push_warning("Missing ROM unit type %d" % type_id)
		return
	var hp := int(raw[0]) + (int(raw[1]) << 8)
	units.append({
		"cell": Vector2i(int(entry["position_x"]), int(entry["position_y"])),
		"type_id": type_id,
		"player": is_player,
		"ally": is_ally,
		"hp": hp,
		"max_hp": hp,
		"movement": int(raw[7]),
	})


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and touch_enabled:
		_handle_touch(event.position)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not touch_enabled:
		_handle_touch(event.position)
		return
	if event is InputEventJoypadMotion:
		var direction := 0
		if absf(event.axis_value) > 0.7:
			direction = 1 if event.axis_value > 0.0 else -1
		var previous: int = axis_state.get(event.axis, 0)
		axis_state[event.axis] = direction
		if direction != 0 and direction != previous:
			if event.axis == JOY_AXIS_LEFT_X:
				_handle_key(KEY_RIGHT if direction > 0 else KEY_LEFT)
			elif event.axis == JOY_AXIS_LEFT_Y:
				_handle_key(KEY_DOWN if direction > 0 else KEY_UP)
		return
	if event is InputEventJoypadButton and event.pressed:
		var mapping := {
			JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
			JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
			JOY_BUTTON_A: KEY_A, JOY_BUTTON_B: KEY_B, JOY_BUTTON_BACK: KEY_F8,
		}
		if mapping.has(event.button_index):
			_handle_key(mapping[event.button_index])


func _handle_touch(position: Vector2) -> void:
	if Rect2(195, 0, 61, 18).has_point(position):
		_handle_key(KEY_F8)
	elif menu_open and Rect2(178, 126, 60, 76).has_point(position):
		menu_index = clampi(floori((position.y - 129.0) / 20.0), 0, COMMANDS.size() - 1)
		_choose_command()
		queue_redraw()
	elif position.distance_to(Vector2(214, 194)) <= 16.0:
		_handle_key(KEY_A)
	elif position.distance_to(Vector2(183, 216)) <= 14.0:
		_handle_key(KEY_B)
	elif Rect2(18, 158, 50, 70).has_point(position):
		_handle_key(KEY_UP if position.y < 182 else KEY_DOWN)
	elif Rect2(0, 178, 68, 34).has_point(position):
		_handle_key(KEY_LEFT if position.x < 21 else KEY_RIGHT)
	else:
		cursor = Vector2i(
			clampi(floori(position.x / TILE), 0, SCREEN.x - 1),
			clampi(view_offset_y + floori(position.y / TILE), 0, world_height - 1)
		)
		_update_scroll()
		queue_redraw()


func _handle_key(key: Key) -> void:
	if key == KEY_F8:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
		return
	if key in [KEY_B, KEY_ESCAPE, KEY_X, KEY_BACKSPACE]:
		selected_index = -1
		menu_open = false
		action_mode = "select"
		status_message = "已取消"
		queue_redraw()
		return
	if menu_open:
		if key == KEY_UP:
			menu_index = posmod(menu_index - 1, COMMANDS.size())
		elif key == KEY_DOWN:
			menu_index = posmod(menu_index + 1, COMMANDS.size())
		elif key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER]:
			_choose_command()
		else:
			return
		queue_redraw()
		return
	if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var step := Vector2i.ZERO
		match key:
			KEY_UP: step.y = -1
			KEY_DOWN: step.y = 1
			KEY_LEFT: step.x = -1
			KEY_RIGHT: step.x = 1
		cursor = Vector2i(
			clampi(cursor.x + step.x, 0, SCREEN.x - 1),
			clampi(cursor.y + step.y, 0, world_height - 1)
		)
		_update_scroll()
	elif key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER]:
		match action_mode:
			"select": _select_unit()
			"move": _commit_move()
			"attack": _commit_attack()
	else:
		return
	queue_redraw()


func _update_scroll() -> void:
	var screen_y := cursor.y - view_offset_y
	if screen_y < TOP_SCROLL_THRESHOLD:
		view_offset_y = maxi(0, cursor.y - TOP_SCROLL_THRESHOLD)
	elif screen_y > BOTTOM_SCROLL_THRESHOLD:
		view_offset_y = mini(max_scroll_y, cursor.y - BOTTOM_SCROLL_THRESHOLD)


func _unit_at(cell: Vector2i) -> int:
	for index in units.size():
		if int(units[index]["hp"]) > 0 and units[index]["cell"] == cell:
			return index
	return -1


func _select_unit() -> void:
	selected_index = _unit_at(cursor)
	if selected_index < 0 or not bool(units[selected_index]["player"]):
		selected_index = -1
		status_message = "请选择蓝色己方单位"
		return
	menu_open = true
	menu_index = 0
	status_message = "类型%d HP%d/%d 移动%d" % [
		units[selected_index]["type_id"], units[selected_index]["hp"],
		units[selected_index]["max_hp"], units[selected_index]["movement"]
	]


func _choose_command() -> void:
	menu_open = false
	match menu_index:
		0:
			action_mode = "move"
			status_message = "移动%d格 · 绿色可走 红色阻挡 · A确认" % int(units[selected_index]["movement"])
		1:
			action_mode = "attack"
			status_message = "选择相邻红色敌方单位，A确认"
		2:
			selected_index = -1
			status_message = "该单位休息"


func _terrain_passable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= SCREEN.x or cell.y < 0 or cell.y >= map_grid.size():
		return false
	for code in passable_codes:
		if int(code) == int(map_grid[cell.y][cell.x]):
			return true
	return false


func _move_error(cell: Vector2i) -> String:
	if selected_index < 0:
		return "没有选中己方单位"
	var origin: Vector2i = units[selected_index]["cell"]
	if absi(origin.x - cell.x) + absi(origin.y - cell.y) > int(units[selected_index]["movement"]):
		return "超出该兵种的移动范围"
	if not _terrain_passable(cell):
		return "ROM地形不能通行"
	var occupant := _unit_at(cell)
	if occupant >= 0 and occupant != selected_index:
		return "该格已有单位"
	return ""


func _commit_move() -> void:
	var error := _move_error(cursor)
	if error != "":
		status_message = error
		return
	units[selected_index]["cell"] = cursor
	status_message = "已移动到 (%d,%d) · 选中己方单位后可攻击" % [cursor.x, cursor.y]
	selected_index = -1
	action_mode = "select"


func _attack_error(cell: Vector2i) -> String:
	if selected_index < 0:
		return "没有选中己方单位"
	var origin: Vector2i = units[selected_index]["cell"]
	if absi(origin.x - cell.x) + absi(origin.y - cell.y) != 1:
		return "普通攻击只允许上下左右相邻格"
	var target := _unit_at(cell)
	if target < 0 or bool(units[target]["player"]) or bool(units[target]["ally"]):
		return "该格没有红色敌方单位"
	return ""


func _basic_damage(attacker_type: int, target_type: int) -> int:
	var attack_raw: Array = definitions[attacker_type]["raw_bytes"]
	var target_raw: Array = definitions[target_type]["raw_bytes"]
	var attack := int(attack_raw[2]) + (int(attack_raw[3]) << 8)
	var defense := int(target_raw[6])
	var difference := attack - defense
	if difference < 0:
		return 16 if difference >= -16 else 8
	return int(difference / 2) + 20


func _commit_attack() -> void:
	var error := _attack_error(cursor)
	if error != "":
		status_message = error
		return
	var target := _unit_at(cursor)
	var damage := _basic_damage(int(units[selected_index]["type_id"]), int(units[target]["type_id"]))
	units[target]["hp"] = maxi(0, int(units[target]["hp"]) - damage)
	status_message = "伤害%d · 敌方HP%d%s" % [damage, units[target]["hp"], " · 击倒" if int(units[target]["hp"]) == 0 else ""]
	selected_index = -1
	action_mode = "select"


func _draw() -> void:
	draw_texture(BACKGROUND, Vector2(0, -view_offset_y * TILE))
	if action_mode == "move" and selected_index >= 0:
		_draw_move_range()
	elif action_mode == "attack" and selected_index >= 0:
		_draw_attack_range()
	for index in units.size():
		_draw_unit(index)
	var cursor_screen := Vector2i(cursor.x, cursor.y - view_offset_y) * TILE
	draw_rect(Rect2i(cursor_screen + Vector2i.ONE, Vector2i(14, 14)), Color("ffe862"), false, 1.0)
	_draw_hud()
	if menu_open:
		_draw_menu()
	if touch_enabled:
		_draw_touch_controls()


func _draw_move_range() -> void:
	var origin: Vector2i = units[selected_index]["cell"]
	var radius := int(units[selected_index]["movement"])
	for y in range(maxi(0, origin.y - radius), mini(world_height - 1, origin.y + radius) + 1):
		for x in range(maxi(0, origin.x - radius), mini(SCREEN.x - 1, origin.x + radius) + 1):
			var cell := Vector2i(x, y)
			if absi(x - origin.x) + absi(y - origin.y) > radius:
				continue
			var color := Color(0.1, 0.9, 0.35, 0.28) if _move_error(cell) == "" else Color(0.95, 0.1, 0.12, 0.30)
			draw_rect(Rect2i(Vector2i(x, y - view_offset_y) * TILE + Vector2i.ONE, Vector2i(14, 14)), color)


func _draw_attack_range() -> void:
	var origin: Vector2i = units[selected_index]["cell"]
	for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var cell: Vector2i = origin + step
		if _attack_error(cell) == "":
			draw_rect(Rect2i(Vector2i(cell.x, cell.y - view_offset_y) * TILE + Vector2i.ONE, Vector2i(14, 14)), Color("ff6555"), false, 2.0)


func _draw_unit(index: int) -> void:
	var unit: Dictionary = units[index]
	if int(unit["hp"]) <= 0:
		return
	var cell: Vector2i = unit["cell"]
	var screen_y := cell.y - view_offset_y
	if screen_y < 0 or screen_y >= SCREEN.y:
		return
	var origin := Vector2i(cell.x, screen_y) * TILE
	var type_id := int(unit["type_id"])
	# Only the first two battle silhouettes have been matched to a live screenshot.
	# Other types reuse ROM infantry pixels with an explicit ID badge until their
	# own battle-time CHR and OAM pairing can be captured.
	var is_friendly: bool = bool(unit["player"]) or bool(unit["ally"])
	var pose: Texture2D = (PLAYER_MOUNTED if is_friendly else MOUNTED) if type_id in [1, 2] else (PLAYER_INFANTRY if is_friendly else INFANTRY)
	draw_rect(Rect2i(origin, Vector2i(TILE, TILE)), Color8(190, 190, 190))
	draw_texture(pose, Vector2(origin))
	if type_id > 2:
		var label := str(type_id)
		var badge_width := 5 + 4 * label.length()
		draw_rect(Rect2i(origin + Vector2i(16 - badge_width, 8), Vector2i(badge_width, 8)), Color("17171b"))
		draw_string(ThemeDB.fallback_font, Vector2(origin + Vector2i(17 - badge_width, 14)), label, HORIZONTAL_ALIGNMENT_LEFT, badge_width - 1, 7, Color("ffe4a4"))
	var side_color := Color("68e982") if bool(unit["ally"]) else (Color("56d7ff") if bool(unit["player"]) else Color("ff665b"))
	draw_rect(Rect2i(origin + Vector2i(1, 1), Vector2i(3, 3)), side_color)
	if index == selected_index:
		draw_rect(Rect2i(origin + Vector2i.ONE, Vector2i(14, 14)), side_color, false, 1.0)


func _draw_hud() -> void:
	draw_rect(Rect2i(0, 0, 256, 18), Color(0.04, 0.04, 0.05, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(3, 12), "ROM第5战 · 世界Y %d–%d" % [view_offset_y, view_offset_y + 14], HORIZONTAL_ALIGNMENT_LEFT, 186, 8, Color.WHITE)
	draw_rect(Rect2i(195, 0, 61, 18), Color("382b2b"))
	draw_string(ThemeDB.fallback_font, Vector2(199, 12), "F8返回", HORIZONTAL_ALIGNMENT_LEFT, 55, 8, Color("fff0a8"))
	draw_rect(Rect2i(0, 225, 256, 15), Color(0.04, 0.04, 0.05, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(4, 236), status_message, HORIZONTAL_ALIGNMENT_LEFT, 248, 8, Color.WHITE)


func _draw_menu() -> void:
	draw_rect(Rect2i(178, 126, 60, 76), Color("1b191b"))
	draw_rect(Rect2i(178, 126, 60, 76), Color("f2e8d5"), false, 1.0)
	for index in COMMANDS.size():
		var color := Color("ffe862") if index == menu_index else Color.WHITE
		draw_string(ThemeDB.fallback_font, Vector2(184, 148 + index * 20), ("▶" if index == menu_index else " ") + COMMANDS[index], HORIZONTAL_ALIGNMENT_LEFT, 52, 9, color)


func _draw_touch_controls() -> void:
	var fill := Color(0.04, 0.04, 0.05, 0.75)
	for rect in [Rect2i(21, 164, 22, 62), Rect2i(1, 184, 62, 22)]:
		draw_rect(rect, fill)
		draw_rect(rect, Color.WHITE, false, 1.0)
	for center in [Vector2(214, 194), Vector2(183, 216)]:
		draw_circle(center, 14, fill)
		draw_arc(center, 14, 0, TAU, 24, Color.WHITE, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(210, 198), "A", HORIZONTAL_ALIGNMENT_LEFT, 12, 10, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(179, 219), "B", HORIZONTAL_ALIGNMENT_LEFT, 12, 9, Color.WHITE)
