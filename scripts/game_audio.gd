extends Node

const MUSIC := {
	"title": "res://assets/audio/nsf_00.mp3",
	"battle": "res://assets/audio/nsf_01.mp3",
}
const EFFECTS := {
	"cursor": "res://assets/audio/nsf_10.mp3",
	"confirm": "res://assets/audio/nsf_11.mp3",
	"cancel": "res://assets/audio/nsf_12.mp3",
	"move": "res://assets/audio/nsf_17.mp3",
	"attack": "res://assets/audio/nsf_18.mp3",
	"turn": "res://assets/audio/nsf_24.mp3",
}
const EFFECT_GAIN_DB := {
	"cursor": 18.0,
	"confirm": 18.0,
	"cancel": 12.0,
	"move": 8.0,
	"attack": 0.0,
	"turn": 8.0,
}

var music_enabled := true
var current_music := ""
var music_player := AudioStreamPlayer.new()
var effect_players: Array[AudioStreamPlayer] = []
var effect_index := 0

func _ready() -> void:
	add_child(music_player)
	music_player.volume_db = -3.0
	for index in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = 0.0
		add_child(player)
		effect_players.append(player)
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		music_enabled = bool(config.get_value("audio", "music_enabled", true))

func play_music(name: String) -> void:
	if name == current_music and music_player.playing:
		return
	current_music = name
	music_player.stop()
	if not MUSIC.has(name):
		return
	var clip := load(MUSIC[name]) as AudioStreamMP3
	if clip == null:
		return
	clip.loop = true
	music_player.stream = clip
	if music_enabled:
		music_player.play()

func play_effect(name: String) -> void:
	if not EFFECTS.has(name):
		return
	var clip := load(EFFECTS[name]) as AudioStreamMP3
	if clip == null:
		return
	var player := effect_players[effect_index]
	effect_index = (effect_index + 1) % effect_players.size()
	player.stop()
	player.volume_db = float(EFFECT_GAIN_DB.get(name, 0.0))
	player.stream = clip
	player.play()

func toggle_music() -> bool:
	music_enabled = not music_enabled
	if music_enabled:
		if music_player.stream != null:
			music_player.play()
	else:
		music_player.stop()
	var config := ConfigFile.new()
	config.set_value("audio", "music_enabled", music_enabled)
	config.save("user://settings.cfg")
	return music_enabled
