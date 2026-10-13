extends Node2D

## Small playable movement demo using the decoded stage-6 deployment records.

const TILE := 16
const GRID := Vector2i(16, 15)
const SCROLL_ANCHOR_Y := 6
const SCREEN_LAST_MOVABLE_Y := 12
const STAGE_INDEX := 5
const LAYOUTS_PATH := "res://data/rom_stage_unit_layouts.json"
const MAPS_PATH := "res://data/rom_battle_stage_records.json"
const RULES_PATH := "res://data/rom_stage_movement_rules.json"
const UNITS_PATH := "res://data/rom_unit_slot_records.json"
const BACKGROUND := preload("res://assets/rom_reference/rom_battle_stage_candidate_05.png")
const PLAYER_INFANTRY := preload("res://assets/rom_reference/rom_stage00_infantry_player_pose.png")
const PLAYER_MOUNTED := preload("res://assets/rom_reference/rom_stage00_mounted_player_pose.png")
const ENEMY_INFANTRY := preload("res://assets/rom_reference/rom_stage00_infantry_pose.png")
const ENEMY_MOUNTED := preload("res://assets/rom_reference/rom_stage00_mounted_pose.png")

var units: Array[Dictionary] = []
var blockers: Array[Vector2i] = []
var blocker_type_ids: Array[int] = []
var passable_codes: Array = []
var map_grid: Array = []
var scroll_limit := 0
var movement_records: Dictionary = {}
var cursor := Vector2i.ZERO
var world_max_y := GRID.y - 1
var max_scroll_y := 0
var view_offset_y := 0
var selected_index := -1
var moving := false
var status_message := ""
var touch_enabled := false
var axis_state := {}


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	touch_enabled = DisplayServer.is_touchscreen_available()
	if not _load_rom_data():
		return
	cursor = units[0]["cell"]
	status_message = "第六关 部署移动演练  方向键选格 A选中/确认 B取消"
	queue_redraw()


func _load_rom_data() -> bool:
	var layouts: Dictionary = _read_json(LAYOUTS_PATH)
	var maps: Dictionary = _read_json(MAPS_PATH)
	var rules: Dictionary = _read_json(RULES_PATH)
	var unit_data: Dictionary = _read_json(UNITS_PATH)
	if layouts.is_empty() or maps.is_empty() or rules.is_empty() or unit_data.is_empty():
		push_error("Unable to load ROM stage movement data")
		return false
	var layout_rows: Array = layouts.get("records", [])
	var map_rows: Array = maps.get("records", [])
	var rule_rows: Array = rules.get("stages", [])
	if STAGE_INDEX >= layout_rows.size() or STAGE_INDEX >= map_rows.size() or STAGE_INDEX >= rule_rows.size():
		push_error("ROM data does not contain stage %d" % STAGE_INDEX)
		return false
	var layout: Dictionary = layout_rows[STAGE_INDEX]
	map_grid = map_rows[STAGE_INDEX].get("map_source_world_16x15_pages", [])
	scroll_limit = int(map_rows[STAGE_INDEX].get("vertical_scroll_limit_cells", 0))
	passable_codes = rule_rows[STAGE_INDEX].get("passable_map_codes", [])
	for row in unit_data.get("records", []):
		if row is Dictionary and row.get("movement_allowance_points") != null:
			movement_records[int(row["unit_id"])] = row

	for deployment in layout.get("player_deployments", []):
		var type_id := int(deployment.get("unit_type_id", -1))
		var stats: Dictionary = movement_records.get(type_id, {})
		var cell := Vector2i(int(deployment["position_x"]), int(deployment["position_y"]))
		units.append({
			"cell": cell,
			"screen_position": cell * TILE,
			"type_id": type_id,
			"movement": int(stats.get("movement_allowance_points", 0)),
		})
	for group_key in ["unit_group_1", "unit_group_2"]:
		for deployment in layout.get(group_key, []):
			blockers.append(Vector2i(
				int(deployment["position_x"]),
				int(deployment["position_y"])
			))
			blocker_type_ids.append(int(deployment.get("unit_type_id", 0)))
	if units.is_empty():
		push_error("Stage %d has no decoded player deployments" % STAGE_INDEX)
		return false
	for unit in units:
		world_max_y = maxi(world_max_y, int(unit["cell"].y))
	for cell in blockers:
		world_max_y = maxi(world_max_y, cell.y)
	max_scroll_y = scroll_limit
	world_max_y = maxi(world_max_y, max_scroll_y + GRID.y - 1)
	return true


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing ROM data: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)


