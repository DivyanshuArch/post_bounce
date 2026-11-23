@tool
class_name TreePine
extends Node2D

## Top-down tiered pine tree perched on wall ledges.
## Marked @tool so it renders live in the Godot 2D editor.

@export var tree_scale: float = 1.0:
	set(val):
		tree_scale = val
		_regenerate_tiers()
		queue_redraw()

@export var seed_val: int = 0:
	set(val):
		seed_val = val
		_regenerate_tiers()
		queue_redraw()

var sway_phase: float = 0.0
var time_elapsed: float = 0.0
var tiers: Array[Dictionary] = []

func _ready() -> void:
	if seed_val == 0:
		seed_val = int(abs(global_position.x * 73.0 + global_position.y * 31.0)) & 0x7FFFFFFF
	sway_phase = randf() * TAU
	_regenerate_tiers()
	queue_redraw()

func _regenerate_tiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 12345
	var base_r: float = 26.0 * tree_scale
	var rot0: float = rng.randf() * TAU

	tiers = [
		{
			"pts": GeometryUtils.make_pine_tier_polygon(rng, 7, base_r, base_r * 0.55, rot0),
			"color": Palette.PINE_DARK
		},
		{
			"pts": GeometryUtils.make_pine_tier_polygon(rng, 6, base_r * 0.72, base_r * 0.42, rot0 + 0.42),
			"color": Palette.PINE_MID
		},
		{
			"pts": GeometryUtils.make_pine_tier_polygon(rng, 5, base_r * 0.44, base_r * 0.24, rot0 + 0.85),
			"color": Palette.PINE_LIGHT
		}
	]

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time_elapsed += delta
	queue_redraw()

func _draw() -> void:
	if tiers.is_empty():
		_regenerate_tiers()

	# 1. Ground drop shadow
	var shadow_offset := Vector2(8.0 * tree_scale, 10.0 * tree_scale)
	draw_set_transform(shadow_offset, 0.25, Vector2(1.2, 0.95))
	draw_circle(Vector2.ZERO, 19.0 * tree_scale, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Canopies with wind sway
	var wind_x: float = sin(time_elapsed * 1.35 + sway_phase) * 1.2 if not Engine.is_editor_hint() else 0.0
	var wind_y: float = cos(time_elapsed * 1.1 + sway_phase) * 0.8 if not Engine.is_editor_hint() else 0.0

	for k in range(tiers.size()):
		var tier: Dictionary = tiers[k]
		var offset := Vector2(wind_x * (float(k) * 0.45), wind_y * (float(k) * 0.45))
		var pts: PackedVector2Array = tier["pts"]
		var shifted_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shifted_pts.append(p + offset)

		draw_colored_polygon(shifted_pts, tier["color"])
		if k > 0:
			var contour_col := Color(0.498, 0.58, 0.518, 0.2)
			var loop_pts := shifted_pts.duplicate()
			loop_pts.append(shifted_pts[0])
			draw_polyline(loop_pts, contour_col, 1.0, true)
