@tool
class_name TreeBirch
extends Node2D

## Top-down leaning birch tree with striped white trunk and twin canopies.
## Marked @tool so it renders live in the Godot 2D editor.

@export var tree_scale: float = 1.0:
	set(val):
		tree_scale = val
		_regenerate()
		queue_redraw()

@export var seed_val: int = 0:
	set(val):
		seed_val = val
		_regenerate()
		queue_redraw()

var sway_phase: float = 0.0
var time_elapsed: float = 0.0
var lean_vec: Vector2 = Vector2.ZERO
var canopy1: PackedVector2Array = PackedVector2Array()
var canopy2: PackedVector2Array = PackedVector2Array()
var canopy2_off: Vector2 = Vector2.ZERO

func _ready() -> void:
	if seed_val == 0:
		seed_val = int(abs(global_position.x * 67.0 + global_position.y * 43.0)) & 0x7FFFFFFF
	sway_phase = randf() * TAU
	_regenerate()
	queue_redraw()

func _regenerate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 54321
	var r1: float = 19.0 * tree_scale
	var r2: float = 14.0 * tree_scale
	var ang: float = -PI * (0.28 + rng.randf() * 0.6)

	lean_vec = Vector2(cos(ang) * (10.0 * tree_scale), sin(ang) * (10.0 * tree_scale))
	canopy1 = GeometryUtils.make_jagged_polygon(rng, 7, r1, r1 * 0.92, 0.16, rng.randf() * PI)
	canopy2 = GeometryUtils.make_jagged_polygon(rng, 6, r2, r2 * 0.88, 0.16, rng.randf() * PI)
	canopy2_off = Vector2(cos(ang + 0.9) * (9.0 * tree_scale), sin(ang + 0.9) * (9.0 * tree_scale))

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time_elapsed += delta
	queue_redraw()

func _draw() -> void:
	if canopy1.is_empty():
		_regenerate()

	# 1. Ground drop shadow
	var shadow_offset := Vector2(8.0 * tree_scale, 10.0 * tree_scale)
	draw_set_transform(shadow_offset, 0.25, Vector2(1.2, 0.95))
	draw_circle(Vector2.ZERO, 19.0 * tree_scale, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Wind sway & trunk
	var wind_x: float = sin(time_elapsed * 1.35 + sway_phase) * 1.2 if not Engine.is_editor_hint() else 0.0
	var wind_y: float = cos(time_elapsed * 1.1 + sway_phase) * 0.8 if not Engine.is_editor_hint() else 0.0
	var top_pt: Vector2 = lean_vec + Vector2(wind_x * 0.55, wind_y * 0.55)

	# Draw birch trunk
	var trunk_width: float = 4.6 * tree_scale
	var trunk_len: float = top_pt.length()
	if trunk_len > 1.0:
		var trunk_ang: float = top_pt.angle()
		draw_set_transform(Vector2.ZERO, trunk_ang, Vector2.ONE)
		draw_rect(Rect2(0, -trunk_width * 0.5, trunk_len, trunk_width), Palette.BIRCH_TRUNK)
		# Stripes
		for i in range(1, 4):
			var sx: float = (trunk_len * float(i)) / 3.6
			var sh: float = trunk_width * (0.65 if (i % 2 == 0) else 0.52)
			var sy: float = -trunk_width * 0.5 if (i % 2 == 0) else (trunk_width * 0.5 - sh)
			draw_rect(Rect2(sx, sy, 1.5, sh), Palette.BIRCH_STRIPE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Canopies
	var c1_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in canopy1:
		c1_pts.append(p + top_pt)
	draw_colored_polygon(c1_pts, Palette.BIRCH_DARK)
	var loop1 := c1_pts.duplicate()
	loop1.append(c1_pts[0])
	draw_polyline(loop1, Color(0.529, 0.635, 0.565, 0.26), 1.0, true)

	var c2_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in canopy2:
		c2_pts.append(p + top_pt + canopy2_off)
	draw_colored_polygon(c2_pts, Palette.BIRCH_LIGHT)
	var loop2 := c2_pts.duplicate()
	loop2.append(c2_pts[0])
	draw_polyline(loop2, Color(0.608, 0.71, 0.639, 0.26), 1.0, true)
