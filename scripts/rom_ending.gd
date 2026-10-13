extends Node2D

## Original, skippable celebration scene used after the final battle.

const PROJECT_LOGO := preload("res://assets/branding/logo.png")
const COMIC_TRIO := preload("res://assets/branding/comic_trio.png")

enum Phase { PARTY, THANKS }

var phase := Phase.PARTY
var elapsed := 0.0
var touch_press_ms := -1000

func _ready() -> void:
	if not DemoSave.valid_completion_snapshot(DemoSave.completed_run):
		DemoSave.return_to_title = true
		get_tree().change_scene_to_file.call_deferred("res://scenes/intro.tscn")
		return
	DisplayServer.window_set_title("爆笑三国 · 胜利庆祝")
	GameAudio.play_music("")
	queue_redraw()

func _process(delta: float) -> void:
	if phase == Phase.PARTY:
		elapsed += delta
		if elapsed >= 4.8:
			phase = Phase.THANKS
			elapsed = 0.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			_handle_key(KEY_A)
		elif event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
			_handle_key(KEY_B)
	elif event is InputEventScreenTouch and event.pressed:
		touch_press_ms = Time.get_ticks_msec()
		_handle_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() - touch_press_ms > 180:
		_handle_touch(event.position)

func _handle_touch(position: Vector2) -> void:
	var local_x := position.x - _game_origin_x()
	if position.y >= 218.0 and local_x >= 190.0:
		_open_record()
	else:
		_advance()

func _handle_key(key: Key) -> void:
	if key in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_advance()
	elif key in [KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE]:
		_open_record()

func _advance() -> void:
	if phase == Phase.PARTY:
		phase = Phase.THANKS
		elapsed = 0.0
		queue_redraw()
	else:
		_open_record()

func _open_record() -> void:
	get_tree().change_scene_to_file("res://scenes/campaign_ending.tscn")

func _game_origin_x() -> float:
	return floorf((get_viewport_rect().size.x - 256.0) / 2.0)

func _draw_centered(value: String, y: float, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(8, y), value, HORIZONTAL_ALIGNMENT_CENTER, 240, size, color)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color("10131e"))
	draw_set_transform(Vector2(_game_origin_x(), 0))
	draw_rect(Rect2(0, 0, 256, 240), Color("211b37"))
	draw_rect(Rect2(0, 0, 11, 206), Color("88322e"))
	draw_rect(Rect2(245, 0, 11, 206), Color("88322e"))
	draw_rect(Rect2(0, 0, 256, 9), Color("d9a34e"))
	draw_rect(Rect2(0, 202, 256, 38), Color("3b2b31"))
	draw_rect(Rect2(0, 202, 256, 4), Color("d9a34e"))
	for x in [16, 30, 226, 240]:
		draw_rect(Rect2(x, 18 + (x % 3) * 9, 3, 3), Color("f4d87a"))
	draw_texture_rect(PROJECT_LOGO, Rect2(49, 2, 158, 70), false)
	var hop := sin(elapsed * 8.0) * (3.0 if phase == Phase.PARTY else 1.0)
	draw_texture_rect(COMIC_TRIO, Rect2(21, 72 + hop, 214, 126), false)
	if phase == Phase.PARTY:
		var caption := "主公：全员都到齐了吗？"
		if elapsed >= 1.5 and elapsed < 3.1:
			caption = "军师：到齐了……就是头盔又丢了。"
		elif elapsed >= 3.1:
			caption = "三位将军：先拍张照，再回去庆功！"
		_draw_centered(caption, 218, 9, Color("fff0c5"))
		_draw_centered("A / START 继续　　B 跳过", 235, 8, Color("d8c394"))
	else:
		_draw_centered("天下安定！头盔依旧失踪！", 217, 10, Color("ffe09b"))
		_draw_centered("鸣谢：陪这支队伍走完全程的你", 231, 8, Color("e7d7bd"))
		draw_rect(Rect2(190, 218, 61, 18), Color("553e31"))
		draw_rect(Rect2(190, 218, 61, 18), Color("c69558"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(192, 231), "B 跳过", HORIZONTAL_ALIGNMENT_CENTER, 57, 8, Color("fff1c8"))
	draw_set_transform(Vector2.ZERO)
