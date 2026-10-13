extends Node

## A normal-input campaign probe. It never changes HP, victory, or stage state.

const FORMAL_SAVE_PATH := "user://bao_xiao_san_guo_demo_progress.json"
const MAX_TURNS_PER_STAGE := 80
const MAX_ACTIONS_PER_STAGE := 2500

var output_dir := ""
var rows: Array[Dictionary] = []
var action_log: Array[Dictionary] = []
var formal_before := {}
var failure := ""
var retry_check := {}
var finale_check := {}
var checkpoints: Array[Dictionary] = []
var checkpoint_keys := {}
var transition_checks: Array[Dictionary] = []
var defensive_slots := {}
var resume_source := ""
var start_stage := 0
var stop_after_stage := 18
var max_turns_per_stage := MAX_TURNS_PER_STAGE
var capture_stage_images := false
var play_speed := 1.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	output_dir = OS.get_environment("BAOXIAO_CAMPAIGN_PLAY_DIR")
	var workspace := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if not output_dir.is_absolute_path() or not output_dir.simplify_path().begins_with(workspace + "/tmp/") or DirAccess.dir_exists_absolute(output_dir):
		push_error("BAOXIAO_CAMPAIGN_PLAY_DIR must be a fresh directory inside workspace tmp")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		get_tree().quit(2)
		return
	capture_stage_images = OS.get_environment("BAOXIAO_CAPTURE_STAGE_IMAGES") == "1"
	var requested_speed := OS.get_environment("BAOXIAO_PLAY_SPEED")
	if requested_speed != "":
		play_speed = clampf(float(requested_speed), 1.0, 10.0)
	Engine.time_scale = play_speed
	if capture_stage_images and DisplayServer.get_name() == "headless":
		push_error("Stage images require a graphical Godot display")
		get_tree().quit(2)
		return
	formal_before = _formal_fingerprint()
	DemoSave.save_path = output_dir.path_join("isolated-play-save.json")
	DemoSave.return_to_title = false
	resume_source = OS.get_environment("BAOXIAO_PLAY_RESUME_SAVE")
	if resume_source != "":
		var resume_name := resume_source.get_file()
		if not resume_source.is_absolute_path() or not resume_source.simplify_path().begins_with(workspace + "/tmp/") or not (resume_name == "isolated-play-save.json" or (resume_name.begins_with("checkpoint-stage") and resume_name.ends_with(".json"))) or DirAccess.copy_absolute(resume_source, DemoSave.save_path) != OK:
			push_error("Resume save must be an earlier isolated play save in workspace tmp")
			get_tree().quit(2)
			return
		var resume_snapshot: Dictionary = DemoSave.read_snapshot()
		start_stage = int(resume_snapshot.get("stage", -1))
		if start_stage < 0 or start_stage > 18:
			get_tree().quit(2)
			return
	var requested_stop := OS.get_environment("BAOXIAO_PLAY_STOP_AFTER_STAGE")
	if requested_stop != "":
		stop_after_stage = clampi(int(requested_stop), start_stage + 1, 19) - 1
	var requested_max_turns := OS.get_environment("BAOXIAO_PLAY_MAX_TURNS")
	if requested_max_turns != "":
		max_turns_per_stage = clampi(int(requested_max_turns), 1, MAX_TURNS_PER_STAGE)
	print("Natural probe: isolated save prepared")
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	get_tree().root.add_child(intro)
	get_tree().current_scene = intro
	await get_tree().process_frame
	if resume_source == "":
		for unused in range(7): intro._advance()
	else:
		for unused in range(3): intro._advance()
		intro._move_selection(1)
		intro._advance()
	await get_tree().process_frame
	print("Natural probe: title sequence advanced to ", get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "null")
	if get_tree().current_scene == null or not get_tree().current_scene.has_method("_demo_snapshot"):
		failure = "title-to-first-battle transition failed"
	else:
		var final_stage_progress_before: Dictionary = {}
		for stage in range(start_stage, stop_after_stage + 1):
			var stage_progress_before: Dictionary = DemoSave.campaign_progress.snapshot()
			final_stage_progress_before = stage_progress_before
			if not await _play_stage(stage):
				if get_tree().current_scene != null and get_tree().current_scene.demo_defeat:
					await _check_defeat_retry(stage)
				break
			if stage < stop_after_stage:
				var battle: Node = get_tree().current_scene
				var expected_progress: Dictionary = battle._campaign_snapshot()
				var precommit_unchanged: bool = JSON.stringify(stage_progress_before) == JSON.stringify(DemoSave.campaign_progress.snapshot())
				battle._handle_key(KEY_A)
				var next_scene: Node = await _wait_for_scene()
				var roster_valid := true
				if stage >= 9 and next_scene != null and next_scene.scene_file_path == "res://scenes/roster_selection.tscn":
					roster_valid = DemoSave.valid_roster_selection(stage + 1, next_scene.selected)
					if not roster_valid:
						failure = "invalid selection before stage %d" % (stage + 2)
						break
					next_scene._handle_key(KEY_ENTER)
					next_scene = await _wait_for_scene()
				if get_tree().current_scene == null or get_tree().current_scene.scene_file_path != DemoSave.scene_for_stage(stage + 1):
					failure = "stage %d transition failed; scene=%s" % [stage + 2, get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "null"]
					break
				next_scene = get_tree().current_scene
				var progress_matches: bool = JSON.stringify(expected_progress) == JSON.stringify(DemoSave.campaign_progress.snapshot())
				var deployment_matches := true
				for slot in next_scene.player_unit_count:
					var unit_index: int = next_scene.opponent_unit_count + slot
					var roster_index: int = next_scene.player_roster_indices[slot]
					if next_scene.unit_type_ids[unit_index] != int(expected_progress["types"][roster_index]) or next_scene.unit_experience[unit_index] != int(expected_progress["experience"][roster_index]):
						deployment_matches = false
				transition_checks.append({"from_stage": stage + 1, "to_stage": stage + 2, "precommit_unchanged": precommit_unchanged, "campaign_progress": progress_matches, "deployed_types_and_experience": deployment_matches, "roster_valid": roster_valid})
				if not precommit_unchanged or not progress_matches or not deployment_matches:
					failure = "stage %d campaign growth was lost on transition" % (stage + 2)
					break
		if failure == "" and stop_after_stage == 18 and rows.size() == 19 - start_stage:
			await _check_finale(final_stage_progress_before)
	var formal_after := _formal_fingerprint()
	if formal_after != formal_before:
		failure = "formal save changed"
	_write_report(formal_after)
	get_tree().quit(0 if failure == "" and rows.size() == stop_after_stage - start_stage + 1 else 1)

