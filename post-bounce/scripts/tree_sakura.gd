@tool
class_name TreeSakura
extends Node2D

## Japanese Cherry Blossom (Sakura) tree with multi-tiered pink canopies,
## wind sway, and scattered fallen petals.
## Marked @tool for real-time preview in the Godot 2D editor.

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
var fallen_petals: Array[Vector2] = []

const SAKURA_DARK := Color("#9d174d")   # Deep rose shadow
const SAKURA_MID := Color("#db2777")    # Vibrant cherry blossom
const SAKURA_LIGHT := Color("#f472b6")  # Soft petal pink
const SAKURA_PALE := Color("#fbcfe8")   # Blossom highlight

func _ready() -> void:
	if seed_val == 0:
		seed_val = int(abs(global_position.x * 61.0 + global_position.y * 43.0)) & 0x7FFFFFFF
	sway_phase = randf() * TAU
	_regenerate_tiers()
	queue_redraw()

func _regenerate_tiers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val if seed_val != 0 else 54321
	var base_r: float = 28.0 * tree_scale
	var rot0: float = rng.randf() * TAU

	tiers = [
		{
			"pts": GeometryUtils.make_jagged_polygon(rng, 8, base_r * 1.1, base_r * 0.75, 0.18, rot0),
			"color": SAKURA_DARK
		},
		{
			"pts": GeometryUtils.make_jagged_polygon(rng, 7, base_r * 0.88, base_r * 0.58, 0.22, rot0 + 0.35),
			"color": SAKURA_MID
		},
		{
			"pts": GeometryUtils.make_jagged_polygon(rng, 6, base_r * 0.62, base_r * 0.4, 0.25, rot0 + 0.75),
			"color": SAKURA_LIGHT
		},
		{
			"pts": GeometryUtils.make_jagged_polygon(rng, 5, base_r * 0.36, base_r * 0.22, 0.28, rot0 + 1.2),
			"color": SAKURA_PALE
		}
	]

	fallen_petals.clear()
	for i in range(12):
		var r: float = (15.0 + rng.randf() * 32.0) * tree_scale
		var a: float = rng.randf() * TAU
		fallen_petals.append(Vector2(cos(a) * r + 4.0, sin(a) * r * 0.7 + 6.0))

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
	draw_set_transform(shadow_offset, 0.2, Vector2(1.25, 0.9))
	draw_circle(Vector2.ZERO, 20.0 * tree_scale, Palette.SHADOW)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Scattered fallen petals on ground
	for fp in fallen_petals:
		draw_circle(fp, 1.8 * tree_scale, SAKURA_LIGHT)

	# 3. Billowing cherry blossom canopies with wind sway
	var wind_x: float = sin(time_elapsed * 1.4 + sway_phase) * 1.4 if not Engine.is_editor_hint() else 0.0
	var wind_y: float = cos(time_elapsed * 1.1 + sway_phase) * 0.9 if not Engine.is_editor_hint() else 0.0

	for k in range(tiers.size()):
		var tier: Dictionary = tiers[k]
		var offset := Vector2(wind_x * (float(k) * 0.5), wind_y * (float(k) * 0.5))
		var pts: PackedVector2Array = tier["pts"]
		var shifted_pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in pts:
			shifted_pts.append(p + offset)

		draw_colored_polygon(shifted_pts, tier["color"])
		if k > 0:
			var contour_col := Color(1.0, 0.85, 0.92, 0.25)
			var loop_pts := shifted_pts.duplicate()
			loop_pts.append(shifted_pts[0])
			draw_polyline(loop_pts, contour_col, 1.0, true)
