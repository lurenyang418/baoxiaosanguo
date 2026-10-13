extends Node2D
class_name BattleCinematics

signal queue_finished

const ENEMY_INFANTRY := preload("res://assets/rom_reference/rom_stage00_infantry_pose.png")
const ENEMY_MOUNTED := preload("res://assets/rom_reference/rom_stage00_mounted_pose.png")
const PLAYER_MOUNTED := preload("res://assets/rom_reference/rom_stage00_mounted_player_pose.png")
const PLAYER_INFANTRY := preload("res://assets/rom_reference/rom_stage00_infantry_player_pose.png")
const COMBAT_ROOF_A := preload("res://assets/rom_reference/combat_roof_a.png")
const COMBAT_ROOF_B := preload("res://assets/rom_reference/combat_roof_b.png")
const COMBAT_RIGHT_IDLE := preload("res://assets/rom_reference/combat_figure_right_idle.png")
const COMBAT_RIGHT_THROW := preload("res://assets/rom_reference/combat_figure_right_throw.png")
const COMBAT_LEFT_IDLE := preload("res://assets/rom_reference/combat_figure_left_idle.png")
const COMBAT_LEFT_RUN := preload("res://assets/rom_reference/combat_figure_left_run.png")
const COMBAT_SHOE := preload("res://assets/rom_reference/combat_shoe.png")
const PLAYER_COMBAT_ROOF_A := preload("res://assets/rom_reference/combat_player_roof_a.png")
const PLAYER_COMBAT_ROOF_B := preload("res://assets/rom_reference/combat_player_roof_b.png")
const PLAYER_COMBAT_ROOF_C := preload("res://assets/rom_reference/combat_player_roof_c.png")
const PLAYER_COMBAT_LEFT_IDLE := preload("res://assets/rom_reference/combat_player_left_idle.png")
const PLAYER_COMBAT_LEFT_THROW := preload("res://assets/rom_reference/combat_player_left_throw.png")
const PLAYER_COMBAT_SHOE := preload("res://assets/rom_reference/combat_player_shoe.png")
const PLAYER_COMBAT_RIGHT_IDLE := preload("res://assets/rom_reference/combat_player_right_idle.png")
const PLAYER_COMBAT_RIGHT_RUN := preload("res://assets/rom_reference/combat_player_right_run.png")
const MOUNTED_COMBAT_ROOF_A := preload("res://assets/rom_reference/combat_mounted_roof_a.png")
const MOUNTED_COMBAT_ROOF_B := preload("res://assets/rom_reference/combat_mounted_roof_b.png")
const MOUNTED_COMBAT_RIGHT_IDLE := preload("res://assets/rom_reference/combat_mounted_right_idle.png")
const MOUNTED_COMBAT_RIGHT_THROW := preload("res://assets/rom_reference/combat_mounted_right_throw.png")
const MOUNTED_COMBAT_SHOE := preload("res://assets/rom_reference/combat_mounted_shoe.png")
const MOUNTED_COMBAT_LEFT_IDLE := preload("res://assets/rom_reference/combat_mounted_left_idle.png")
const MOUNTED_COMBAT_LEFT_HIT := preload("res://assets/rom_reference/combat_mounted_left_hit.png")
const ENEMY_TURN_RUNNER := [
	preload("res://assets/rom_reference/turn_runner_enemy_3880.png"),
	preload("res://assets/rom_reference/turn_runner_enemy_3900.png"),
	preload("res://assets/rom_reference/turn_runner_enemy_3920.png"),
	preload("res://assets/rom_reference/turn_runner_enemy_3940.png"),
	preload("res://assets/rom_reference/turn_runner_enemy_3960.png"),
	preload("res://assets/rom_reference/turn_runner_enemy_3980.png"),
	preload("res://assets/rom_reference/turn_runner_enemy_4000.png"),
]
const ENEMY_TURN_RUNNER_POS := [
	Vector2(24, 146), Vector2(60, 150), Vector2(72, 145),
	Vector2(104, 145), Vector2(140, 150), Vector2(152, 146),
	Vector2(184, 146),
]
const PLAYER_TURN_RUNNER := [
	preload("res://assets/rom_reference/turn_runner_player_4920.png"),
	preload("res://assets/rom_reference/turn_runner_player_4940.png"),
	preload("res://assets/rom_reference/turn_runner_player_4960.png"),
	preload("res://assets/rom_reference/turn_runner_player_4980.png"),
	preload("res://assets/rom_reference/turn_runner_player_5000.png"),
	preload("res://assets/rom_reference/turn_runner_player_5020.png"),
	preload("res://assets/rom_reference/turn_runner_player_5040.png"),
]
const PLAYER_TURN_RUNNER_POS := [
	Vector2(178, 146), Vector2(155, 150), Vector2(131, 145),
	Vector2(107, 150), Vector2(75, 150), Vector2(50, 146),
	Vector2(27, 150),
]