func _play_stage(stage: int) -> bool:
	var battle: Node = get_tree().current_scene
	if battle == null or battle.stage_index != stage:
		failure = "wrong stage at %d" % (stage + 1)
		return false
	var start_ms := Time.get_ticks_msec()
	print("Natural probe: start stage ", stage + 1)
	var starting_roster: Array = battle._demo_snapshot().get("roster_selection", [])
	var start_units: int = battle.units.size()
	await _wait_visuals(battle)
	var start_image: Dictionary = await _capture_stage_image(stage, "start")
	if capture_stage_images and not start_image.get("ok", false):
		failure = "stage %d start image failed" % (stage + 1)
		return false
	var actions := 0
	while not battle.demo_clear and not battle.demo_defeat and battle.turn_number <= max_turns_per_stage and actions < MAX_ACTIONS_PER_STAGE:
		var turn_before: int = battle.turn_number
		var checkpoint_key := "%d:%d" % [stage, turn_before]
		if not checkpoint_keys.has(checkpoint_key) and (turn_before == 1 or (stage == 0 and turn_before == 8)):
			checkpoint_keys[checkpoint_key] = true
			battle = await _restart_checkpoint(battle)
			if battle == null:
				failure = "stage %d checkpoint restart/load failed" % (stage + 1)
				break
		if turn_before == 1 or turn_before % 5 == 0:
			print("Natural probe: stage ", stage + 1, " turn ", turn_before, " enemies ", battle._living_opponents(), " actions ", actions, " player_hp ", _player_hp(battle))
		await _wait_visuals(battle)
		if battle.demo_clear or battle.demo_defeat:
			break
		var changed := false
		var player_order := []
		for index in range(battle.opponent_unit_count, battle.opponent_unit_count + battle.player_unit_count):
			player_order.append(index)
		if stage == 4:
			player_order.reverse() # Clear the corridor before moving the objective unit.
		if stage == 8:
			player_order.reverse() # Free the side pocket and corridor before the objective unit moves.
		if stage == 16:
			player_order.pop_front()
			player_order.append(battle.opponent_unit_count) # Let the front line move before its escort.
		for index in player_order:
			if battle.demo_clear or battle.demo_defeat or battle.phase_playback_active:
				break
			if battle.unit_hp[index] <= 0 or battle.acted_unit_slots.has(index):
				continue
			if await _act_unit(battle, index):
				changed = true
				actions += 1
			await _wait_visuals(battle)
		if battle.demo_clear or battle.demo_defeat:
			break
		if battle.turn_number == turn_before and not battle.phase_playback_active and not battle.demo_clear and not battle.demo_defeat:
			battle._handle_key(KEY_ENTER)
			var menu_opened: bool = battle.system_menu_open
			battle._handle_key(KEY_A) # Normal All Rest command.
			if battle.phase_playback_active:
				battle._handle_key(KEY_A) # Normal playback fast-forward.
			await _wait_visuals(battle)
			if not battle.demo_clear and not battle.demo_defeat and (not menu_opened or battle.turn_number == turn_before):
				failure = "stage %d turn %d stalled; menu=%s mode=%s inspected=%d selected=%d" % [stage + 1, turn_before, str(menu_opened), battle.action_mode, battle.inspected_unit_index, battle.selected_unit_index]
				break
		if not changed and battle.turn_number >= max_turns_per_stage:
			break
	if battle == null:
		return false
	var won: bool = battle.demo_clear and not battle.demo_defeat
	await _wait_visuals(battle)
	var end_image: Dictionary = await _capture_stage_image(stage, "end")
	if capture_stage_images and not end_image.get("ok", false):
		failure = "stage %d end image failed" % (stage + 1)
		return false
	var living_units := []
	for index in battle.units.size():
		if battle.unit_hp[index] > 0:
			living_units.append({"index": index, "side": "enemy" if index < battle.opponent_unit_count else ("player" if index < battle.opponent_unit_count + battle.player_unit_count else "ally"), "type": battle.unit_type_ids[index], "x": battle.units[index].x, "y": battle.units[index].y, "hp": battle.unit_hp[index]})
	var row := {"stage": stage + 1, "won": won, "defeat": battle.demo_defeat, "turn": battle.turn_number, "actions": actions, "elapsed_ms": Time.get_ticks_msec() - start_ms, "players": battle.player_unit_count, "enemies": battle.opponent_unit_count, "allies": battle.group1_unit_count, "initial_units": start_units, "roster": starting_roster, "remaining_enemies": battle._living_opponents(), "living_units": living_units, "status": battle.status_message, "start_image": start_image, "end_image": end_image}
	if stage == 8:
		var terrain_rows := []
		for y in range(10, 24):
			var terrain_row := ""
			for x in range(4, 16):
				terrain_row += "." if battle._inspector_cell_passable(Vector2i(x, y)) else "#"
			terrain_rows.append({"y": y, "cells_x4_to_x15": terrain_row})
		row["terrain_window"] = terrain_rows
	rows.append(row)
	print(("PASS " if won else "STOP ") + "natural stage %02d, turn %d, actions %d, enemies %d" % [stage + 1, battle.turn_number, actions, battle._living_opponents()])
	if not won and failure == "":
		failure = "stage %d %s" % [stage + 1, "defeat" if battle.demo_defeat else "turn/action limit"]
	return won

