extends Node2D

## Bank 10's later-stage selection list ($6807) and cap ($05EF), in demo form.

const VISIBLE_ROWS := 10
var stage_index := 10
var limit := 0
var roster: Array = []
var selected: Array[int] = []
var cursor := 0
var first_visible := 0
var message := "A选/取消 · Start出战"
var axis_direction := {}
var swipe_remainder := 0.0
var touch_start := Vector2.ZERO
var touch_moved := false

func _ready() -> void:
	DemoSave.campaign_progress.ensure_loaded()
	stage_index = clampi(DemoSave.prebattle_stage, 10, 18)
	limit = DemoSave.roster_limit(stage_index)
	var file := FileAccess.open("res://data/rom_campaign_roster_seed.json", FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			roster = parsed.get("entries", [])
	selected = DemoSave.selected_roster_for_stage(stage_index)
	DisplayServer.window_set_title("爆笑三国 · 第%d关选将" % (stage_index + 1))
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		var direction := 0
		if absf(event.axis_value) > 0.7:
			direction = 1 if event.axis_value > 0.0 else -1
		var previous: int = axis_direction.get(event.axis, 0)
		axis_direction[event.axis] = direction
		if direction != 0 and direction != previous and event.axis == JOY_AXIS_LEFT_Y:
			_handle_key(KEY_DOWN if direction > 0 else KEY_UP)
	elif event is InputEventJoypadButton and event.pressed:
		var keys := {JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN, JOY_BUTTON_A: KEY_A, JOY_BUTTON_B: KEY_B, JOY_BUTTON_START: KEY_ENTER}
		if keys.has(event.button_index):
			_handle_key(keys[event.button_index])
	elif event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			touch_start = event.position
			touch_moved = false
		elif not touch_moved:
			_handle_touch(event.position)
	elif event is InputEventScreenDrag and event.position.y >= 33.0 and event.position.y < 203.0:
		if event.position.distance_to(touch_start) >= 12.0:
			touch_moved = true
		swipe_remainder += event.relative.y
		if absf(swipe_remainder) >= 17.0:
			var rows := floori(absf(swipe_remainder) / 17.0)
			first_visible = clampi(first_visible + (-rows if swipe_remainder > 0.0 else rows), 0, maxi(0, roster.size() - VISIBLE_ROWS))
			swipe_remainder = 0.0
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and DisplayServer.is_touchscreen_available():
		_handle_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		first_visible = clampi(first_visible + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 0, maxi(0, roster.size() - VISIBLE_ROWS))
		queue_redraw()

func _handle_touch(position: Vector2) -> void:
	var origin := _game_origin_x()
	if origin >= 95.0:
		var left := origin / 2.0
		var right := (origin + 256.0 + get_viewport_rect().size.x) / 2.0
		if Rect2(left - 23, 120, 46, 38).has_point(position):
			_handle_key(KEY_UP)
			return
		if Rect2(left - 23, 171, 46, 38).has_point(position):
			_handle_key(KEY_DOWN)
			return
		if Rect2(right - 26, 92, 52, 37).has_point(position):
			_handle_key(KEY_ENTER)
			return
		if Rect2(right + 12, 149, 46, 46).has_point(position):
			_handle_key(KEY_A)
			return
		if Rect2(right - 51, 182, 46, 46).has_point(position):
			_handle_key(KEY_B)
			return
	position.x -= origin
	if position.x < 0.0 or position.x >= 256.0:
		return
	if position.y >= 33.0 and position.y < 203.0:
		var row := floori((position.y - 34.0) / 17.0)
		cursor = clampi(first_visible + row, 0, roster.size() - 1)
		_handle_key(KEY_A)
	elif position.y >= 208.0 and position.x >= 145.0:
		_handle_key(KEY_ENTER)
	elif position.y >= 208.0:
		_handle_key(KEY_B)

func _handle_key(key: Key) -> void:
	if roster.is_empty():
		return
	match key:
		KEY_UP:
			cursor = maxi(0, cursor - 1)
		KEY_DOWN:
			cursor = mini(roster.size() - 1, cursor + 1)
		KEY_A, KEY_Z, KEY_SPACE:
			if selected.has(cursor):
				selected.erase(cursor)
			elif selected.size() < limit:
				selected.append(cursor)
			else:
				message = "本关最多出战%d人" % limit
		KEY_ENTER, KEY_KP_ENTER:
			if not DemoSave.valid_roster_selection(stage_index, selected):
				message = "至少选择一人"
			else:
				DemoSave.roster_selection.assign(selected)
				get_tree().change_scene_to_file(DemoSave.scene_for_stage(stage_index))
				return
		KEY_B, KEY_ESCAPE, KEY_BACKSPACE:
			get_tree().change_scene_to_file(DemoSave.scene_for_stage(stage_index - 1))
			return
	first_visible = clampi(first_visible, cursor - VISIBLE_ROWS + 1, cursor)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("151d25"))
	var origin := _game_origin_x()
	draw_set_transform(Vector2(origin, 0))
	draw_rect(Rect2(5, 5, 246, 27), Color("354653"))
	draw_string(ThemeDB.fallback_font, Vector2(10, 23), "第%d关 选将 %d/%d" % [stage_index + 1, selected.size(), limit], HORIZONTAL_ALIGNMENT_LEFT, 238, 15, Color("fff0b3"))
	for row in VISIBLE_ROWS:
		var index := first_visible + row
		if index >= roster.size():
			break
		var y := 35 + row * 17
		var current := index == cursor
		var chosen := selected.has(index)
		draw_rect(Rect2(6, y, 244, 16), Color("425b67") if current else Color("202c36"))
		var slot := selected.find(index) + 1 if chosen else 0
		var type_id: int = DemoSave.campaign_progress.types[index]
		var move: int = int(DemoSave.campaign_progress.records.get(type_id, {}).get("movement_points", 0))
		var label := "%s %02d 类型%02d 移%d EXP%d" % ["%02d" % slot if chosen else "--", index, type_id, move, DemoSave.campaign_progress.experience[index]]
		draw_string(ThemeDB.fallback_font, Vector2(11, y + 12), label, HORIZONTAL_ALIGNMENT_LEFT, 231, 11, Color("adf5ff") if chosen else Color("d5d8d5"))
	draw_string(ThemeDB.fallback_font, Vector2(9, 218), "B返回" , HORIZONTAL_ALIGNMENT_LEFT, 90, 10, Color("ffa9a9"))
	draw_string(ThemeDB.fallback_font, Vector2(151, 218), "Start出战", HORIZONTAL_ALIGNMENT_LEFT, 96, 10, Color("baffaa"))
	draw_string(ThemeDB.fallback_font, Vector2(9, 234), message + " · 可滑动", HORIZONTAL_ALIGNMENT_LEFT, 240, 9, Color("fff0b3"))
	draw_set_transform(Vector2.ZERO)
	if DisplayServer.is_touchscreen_available() and origin >= 95.0:
		var left := origin / 2.0
		var right := (origin + 256.0 + get_viewport_rect().size.x) / 2.0
		_draw_touch_panels(origin)
		for item in [[Rect2(left - 23, 120, 46, 38), "▲", false], [Rect2(left - 23, 171, 46, 38), "▼", false], [Rect2(right - 26, 92, 52, 37), "出战", false], [Rect2(right + 12, 149, 46, 46), "A", true], [Rect2(right - 51, 182, 46, 46), "B", false]]:
			_draw_touch_button(item[0], item[1], item[2])

