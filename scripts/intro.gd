extends Node2D

const OPENING_TRIO := preload("res://assets/branding/comic_trio.png")
const PROJECT_LOGO := preload("res://assets/branding/logo.png")
const TITLE := preload("res://assets/intro/1.png")
const MENU := preload("res://assets/intro/1a.png")
const DIFFICULTY := preload("res://assets/intro/1b.png")
const STORY := preload("res://assets/intro/2.png")
const DIALOG := preload("res://assets/intro/2a.png")
const STAGE := preload("res://assets/intro/2b.png")

enum Screen { OPENING, TITLE, MENU, DIFFICULTY, STORY, DIALOG, STAGE }

var screen := Screen.OPENING
var elapsed := 0.0
var menu_index := 0
var difficulty_index := 0
var notice := ""
var last_screen_touch_ms := -1000

func _ready() -> void:
	DisplayServer.window_set_title("爆笑三国")
	if DemoSave.return_to_title:
		DemoSave.return_to_title = false
		screen = Screen.TITLE
	GameAudio.play_music("title" if screen == Screen.TITLE else "")
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if screen == Screen.OPENING and elapsed >= 5.0:
		_set_screen(Screen.TITLE)
	elif screen == Screen.STAGE and elapsed >= 2.5:
		_start_game()
	elif screen in [Screen.OPENING, Screen.TITLE]:
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			_move_selection(-1 if event.keycode in [KEY_UP, KEY_LEFT] else 1)
		elif event.keycode in [KEY_A, KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_advance()
		elif event.keycode in [KEY_B, KEY_X, KEY_ESCAPE, KEY_BACKSPACE]:
			_back()
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT]:
			_move_selection(-1)
		elif event.button_index in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]:
			_move_selection(1)
		elif event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]:
			_advance()
		elif event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
			_back()
	elif event is InputEventScreenTouch and event.pressed:
		last_screen_touch_ms = Time.get_ticks_msec()
		_touch(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Time.get_ticks_msec() - last_screen_touch_ms > 180:
		_touch(event.position)

func _touch(position: Vector2) -> void:
	var local_x := position.x - _game_origin_x()
	if local_x < 0.0 or local_x >= 256.0:
		return
	if screen == Screen.MENU:
		menu_index = 0 if position.y < 116 else 1
	elif screen == Screen.DIFFICULTY:
		difficulty_index = clampi(floori((position.y - 42.0) / 32.0), 0, 2)
	_advance()

func _move_selection(direction: int) -> void:
	if screen == Screen.MENU:
		menu_index = posmod(menu_index + direction, 2)
	elif screen == Screen.DIFFICULTY:
		difficulty_index = posmod(difficulty_index + direction, 3)
	else:
		return
	GameAudio.play_effect("cursor")
	queue_redraw()

func _advance() -> void:
	if screen != Screen.OPENING:
		GameAudio.play_effect("confirm")
	match screen:
		Screen.OPENING: _set_screen(Screen.TITLE)
		Screen.TITLE: _set_screen(Screen.MENU)
		Screen.MENU:
			if menu_index == 0:
				_set_screen(Screen.DIFFICULTY)
			else:
				_load_game()
		Screen.DIFFICULTY:
			DemoSave.difficulty_index = difficulty_index
			_set_screen(Screen.STORY)
		Screen.STORY: _set_screen(Screen.DIALOG)
		Screen.DIALOG: _set_screen(Screen.STAGE)
		Screen.STAGE: _start_game()

func _back() -> void:
	match screen:
		Screen.DIFFICULTY: _set_screen(Screen.MENU)
		Screen.MENU: _set_screen(Screen.TITLE)
		Screen.STORY, Screen.DIALOG: _set_screen(Screen.DIFFICULTY)
		_: return
	GameAudio.play_effect("cancel")

func _load_game() -> void:
	var snapshot := DemoSave.read_snapshot()
	if snapshot.is_empty():
		notice = DemoSave.last_error
		queue_redraw()
		return
	if snapshot.get("completed") == true:
		if not DemoSave.valid_completion_snapshot(snapshot):
			notice = "通关记录无效"
			queue_redraw()
			return
		DemoSave.completed_run = snapshot
		get_tree().change_scene_to_file("res://scenes/campaign_ending.tscn")
		return
	var scene := DemoSave.scene_for_stage(int(snapshot.get("stage", -1)))
	if scene == "":
		notice = "存档关卡无效"
		queue_redraw()
		return
	DemoSave.pending_snapshot = snapshot
	get_tree().change_scene_to_file(scene)

func _set_screen(next: Screen) -> void:
	screen = next
	elapsed = 0.0
	notice = ""
	if screen == Screen.TITLE:
		GameAudio.play_music("title")
	queue_redraw()

func _start_game() -> void:
	DemoSave.campaign_progress.ensure_loaded()
	DemoSave.campaign_progress.reset()
	DemoSave.roster_selection.clear()
	DemoSave.pending_snapshot.clear()
	DemoSave.completed_run.clear()
	GameAudio.play_music("battle")
	get_tree().change_scene_to_file("res://scenes/battle.tscn")

func _game_origin_x() -> float:
	return floorf((get_viewport_rect().size.x - 256.0) / 2.0)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color.BLACK)
	draw_set_transform(Vector2(_game_origin_x(), 0))
	match screen:
		Screen.OPENING: _draw_comedy_opening()
		Screen.TITLE:
			draw_texture(TITLE, Vector2.ZERO)
			if fmod(elapsed, 1.0) < 0.65:
				_draw_label("按 START", 194, Color("f2eee2"))
		Screen.MENU:
			draw_texture(MENU, Vector2.ZERO)
			if menu_index == 1:
				draw_rect(Rect2(76, 93, 4, 11), Color.BLACK)
				draw_rect(Rect2(80, 93, 13, 11), Color8(48, 80, 128))
				draw_texture_rect_region(MENU, Rect2(76, 116, 17, 11), Rect2(76, 93, 17, 11))
		Screen.DIFFICULTY:
			draw_texture(DIFFICULTY, Vector2.ZERO)
			if difficulty_index > 0:
				draw_rect(Rect2(60, 61, 20, 10), Color.BLACK)
				draw_texture_rect_region(DIFFICULTY, Rect2(60, 61 + difficulty_index * 32, 20, 10), Rect2(60, 61, 20, 10))
		Screen.STORY: draw_texture(STORY, Vector2.ZERO)
		Screen.DIALOG: draw_texture(DIALOG, Vector2.ZERO)
		Screen.STAGE: draw_texture(STAGE, Vector2.ZERO)
	if notice != "":
		draw_rect(Rect2(20, 200, 216, 24), Color("171414"))
		_draw_label(notice, 216, Color("f2eee2"))
	if screen in [Screen.STORY, Screen.DIALOG]:
		_draw_label("A / 点击继续", 226, Color("f2eee2"))
	draw_set_transform(Vector2.ZERO)