func _restart_checkpoint(battle: Node) -> Node:
	await _wait_visuals(battle)
	var before: Dictionary = battle._demo_snapshot()
	battle._handle_key(KEY_ENTER)
	for unused in range(4): battle._handle_key(KEY_DOWN)
	battle._handle_key(KEY_A) # Save from the game system menu.
	var saved: Dictionary = DemoSave.read_snapshot()
	var saved_ok: bool = not saved.is_empty() and int(saved.get("stage", -1)) == battle.stage_index
	var checkpoint_file := "checkpoint-stage%02d-turn%03d.json" % [battle.stage_index + 1, battle.turn_number]
	var copied: bool = saved_ok and DirAccess.copy_absolute(DemoSave.save_path, output_dir.path_join(checkpoint_file)) == OK
	DemoSave.return_to_title = true
	get_tree().change_scene_to_file("res://scenes/intro.tscn") # Simulated app restart for save regression.
	var intro: Node = null
	for unused in range(10):
		await get_tree().process_frame
		intro = get_tree().current_scene
		if intro != null:
			break
	if intro == null or intro.scene_file_path != "res://scenes/intro.tscn":
		print("Checkpoint title transition failed: scene=", intro.scene_file_path if intro != null else "null")
		return null
	intro._advance() # Title -> menu.
	intro._move_selection(1) # Load item.
	intro._advance() # Normal title load.
	var loaded: Node = null
	for unused in range(10):
		await get_tree().process_frame
		loaded = get_tree().current_scene
		if loaded != null:
			break
	var loaded_ok: bool = loaded != null and loaded.has_method("_demo_snapshot") and JSON.stringify(before) == JSON.stringify(loaded._demo_snapshot())
	if not loaded_ok:
		var changed_fields := []
		if loaded != null and loaded.has_method("_demo_snapshot"):
			var after: Dictionary = loaded._demo_snapshot()
			for field in before:
				if JSON.stringify(before[field]) != JSON.stringify(after.get(field)):
					changed_fields.append(field)
		print("Checkpoint reload mismatch: scene=", loaded.scene_file_path if loaded != null else "null", " saved=", saved_ok, " copied=", copied, " fields=", changed_fields)
	var row := {"stage": before["stage"] + 1, "turn": before["turn"], "saved": saved_ok, "copied": copied, "checkpoint_file": checkpoint_file, "loaded": loaded_ok, "sha256": FileAccess.get_sha256(DemoSave.save_path) if saved_ok else ""}
	checkpoints.append(row)
	print(("PASS " if saved_ok and copied and loaded_ok else "FAIL ") + "title-load checkpoint stage %d turn %d" % [row["stage"], row["turn"]])
	return loaded if saved_ok and copied and loaded_ok else null

func _wait_for_scene() -> Node:
	for unused in range(10):
		await get_tree().process_frame
		if get_tree().current_scene != null:
			return get_tree().current_scene
	return null

func _check_defeat_retry(stage: int) -> void:
	var defeated: Node = get_tree().current_scene
	var before_progress: Dictionary = DemoSave.campaign_progress.snapshot()
	var defeated_turn: int = defeated.turn_number
	defeated._handle_key(KEY_B) # The visible retry command on the defeat panel.
	await get_tree().process_frame
	var retried: Node = get_tree().current_scene
	var same_stage: bool = retried != null and retried.has_method("_demo_snapshot") and retried.stage_index == stage
	var reset_turn: bool = same_stage and retried.turn_number == 1
	var progress_kept: bool = JSON.stringify(before_progress) == JSON.stringify(DemoSave.campaign_progress.snapshot())
	retry_check = {"stage": stage + 1, "defeated_turn": defeated_turn, "same_stage": same_stage, "reset_turn": reset_turn, "campaign_progress_kept": progress_kept, "passed": same_stage and reset_turn and progress_kept}
	print(("PASS " if retry_check["passed"] else "FAIL ") + "defeat/retry boundary")

