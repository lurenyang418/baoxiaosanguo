extends Node

## Isolated campaign/save regression runner. Never opens the normal user save.

const EXPECTED_ROSTER_CAPS := [8, 6, 8, 8, 10, 10, 10, 10, 12]
const FORMAL_SAVE_PATH := "user://bao_xiao_san_guo_demo_progress.json"

var output_dir := ""
var results: Array[Dictionary] = []
var stage_rows: Array[Dictionary] = []
var failures := 0
var formal_save_before := {}
var formal_save_after := {}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	output_dir = OS.get_environment("BAOXIAO_CAMPAIGN_TEST_DIR")
	var workspace_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if not output_dir.is_absolute_path() or not output_dir.simplify_path().begins_with(workspace_dir + "/tmp/"):
		push_error("BAOXIAO_CAMPAIGN_TEST_DIR must be an absolute path inside the workspace")
		get_tree().quit(2)
		return
	if DirAccess.dir_exists_absolute(output_dir):
		push_error("Refusing to reuse regression output directory: " + output_dir)
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create regression output directory: " + output_dir)
		get_tree().quit(2)
		return
	formal_save_before = _formal_save_fingerprint()
	DemoSave.save_path = output_dir.path_join("isolated-save.json")
	DemoSave.pending_snapshot = {}
	DemoSave.completed_run = {}
	DemoSave.roster_selection.clear()
	DemoSave.campaign_progress.ensure_loaded()
	DemoSave.campaign_progress.reset()
	_record("save isolation", DemoSave.save_path != FORMAL_SAVE_PATH and DemoSave.save_path.begins_with(output_dir + "/"), {"path": DemoSave.save_path})
	_record("missing isolated save", DemoSave.read_snapshot().is_empty() and DemoSave.last_error != "", {"message": DemoSave.last_error})
	for stage in range(19):
		await _check_stage(stage)
	await _check_roundtrip(0)
	await _check_roundtrip(10)
	await _check_roundtrip(14)
	await _check_roundtrip(18)
	await _check_cross_stage_menu_load()
	await _check_action_roundtrip()
	await _check_scroll_roundtrip()
	await _check_completion_roundtrip()
	await _check_invalid_save()
	await _check_invalid_save_menu()
	formal_save_after = _formal_save_fingerprint()
	_record("formal save unchanged", formal_save_before == formal_save_after, {"before": formal_save_before, "after": formal_save_after})
	_write_report()
	get_tree().quit(1 if failures > 0 else 0)

func _open_battle(stage: int) -> Node:
	DemoSave.pending_snapshot = {}
	DemoSave.roster_selection.clear()
	var scene_path: String = DemoSave.scene_for_stage(stage)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return null
	var battle := packed.instantiate()
	add_child(battle)
	await get_tree().process_frame
	if battle.cinematics != null:
		battle.cinematics.finish_all()
	return battle

func _close_battle(battle: Node) -> void:
	if battle != null and is_instance_valid(battle):
		battle.queue_free()
		await get_tree().process_frame

func _check_stage(stage: int) -> void:
	DemoSave.campaign_progress.reset()
	var battle: Node = await _open_battle(stage)
	if battle == null:
		_record("stage %02d scene" % (stage + 1), false, {"reason": "scene missing"})
		return
	var layout: Dictionary = battle.rom_layout_record
	var expected_enemies: int = layout.get("unit_group_2", []).size()
	var expected_allies: int = layout.get("unit_group_1", []).size()
	var expected_players: int = layout.get("player_deployments", []).size() if stage < 10 else EXPECTED_ROSTER_CAPS[stage - 10]
	var expected_units := expected_enemies + expected_players + expected_allies
	var expected_map: Array = battle.rom_stage_record.get("map_source_world_16x15_pages", [])
	var checks := {
		"stage": battle.stage_index == stage,
		"scene": battle.scene_file_path == DemoSave.scene_for_stage(stage),
		"map_width": int(battle.rom_stage_record.get("map_world_dimensions", [0, 0])[0]) == 16,
		"map_height": battle.world_height == expected_map.size(),
		"enemy_count": battle.group2_unit_count == expected_enemies,
		"ally_count": battle.group1_unit_count == expected_allies,
		"player_count": battle.player_unit_count == expected_players,
		"unit_arrays": battle.units.size() == expected_units and battle.unit_hp.size() == expected_units and battle.unit_type_ids.size() == expected_units,
	}
	if stage >= 10:
		checks["roster"] = DemoSave.valid_roster_selection(stage, battle.selected_roster_indices) and battle.selected_roster_indices.size() == EXPECTED_ROSTER_CAPS[stage - 10]
	stage_rows.append({
		"stage": stage + 1, "scene": DemoSave.scene_for_stage(stage),
		"map_width": 16, "map_height": battle.world_height,
		"enemies": expected_enemies, "players": expected_players, "allies": expected_allies,
		"roster_cap": EXPECTED_ROSTER_CAPS[stage - 10] if stage >= 10 else 0,
		"implemented_goal": _goal_label(stage),
		"implemented_defeat": "first player slot HP reaches zero",
	})
	_record("stage %02d ROM setup" % (stage + 1), not checks.values().has(false), checks)
	await _close_battle(battle)

