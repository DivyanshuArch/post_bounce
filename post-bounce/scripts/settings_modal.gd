class_name SettingsModal
extends Control

## Settings dialog matching the Post Bounce reference layout.
## Controls Audio (SFX, Music), Controls (Aim Sensitivity, Trajectory Mode),
## and Gameplay (Screen Shake).

signal closed()

@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sens_slider: HSlider = %SensitivitySlider

@onready var traj_full_btn: Button = %TrajFullBtn
@onready var traj_short_btn: Button = %TrajShortBtn
@onready var traj_off_btn: Button = %TrajOffBtn

@onready var shake_toggle: CheckButton = %ShakeToggle
@onready var close_btn: Button = %CloseBtn
@onready var apply_btn: Button = %ApplyBtn
@onready var panel_card: PanelContainer = %PanelCard

var current_trajectory: String = "FULL"

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)
	apply_btn.pressed.connect(_on_apply_pressed)

	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sens_slider.value_changed.connect(_on_sens_changed)

	traj_full_btn.pressed.connect(func(): _set_trajectory_mode("FULL"))
	traj_short_btn.pressed.connect(func(): _set_trajectory_mode("SHORT"))
	traj_off_btn.pressed.connect(func(): _set_trajectory_mode("OFF"))

	shake_toggle.toggled.connect(_on_shake_toggled)

	_sync_from_settings()

func open() -> void:
	visible = true
	_sync_from_settings()
	panel_card.scale = Vector2(0.92, 0.92)
	panel_card.modulate.a = 0.0
	panel_card.pivot_offset = panel_card.size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel_card, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

func close() -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(panel_card, "scale", Vector2(0.92, 0.92), 0.18).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel_card, "modulate:a", 0.0, 0.18).set_trans(Tween.TRANS_SINE)
	await tw.finished
	visible = false
	closed.emit()

func _sync_from_settings() -> void:
	if not GameSettings:
		return
	sfx_slider.value = GameSettings.sfx_volume * 100.0
	music_slider.value = GameSettings.music_volume * 100.0
	sens_slider.value = GameSettings.aim_sensitivity * 100.0
	shake_toggle.button_pressed = GameSettings.screen_shake_enabled
	_set_trajectory_mode(GameSettings.trajectory_mode)

func _on_sfx_changed(val: float) -> void:
	if GameSettings:
		GameSettings.set_sfx_volume(val / 100.0)

func _on_music_changed(val: float) -> void:
	if GameSettings:
		GameSettings.set_music_volume(val / 100.0)

func _on_sens_changed(val: float) -> void:
	if GameSettings:
		GameSettings.set_aim_sensitivity(val / 100.0)

func _on_shake_toggled(enabled: bool) -> void:
	if GameSettings:
		GameSettings.set_screen_shake(enabled)

func _set_trajectory_mode(mode: String) -> void:
	current_trajectory = mode
	if GameSettings:
		GameSettings.set_trajectory_mode(mode)

	# Update visual highlights
	_style_traj_button(traj_full_btn, mode == "FULL")
	_style_traj_button(traj_short_btn, mode == "SHORT")
	_style_traj_button(traj_off_btn, mode == "OFF")

func _style_traj_button(btn: Button, active: bool) -> void:
	if active:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		btn.modulate = Color(0.65, 0.75, 0.7, 0.65)

func _on_close_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	close()

func _on_apply_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	if GameSettings:
		GameSettings.save_settings()
	close()