var pending: Array[Dictionary] = []
var current: Dictionary = {}
var capture_mode := false
var captured: Array[Dictionary] = []
var elapsed := 0.0
var rom_stage0_enabled := false

func is_busy() -> bool:
	return not current.is_empty() or not pending.is_empty()

func enqueue_turn(player_turn: bool) -> void:
	_queue_event({"kind": "turn", "player": player_turn, "duration": 2.12})
	_start_next()

func enqueue_attack(player_attacker: bool, attacker_type: int, defender_type: int, damage: int, technique: bool = false, affected_count: int = 1) -> void:
	var infantry_capture := rom_stage0_enabled and not technique and attacker_type == 0 and defender_type == 0
	var mounted_capture := rom_stage0_enabled and not technique and not player_attacker and attacker_type == 1 and defender_type == 0
	_queue_event({
		"kind": "rom_mounted_attack" if mounted_capture else ("rom_attack" if infantry_capture else "attack"), "player": player_attacker,
		"attacker_type": attacker_type, "defender_type": defender_type,
		"damage": damage, "technique": technique, "affected_count": affected_count, "duration": 2.15 if infantry_capture or mounted_capture else 1.15,
	})
	_start_next()

func enqueue_heal(player_side: bool, healer_type: int, target_type: int, recovered: int, affected_count: int = 1) -> void:
	_queue_event({
		"kind": "attack", "player": player_side, "healing": true,
		"attacker_type": healer_type, "defender_type": target_type,
		"damage": recovered, "technique": true, "affected_count": affected_count, "duration": 1.15,
	})
	_start_next()

func _queue_event(event: Dictionary) -> void:
	if capture_mode:
		captured.append(event)
	else:
		pending.append(event)

func take_captured_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = captured.duplicate(true)
	captured.clear()
	return events

func play_events(events: Array) -> void:
	for event in events:
		pending.append(event)
	_start_next()

func finish_all() -> void:
	pending.clear()
	current = {}
	queue_redraw()
	queue_finished.emit()

func _start_next() -> void:
	if capture_mode:
		return
	if not current.is_empty():
		return
	if pending.is_empty():
		queue_finished.emit()
		return
	current = pending.pop_front()
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	position.x = floorf((get_viewport_rect().size.x - 256.0) / 2.0)
	if current.is_empty():
		return
	elapsed += delta
	if elapsed >= float(current["duration"]):
		current = {}
		_start_next()
	queue_redraw()

func _draw() -> void:
	if current.is_empty():
		return
	if current["kind"] == "turn":
		_draw_turn()
	elif current["kind"] == "rom_attack":
		_draw_rom_stage0_attack()
	elif current["kind"] == "rom_mounted_attack":
		_draw_rom_stage0_mounted_attack()
	else:
		_draw_attack()

func _pose(player_side: bool, type_id: int) -> Texture2D:
	if player_side:
		return PLAYER_MOUNTED if type_id == 1 else PLAYER_INFANTRY
	return ENEMY_MOUNTED if type_id == 1 else ENEMY_INFANTRY

func _draw_turn() -> void:
	var player_turn: bool = current["player"]
	# The red and blue runners come from independent ROM turn transitions.
	# They are drawn over the live map, as they appear in the source game.
	var frames := PLAYER_TURN_RUNNER if player_turn else ENEMY_TURN_RUNNER
	var positions := PLAYER_TURN_RUNNER_POS if player_turn else ENEMY_TURN_RUNNER_POS
	var frame_index := mini(int(elapsed / float(current["duration"]) * frames.size()), frames.size() - 1)
	draw_texture(frames[frame_index], positions[frame_index])

