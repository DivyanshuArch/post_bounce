class_name LoadingScreen
extends Control

## Asynchronous loading screen with ricochet bounce visual and gameplay tips.

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var percent_label: Label = %PercentLabel
@onready var tip_label: Label = %TipLabel
@onready var ricochet_canvas: Control = %RicochetVisual

var target_scene_path: String = "res://scenes/main.tscn"
var progress: Array = []
var min_display_time: float = 0.8
var time_elapsed: float = 0.0
var load_complete: bool = false
var anim_t: float = 0.0

var tips: Array[String] = [
	"Tip: Drag back to aim - release to unleash your ricochet.",
	"Tip: Use wall bounces to navigate around difficult obstacles.",
	"Tip: Collect golden diamonds to maximize your level score.",
	"Tip: Turn on Mobile Hotspot to play multiplayer anywhere without a router!",
	"Tip: Fewer shots taken means higher ranking and glory.",
	"Tip: Right-click or press Escape while aiming to cancel a shot."
]

func _ready() -> void:
	if SceneManager and not SceneManager.current_target_scene.is_empty():
		target_scene_path = SceneManager.current_target_scene

	# Pick random tip
	randomize()
	tip_label.text = tips[randi() % tips.size()]

	progress_bar.value = 0.0
	percent_label.text = "0%"

	ResourceLoader.load_threaded_request(target_scene_path)
	ricochet_canvas.draw.connect(_on_draw_ricochet)

func _process(delta: float) -> void:
	time_elapsed += delta
	anim_t += delta * 4.0
	ricochet_canvas.queue_redraw()

	var status = ResourceLoader.load_threaded_get_status(target_scene_path, progress)
	var real_progress: float = 0.0
	if not progress.is_empty():
		real_progress = progress[0]

	# Smoothly interpolate progress bar
	var visual_target := real_progress
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		visual_target = 1.0

	var cur_val: float = progress_bar.value / 100.0
	var new_val := lerpf(cur_val, visual_target, delta * 8.0)
	progress_bar.value = new_val * 100.0
	percent_label.text = "%d%%" % int(new_val * 100.0)

	if status == ResourceLoader.THREAD_LOAD_LOADED and time_elapsed >= min_display_time and not load_complete:
		if progress_bar.value >= 98.0:
			load_complete = true
			_finish_loading()

func _finish_loading() -> void:
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(target_scene_path)
	if packed_scene:
		get_tree().change_scene_to_packed(packed_scene)
	else:
		get_tree().change_scene_to_file(target_scene_path)

func _on_draw_ricochet() -> void:
	# Draw animated bouncing ball between two points
	var center := ricochet_canvas.size * 0.5
	var p0 := center + Vector2(-60.0, 10.0)
	var p_bounce := center + Vector2(0.0, 30.0)
	var p1 := center + Vector2(60.0, -10.0)

	# Trajectory guide lines
	ricochet_canvas.draw_dashed_line(p0, p_bounce, Color(0.48, 0.58, 0.52, 0.4), 2.0, 6.0)
	ricochet_canvas.draw_dashed_line(p_bounce, p1, Color(0.48, 0.58, 0.52, 0.4), 2.0, 6.0)

	# Mini bounce pad
	ricochet_canvas.draw_line(p_bounce + Vector2(-24.0, 0.0), p_bounce + Vector2(24.0, 0.0), Color(0.55, 0.72, 0.62, 0.7), 3.0)

	# Bouncing ball position along cycle
	var cycle := fmod(anim_t, 2.0) # 0 to 2
	var ball_pos: Vector2
	var ball_scale := Vector2.ONE

	if cycle < 1.0:
		var u := cycle
		ball_pos = p0.lerp(p_bounce, u)
		if u > 0.85:
			# Squash on impact
			ball_scale = Vector2(1.3, 0.7)
	else:
		var u := cycle - 1.0
		ball_pos = p_bounce.lerp(p1, u)
		if u < 0.15:
			# Stretch leaving impact
			ball_scale = Vector2(0.7, 1.3)

	# Draw ball with soft glow
	ricochet_canvas.draw_circle(ball_pos, 10.0 * ball_scale.x, Color(0.95, 0.96, 0.94, 0.2))
	ricochet_canvas.draw_circle(ball_pos, 7.0 * ball_scale.x, Color(0.96, 0.95, 0.92, 1.0))
