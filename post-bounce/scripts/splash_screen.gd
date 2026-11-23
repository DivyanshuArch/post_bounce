class_name SplashScreen
extends Control

## Splash screen displaying Mithila Games studio presentation.
## Smoothly fades in, breathes, and transitions to Main Menu.
## Click or keypress skips directly to Main Menu.

@onready var logo: TextureRect = $CenterContainer/Logo
@onready var background: ColorRect = $Background

var skipped: bool = false

func _ready() -> void:
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.94, 0.94)
	logo.pivot_offset = logo.size * 0.5

	_start_splash_sequence()

func _start_splash_sequence() -> void:
	var tw := create_tween()
	# Fade in & gentle scale up
	tw.set_parallel(true)
	tw.tween_property(logo, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Hold
	tw.chain().tween_interval(1.1)

	# Fade out
	tw.chain().set_parallel(true)
	tw.tween_property(logo, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(logo, "scale", Vector2(1.04, 1.04), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	await tw.finished
	_go_to_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if skipped:
		return
	if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		skipped = true
		_go_to_main_menu()

func _go_to_main_menu() -> void:
	if skipped and get_tree().current_scene != self:
		return
	skipped = true
	if SceneManager:
		SceneManager.change_scene("res://scenes/main_menu.tscn", false, 0.35)
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