func _check_finale(stage_progress_before: Dictionary) -> void:
	var battle: Node = get_tree().current_scene
	var expected_progress: Dictionary = battle._campaign_snapshot()
	var precommit_unchanged: bool = JSON.stringify(stage_progress_before) == JSON.stringify(DemoSave.campaign_progress.snapshot())
	var save_hash_before: String = FileAccess.get_sha256(DemoSave.save_path)
	battle._handle_key(KEY_A) # Confirm stage 19 victory.
	var ending: Node = await _wait_for_scene()
	var committed_progress: bool = JSON.stringify(expected_progress) == JSON.stringify(DemoSave.campaign_progress.snapshot())
	var victory_celebration: bool = ending != null and ending.scene_file_path == "res://scenes/rom_ending.tscn"
	if not victory_celebration:
		failure = "stage 19 did not enter victory celebration"
		return
	ending._handle_key(KEY_A) # Party scene -> thank-you card.
	var thanks_phase: bool = int(ending.get("phase")) == 1
	ending._handle_key(KEY_A) # Thank-you card -> completion record.
	var record_scene: Node = await _wait_for_scene()
	var record_opened: bool = record_scene != null and record_scene.scene_file_path == "res://scenes/campaign_ending.tscn"
	if not record_opened:
		failure = "victory celebration did not enter completion record"
		return
	var expected_campaign: Dictionary = record_scene.campaign.duplicate(true)
	var progress_matches: bool = JSON.stringify(expected_campaign) == JSON.stringify(DemoSave.completed_run.get("campaign", {}))
	record_scene._handle_key(KEY_RIGHT)
	var second_page: bool = record_scene.page == 1
	var save_unchanged_before_explicit: bool = save_hash_before == FileAccess.get_sha256(DemoSave.save_path)
	record_scene._handle_key(KEY_DOWN)
	record_scene._handle_key(KEY_A) # Explicit completion save.
	var saved: Dictionary = DemoSave.read_snapshot()
	var saved_valid: bool = DemoSave.valid_completion_snapshot(saved)
	record_scene._handle_key(KEY_B) # Return to title.
	var title: Node = await _wait_for_scene()
	var title_opened: bool = title != null and title.scene_file_path == "res://scenes/intro.tscn"
	var loaded_record := false
	var load_scene := ""
	var load_notice := ""
	var load_campaign_matches := false
	if title_opened:
		title._advance() # Title -> menu.
		title._move_selection(1)
		title._advance() # Load saved completion record.
		var loaded: Node = await _wait_for_scene()
		load_scene = loaded.scene_file_path if loaded != null else "null"
		if loaded != null and loaded.scene_file_path == "res://scenes/intro.tscn":
			load_notice = loaded.notice
		if loaded != null and loaded.scene_file_path == "res://scenes/campaign_ending.tscn":
			# JSON.parse_string normalizes integer arrays to the numeric form used
			# by the persisted JSON file before comparing the loaded record.
			load_campaign_matches = JSON.stringify(loaded.campaign) == JSON.stringify(JSON.parse_string(JSON.stringify(expected_campaign)))
		loaded_record = load_campaign_matches
	finale_check = {"precommit_unchanged": precommit_unchanged, "committed_progress": committed_progress, "save_unchanged_before_explicit": save_unchanged_before_explicit, "victory_celebration": victory_celebration, "thanks_phase": thanks_phase, "completion_record": record_opened, "campaign_matches": progress_matches, "page_navigation": second_page, "explicit_save": saved_valid, "title_opened": title_opened, "title_load": loaded_record, "load_scene": load_scene, "load_notice": load_notice, "load_campaign_matches": load_campaign_matches}
	if finale_check.values().has(false):
		failure = "stage 19 celebration/record/load check failed"
	print(("PASS " if failure == "" else "FAIL ") + "stage 19 celebration/record/title-load")

func _player_hp(battle: Node) -> Array:
	var hp := []
	for index in range(battle.opponent_unit_count, battle.opponent_unit_count + battle.player_unit_count):
		hp.append(battle.unit_hp[index])
	return hp

func _other_player_alive(battle: Node, excluded: int) -> bool:
	for index in range(battle.opponent_unit_count, battle.opponent_unit_count + battle.player_unit_count):
		if index != excluded and battle.unit_hp[index] > 0:
			return true
	return false

