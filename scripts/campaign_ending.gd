extends Node2D

## Completion summary shown after the original victory celebration.

const ROWS_PER_PAGE := 10
const PANEL_WIDTH := 256
var page := 0
var action_index := 0
var notice := ""
var class_names := {}
var campaign: Dictionary = {}
var touch_press_ms := -1000

func _ready() -> void:
	DisplayServer.window_set_title("爆笑三国 · 通关记录")
	if not DemoSave.valid_completion_snapshot(DemoSave.completed_run):
		DemoSave.return_to_title = true
		get_tree().change_scene_to_file.call_deferred("res://scenes/intro.tscn")
		return
	campaign = DemoSave.completed_run["campaign"].duplicate(true)
	var file := FileAccess.open("res://data/rom_class_reference.json", FileAccess.READ)
	if file != null:
		var value: Variant = JSON.parse_string(file.get_as_text())
		if value is Dictionary:
			for record in value.get("classes", []):
				for type_id in record.get("unit_type_ids", []):
					class_names[int(type_id)] = str(record.get("name", ""))
	GameAudio.play_music("title")
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		var keys := {
			JOY_BUTTON_DPAD_LEFT: KEY_LEFT, JOY_BUTTON_DPAD_RIGHT: KEY_RIGHT,
			JOY_BUTTON_DPAD_UP: KEY_UP, JOY_BUTTON_DPAD_DOWN: KEY_DOWN,
			JOY_BUTTON_A: KEY_A, JOY_BUTTON_START: KEY_A,
			JOY_BUTTON_B: KEY_B, JOY_BUTTON_BACK: KEY_B,
			JOY_BUTTON_Y: KEY_R,
		}
		if keys.has(event.button_index):
			_handle_key(keys[event.button_index])
	elif event is InputEventScreenTouch and event.pressed:
		touch_press_ms = Time.get_ticks_msec()
		_handle_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() - touch_press_ms > 180:
		_handle_touch(event.position)

func _handle_key(key: Key) -> void:
	match key:
		KEY_LEFT, KEY_Q:
			page = posmod(page - 1, 2)
			GameAudio.play_effect("cursor")
		KEY_RIGHT, KEY_E:
			page = posmod(page + 1, 2)
			GameAudio.play_effect("cursor")
		KEY_UP, KEY_DOWN:
			action_index = 1 - action_index
			GameAudio.play_effect("cursor")
		KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_activate()
		KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE:
			_return_to_title()
		KEY_R:
			_replay_celebration()
	queue_redraw()

func _handle_touch(position: Vector2) -> void:
	var x := position.x - _game_origin_x()
	if x < 0.0 or x >= PANEL_WIDTH:
		return
	if position.y >= 175.0 and position.y < 191.0:
		_replay_celebration()
	elif position.y >= 191.0:
		action_index = 0 if position.y < 214.0 else 1
		_activate()
	elif position.y >= 37.0 and position.y <= 59.0:
		_handle_key(KEY_LEFT if x < 128.0 else KEY_RIGHT)
	queue_redraw()

func _activate() -> void:
	GameAudio.play_effect("confirm")
	if action_index == 0:
		_return_to_title()
		return
	if DemoSave.write_snapshot(DemoSave.completed_run):
		notice = "通关记录已保存"
	else:
		notice = DemoSave.last_error
	queue_redraw()

func _return_to_title() -> void:
	DemoSave.return_to_title = true
	get_tree().change_scene_to_file("res://scenes/intro.tscn")

func _replay_celebration() -> void:
	get_tree().change_scene_to_file("res://scenes/rom_ending.tscn")

func _game_origin_x() -> float:
	return floorf((get_viewport_rect().size.x - PANEL_WIDTH) / 2.0)

func _draw_text(value: String, x: float, y: float, width: float, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), value, align, width, size, color)

func _draw() -> void:
	if campaign.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("16252b"))
	draw_set_transform(Vector2(_game_origin_x(), 0))
	draw_rect(Rect2(4, 4, 248, 232), Color("1f3034"))
	draw_rect(Rect2(5, 5, 246, 230), Color("dac491"), false, 2)
	draw_rect(Rect2(9, 9, 238, 27), Color("593e34"))
	_draw_text("通 关 记 录", 12, 28, 232, 18, Color("ffe2a3"), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("十九关完成 · 己方部队", 9, 49, 238, 11, Color("d7eee9"), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("◀", 13, 63, 19, 12, Color("f4cf82"))
	_draw_text("%d / 2" % (page + 1), 104, 63, 48, 10, Color("f4cf82"), HORIZONTAL_ALIGNMENT_CENTER)
	_draw_text("▶", 225, 63, 19, 12, Color("f4cf82"))
	var types: Array = campaign["types"]
	var xp: Array = campaign["experience"]
	for row in ROWS_PER_PAGE:
		var slot := page * ROWS_PER_PAGE + row
		if slot >= types.size():
			break
		var y := 68 + row * 12
		draw_rect(Rect2(12, y - 9, 232, 11), Color("30464a") if row % 2 == 0 else Color("273a3e"))
		var type_id := int(types[slot])
		var unit_name := str(class_names.get(type_id, "部队%d" % type_id))
		_draw_text("%02d" % (slot + 1), 17, y, 24, 9, Color("b9d5d8"))
		_draw_text(unit_name, 43, y, 112, 9, Color("f9e6b5"))
		_draw_text("EXP %d" % int(xp[slot]), 155, y, 83, 9, Color("b8ebbe"), HORIZONTAL_ALIGNMENT_RIGHT)
	_draw_text("R / 点击重看胜利庆祝", 18, 187, 220, 9, Color("f4cf82"), HORIZONTAL_ALIGNMENT_CENTER)
	for index in 2:
		var y := 194 + index * 21
		draw_rect(Rect2(17, y - 10, 222, 18), Color("64745c") if action_index == index else Color("324247"))
		_draw_text("返回标题" if index == 0 else "保存通关记录", 23, y + 3, 210, 11, Color("fff1c8") if action_index == index else Color("d6ded8"), HORIZONTAL_ALIGNMENT_CENTER)
	if notice != "":
		draw_rect(Rect2(20, 175, 216, 15), Color("111c1c"))
		_draw_text(notice, 23, 186, 210, 9, Color("fff1c8"), HORIZONTAL_ALIGNMENT_CENTER)
	draw_set_transform(Vector2.ZERO)
