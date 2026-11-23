@tool
class_name TerracottaMonument
extends Node2D

## Ancient Bihar / Nalanda-inspired terracotta brick monument or stupa.
## Features stepped terracotta brick tiers, carved relief motifs, and glowing diyas.
## Marked @tool for real-time preview in the Godot 2D editor.

@export var monument_radius: float = 38.0:
	set(val):
		monument_radius = val
		_rebuild_polygon()
		queue_redraw()

@export var sides: int = 8:
	set(val):
		sides = clampi(val, 4, 12)
		_rebuild_polygon()
		queue_redraw()

@export var is_solid: bool = true:
	set(val):
		is_solid = val
		queue_redraw()

var polygon: PackedVector2Array = PackedVector2Array()
var segment_flashes: Array[float] = []
var time_elapsed: float = 0.0

const TERRA_BASE := Color("#69281a")
const TERRA_MID := Color("#ad4834")
const TERRA_LIGHT := Color("#cf684e")
const TERRA_LINE := Color("#fbbf24")

func _ready() -> void:
	_rebuild_polygon()
	queue_redraw()

func _rebuild_polygon() -> void:
	polygon.clear()
	var step: float = TAU / float(sides)
	for i in range(sides):
		var ang: float = float(i) * step - PI * 0.5
		polygon.append(Vector2(cos(ang), sin(ang)) * monument_radius)
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
	if polygon.size() < sides:
		_rebuild_polygon()

	# 1. Ground drop shadow
	var shadow_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		shadow_pts.append(p + Vector2(7.0, 9.0))
	draw_colored_polygon(shadow_pts, Palette.SHADOW)

	# 2. Outer stepped terracotta tier
	draw_colored_polygon(polygon, TERRA_BASE)

	# 3. Middle brick tier
	var mid_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		mid_pts.append(p * 0.74)
	draw_colored_polygon(mid_pts, TERRA_MID)

	# Brick joints / radial spokes
	for i in range(sides):
		draw_line(mid_pts[i], polygon[i], Color(0.24, 0.09, 0.06, 0.5), 1.0)

	# 4. Inner sanctum / Stupa dome
	var top_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		top_pts.append(p * 0.44)
	draw_colored_polygon(top_pts, TERRA_LIGHT)

	# Central terracotta medallion / lotus carving
	draw_circle(Vector2.ZERO, monument_radius * 0.22, Color("#e76f51"))
	draw_circle(Vector2.ZERO, monument_radius * 0.11, Color("#f4a261"))

	# 5. Glowing clay diyas on corner plinths
	var flicker: float = 0.8 + 0.2 * sin(time_elapsed * 6.5) if not Engine.is_editor_hint() else 0.95
	var diya_count: int = mini(sides, 4)
	var step_idx: int = sides / diya_count
	for k in range(diya_count):
		var pt: Vector2 = polygon[k * step_idx] * 0.86
		draw_circle(pt, 8.0 * flicker, Color(1.0, 0.7, 0.2, 0.22))
		draw_circle(pt, 3.2, Color("#b45309")) # Terracotta lamp
		draw_circle(pt, 1.6 * flicker, Color("#fff8c7")) # Flame

	# 6. Outer boundary contour line with bounce flash
	for i in range(sides):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % sides]
		var f_val: float = segment_flashes[i] if i < segment_flashes.size() else 0.0
		var col: Color = Palette.CONTOUR_FLASH if f_val > 0.02 else TERRA_LINE
		var width: float = 2.4 + f_val * 1.8 if f_val > 0.02 else 2.0
		draw_line(a, b, col, width, true)