func _act_unit(battle: Node, index: int) -> bool:
	var origin: Vector2i = battle.units[index]
	if not _cursor_to(battle, origin):
		return false
	battle._handle_key(KEY_A)
	if not battle.command_open or battle.selected_unit_index != index:
		return false
	if battle.stage_index == 6 and index != battle.opponent_unit_count and battle._living_opponents() <= 2 and battle.unit_type_ids[battle.opponent_unit_count] == 5 and battle.unit_experience[battle.opponent_unit_count] < 220:
		for unused in range(3): battle._handle_key(KEY_DOWN)
		battle._handle_key(KEY_A) # Leave weakened enemies for the first slot to gain EXP.
		_log_action(battle, index, "training rest", origin)
		return battle.acted_unit_slots.has(index)
	if battle.stage_index == 0 and index == battle.opponent_unit_count and battle._living_opponents() > 2 and _other_player_alive(battle, index):
		for unused in range(3):
			battle._handle_key(KEY_DOWN)
		battle._handle_key(KEY_A) # Keep the defeat-critical first slot in reserve.
		_log_action(battle, index, "rest", origin)
		return battle.acted_unit_slots.has(index)
	if battle.stage_index == 4 and index == battle.opponent_unit_count and origin.y == 29 and _other_player_alive(battle, index) and battle._living_opponents() > 0:
		for unused in range(3): battle._handle_key(KEY_DOWN)
		battle._handle_key(KEY_A)
		_log_action(battle, index, "rest", origin)
		return battle.acted_unit_slots.has(index)
	if battle.stage_index == 4 and index == battle.opponent_unit_count and origin.y < 29 and _other_player_alive(battle, index) and battle._living_opponents() > 0:
		battle._handle_key(KEY_A)
		var retreat_cells: Dictionary = battle._reachable_move_cells()
		var retreat := origin
		for cell in retreat_cells:
			if cell.y > retreat.y or (cell.y == retreat.y and absi(cell.x - 7) < absi(retreat.x - 7)):
				retreat = cell
		if retreat != origin and _cursor_to(battle, retreat):
			battle._handle_key(KEY_A)
			_log_action(battle, index, "retreat", retreat)
			return battle.acted_unit_slots.has(index)
		battle._handle_key(KEY_B)
		return false
	if battle.stage_index == 5 and index == battle.opponent_unit_count and _defensive_action(battle, index):
		return true
	if battle.stage_index == 6 and index == battle.opponent_unit_count and battle._living_opponents() <= 7 and _defensive_action(battle, index):
		return true
	if battle.stage_index == 7 and index == battle.opponent_unit_count and _defensive_action(battle, index):
		return true
	if battle.stage_index == 11 and index == battle.opponent_unit_count:
		if battle.unit_hp[index] * 100 < battle._unit_max_hp(index) * 45 and _defensive_action(battle, index):
			return true
		if _move_to_stage_twelve_rear(battle, index):
			return true
	if battle.stage_index == 16 and index == battle.opponent_unit_count and _escort_stage_seventeen(battle, index):
		return true
	if battle.stage_index == 8 and index != battle.opponent_unit_count and (origin.x == 9 or origin.x == 10) and origin.y >= 17 and origin.y <= 24 and origin.y <= battle.units[battle.opponent_unit_count].y + 1 and _clear_stage_nine_corridor(battle, index):
		return true
	if battle.stage_index == 8 and index != battle.opponent_unit_count:
		var route_distances: Dictionary = _stage_nine_goal_distances(battle)
		var first_distance: int = int(route_distances.get(battle.units[battle.opponent_unit_count], 9999))
		var unit_distance: int = int(route_distances.get(origin, 9999))
		if unit_distance < first_distance and first_distance - unit_distance <= 5 and _move_to_stage_nine_goal(battle, index):
			return true
	var objective_blocked := false
	if battle.stage_index == 8 and index == battle.opponent_unit_count:
		if _defensive_action(battle, index):
			return true
		if _move_to_stage_nine_goal(battle, index):
			return true
		objective_blocked = true
	if battle.stage_index >= 6 and index == battle.opponent_unit_count and _other_player_alive(battle, index) and battle._living_opponents() > 0 and not (battle.stage_index == 6 and battle._living_opponents() <= 7) and battle.stage_index != 7 and battle.stage_index != 8 and battle.stage_index != 16:
		return _guard_first_action(battle, index)
	if _try_technique(battle, index, true):
		return true
	if not battle.command_open:
		return false
	if _try_technique(battle, index, false, true):
		return true
	if not battle.command_open:
		return false
	var targets: Array[int] = []
	for enemy in range(battle.opponent_unit_count):
		if battle.unit_hp[enemy] > 0 and _distance(origin, battle.units[enemy]) == 1:
			targets.append(enemy)
	if not targets.is_empty():
		targets.sort_custom(func(a: int, b: int) -> bool: return battle.unit_hp[a] < battle.unit_hp[b])
		battle._handle_key(KEY_DOWN)
		battle._handle_key(KEY_A) # Attack command.
		var target: int = targets[0]
		if not _cursor_to(battle, battle.units[target]):
			return false
		battle._handle_key(KEY_A)
		_log_action(battle, index, "attack", battle.units[target])
		return battle.acted_unit_slots.has(index) or battle.demo_clear
	if _try_technique(battle, index, false):
		return true
	if not battle.command_open:
		return false
	if objective_blocked:
		for unused in range(3): battle._handle_key(KEY_DOWN)
		battle._handle_key(KEY_A)
		_log_action(battle, index, "objective wait", origin)
		return battle.acted_unit_slots.has(index)
	battle._handle_key(KEY_A) # Move command.
	var reachable: Dictionary = battle._reachable_move_cells()
	var distances: Dictionary = _enemy_distance_map(battle)
	var preferred_range := 2 if skill_id_for_unit(battle, index) > 0 else 0
	if battle.stage_index == 7 and preferred_range > 0:
		for row in battle._technique_menu_rows():
			if bool(row["supported"]) and not bool(row["healing"]):
				preferred_range = maxi(preferred_range, int(row["packet"].get("maximum_range_cells", 0)))
	var best := origin
	var best_score := 999999
	for cell in reachable:
		if cell == origin:
			continue
		var distance_to_goal: int = _target_distance(battle, index, cell, distances)
		var score: int = _maze_attack_position_score(battle, cell, preferred_range, distance_to_goal, int(reachable[cell])) if battle.stage_index == 8 else (absi(distance_to_goal - preferred_range) if preferred_range > 0 else distance_to_goal) * 100 + int(reachable[cell])
		if score < best_score:
			best_score = score
			best = cell
	if best == origin:
		battle._handle_key(KEY_B)
		return false
	if not _cursor_to(battle, best):
		return false
	battle._handle_key(KEY_A)
	_log_action(battle, index, "move", best)
	return battle.acted_unit_slots.has(index) or battle.demo_clear

