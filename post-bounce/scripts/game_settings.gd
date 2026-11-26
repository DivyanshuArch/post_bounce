class_name GameSettingsNode
extends Node

## Global Game Settings and persistent state for Moonlit Ricochet / Post Bounce.
## Handles audio volumes, controls sensitivity, trajectory preferences, screen shake,
## and player high scores stored in user://settings.cfg.

signal settings_changed()
signal best_score_updated(new_score: int)
signal gems_changed(new_amount: int)
signal skin_equipped(skin_id: String)
signal progression_updated()

const CONFIG_PATH := "user://settings.cfg"

var sfx_volume: float = 1.0
var music_volume: float = 0.8
var is_muted: bool = false

var aim_sensitivity: float = 1.0
var trajectory_mode: String = "FULL" # "FULL", "SHORT", "OFF"
var screen_shake_enabled: bool = true
var photon_app_id: String = ""

var best_score: int = 1420

# Economy & Progression
var gems: int = 50
var equipped_skin: String = "moonlit_pearl"
var unlocked_skins: Array = ["moonlit_pearl"]
var unlocked_level: int = 1
var level_stars: Dictionary = {} # level_int -> stars_int (0..3)
var level_best_shots: Dictionary = {} # level_int -> shots_int

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

func add_gems(amount: int) -> void:
	if amount > 0:
		gems += amount
		gems_changed.emit(gems)
		save_settings()

func spend_gems(amount: int) -> bool:
	if amount <= gems:
		gems -= amount
		gems_changed.emit(gems)
		save_settings()
		return true
	return false

func is_skin_unlocked(skin_id: String) -> bool:
	return unlocked_skins.has(skin_id) or skin_id == "moonlit_pearl"

func unlock_skin(skin_id: String) -> bool:
	if not unlocked_skins.has(skin_id):
		unlocked_skins.append(skin_id)
		save_settings()
		return true
	return false

func equip_skin(skin_id: String) -> void:
	if is_skin_unlocked(skin_id):
		equipped_skin = skin_id
		skin_equipped.emit(skin_id)
		save_settings()

func record_level_completion(level_num: int, shots: int, stars: int) -> void:
	var l_str := str(level_num)
	var prev_stars: int = int(level_stars.get(l_str, 0))
	var prev_shots: int = int(level_best_shots.get(l_str, 9999))

	if stars > prev_stars:
		level_stars[l_str] = stars
	if shots < prev_shots:
		level_best_shots[l_str] = shots

	# Unlock next level
	if level_num >= unlocked_level:
		unlocked_level = level_num + 1

	progression_updated.emit()
	save_settings()

func get_newest_incomplete_level() -> int:
	# Returns the 1-based index of the newest incomplete level
	for lvl in range(1, unlocked_level + 1):
		var stars: int = int(level_stars.get(str(lvl), 0))
		if stars == 0:
			return lvl
	return unlocked_level

func get_total_stars() -> int:
	var total: int = 0
	for k in level_stars:
		total += int(level_stars[k])
	return total

func get_level_stars(level_num: int) -> int:
	return int(level_stars.get(str(level_num), 0))

func get_level_best_shots(level_num: int) -> int:
	return int(level_best_shots.get(str(level_num), 0))

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

	# Economy & Progression
	cfg.set_value("progression", "gems", gems)
	cfg.set_value("progression", "equipped_skin", equipped_skin)
	cfg.set_value("progression", "unlocked_skins", unlocked_skins)
	cfg.set_value("progression", "unlocked_level", unlocked_level)
	cfg.set_value("progression", "level_stars", level_stars)
	cfg.set_value("progression", "level_best_shots", level_best_shots)

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

	# Economy & Progression
	gems = int(cfg.get_value("progression", "gems", 50))
	equipped_skin = str(cfg.get_value("progression", "equipped_skin", "moonlit_pearl"))
	unlocked_skins = Array(cfg.get_value("progression", "unlocked_skins", ["moonlit_pearl"]))
	if not unlocked_skins.has("moonlit_pearl"):
		unlocked_skins.append("moonlit_pearl")
	unlocked_level = maxi(1, int(cfg.get_value("progression", "unlocked_level", 1)))
	level_stars = Dictionary(cfg.get_value("progression", "level_stars", {}))
	level_best_shots = Dictionary(cfg.get_value("progression", "level_best_shots", {}))

	_apply_audio_settings()

