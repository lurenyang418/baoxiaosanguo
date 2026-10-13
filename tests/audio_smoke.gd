extends Node

## Captures the game's decoded tracks on the Master bus without recording user audio.

var output_dir := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	output_dir = OS.get_environment("BAOXIAO_AUDIO_TEST_DIR")
	var workspace := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if not output_dir.is_absolute_path() or not output_dir.simplify_path().begins_with(workspace + "/tmp/") or DirAccess.dir_exists_absolute(output_dir):
		push_error("BAOXIAO_AUDIO_TEST_DIR must be a fresh directory inside workspace tmp")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		get_tree().quit(2)
		return
	var master_index := AudioServer.get_bus_index("Master")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2.0
	var effect_index := AudioServer.get_bus_effect_count(master_index)
	AudioServer.add_bus_effect(master_index, capture)
	GameAudio.music_enabled = true # In-memory only; no settings file is changed.
	GameAudio.play_music("title")
	await get_tree().create_timer(0.7).timeout
	var music: Dictionary = _measure(capture)
	GameAudio.music_player.stop()
	capture.clear_buffer()
	GameAudio.play_effect("confirm")
	await get_tree().create_timer(0.7).timeout
	var effect: Dictionary = _measure(capture)
	for player in GameAudio.effect_players:
		player.stop()
		player.stream = null
	GameAudio.music_player.stream = null
	AudioServer.remove_bus_effect(master_index, effect_index)
	capture = null
	await get_tree().process_frame
	var passed: bool = music["frames"] > 0 and music["peak"] > 0.001 and effect["frames"] > 0 and effect["peak"] > 0.001
	var report := {"result": "pass" if passed else "fail", "godot_version": Engine.get_version_info().get("string", ""), "audio_driver": AudioServer.get_driver_name(), "music": music, "confirm_effect": effect, "scope": "Godot Master-bus sample capture; not acoustic listening"}
	var file := FileAccess.open(output_dir.path_join("audio-smoke.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  ") + "\n")
		file.close()
	print("PASS audio mixer capture" if passed else "FAIL audio mixer capture")
	get_tree().quit(0 if passed else 1)

func _measure(capture: AudioEffectCapture) -> Dictionary:
	var available := capture.get_frames_available()
	var samples := capture.get_buffer(available)
	var peak := 0.0
	var square_sum := 0.0
	for sample in samples:
		var level: float = maxf(absf(sample.x), absf(sample.y))
		peak = maxf(peak, level)
		square_sum += level * level
	return {"frames": samples.size(), "peak": peak, "rms": sqrt(square_sum / samples.size()) if not samples.is_empty() else 0.0, "discarded_frames": capture.get_discarded_frames()}