func skill_id_for_unit(battle: Node, index: int) -> int:
	var raw: Array = battle.rom_unit_records.get(battle.unit_type_ids[index], {}).get("raw_bytes", [])
	return int(raw[8]) if raw.size() > 8 else 0

func _maze_attack_position_score(battle: Node, cell: Vector2i, maximum_range: int, path_distance: int, steps: int) -> int:
	var attack_score := 9999
	for enemy in range(battle.opponent_unit_count):
		if battle.unit_hp[enemy] <= 0 or battle._unit_at_cell(battle.units[enemy]) != enemy:
			continue
		var distance: int = _distance(cell, battle.units[enemy])
		if distance == 1 or (maximum_range >= 2 and distance >= 2 and distance <= maximum_range):
			attack_score = mini(attack_score, (maximum_range - distance) * 10 + steps)
	if attack_score < 9999:
		return attack_score
	return 1000 + path_distance * 100 + steps

func _move_to_stage_nine_goal(battle: Node, index: int) -> bool:
	var distances: Dictionary = _stage_nine_goal_distances(battle)
	var origin: Vector2i = battle.units[index]
	var best := origin
	var best_distance: int = int(distances.get(origin, 9999))
	for cell in battle._reachable_move_cells():
		var distance: int = int(distances.get(cell, 9999))
		if distance < best_distance:
			best = cell
			best_distance = distance
	if best == origin:
		return false
	battle._handle_key(KEY_A) # Move command.
	if not _cursor_to(battle, best):
		return false
	battle._handle_key(KEY_A)
	_log_action(battle, index, "objective move", best)
	return battle.acted_unit_slots.has(index) or battle.demo_clear

func _clear_stage_nine_corridor(battle: Node, index: int) -> bool:
	battle._handle_key(KEY_A) # Move command.
	var origin: Vector2i = battle.units[index]
	var reachable: Dictionary = battle._reachable_move_cells()
	var best := origin
	var best_score := 99999
	for cell in reachable:
		if cell.x < 10 or cell.x < origin.x or cell == origin or cell.y > origin.y + 2:
			continue
		var score: int = (0 if cell.x > 10 else 100) + absi(cell.y - origin.y) * 10 + int(reachable[cell])
		if score < best_score:
			best = cell
			best_score = score
	if best == origin:
		battle._handle_key(KEY_B)
		return false
	if not _cursor_to(battle, best):
		return false
	battle._handle_key(KEY_A)
	_log_action(battle, index, "clear corridor", best)
	return battle.acted_unit_slots.has(index) or battle.demo_clear

func _stage_nine_goal_distances(battle: Node) -> Dictionary:
	var frontier: Array[Vector2i] = []
	var distances := {}
	for y in range(13):
		for x in range(12, 16):
			var cell := Vector2i(x, y)
			if battle._inspector_cell_passable(cell):
				distances[cell] = 0
				frontier.append(cell)
	var head := 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next_cell: Vector2i = cell + direction
			if distances.has(next_cell) or not battle._inspector_cell_passable(next_cell):
				continue
			distances[next_cell] = distances[cell] + 1
			frontier.append(next_cell)
	return distances

func _defensive_action(battle: Node, index: int) -> bool:
	var maximum: int = battle._unit_max_hp(index)
	if battle.unit_hp[index] * 100 < maximum * 55:
		defensive_slots[index] = true
	elif battle.unit_hp[index] * 100 >= maximum * 90:
		defensive_slots[index] = false
	if not bool(defensive_slots.get(index, false)):
		return false
	var distances: Dictionary = _enemy_distance_map(battle)
	var origin: Vector2i = battle.units[index]
	if int(distances.get(origin, 9999)) <= 2:
		battle._handle_key(KEY_A) # Move command, retreat from nearby enemies.
		var reachable: Dictionary = battle._reachable_move_cells()
		var best := origin
		var best_distance: int = int(distances.get(origin, 9999))
		for cell in reachable:
			var distance: int = int(distances.get(cell, 9999))
			if distance > best_distance:
				best = cell
				best_distance = distance
		if best != origin and _cursor_to(battle, best):
			battle._handle_key(KEY_A)
			_log_action(battle, index, "defensive move", best)
			return battle.acted_unit_slots.has(index)
		battle._handle_key(KEY_B)
		battle._handle_key(KEY_A)
		if not battle.command_open:
			return false
	for unused in range(3): battle._handle_key(KEY_DOWN)
	battle._handle_key(KEY_A) # Rest while outside attack range.
	_log_action(battle, index, "defensive rest", origin)
	return battle.acted_unit_slots.has(index)

func _move_to_stage_twelve_rear(battle: Node, index: int) -> bool:
	var origin: Vector2i = battle.units[index]
	var distances: Dictionary = battle._terrain_distances_from(Vector2i(9, 20))
	var best_distance: int = int(distances.get(origin, 9999))
	if best_distance == 0:
		return false
	battle._handle_key(KEY_A) # Move command.
	var reachable: Dictionary = battle._reachable_move_cells()
	var best := origin
	for cell in reachable:
		var distance: int = int(distances.get(cell, 9999))
		if distance < best_distance:
			best = cell
			best_distance = distance
	if best == origin:
		battle._handle_key(KEY_B)
		return false
	if not _cursor_to(battle, best):
		return false
	battle._handle_key(KEY_A)
	_log_action(battle, index, "rear route", best)
	return battle.acted_unit_slots.has(index)