func _goal_label(stage: int) -> String:
	match stage:
		4: return "first player north or clear enemies"
		5: return "first player south or clear enemies"
		8: return "first player northeast or clear enemies"
		11: return "first enemy defeated or clear enemies"
		_: return "clear enemies"

func _check_roundtrip(stage: int) -> void:
	DemoSave.campaign_progress.reset()
	var battle: Node = await _open_battle(stage)
	if battle == null:
		_record("stage %02d roundtrip" % (stage + 1), false, {"reason": "scene missing"})
		return
	var before: Dictionary = battle._demo_snapshot()
	var write_ok: bool = DemoSave.write_snapshot(before)
	var saved: Dictionary = DemoSave.read_snapshot()
	await _close_battle(battle)
	if not write_ok or saved.is_empty():
		_record("stage %02d roundtrip" % (stage + 1), false, {"reason": DemoSave.last_error})
		return
	DemoSave.pending_snapshot = saved
	var packed: PackedScene = load(DemoSave.scene_for_stage(stage))
	var restored := packed.instantiate()
	add_child(restored)
	await get_tree().process_frame
	if restored.cinematics != null:
		restored.cinematics.finish_all()
	var after: Dictionary = restored._demo_snapshot()
	_record("stage %02d roundtrip" % (stage + 1), JSON.stringify(before) == JSON.stringify(after), {"stage": stage + 1, "field_count": before.size(), "status": restored.status_message})
	await _close_battle(restored)

func _cursor_to(battle: Node, destination: Vector2i) -> bool:
	var attempts := 0
	while battle.cursor != destination and attempts < 80:
		var key: Key = KEY_RIGHT if battle.cursor.x < destination.x else (KEY_LEFT if battle.cursor.x > destination.x else (KEY_DOWN if battle.cursor.y < destination.y else KEY_UP))
		battle._handle_key(key)
		attempts += 1
	return battle.cursor == destination

func _check_cross_stage_menu_load() -> void:
	DemoSave.campaign_progress.reset()
	var target_battle: Node = await _open_battle(10)
	if target_battle == null:
		_record("stage 01 to 11 menu load", false, {"reason": "stage 11 missing"})
		return
	var expected: Dictionary = target_battle._demo_snapshot()
	var saved: bool = DemoSave.write_snapshot(expected)
	await _close_battle(target_battle)
	var original_scene: Node = get_tree().current_scene
	var source: Node = load(DemoSave.scene_for_stage(0)).instantiate()
	get_tree().root.add_child(source)
	get_tree().current_scene = source
	await get_tree().process_frame
	source.cinematics.finish_all()
	source._handle_key(KEY_ENTER)
	for unused in range(3): source._handle_key(KEY_DOWN)
	source._handle_key(KEY_A) # System menu Load, changing to stage 11.
	await get_tree().process_frame
	var loaded: Node = get_tree().current_scene
	var correct_scene: bool = loaded != null and loaded.scene_file_path == DemoSave.scene_for_stage(10)
	var restored: bool = correct_scene and JSON.stringify(loaded._demo_snapshot()) == JSON.stringify(expected)
	_record("stage 01 to 11 menu load", saved and correct_scene and restored, {"saved": saved, "correct_scene": correct_scene, "restored": restored, "roster": expected["roster_selection"]})
	get_tree().current_scene = original_scene
	if loaded != null and is_instance_valid(loaded):
		loaded.queue_free()
		await get_tree().process_frame