func _unhandled_input(event: InputEvent) -> void:
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
		elif direction == 0:
			return
		return
	if event is InputEventJoypadButton and event.pressed:
		var button_to_key := {
			JOY_BUTTON_DPAD_UP: KEY_UP,
			JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
			JOY_BUTTON_DPAD_LEFT: KEY_LEFT,
		JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
		JOY_BUTTON_A: KEY_A,
		JOY_BUTTON_B: KEY_B,
		JOY_BUTTON_BACK: KEY_F7,
		}
		if button_to_key.has(event.button_index):
			_handle_key(button_to_key[event.button_index])
		return
	if event is InputEventScreenTouch and event.pressed and touch_enabled:
		_handle_touch(event.position)
	# Touchscreens may synthesize a mouse click for the same tap. Process the
	# native touch event above, but don't apply the synthesized click a second time.
	elif event is InputEventMouseButton and event.pressed and not touch_enabled:
		_handle_touch(event.position)


func _handle_touch(position: Vector2) -> void:
	if Rect2(195, 0, 61, 18).has_point(position):
		_handle_key(KEY_F7)
	elif position.distance_to(Vector2(214, 194)) <= 17.0:
		_handle_key(KEY_A)
	elif position.distance_to(Vector2(183, 216)) <= 14.0:
		_handle_key(KEY_B)
	elif Rect2(18, 158, 50, 70).has_point(position):
		_handle_key(KEY_UP if position.y < 182 else KEY_DOWN)
	elif Rect2(0, 178, 68, 34).has_point(position):
		_handle_key(KEY_LEFT if position.x < 21 else KEY_RIGHT)
	else:
		cursor = Vector2i(clampi(floori(position.x / TILE), 0, GRID.x - 1), clampi(view_offset_y + floori(position.y / TILE), 0, world_max_y))
		_update_view_offset()
		queue_redraw()


func _handle_key(key: Key) -> void:
	if key == KEY_F7:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
		return
	if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		var delta := Vector2i.ZERO
		match key:
			KEY_UP: delta.y = -1
			KEY_DOWN: delta.y = 1
			KEY_LEFT: delta.x = -1
			KEY_RIGHT: delta.x = 1
		cursor = Vector2i(clampi(cursor.x + delta.x, 0, GRID.x - 1), clampi(cursor.y + delta.y, 0, world_max_y))
		_update_view_offset()
	elif key in [KEY_A, KEY_Z, KEY_SPACE]:
		if moving:
			_commit_move()
		elif selected_index >= 0:
			moving = true
			status_message = "选择移动目的地：范围%d格；绿色可达，红色被阻挡" % int(units[selected_index]["movement"])
		else:
			selected_index = _unit_at(cursor)
			if selected_index < 0:
				status_message = "请将光标移到蓝色玩家单位上，再按 A"
			else:
				cursor = units[selected_index]["cell"]
				status_message = "已选类型%d，移动点数%d；再按 A 选择目的地" % [units[selected_index]["type_id"], units[selected_index]["movement"]]
	elif key in [KEY_B, KEY_ESCAPE, KEY_X]:
		selected_index = -1
		moving = false
		status_message = "已取消选择"
	else:
		return
	queue_redraw()