func _escort_stage_seventeen(battle: Node, index: int) -> bool:
	var tank_index := index + 1
	if tank_index >= battle.units.size() or battle.unit_hp[tank_index] <= 0:
		return false
	var origin: Vector2i = battle.units[index]
	var tank: Vector2i = battle.units[tank_index]
	var separation := _distance(origin, tank)
	if origin.y >= tank.y and separation >= 1 and separation <= 3:
		for unused in range(3): battle._handle_key(KEY_DOWN)
		battle._handle_key(KEY_A)
		_log_action(battle, index, "escort rest", origin)
		return battle.acted_unit_slots.has(index)
	battle._handle_key(KEY_A) # Move command.
	var reachable: Dictionary = battle._reachable_move_cells()
	var best := origin
	var best_score := 999999
	for cell in reachable:
		if cell.y < tank.y or cell == tank:
			continue
		var distance_to_tank := _distance(cell, tank)
		var enemy_distance := _nearest_enemy_manhattan(battle, cell)
		var score: int = absi(distance_to_tank - 2) * 100 + (0 if cell.y > tank.y else 80)
		if enemy_distance < 3:
			score += (3 - enemy_distance) * 200
		if score < best_score:
			best = cell
			best_score = score
	if best != origin and _cursor_to(battle, best):
		battle._handle_key(KEY_A)
		_log_action(battle, index, "escort move", best)
		return battle.acted_unit_slots.has(index)
	battle._handle_key(KEY_B)
	battle._handle_key(KEY_A)
	if battle.command_open:
		for unused in range(3): battle._handle_key(KEY_DOWN)
		battle._handle_key(KEY_A)
		_log_action(battle, index, "escort rest", origin)
		return battle.acted_unit_slots.has(index)
	return false

func _guard_first_action(battle: Node, index: int) -> bool:
	var origin: Vector2i = battle.units[index]
	var nearest: int = _nearest_enemy_manhattan(battle, origin)
	if nearest <= 5:
		battle._handle_key(KEY_A) # Move away from the enemy approach.
		var reachable: Dictionary = battle._reachable_move_cells()
		var best := origin
		var best_distance := nearest
		for cell in reachable:
			var distance: int = _nearest_enemy_manhattan(battle, cell)
			if distance > best_distance:
				best = cell
				best_distance = distance
		if best != origin and _cursor_to(battle, best):
			battle._handle_key(KEY_A)
			_log_action(battle, index, "guard move", best)
			return battle.acted_unit_slots.has(index)
		battle._handle_key(KEY_B)
		battle._handle_key(KEY_A)
		if not battle.command_open:
			return false
	for unused in range(3): battle._handle_key(KEY_DOWN)
	battle._handle_key(KEY_A)
	_log_action(battle, index, "guard rest", origin)
	return battle.acted_unit_slots.has(index)

func _nearest_enemy_manhattan(battle: Node, cell: Vector2i) -> int:
	var nearest := 9999
	for enemy in range(battle.opponent_unit_count):
		if battle.unit_hp[enemy] > 0:
			nearest = mini(nearest, _distance(cell, battle.units[enemy]))
	return nearest

func _try_technique(battle: Node, index: int, healing_only: bool, area_only: bool = false) -> bool:
	var skill_id: int = battle._selected_technique_id()
	if skill_id <= 0:
		return false
	var rows: Array = battle._technique_menu_rows()
	var origin: Vector2i = battle.units[index]
	var chosen_row := -1
	var chosen_target := -1
	var chosen_score := -1
	var chosen_healing := false
	for row_index in rows.size():
		var row: Dictionary = rows[row_index]
		if not bool(row["supported"]) or bool(row["healing"]) != healing_only:
			continue
		var packet: Dictionary = row["packet"]
		if area_only and int(packet.get("area_code", 1)) == 1:
			continue
		var healing: bool = bool(row["healing"])
		var min_range: int = 0 if healing else battle._technique_minimum_range(skill_id)
		var max_range: int = int(packet.get("maximum_range_cells", 0))
		var magnitude: int = int(packet.get("effect_magnitude", 0))
		var first_target: int = battle.opponent_unit_count if healing else 0
		var last_target: int = battle.units.size() if healing else battle.opponent_unit_count
		for target_index in range(first_target, last_target):
			if battle.unit_hp[target_index] <= 0 or battle._unit_at_cell(battle.units[target_index]) != target_index:
				continue
			var distance := _distance(origin, battle.units[target_index])
			if distance < min_range or distance > max_range:
				continue
			var score := 0
			if healing:
				var missing: int = battle._unit_max_hp(target_index) - battle.unit_hp[target_index]
				if missing < 10:
					continue
				score = mini(magnitude, missing) + (100 if target_index == battle.opponent_unit_count else 0) + (25 if battle.unit_hp[target_index] * 2 < battle._unit_max_hp(target_index) else 0)
			else:
				for enemy in range(battle.opponent_unit_count):
					if battle.unit_hp[enemy] > 0 and battle._technique_area_contains(battle.units[target_index], battle.units[enemy], int(packet.get("area_code", 1))):
						score += mini(magnitude, battle.unit_hp[enemy]) + (50 if battle.unit_hp[enemy] <= magnitude else 0)
			if score > chosen_score:
				chosen_score = score
				chosen_row = row_index
				chosen_target = target_index
				chosen_healing = healing
	if chosen_row < 0:
		return false
	battle._handle_key(KEY_DOWN)
	battle._handle_key(KEY_DOWN)
	battle._handle_key(KEY_A) # Technique command.
	if not battle.technique_menu_open:
		return false
	while battle.technique_menu_index != chosen_row:
		battle._handle_key(KEY_DOWN if battle.technique_menu_index < chosen_row else KEY_UP)
	battle._handle_key(KEY_A) # Selected supported variant.
	if battle.action_mode != "technique":
		return false
	var target: Vector2i = battle.units[chosen_target]
	if not _cursor_to(battle, target):
		return false
	var turn_before: int = battle.turn_number
	var hp_before: int = battle.unit_hp[chosen_target]
	battle._handle_key(KEY_A)
	var applied: bool = battle.acted_unit_slots.has(index) or battle.demo_clear or battle.turn_number != turn_before or battle.unit_hp[chosen_target] != hp_before
	if applied:
		_log_action(battle, index, "heal" if chosen_healing else "technique", target)
	else:
		print("Technique rejected at stage ", battle.stage_index + 1, " unit ", index, ": ", battle.status_message)
		battle._handle_key(KEY_B)
		battle._handle_key(KEY_B)
	return applied

