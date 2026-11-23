class_name HelpModal
extends Control

## How-to-play overlay guide explaining slingshot aiming, ricocheting, and course goals.

signal closed()

@onready var close_btn: Button = %CloseBtn
@onready var panel_card: PanelContainer = %PanelCard

func _ready() -> void:
	close_btn.pressed.connect(_on_close_pressed)

func open() -> void:
	visible = true
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

func _on_close_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	close()
