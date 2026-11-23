@tool
class_name ShrineLantern
extends Node2D

## Japanese stone Toro lantern with hexagonal carved stone roof,
## glowing lattice firebox, and solid ricochet collision.
## Marked @tool for real-time preview in the Godot 2D editor.

@export var lantern_radius: float = 22.0:
	set(val):
		lantern_radius = val
		_rebuild_polygon()
		queue_redraw()

@export var is_solid: bool = true:
	set(val):
		is_solid = val
		queue_redraw()

var polygon: PackedVector2Array = PackedVector2Array()
var segment_flashes: Array[float] = []
var time_elapsed: float = 0.0

const STONE_DARK := Color("#2e2a3b")   # Shadowed slate
const STONE_MID := Color("#524c66")    # Carved granite
const STONE_LIGHT := Color("#857c9e")  # Highlighted stone
const LANTERN_GLOW := Color("#fef08a") # Warm candle flame

func _ready() -> void:
	_rebuild_polygon()
	queue_redraw()

func _rebuild_polygon() -> void:
	polygon.clear()
	var sides: int = 6
	var step: float = TAU / float(sides)
	for i in range(sides):
		var ang: float = float(i) * step - PI * 0.5
		polygon.append(Vector2(cos(ang), sin(ang)) * lantern_radius)
	segment_flashes.resize(sides)
	segment_flashes.fill(0.0)

func get_global_segments() -> Array:
	if not is_solid or polygon.size() < 3:
		return []
	var res: Array = []
	var count: int = polygon.size()
	for i in range(count):
		res.append({
			"a": to_global(polygon[i]),
			"b": to_global(polygon[(i + 1) % count]),
			"flash": 0.0,
			"obstacle": self,
			"seg_idx": i
		})
	return res

func trigger_flash(seg_idx: int) -> void:
	if seg_idx >= 0 and seg_idx < segment_flashes.size():
		segment_flashes[seg_idx] = 1.0
		queue_redraw()

func _process(delta: float) -> void:
	time_elapsed += delta
	var needs_redraw: bool = false
	for i in range(segment_flashes.size()):
		if segment_flashes[i] > 0.0:
			segment_flashes[i] = maxf(0.0, segment_flashes[i] - delta * 3.8)
			needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if polygon.size() < 6:
		_rebuild_polygon()

	# 1. Ground drop shadow
	var shadow_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		shadow_pts.append(p + Vector2(6.0, 8.0))
	draw_colored_polygon(shadow_pts, Palette.SHADOW)

	# 2. Hexagonal stone base & roof (Kasa)
	draw_colored_polygon(polygon, STONE_MID)

	# 3. Inner roof ridges / facet lines
	for i in range(6):
		draw_line(Vector2.ZERO, polygon[i], STONE_DARK, 1.2)

	# 4. Firebox chamber with warm lantern glow (Hibukuro)
	var glow: float = 0.82 + 0.18 * sin(time_elapsed * 5.0) if not Engine.is_editor_hint() else 0.95
	var fire_box: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		fire_box.append(p * 0.52)
	draw_colored_polygon(fire_box, STONE_DARK)

	# Pulsing soft lantern aura
	draw_circle(Vector2.ZERO, lantern_radius * 0.65 * glow, Color(1.0, 0.92, 0.5, 0.22))
	# Inner glowing flame
	draw_circle(Vector2.ZERO, lantern_radius * 0.28 * glow, LANTERN_GLOW)

	# 5. Sacred top finial jewel (Hōju)
	draw_circle(Vector2.ZERO, lantern_radius * 0.16, STONE_LIGHT)

	# 6. Outer boundary contour line with bounce flash
	for i in range(6):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % 6]
		var f_val: float = segment_flashes[i] if i < segment_flashes.size() else 0.0
		var col: Color = Palette.CONTOUR_FLASH if f_val > 0.02 else Color("#f43f5e")
		var width: float = 2.4 + f_val * 1.8 if f_val > 0.02 else 1.8
		draw_line(a, b, col, width, true)