func _draw_comedy_opening() -> void:
	draw_rect(Rect2(0, 0, 256, 240), Color("17243a"))
	for point in [Vector2i(19, 18), Vector2i(35, 42), Vector2i(225, 20), Vector2i(211, 49), Vector2i(18, 96), Vector2i(238, 108)]:
		draw_rect(Rect2(Vector2(point), Vector2(2, 2)), Color("f6d477"))
	draw_rect(Rect2(0, 48, 10, 152), Color("9b302b"))
	draw_rect(Rect2(246, 48, 10, 152), Color("9b302b"))
	draw_rect(Rect2(0, 48, 12, 5), Color("e7aa54"))
	draw_rect(Rect2(244, 48, 12, 5), Color("e7aa54"))
	draw_rect(Rect2(0, 198, 256, 42), Color("3b2930"))
	draw_rect(Rect2(0, 198, 256, 4), Color("d6a14f"))
	draw_texture_rect(PROJECT_LOGO, Rect2(49, 1, 158, 70), false)
	var drop := clampf(elapsed / 0.75, 0.0, 1.0)
	var drop_y := lerpf(-126.0, 70.0, drop) - sin(drop * PI) * 12.0
	var bounce := sin(elapsed * 8.0) * 2.0 if elapsed > 0.75 else 0.0
	draw_texture_rect(OPENING_TRIO, Rect2(21, drop_y + bounce, 214, 126), false)
	var caption := "刘备：人都到齐了吗？"
	if elapsed >= 1.1 and elapsed < 2.2:
		caption = "军师：先把地图翻个面。"
	elif elapsed >= 2.2 and elapsed < 3.3:
		caption = "将军：我的头盔刚才还在这儿。"
	elif elapsed >= 3.3:
		caption = "好了——这回朝着敌营出发！"
	draw_string(ThemeDB.fallback_font, Vector2(12, 216), caption, HORIZONTAL_ALIGNMENT_CENTER, 232, 10, Color("fff0c5"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 233), "A / START 继续　　自动进入游戏", HORIZONTAL_ALIGNMENT_CENTER, 232, 8, Color("d9c394"))

func _draw_label(label: String, y: int, color: Color, x: int = 0, size: int = 10) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_CENTER, 256 if x == 0 else 20, size, color)