func _draw_attack() -> void:
	var player_attacker: bool = current["player"]
	var technique: bool = current["technique"]
	var healing := bool(current.get("healing", false))
	var defender_player := player_attacker if healing else not player_attacker
	var t := clampf(elapsed / float(current["duration"]), 0.0, 1.0)
	draw_rect(Rect2(7, 35, 242, 170), Color("171c20"))
	draw_rect(Rect2(7, 35, 242, 170), Color("c59b60"), false, 3.0)
	draw_rect(Rect2(13, 73, 230, 84), Color("465350"))
	draw_rect(Rect2(13, 157, 230, 39), Color("9d8060"))
	for x in range(18, 241, 16):
		draw_rect(Rect2(x, 171, 8, 2), Color("d2ad79"))
		draw_rect(Rect2(x + 7, 183, 7, 2), Color("6e5946"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 57), "我军" if player_attacker else "敌军", HORIZONTAL_ALIGNMENT_LEFT, 75, 12, Color("a8dfff") if player_attacker else Color("ffab86"))
	draw_string(ThemeDB.fallback_font, Vector2(160, 57), "我军" if defender_player else "敌军", HORIZONTAL_ALIGNMENT_LEFT, 75, 12, Color("a8dfff") if defender_player else Color("ffab86"))
	var attacker_x := 28.0
	if t >= 0.24 and t < 0.55:
		attacker_x += 63.0 * (t - 0.24) / 0.31
	elif t >= 0.55 and t < 0.78:
		attacker_x += 63.0
	elif t >= 0.78:
		attacker_x += 63.0 * (1.0 - (t - 0.78) / 0.22)
	var defender_x := 165.0 + (9.0 if t >= 0.55 and t < 0.82 else 0.0)
	var attacker_bob := -3.0 if t >= 0.35 and t < 0.57 else 0.0
	var defender_bob := -6.0 if t >= 0.58 and t < 0.73 else 0.0
	draw_texture_rect(_pose(player_attacker, int(current["attacker_type"])), Rect2(floorf(attacker_x), 96 + attacker_bob, 64, 64), false)
	draw_texture_rect(_pose(defender_player, int(current["defender_type"])), Rect2(floorf(defender_x), 96 + defender_bob, 64, 64), false)
	if t >= 0.26 and t < 0.55:
		draw_string(ThemeDB.fallback_font, Vector2(91, 91), "补一补！" if healing else "嘿！" if not technique else "看招！", HORIZONTAL_ALIGNMENT_LEFT, 68, 12, Color("fff2d0"))
	if t >= 0.55 and t < 0.89:
		var impact := Vector2(160, 118)
		draw_colored_polygon(PackedVector2Array([
			impact + Vector2(-21, 0), impact + Vector2(-7, -7), impact + Vector2(0, -20), impact + Vector2(7, -7),
			impact + Vector2(21, 0), impact + Vector2(7, 7), impact + Vector2(0, 20), impact + Vector2(-7, 7),
		]), Color("8fe6a0") if healing else Color("ffe98b"))
		draw_string(ThemeDB.fallback_font, Vector2(164, 91), "舒服了！" if healing else "哎呀！", HORIZONTAL_ALIGNMENT_LEFT, 69, 12, Color("fff2d0"))
		draw_string(ThemeDB.fallback_font, Vector2(111, 79), ("+%d" if healing else "-%d") % int(current["damage"]), HORIZONTAL_ALIGNMENT_CENTER, 75, 17, Color("8fe6a0") if healing else Color("ff8d75"))
	var effect_label := "治疗" if healing else "技术" if technique else "攻击"
	if int(current.get("affected_count", 1)) > 1:
		effect_label = ("群体治疗%d人 · 总回复%d" if healing else "范围攻击%d人 · 总伤害%d") % [int(current["affected_count"]), int(current["damage"])]
	draw_string(ThemeDB.fallback_font, Vector2(0, 193), effect_label, HORIZONTAL_ALIGNMENT_CENTER, 256, 10, Color("fff2d0"))

