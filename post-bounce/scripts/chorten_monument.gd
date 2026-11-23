@tool
class_name ChortenMonument
extends Node2D

## Himalayan Tibetan Buddhist Chorten / Stupa with stepped white square base,
## dome, golden 13-tiered spire, and sun-moon pinnacle.
## Marked @tool for real-time preview in the Godot 2D editor.

@export var monument_radius: float = 36.0:
	set(val):
		monument_radius = val
		_rebuild_polygon()
		queue_redraw()

@export var is_solid: bool = true:
	set(val):
		is_solid = val
		queue_redraw()

var polygon: PackedVector2Array = PackedVector2Array()
var segment_flashes: Array[float] = []
var time_elapsed: float = 0.0

const STUPA_WHITE := Color("#f8fafc")
const STUPA_BASE := Color("#334155")
const STUPA_GOLD := Color("#f59e0b")
const STUPA_RED := Color("#b91c1c")
const CONTOUR_CYAN := Color("#38bdf8")

func _ready() -> void:
	_rebuild_polygon()
	queue_redraw()

func _rebuild_polygon() -> void:
	polygon.clear()
	var sides: int = 8
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
	if Engine.is_editor_hint():
		return
	time_elapsed += delta
	var needs_redraw: bool = false
	for i in range(segment_flashes.size()):
		if segment_flashes[i] > 0.0:
			segment_flashes[i] = maxf(0.0, segment_flashes[i] - delta * 3.8)
			needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if polygon.size() < 8:
		_rebuild_polygon()

	# 1. Ground drop shadow
	var shadow_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		shadow_pts.append(p + Vector2(7.0, 9.0))
	draw_colored_polygon(shadow_pts, Palette.SHADOW)

	# 2. Dark stone plinth base
	draw_colored_polygon(polygon, STUPA_BASE)

	# 3. Stepped white square/octagonal terraces
	var terrace_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		terrace_pts.append(p * 0.8)
	draw_colored_polygon(terrace_pts, STUPA_WHITE)

	# Red decorative band (charkhi)
	var band_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		band_pts.append(p * 0.65)
	draw_colored_polygon(band_pts, STUPA_RED)

	# 4. White hemispherical dome (Bumpa)
	draw_circle(Vector2.ZERO, monument_radius * 0.48, STUPA_WHITE)
	draw_circle(Vector2.ZERO, monument_radius * 0.46, Color("#e2e8f0"))

	# 5. Golden tiered spire & Harmika
	draw_circle(Vector2.ZERO, monument_radius * 0.28, STUPA_GOLD)
	draw_circle(Vector2.ZERO, monument_radius * 0.16, Color("#d97706"))

	# Pinnacle Sun & Crescent Moon
	draw_circle(Vector2.ZERO, monument_radius * 0.08, Color("#fffbeb"))

	# 6. Outer boundary contour line with bounce flash
	for i in range(8):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % 8]
		var f_val: float = segment_flashes[i] if i < segment_flashes.size() else 0.0
		var col: Color = Palette.CONTOUR_FLASH if f_val > 0.02 else CONTOUR_CYAN
		var width: float = 2.4 + f_val * 1.8 if f_val > 0.02 else 2.0
		draw_line(a, b, col, width, true)
