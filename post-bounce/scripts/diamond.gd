class_name Diamond
extends Node2D

## Glowing yellow diamond along bank-shot lanes.

signal collected_signal(diamond: Diamond)

@export var bob_speed: float = 2.3
@export var bob_height: float = 2.5
@export var phase_offset: float = 0.0

var is_collected: bool = false
var time_elapsed: float = 0.0

func _ready() -> void:
	if phase_offset == 0.0:
		phase_offset = randf() * TAU

func _process(delta: float) -> void:
	if is_collected:
		return
	time_elapsed += delta
	queue_redraw()

func collect() -> void:
	if is_collected:
		return
	is_collected = true
	collected_signal.emit(self)
	queue_redraw()

func _draw() -> void:
	if is_collected:
		return

	var pulse: float = 0.5 + 0.5 * sin(time_elapsed * 2.7 + phase_offset)
	var bob: float = sin(time_elapsed * bob_speed + phase_offset) * bob_height
	var center := Vector2(0.0, bob)

	# 1. Outer translucent golden aura
	var aura_r: float = 16.0 + pulse * 4.0
	var col_outer := Color(0.98, 0.89, 0.4, 0.17 + pulse * 0.08)
	draw_circle(center, aura_r, col_outer)

	var col_inner := Color(0.98, 0.89, 0.4, 0.28)
	draw_circle(center, aura_r * 0.54, col_inner)

	# 2. Tilted geometric diamond
	var rot: float = sin(time_elapsed * 1.4 + phase_offset) * 0.15
	var xform := Transform2D(rot, center)

	var core_pts: PackedVector2Array = [
		xform * Vector2(0.0, -8.0),
		xform * Vector2(6.0, 0.0),
		xform * Vector2(0.0, 8.0),
		xform * Vector2(-6.0, 0.0)
	]
	draw_colored_polygon(core_pts, Palette.DIAMOND_CORE)

	var hl_pts: PackedVector2Array = [
		xform * Vector2(0.0, -4.2),
		xform * Vector2(2.8, 0.0),
		xform * Vector2(0.0, 1.8),
		xform * Vector2(-2.2, -0.8)
	]
	draw_colored_polygon(hl_pts, Palette.DIAMOND_HIGHLIGHT)