func _draw_rom_stage0_attack() -> void:
	if bool(current["player"]):
		_draw_rom_stage0_player_attack()
		return
	var t := clampf(elapsed / float(current["duration"]), 0.0, 1.0)
	draw_rect(Rect2(0, 0, 256, 240), Color.BLACK)
	# These unscaled layers come from actual FCEUX frames of the supplied ROM.
	# The source scene shows one large figure at a time against a black screen.
	draw_texture(COMBAT_ROOF_A if t < 0.47 else COMBAT_ROOF_B, Vector2.ZERO)
	if t >= 0.10 and t < 0.47:
		draw_texture(COMBAT_RIGHT_THROW if t >= 0.32 else COMBAT_RIGHT_IDLE, Vector2(180, 148))
		if t >= 0.34:
			var shoe_x := 154.0 - (t - 0.34) / 0.13 * 120.0
			draw_texture(COMBAT_SHOE, Vector2(floorf(shoe_x), 132))
	elif t >= 0.47 and t < 0.88:
		draw_texture(COMBAT_LEFT_RUN if t >= 0.64 and t < 0.78 else COMBAT_LEFT_IDLE,
			Vector2(48, 148) if t >= 0.64 and t < 0.78 else Vector2(24, 148))
	if t >= 0.72 and t < 0.88:
		draw_string(ThemeDB.fallback_font, Vector2(55, 138), "-%d" % int(current["damage"]), HORIZONTAL_ALIGNMENT_LEFT, 48, 9, Color("a5e0a0"))

func _draw_rom_stage0_player_attack() -> void:
	var t := clampf(elapsed / float(current["duration"]), 0.0, 1.0)
	draw_rect(Rect2(0, 0, 256, 240), Color.BLACK)
	# Independent player-attack capture: FCEUX frames 3700–3900.
	# Roof, actor poses and flying shoe are all ROM pixels, not mirrored art.
	if t < 0.34:
		draw_texture(PLAYER_COMBAT_ROOF_A, Vector2.ZERO)
	elif t < 0.56:
		draw_texture(PLAYER_COMBAT_ROOF_B, Vector2.ZERO)
	else:
		draw_texture(PLAYER_COMBAT_ROOF_C, Vector2.ZERO)
	if t >= 0.07 and t < 0.34:
		draw_texture(PLAYER_COMBAT_LEFT_THROW if t >= 0.21 else PLAYER_COMBAT_LEFT_IDLE,
			Vector2(46, 148) if t >= 0.21 else Vector2(48, 148))
		if t >= 0.27:
			draw_texture(PLAYER_COMBAT_SHOE, Vector2(105, 110))
	elif t >= 0.56 and t < 0.89:
		draw_texture(PLAYER_COMBAT_RIGHT_RUN if t >= 0.68 else PLAYER_COMBAT_RIGHT_IDLE,
			Vector2(160, 148) if t >= 0.68 else Vector2(128, 148))
	if t >= 0.75 and t < 0.91:
		draw_string(ThemeDB.fallback_font, Vector2(154, 138), "-%d" % int(current["damage"]), HORIZONTAL_ALIGNMENT_LEFT, 48, 9, Color("a5e0a0"))

func _draw_rom_stage0_mounted_attack() -> void:
	var t := clampf(elapsed / float(current["duration"]), 0.0, 1.0)
	draw_rect(Rect2(0, 0, 256, 240), Color.BLACK)
	# The first battle's type-1 enemy attack, captured with slot 3 active in
	# FCEUX frames 4680–4840. It uses a mounted actor on the right.
	draw_texture(MOUNTED_COMBAT_ROOF_A if t < 0.48 else MOUNTED_COMBAT_ROOF_B, Vector2.ZERO)
	if t >= 0.08 and t < 0.43:
		draw_texture(MOUNTED_COMBAT_RIGHT_THROW if t >= 0.26 else MOUNTED_COMBAT_RIGHT_IDLE, Vector2(180, 148))
		if t >= 0.31:
			draw_texture(MOUNTED_COMBAT_SHOE, Vector2(128, 108))
	elif t >= 0.48 and t < 0.91:
		draw_texture(MOUNTED_COMBAT_LEFT_HIT if t >= 0.69 else MOUNTED_COMBAT_LEFT_IDLE, Vector2(45, 148))
	if t >= 0.76 and t < 0.91:
		draw_string(ThemeDB.fallback_font, Vector2(68, 138), "-%d" % int(current["damage"]), HORIZONTAL_ALIGNMENT_LEFT, 48, 9, Color("a5e0a0"))