func _draw_touch_panels(origin: float) -> void:
	var width := get_viewport_rect().size.x
	draw_rect(Rect2(0, 0, origin, 240), Color("263032"))
	draw_rect(Rect2(origin + 256, 0, width - origin - 256, 240), Color("263032"))
	for edge_x in [origin - 5.0, origin + 258.0]:
		draw_rect(Rect2(edge_x, 0, 3, 240), Color("b18a59"))
		draw_rect(Rect2(edge_x + 1, 0, 1, 240), Color("ead2a3"))
	for y in [17.0, 222.0]:
		draw_rect(Rect2(10, y, origin - 20, 2), Color("435153"))
		draw_rect(Rect2(origin + 266, y, origin - 20, 2), Color("435153"))

func _touch_button_shape(rect: Rect2, corner: float) -> PackedVector2Array:
	var end := rect.end
	return PackedVector2Array([
		Vector2(rect.position.x + corner, rect.position.y), Vector2(end.x - corner, rect.position.y),
		Vector2(end.x, rect.position.y + corner), Vector2(end.x, end.y - corner),
		Vector2(end.x - corner, end.y), Vector2(rect.position.x + corner, end.y),
		Vector2(rect.position.x, end.y - corner), Vector2(rect.position.x, rect.position.y + corner),
	])

func _draw_touch_button(hitbox: Rect2, label: String, primary: bool) -> void:
	var rect := hitbox.grow(-2)
	draw_colored_polygon(_touch_button_shape(Rect2(rect.position + Vector2(2, 3), rect.size), 7), Color("111819"))
	draw_colored_polygon(_touch_button_shape(rect, 7), Color("e7ad5f") if primary else Color("b18a59"))
	var face := rect.grow(-3)
	draw_colored_polygon(_touch_button_shape(face, 5), Color("c58342") if primary else Color("58615b"))
	draw_rect(Rect2(face.position.x + 9, face.position.y + 3, face.size.x - 18, 2), Color("f7d99c") if primary else Color("a9b3aa"))
	draw_string(ThemeDB.fallback_font, Vector2(face.position.x, face.position.y + face.size.y / 2.0 + (6.0 if label in ["A", "B"] else 4.0)), label, HORIZONTAL_ALIGNMENT_CENTER, face.size.x, 17 if label in ["A", "B"] else 10, Color("fff2d0"))

func _game_origin_x() -> float:
	return floorf((get_viewport_rect().size.x - 256.0) / 2.0)