func _check_action_roundtrip() -> void:
	DemoSave.campaign_progress.reset()
	var battle: Node = await _open_battle(0)
	if battle == null:
		_record("first-battle action save", false, {"reason": "scene missing"})
		return
	var player_index: int = battle.opponent_unit_count
	var starting_cell: Vector2i = battle.units[player_index]
	var selected: bool = _cursor_to(battle, starting_cell)
	battle._handle_key(KEY_A)
	selected = selected and battle.command_open and battle.selected_unit_index == player_index
	if not selected:
		_record("first-battle action save", false, {"reason": "normal unit selection failed"})
		await _close_battle(battle)
		return
	battle._handle_key(KEY_A) # The first command is Move.
	var destination := starting_cell
	for candidate in battle._reachable_move_cells().keys():
		if candidate != starting_cell:
			destination = candidate
			break
	if destination == starting_cell or not _cursor_to(battle, destination):
		_record("first-battle action save", false, {"reason": "no legal player move found"})
		await _close_battle(battle)
		return
	battle._handle_key(KEY_A)
	var moved: bool = battle.units[player_index] == destination and battle.acted_unit_slots.has(player_index)
	battle._handle_key(KEY_ENTER)
	var menu_opened: bool = battle.system_menu_open
	for unused in range(4):
		battle._handle_key(KEY_DOWN)
	var menu_index: int = battle.system_menu_index
	battle._handle_key(KEY_A) # System menu item 4 saves progress.
	var save_status: String = battle.status_message
	var before_menu_reload: Dictionary = battle._demo_snapshot()
	var saved: Dictionary = DemoSave.read_snapshot()
	var saved_position: Array = saved.get("positions", [])[player_index] if saved.get("positions", []).size() > player_index else []
	var saved_through_menu: bool = saved_position.size() == 2 and int(saved_position[0]) == destination.x and int(saved_position[1]) == destination.y
	await _close_battle(battle)
	DemoSave.pending_snapshot = saved
	var restored: Node = load(DemoSave.scene_for_stage(0)).instantiate()
	add_child(restored)
	await get_tree().process_frame
	restored.cinematics.finish_all()
	var restored_ok: bool = JSON.stringify(restored._demo_snapshot()) == JSON.stringify(before_menu_reload)
	var restored_diff: Array[String] = []
	for field in before_menu_reload.keys():
		if JSON.stringify(restored._demo_snapshot().get(field)) != JSON.stringify(before_menu_reload.get(field)):
			restored_diff.append(str(field))
	_record("first-battle move/menu-save/reload", moved and saved_through_menu and restored_ok, {"moved": moved, "menu_opened": menu_opened, "menu_index": menu_index, "status": save_status, "saved_stage": saved.get("stage", -1), "saved_position": saved_position, "saved_through_menu": saved_through_menu, "restored": restored_ok, "restored_diff": restored_diff, "destination": [destination.x, destination.y]})
	if not restored_ok:
		await _close_battle(restored)
		return
	restored._handle_key(KEY_ENTER)
	restored._handle_key(KEY_A) # All rest; resolves one automatic phase.
	var resolved: Dictionary = restored._demo_snapshot()
	var had_playback: bool = restored.phase_playback_active
	if had_playback:
		restored._handle_key(KEY_A) # The visible A fast-forward operation.
	for unused in range(180):
		if not restored.phase_playback_active:
			break
		await get_tree().process_frame
	var after_skip: Dictionary = restored._demo_snapshot()
	var unchanged: bool = true
	for field in ["positions", "hp", "types", "experience", "campaign", "acted", "turn", "clear", "defeat"]:
		if JSON.stringify(resolved.get(field)) != JSON.stringify(after_skip.get(field)):
			unchanged = false
	var ended: bool = restored.turn_number == 2 and not restored.phase_playback_active
	_record("first-battle round/fast-forward", had_playback and ended and unchanged, {"playback_started": had_playback, "turn": restored.turn_number, "state_unchanged_by_skip": unchanged, "first_player_hp": restored.unit_hp[player_index]})
	var turn_snapshot: Dictionary = restored._demo_snapshot()
	var turn_saved: bool = DemoSave.write_snapshot(turn_snapshot)
	await _close_battle(restored)
	DemoSave.pending_snapshot = DemoSave.read_snapshot()
	var turn_restored: Node = load(DemoSave.scene_for_stage(0)).instantiate()
	add_child(turn_restored)
	await get_tree().process_frame
	turn_restored.cinematics.finish_all()
	var turn_matches: bool = JSON.stringify(turn_snapshot) == JSON.stringify(turn_restored._demo_snapshot())
	_record("first-battle post-turn save/reload", turn_saved and turn_matches, {"turn": turn_restored.turn_number, "saved": turn_saved, "restored": turn_matches})
	await _close_battle(turn_restored)

