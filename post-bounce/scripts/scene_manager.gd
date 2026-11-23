class_name SceneManagerNode
extends CanvasLayer

## Global Scene Transition Manager.
## Handles smooth fading, scene switching, and optional loading screen dispatch.

signal transition_started()
signal transition_finished()

var overlay: ColorRect
var current_target_scene: String = ""
var is_transitioning: bool = false

func _ready() -> void:
	layer = 100
	overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.08, 0.11, 0.09, 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = 0.0
	add_child(overlay)

func change_scene(target_path: String, use_loading_screen: bool = false, fade_time: float = 0.3) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	transition_started.emit()

	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	if use_loading_screen:
		current_target_scene = target_path
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")
	else:
		get_tree().change_scene_to_file(target_path)

	# Wait a frame for new scene ready
	await get_tree().process_frame

	var tw_in := create_tween()
	tw_in.tween_property(overlay, "modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_in.finished

	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false
	transition_finished.emit()

func fade_in(duration: float = 0.4) -> void:
	overlay.modulate.a = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out(duration: float = 0.4) -> void:
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