func _target_distance(battle: Node, index: int, origin: Vector2i, distances: Dictionary) -> int:
	if index == battle.opponent_unit_count:
		if battle.stage_index == 4: return _distance(origin, Vector2i(7, 29)) if _other_player_alive(battle, index) and battle._living_opponents() > 0 else _distance(origin, Vector2i(8, 14))
		if battle.stage_index == 5: return _distance(origin, Vector2i(8, 29))
		if battle.stage_index == 8: return _distance(origin, Vector2i(12, 12))
	return int(distances.get(origin, 9999))

func _enemy_distance_map(battle: Node) -> Dictionary:
	var frontier: Array[Vector2i] = []
	var distance := {}
	for enemy in range(battle.opponent_unit_count):
		if battle.unit_hp[enemy] > 0:
			var cell: Vector2i = battle.units[enemy]
			if not distance.has(cell):
				distance[cell] = 0
				frontier.append(cell)
	var head := 0
	while head < frontier.size():
		var cell: Vector2i = frontier[head]
		head += 1
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next_cell: Vector2i = cell + direction
			if distance.has(next_cell) or not battle._inspector_cell_passable(next_cell):
				continue
			distance[next_cell] = distance[cell] + 1
			frontier.append(next_cell)
	return distance

func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func _cursor_to(battle: Node, destination: Vector2i) -> bool:
	var attempts := 0
	while battle.cursor != destination and attempts < 100:
		var key: Key = KEY_RIGHT if battle.cursor.x < destination.x else (KEY_LEFT if battle.cursor.x > destination.x else (KEY_DOWN if battle.cursor.y < destination.y else KEY_UP))
		battle._handle_key(key)
		attempts += 1
	return battle.cursor == destination

func _wait_visuals(battle: Node) -> void:
	for unused in range(600):
		if not battle.is_inside_tree():
			return
		if battle.phase_playback_active:
			battle._handle_key(KEY_A)
		if battle.promotion_unit >= 0:
			var archer_choice: int = battle.promotion_choices.find(5)
			if archer_choice >= 0:
				for unused_choice in range(archer_choice): battle._handle_key(KEY_RIGHT)
			battle._handle_key(KEY_A) # Confirm a visible promotion choice.
		if battle.inspected_unit_index >= 0:
			battle._handle_key(KEY_B) # Close unit details.
		if not battle.phase_playback_active and not battle._cinematics_busy():
			return
		await get_tree().process_frame

func _capture_stage_image(stage: int, moment: String) -> Dictionary:
	if not capture_stage_images:
		return {}
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var filename := "stage%02d-%s.png" % [stage + 1, moment]
	var path := output_dir.path_join(filename)
	var saved: bool = not screenshot.is_empty() and screenshot.save_png(path) == OK
	return {"ok": saved, "file": filename, "width": screenshot.get_width(), "height": screenshot.get_height(), "sha256": FileAccess.get_sha256(path) if saved else ""}

func _log_action(battle: Node, index: int, kind: String, cell: Vector2i) -> void:
	action_log.append({"stage": battle.stage_index + 1, "turn": battle.turn_number, "unit": index, "kind": kind, "x": cell.x, "y": cell.y})

func _formal_fingerprint() -> Dictionary:
	if not FileAccess.file_exists(FORMAL_SAVE_PATH): return {"exists": false}
	return {"exists": true, "sha256": FileAccess.get_sha256(FORMAL_SAVE_PATH)}

func _write_report(formal_after: Dictionary) -> void:
	var completed: bool = failure == "" and rows.size() == stop_after_stage - start_stage + 1
	var result_label := "incomplete"
	if completed:
		result_label = "rehearsal_pass" if resume_source != "" else ("pass" if stop_after_stage == 18 else "partial_pass")
	var report := {"result": result_label, "resume_source": resume_source, "failure": failure, "godot_version": Engine.get_version_info().get("string", ""), "play_speed": play_speed, "formal_save_before": formal_before, "formal_save_after": formal_after, "stages": rows, "actions": action_log, "checkpoints": checkpoints, "transitions": transition_checks, "defeat_retry": retry_check, "finale": finale_check}
	var file := FileAccess.open(output_dir.path_join("natural-playthrough.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