func _check_scroll_roundtrip() -> void:
	DemoSave.campaign_progress.reset()
	var battle: Node = await _open_battle(0)
	if battle == null:
		_record("vertical-scroll save/reload", false, {"reason": "battle missing"})
		return
	var target := Vector2i(battle.cursor.x, battle.world_height - 1)
	var reached: bool = _cursor_to(battle, target)
	var before: Dictionary = battle._demo_snapshot()
	var scrolled: bool = int(before["scroll"]) > 0
	var saved: bool = DemoSave.write_snapshot(before)
	await _close_battle(battle)
	DemoSave.pending_snapshot = DemoSave.read_snapshot()
	var restored: Node = load(DemoSave.scene_for_stage(0)).instantiate()
	add_child(restored)
	await get_tree().process_frame
	restored.cinematics.finish_all()
	var matching: bool = JSON.stringify(before) == JSON.stringify(restored._demo_snapshot())
	_record("vertical-scroll save/reload", reached and scrolled and saved and matching, {"cursor": before["cursor"], "scroll": before["scroll"], "rom_enemy_scroll": before["rom_enemy_scroll"], "restored": matching})
	await _close_battle(restored)

func _check_completion_roundtrip() -> void:
	DemoSave.campaign_progress.reset()
	var record: Dictionary = DemoSave.completion_snapshot()
	DemoSave.completed_run = record.duplicate(true)
	var scene: Node = load("res://scenes/campaign_ending.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var displayed: bool = JSON.stringify(scene.campaign) == JSON.stringify(record["campaign"])
	scene._handle_key(KEY_RIGHT)
	var second_page: bool = scene.page == 1
	scene._handle_key(KEY_LEFT)
	var first_page: bool = scene.page == 0
	scene._handle_key(KEY_DOWN)
	scene._handle_key(KEY_A) # Explicit Save completion record action.
	var saved: Dictionary = DemoSave.read_snapshot()
	var valid: bool = DemoSave.valid_completion_snapshot(saved)
	var expected_saved: Dictionary = JSON.parse_string(JSON.stringify(record))
	var fields_match: bool = JSON.stringify(saved) == JSON.stringify(expected_saved)
	_record("synthetic completion record UI/save", displayed and second_page and first_page and valid and fields_match, {"synthetic": true, "displayed": displayed, "page_navigation": second_page and first_page, "explicit_save": valid, "fields_match": fields_match, "status": scene.notice})
	await _close_battle(scene)
	DemoSave.completed_run = {}

func _check_invalid_save() -> void:
	var battle: Node = await _open_battle(0)
	if battle == null:
		_record("invalid save", false, {"reason": "battle missing"})
		return
	var valid: Dictionary = battle._demo_snapshot()
	var invalid_cases := {}
	var bad_version: Dictionary = valid.duplicate(true)
	bad_version["version"] = 999
	invalid_cases["unknown version"] = bad_version
	var bad_stage: Dictionary = valid.duplicate(true)
	bad_stage["stage"] = 19
	invalid_cases["unsupported stage"] = bad_stage
	var bad_hp: Dictionary = valid.duplicate(true)
	bad_hp["hp"][0] = -1
	invalid_cases["negative HP"] = bad_hp
	var bad_position: Dictionary = valid.duplicate(true)
	bad_position["positions"][0] = [99, 99]
	invalid_cases["out-of-bounds position"] = bad_position
	var bad_length: Dictionary = valid.duplicate(true)
	bad_length["positions"].pop_back()
	invalid_cases["array length"] = bad_length
	var bad_xp: Dictionary = valid.duplicate(true)
	bad_xp["experience"][battle.opponent_unit_count] = -1
	invalid_cases["negative experience"] = bad_xp
	var bad_campaign: Dictionary = valid.duplicate(true)
	bad_campaign["campaign"]["types"][0] = 255
	invalid_cases["unreachable promotion"] = bad_campaign
	var false_victory: Dictionary = valid.duplicate(true)
	false_victory["clear"] = true
	invalid_cases["false victory"] = false_victory
	var false_defeat: Dictionary = valid.duplicate(true)
	false_defeat["defeat"] = true
	invalid_cases["false defeat"] = false_defeat
	var bad_completion: Dictionary = DemoSave.completion_snapshot()
	bad_completion["campaign"]["experience"].pop_back()
	var completion_rejected: bool = not DemoSave.valid_completion_snapshot(bad_completion)
	var checks := {}
	for name in invalid_cases:
		var before: String = JSON.stringify(battle._demo_snapshot())
		var rejected: bool = not battle._apply_demo_snapshot(invalid_cases[name])
		checks[name] = rejected and JSON.stringify(battle._demo_snapshot()) == before
	await _close_battle(battle)
	var roster_battle: Node = await _open_battle(10)
	if roster_battle != null:
		var duplicate_roster: Dictionary = roster_battle._demo_snapshot()
		duplicate_roster["roster_selection"][1] = duplicate_roster["roster_selection"][0]
		checks["duplicate roster"] = not roster_battle._apply_demo_snapshot(duplicate_roster)
		await _close_battle(roster_battle)
	else:
		checks["duplicate roster"] = false
	var malformed := FileAccess.open(DemoSave.save_path, FileAccess.WRITE)
	if malformed != null:
		malformed.store_string("{malformed json")
		malformed.close()
	var malformed_rejected: bool = DemoSave.read_snapshot().is_empty()
	checks["malformed JSON"] = malformed_rejected
	checks["damaged completion"] = completion_rejected
	_record("invalid save rejection", not checks.values().has(false), checks)

func _check_invalid_save_menu() -> void:
	DemoSave.campaign_progress.reset()
	var battle: Node = await _open_battle(0)
	if battle == null:
		_record("invalid save menu recovery", false, {"reason": "battle missing"})
		return
	var before: Dictionary = battle._demo_snapshot()
	var invalid: Dictionary = before.duplicate(true)
	invalid["hp"][0] = -1
	var invalid_written: bool = DemoSave.write_snapshot(invalid)
	_choose_load_command(battle)
	var rejected_with_notice: bool = battle.status_message == "存档与本关ROM数据不匹配"
	var state_unchanged: bool = JSON.stringify(before) == JSON.stringify(battle._demo_snapshot())
	var malformed := FileAccess.open(DemoSave.save_path, FileAccess.WRITE)
	if malformed != null:
		malformed.store_string("{malformed json")
		malformed.close()
	_choose_load_command(battle)
	var format_notice: bool = battle.status_message == "存档格式不兼容"
	var malformed_unchanged: bool = JSON.stringify(before) == JSON.stringify(battle._demo_snapshot())
	var valid_written: bool = DemoSave.write_snapshot(before)
	_choose_load_command(battle)
	var valid_recovered: bool = battle.status_message == "已读取第1关演示进度" and JSON.stringify(before) == JSON.stringify(battle._demo_snapshot())
	_record("invalid save menu recovery", invalid_written and rejected_with_notice and state_unchanged and format_notice and malformed_unchanged and valid_written and valid_recovered, {"invalid_written": invalid_written, "invalid_notice": rejected_with_notice, "state_unchanged": state_unchanged, "malformed_notice": format_notice, "malformed_unchanged": malformed_unchanged, "valid_written": valid_written, "valid_recovered": valid_recovered})
	await _close_battle(battle)

func _choose_load_command(battle: Node) -> void:
	battle._handle_key(KEY_ENTER)
	for unused in range(3): battle._handle_key(KEY_DOWN)
	battle._handle_key(KEY_A)

func _formal_save_fingerprint() -> Dictionary:
	if not FileAccess.file_exists(FORMAL_SAVE_PATH):
		return {"exists": false}
	return {"exists": true, "sha256": FileAccess.get_sha256(FORMAL_SAVE_PATH)}

func _record(name: String, ok: bool, details: Dictionary) -> void:
	results.append({"name": name, "ok": ok, "details": details})
	if not ok:
		failures += 1
	print(("PASS " if ok else "FAIL ") + name)

func _write_report() -> void:
	var report := {"godot_version": Engine.get_version_info().get("string", ""), "result": "fail" if failures > 0 else "pass", "checks": results, "failures": failures, "save_path": DemoSave.save_path, "formal_save_before": formal_save_before, "formal_save_after": formal_save_after}
	var file := FileAccess.open(output_dir.path_join("automated-report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	var csv := FileAccess.open(output_dir.path_join("stage-baseline.csv"), FileAccess.WRITE)
	if csv != null:
		csv.store_string("stage,scene,map_width,map_height,enemies,players,allies,roster_cap,implemented_goal,implemented_defeat\n")
		for row in stage_rows:
			csv.store_string("%d,%s,%d,%d,%d,%d,%d,%d,%s,%s\n" % [row["stage"], row["scene"], row["map_width"], row["map_height"], row["enemies"], row["players"], row["allies"], row["roster_cap"], row["implemented_goal"], row["implemented_defeat"]])
		csv.close()