func _update_view_offset() -> void:
	# Keep the cursor in the visible vertical range while panning the ROM map.
	var screen_y := cursor.y - view_offset_y
	if screen_y < SCROLL_ANCHOR_Y:
		view_offset_y = maxi(0, cursor.y - SCROLL_ANCHOR_Y)
	elif screen_y > SCREEN_LAST_MOVABLE_Y:
		view_offset_y = mini(max_scroll_y, cursor.y - SCREEN_LAST_MOVABLE_Y)


func _unit_at(cell: Vector2i) -> int:
	for i in range(units.size()):
		if units[i]["cell"] == cell:
			return i
	return -1


func _inside_movement_range(cell: Vector2i) -> bool:
	if selected_index < 0:
		return false
	var origin_pixels: Vector2i = units[selected_index]["screen_position"]
	var destination_pixels := cell * TILE
	# The ROM subtracts pixel coordinates first, then shifts each absolute axis
	# delta right by four.
	var distance := absi(destination_pixels.x - origin_pixels.x) >> 4
	var distance_y := absi(destination_pixels.y - origin_pixels.y) >> 4
	return distance + distance_y <= int(units[selected_index]["movement"])


func _is_passable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= map_grid[0].size() or cell.y < 0 or cell.y >= map_grid.size():
		return false
	var row: Array = map_grid[cell.y]
	if cell.x >= row.size():
		return false
	for code in passable_codes:
		if int(code) == int(row[cell.x]):
			return true
	return false


func _is_blocked(cell: Vector2i) -> bool:
	if blockers.has(cell):
		return true
	for i in range(units.size()):
		if i != selected_index and units[i]["cell"] == cell:
			return true
	return false


func _commit_move() -> void:
	if not _inside_movement_range(cursor):
		status_message = "超出该单位的 %d 格移动范围" % int(units[selected_index]["movement"])
	elif not _is_passable(cursor):
		status_message = "ROM 地形不允许通过"
	elif _is_blocked(cursor):
		status_message = "该格已被单位占据"
	else:
		units[selected_index]["cell"] = cursor
		units[selected_index]["screen_position"] = cursor * TILE
		status_message = "类型%d已移动至 (%d,%d)" % [units[selected_index]["type_id"], cursor.x, cursor.y]
		selected_index = -1
		moving = false
	queue_redraw()


