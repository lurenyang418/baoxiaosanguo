extends Node

## Native Godot save for the playable campaign prototype, separate from NES saves.

const SAVE_VERSION := 1
var save_path := "user://bao_xiao_san_guo_demo_progress.json"
var pending_snapshot: Dictionary = {}
var completed_run: Dictionary = {}
var return_to_title := false
var last_error := ""
var prebattle_stage := 10
var roster_selection: Array[int] = []
var difficulty_index := 0
var campaign_progress = preload("res://scripts/campaign_progress.gd").new()

func _ready() -> void:
	var regression_path := OS.get_environment("BAOXIAO_REGRESSION_SAVE_PATH")
	if regression_path == "":
		return
	var workspace_dir := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var regression_root := OS.get_environment("BAOXIAO_REGRESSION_SAVE_ROOT")
	if regression_root == "":
		regression_root = workspace_dir.path_join("tmp")
	if not regression_root.is_absolute_path() or not regression_path.is_absolute_path() or not regression_path.simplify_path().begins_with(regression_root.simplify_path().trim_suffix("/") + "/"):
		save_path = ""
		push_error("BAOXIAO_REGRESSION_SAVE_PATH must be an absolute path inside the regression save root")
		get_tree().quit(2)
		return
	save_path = regression_path

func roster_limit(stage: int) -> int:
	var file := FileAccess.open("res://data/rom_roster_selection_limits.json", FileAccess.READ)
	if file == null:
		return 0
	var data: Variant = JSON.parse_string(file.get_as_text())
	if not (data is Dictionary):
		return 0
	for record in data.get("records", []):
		if int(record.get("stage_index", -1)) == stage:
			return int(record.get("max_selected_units", 0))
	return 0

func valid_roster_selection(stage: int, selection: Array) -> bool:
	var limit := roster_limit(stage)
	if limit <= 0 or selection.is_empty() or selection.size() > limit:
		return false
	var seen := {}
	for value in selection:
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		var index := int(value)
		if float(value) != float(index) or index < 0 or index >= 20 or seen.has(index):
			return false
		seen[index] = true
	return true

func selected_roster_for_stage(stage: int) -> Array[int]:
	if valid_roster_selection(stage, roster_selection):
		return roster_selection.duplicate()
	var result: Array[int] = []
	for index in range(roster_limit(stage)):
		result.append(index)
	return result

func write_snapshot(snapshot: Dictionary) -> bool:
	last_error = ""
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入存档"
		return false
	file.store_string(JSON.stringify(snapshot, "  ") + "\n")
	file.flush()
	var failed := file.get_error() != OK
	file.close()
	if failed:
		last_error = "存档写入失败"
	return not failed

func read_snapshot() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(save_path):
		last_error = "尚无演示存档"
		return {}
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "无法读取存档"
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		last_error = "存档格式不兼容"
		return {}
	var value: Variant = parser.data
	if not (value is Dictionary) or int(value.get("version", -1)) != SAVE_VERSION:
		last_error = "存档格式不兼容"
		return {}
	return value

func completion_snapshot() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"stage": 18,
		"completed": true,
		"campaign": campaign_progress.snapshot(),
	}

func valid_completion_snapshot(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for field in [value.get("version"), value.get("stage")]:
		if not (typeof(field) in [TYPE_INT, TYPE_FLOAT]) or float(field) != float(int(field)):
			return false
	return int(value["version"]) == SAVE_VERSION and int(value["stage"]) == 18 and value.get("completed") is bool and value["completed"] and campaign_progress.valid_snapshot(value.get("campaign"))

func scene_for_stage(stage: int) -> String:
	if stage == 0:
		return "res://scenes/battle.tscn"
	if stage >= 1 and stage <= 18:
		return "res://scenes/battle_stage%d.tscn" % stage
	return ""
