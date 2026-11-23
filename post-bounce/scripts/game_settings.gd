class_name GameSettingsNode
extends Node

## Global Game Settings and persistent state for Moonlit Ricochet / Post Bounce.
## Handles audio volumes, controls sensitivity, trajectory preferences, screen shake,
## and player high scores stored in user://settings.cfg.

signal settings_changed()
signal best_score_updated(new_score: int)

const CONFIG_PATH := "user://settings.cfg"

var sfx_volume: float = 1.0
var music_volume: float = 0.8
var is_muted: bool = false

var aim_sensitivity: float = 1.0
var trajectory_mode: String = "FULL" # "FULL", "SHORT", "OFF"
var screen_shake_enabled: bool = true
var photon_app_id: String = ""

var best_score: int = 1420

func _ready() -> void:
	load_settings()

func set_sfx_volume(val: float) -> void:
	sfx_volume = clampf(val, 0.0, 1.0)
	_apply_audio_settings()

func set_music_volume(val: float) -> void:
	music_volume = clampf(val, 0.0, 1.0)
	_apply_audio_settings()

func set_muted(muted: bool) -> void:
	is_muted = muted
	_apply_audio_settings()

func toggle_mute() -> bool:
	set_muted(not is_muted)
	return is_muted

func set_aim_sensitivity(val: float) -> void:
	aim_sensitivity = clampf(val, 0.25, 2.0)

func set_trajectory_mode(mode: String) -> void:
	if mode in ["FULL", "SHORT", "OFF"]:
		trajectory_mode = mode

func set_screen_shake(enabled: bool) -> void:
	screen_shake_enabled = enabled

func record_score(score: int) -> void:
	if score > best_score:
		best_score = score
		best_score_updated.emit(best_score)
		save_settings()

func _apply_audio_settings() -> void:
	if SoundManager and SoundManager.has_method("update_volume_settings"):
		SoundManager.update_volume_settings(sfx_volume, music_volume, is_muted)
	settings_changed.emit()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "is_muted", is_muted)

	cfg.set_value("controls", "aim_sensitivity", aim_sensitivity)
	cfg.set_value("controls", "trajectory_mode", trajectory_mode)

	cfg.set_value("gameplay", "screen_shake_enabled", screen_shake_enabled)
	cfg.set_value("gameplay", "best_score", best_score)
	cfg.set_value("network", "photon_app_id", photon_app_id)

	cfg.save(CONFIG_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		_apply_audio_settings()
		return

	sfx_volume = float(cfg.get_value("audio", "sfx_volume", 1.0))
	music_volume = float(cfg.get_value("audio", "music_volume", 0.8))
	is_muted = bool(cfg.get_value("audio", "is_muted", false))

	aim_sensitivity = float(cfg.get_value("controls", "aim_sensitivity", 1.0))
	trajectory_mode = str(cfg.get_value("controls", "trajectory_mode", "FULL"))

	screen_shake_enabled = bool(cfg.get_value("gameplay", "screen_shake_enabled", true))
	best_score = int(cfg.get_value("gameplay", "best_score", 1420))
	photon_app_id = str(cfg.get_value("network", "photon_app_id", ""))

	_apply_audio_settings()