func _draw() -> void:
	draw_texture(BACKGROUND, Vector2(0, -view_offset_y * TILE))
	if moving:
		for screen_y in range(GRID.y):
			for screen_x in range(GRID.x):
				var cell := Vector2i(screen_x, view_offset_y + screen_y)
				if _inside_movement_range(cell):
					var ok := _is_passable(cell) and not _is_blocked(cell)
					var tint := Color(0.08, 0.9, 0.3, 0.34) if ok else Color(0.95, 0.1, 0.12, 0.38)
					draw_rect(Rect2i(Vector2i(screen_x, screen_y) * TILE + Vector2i(1, 1), Vector2i(14, 14)), tint)
	for index in blockers.size():
		var cell: Vector2i = blockers[index]
		var screen_cell := Vector2i(cell.x, cell.y - view_offset_y)
		if screen_cell.x < 0 or screen_cell.x >= GRID.x or screen_cell.y < 0 or screen_cell.y >= GRID.y:
			continue
		_draw_rom_unit(screen_cell * TILE, blocker_type_ids[index], false)
	for i in range(units.size()):
		var unit: Dictionary = units[i]
		var origin := Vector2i(int(unit["cell"].x) * TILE, int(unit["screen_position"].y) - view_offset_y * TILE)
		if origin.y < -TILE or origin.y >= GRID.y * TILE:
			continue
		_draw_rom_unit(origin, int(unit["type_id"]), true)
		if i == selected_index:
			draw_rect(Rect2i(origin + Vector2i(1, 1), Vector2i(14, 14)), Color("fff0a8"), false, 1.0)
	var cursor_origin := Vector2i(cursor.x, cursor.y - view_offset_y) * TILE
	draw_rect(Rect2i(cursor_origin + Vector2i(1, 1), Vector2i(14, 14)), Color("fff0a8"), false, 1.0)
	draw_rect(Rect2i(2, 2, 252, 24), Color(0.02, 0.02, 0.03, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(5, 11), "第六关 ROM部署演练 · 蓝玩家 红敌军 · A选中/移动 B取消", HORIZONTAL_ALIGNMENT_LEFT, 185, 8, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(5, 21), "方向键移动 · 位置/地形通行规则读取ROM数据", HORIZONTAL_ALIGNMENT_LEFT, 185, 8, Color("ffe3a1"))
	draw_rect(Rect2i(195, 2, 59, 22), Color(0.04, 0.04, 0.05, 0.82))
	draw_string(ThemeDB.fallback_font, Vector2(199, 11), "F7返回", HORIZONTAL_ALIGNMENT_LEFT, 51, 8, Color("fff0a8"))
	var offscreen_enemies := 0
	for cell in blockers:
		if cell.y < view_offset_y or cell.y >= view_offset_y + GRID.y:
			offscreen_enemies += 1
	if offscreen_enemies > 0:
		# Indicate opposing units that are outside the current scrolling viewport.
		var below := blockers.any(func(cell: Vector2i) -> bool: return cell.y >= view_offset_y + GRID.y)
		var direction := PackedVector2Array([Vector2(238, 208), Vector2(248, 208), Vector2(243, 218)]) if below else PackedVector2Array([Vector2(238, 34), Vector2(248, 34), Vector2(243, 24)])
		draw_colored_polygon(direction, Color("e85c50"))
	draw_string(ThemeDB.fallback_font, Vector2(15, 34), "视窗世界Y %d–%d · 敌方未显示 %d队" % [view_offset_y, view_offset_y + GRID.y - 1, offscreen_enemies], HORIZONTAL_ALIGNMENT_LEFT, 236, 8, Color("ffd0b4"))
	draw_rect(Rect2i(0, 225, 256, 15), Color(0.04, 0.04, 0.05, 0.86))
	draw_string(ThemeDB.fallback_font, Vector2(4, 236), status_message, HORIZONTAL_ALIGNMENT_LEFT, 248, 8, Color.WHITE)
	if touch_enabled:
		_draw_touch_controls()


func _draw_rom_unit(origin: Vector2i, type_id: int, is_player: bool) -> void:
	var pose: Texture2D = (PLAYER_MOUNTED if is_player else ENEMY_MOUNTED) if type_id in [1, 2] else (PLAYER_INFANTRY if is_player else ENEMY_INFANTRY)
	draw_rect(Rect2i(origin, Vector2i(TILE, TILE)), Color8(190, 190, 190))
	draw_texture(pose, Vector2(origin))
	if type_id > 2:
		var label := str(type_id)
		var badge_width := 5 + 4 * label.length()
		draw_rect(Rect2i(origin + Vector2i(TILE - badge_width, 8), Vector2i(badge_width, 8)), Color("17171b"))
		draw_string(ThemeDB.fallback_font, Vector2(origin + Vector2i(TILE + 1 - badge_width, 14)), label, HORIZONTAL_ALIGNMENT_LEFT, badge_width - 1, 7, Color("ffe4a4"))


func _draw_touch_controls() -> void:
	var fill := Color(0.04, 0.04, 0.05, 0.68)
	var edge := Color(0.92, 0.88, 0.77, 0.82)
	for rect in [Rect2i(21, 164, 22, 62), Rect2i(1, 184, 62, 22)]:
		draw_rect(rect, fill)
		draw_rect(rect, edge, false, 1.0)
	draw_circle(Vector2(214, 194), 15.0, fill)
	draw_arc(Vector2(214, 194), 15.0, 0.0, TAU, 24, edge, 1.0)
	draw_circle(Vector2(183, 216), 13.0, fill)
	draw_arc(Vector2(183, 216), 13.0, 0.0, TAU, 24, edge, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(210, 197), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(179, 219), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
