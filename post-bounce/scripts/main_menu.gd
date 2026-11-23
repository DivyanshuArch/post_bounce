class_name MainMenu
extends Control

## Main Menu controller for Moonlit Ricochet / Post Bounce.
## Implements the exact layout and visual design from assets/references/Main-Menu.png.

@onready var start_btn: Button = %StartButton
@onready var multiplayer_btn: Button = %MultiplayerButton
@onready var settings_btn: Button = %SettingsButton

@onready var help_icon_btn: Button = %HelpIconButton
@onready var sound_icon_btn: Button = %SoundIconButton
@onready var gear_icon_btn: Button = %GearIconButton

@onready var best_score_label: Label = %BestScoreLabel
@onready var version_label: Label = %VersionLabel
@onready var logo_visual: Control = %LogoVisual

@onready var settings_modal: SettingsModal = $SettingsModal
@onready var help_modal: HelpModal = $HelpModal

var anim_t: float = 0.0

func _ready() -> void:
	# Button signals
	start_btn.pressed.connect(_on_start_pressed)
	multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)

	help_icon_btn.pressed.connect(_on_help_pressed)
	sound_icon_btn.pressed.connect(_on_sound_toggle_pressed)
	gear_icon_btn.pressed.connect(_on_settings_pressed)

	# Sound hover effects
	for btn in [start_btn, multiplayer_btn, settings_btn, help_icon_btn, sound_icon_btn, gear_icon_btn]:
		btn.mouse_entered.connect(func():
			if SoundManager:
				SoundManager.play_ui_hover()
		)

	# Logo animation
	if logo_visual:
		logo_visual.draw.connect(_on_draw_logo_emblem)

	# Best score
	_update_best_score_display()
	if GameSettings:
		GameSettings.best_score_updated.connect(func(_score): _update_best_score_display())
		_update_sound_icon(GameSettings.is_muted)

func _process(delta: float) -> void:
	anim_t += delta * 3.0
	if logo_visual:
		logo_visual.queue_redraw()

func _update_best_score_display() -> void:
	var score: int = 1420
	if GameSettings:
		score = GameSettings.best_score
	best_score_label.text = "BEST SCORE: %s" % _format_number(score)

func _format_number(n: int) -> String:
	var s := str(n)
	var res := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			res = "," + res
	return res

func _on_start_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	if SceneManager:
		SceneManager.change_scene("res://scenes/main.tscn", true, 0.3)
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_multiplayer_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	if SceneManager:
		SceneManager.change_scene("res://scenes/multiplayer_lobby.tscn", false, 0.25)
	else:
		get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")

func _on_settings_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	settings_modal.open()

func _on_help_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	help_modal.open()

func _on_sound_toggle_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	var muted: bool = false
	if GameSettings:
		muted = GameSettings.toggle_mute()
	elif SoundManager:
		muted = SoundManager.toggle_mute()
	_update_sound_icon(muted)

const ICON_SOUND_ON = preload("res://assets/icons/icon_sound_on.svg")
const ICON_SOUND_OFF = preload("res://assets/icons/icon_sound_off.svg")

func _update_sound_icon(muted: bool) -> void:
	if is_instance_valid(sound_icon_btn):
		sound_icon_btn.icon = ICON_SOUND_OFF if muted else ICON_SOUND_ON
		sound_icon_btn.text = ""


func _on_draw_logo_emblem() -> void:
	var center := logo_visual.size * 0.5
	var bounce_point := center + Vector2(0.0, 14.0)
	var left_point := center + Vector2(-46.0, -8.0)
	var right_point := center + Vector2(46.0, -8.0)

	# Platform line
	logo_visual.draw_line(bounce_point + Vector2(-22.0, 0.0), bounce_point + Vector2(22.0, 0.0), Color(0.48, 0.62, 0.52, 0.8), 2.5)

	# Dashed ricochet path
	logo_visual.draw_dashed_line(left_point, bounce_point, Color(0.42, 0.54, 0.46, 0.45), 1.5, 4.0)
	logo_visual.draw_dashed_line(bounce_point, right_point, Color(0.42, 0.54, 0.46, 0.45), 1.5, 4.0)

	# Bouncing ball along trajectory
	var cycle := fmod(anim_t, 2.0)
	var ball_pos: Vector2
	var ball_scale := Vector2.ONE

	if cycle < 1.0:
		var u := cycle
		ball_pos = left_point.lerp(bounce_point, u)
		if u > 0.85:
			ball_scale = Vector2(1.25, 0.75)
	else:
		var u := cycle - 1.0
		ball_pos = bounce_point.lerp(right_point, u)
		if u < 0.15:
			ball_scale = Vector2(0.75, 1.25)

	# Draw glowing ball
	logo_visual.draw_circle(ball_pos, 7.5 * ball_scale.x, Color(0.95, 0.96, 0.94, 0.25))
	logo_visual.draw_circle(ball_pos, 5.0 * ball_scale.x, Color(0.96, 0.95, 0.92, 1.0))
