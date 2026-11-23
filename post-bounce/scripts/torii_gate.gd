@tool
class_name ToriiGate
extends Node2D

## Japanese Shinto Torii Gate with vermillion lacquer lintel, black caps,
## central tablet plaque, and two solid pillar posts that ricochet the ball.
## Marked @tool for real-time preview in the Godot 2D editor.

@export var gate_width: float = 110.0:
	set(val):
		gate_width = val
		_rebuild_pillars()
		queue_redraw()

@export var pillar_radius: float = 9.0:
	set(val):
		pillar_radius = val
		_rebuild_pillars()
		queue_redraw()

@export var is_solid: bool = true:
	set(val):
		is_solid = val
		queue_redraw()

var left_pillar_pts: PackedVector2Array = PackedVector2Array()
var right_pillar_pts: PackedVector2Array = PackedVector2Array()
var segment_flashes: Array[float] = []

const VERMILLION := Color("#e11d48")      # Japanese Shinto red lacquer
const VERMILLION_BRIGHT := Color("#f43f5e")# Highlight red
const LACQUER_BLACK := Color("#18181b")   # Top caps and tablet
const GOLD_ACCENT := Color("#fbbf24")     # Tablet inscription gold

func _ready() -> void:
	_rebuild_pillars()
	queue_redraw()

func _rebuild_pillars() -> void:
	left_pillar_pts.clear()
	right_pillar_pts.clear()
	var sides: int = 8
	var step: float = TAU / float(sides)
	var half_span: float = gate_width * 0.38

	for i in range(sides):
		var ang: float = float(i) * step
		var offset := Vector2(cos(ang), sin(ang)) * pillar_radius
		left_pillar_pts.append(Vector2(-half_span, 0.0) + offset)
		right_pillar_pts.append(Vector2(half_span, 0.0) + offset)

	segment_flashes.resize(sides * 2)
	segment_flashes.fill(0.0)

func get_global_segments() -> Array:
	if not is_solid:
		return []
	var res: Array = []
	var sides: int = left_pillar_pts.size()
	# Left pillar
	for i in range(sides):
		res.append({
			"a": to_global(left_pillar_pts[i]),
			"b": to_global(left_pillar_pts[(i + 1) % sides]),
			"flash": 0.0,
			"obstacle": self,
			"seg_idx": i
		})
	# Right pillar
	for i in range(sides):
		res.append({
			"a": to_global(right_pillar_pts[i]),
			"b": to_global(right_pillar_pts[(i + 1) % sides]),
			"flash": 0.0,
			"obstacle": self,
			"seg_idx": sides + i
		})
	return res

func trigger_flash(seg_idx: int) -> void:
	if seg_idx >= 0 and seg_idx < segment_flashes.size():
		segment_flashes[seg_idx] = 1.0
		queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var needs_redraw: bool = false
	for i in range(segment_flashes.size()):
		if segment_flashes[i] > 0.0:
			segment_flashes[i] = maxf(0.0, segment_flashes[i] - delta * 3.8)
			needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if left_pillar_pts.is_empty():
		_rebuild_pillars()

	var hw: float = gate_width * 0.5
	var half_span: float = gate_width * 0.38

	# 1. Ground drop shadow
	draw_rect(Rect2(-hw + 8.0, -12.0 + 10.0, gate_width + 12.0, 18.0), Palette.SHADOW)
	draw_circle(Vector2(-half_span + 6.0, 8.0), pillar_radius * 1.3, Palette.SHADOW)
	draw_circle(Vector2(half_span + 6.0, 8.0), pillar_radius * 1.3, Palette.SHADOW)

	# 2. Lower tie beam (Nuki)
	draw_rect(Rect2(-half_span - 8.0, -4.0, (half_span + 8.0) * 2.0, 7.0), VERMILLION)

	# 3. Two vertical pillar posts (Hashira)
	draw_colored_polygon(left_pillar_pts, LACQUER_BLACK)
	draw_colored_polygon(right_pillar_pts, LACQUER_BLACK)
	draw_circle(Vector2(-half_span, 0.0), pillar_radius * 0.75, VERMILLION)
	draw_circle(Vector2(half_span, 0.0), pillar_radius * 0.75, VERMILLION)

	# 4. Upper main lintel beam (Kasagi & Shimaki) with sweeping curved ends
	var lintel_pts: PackedVector2Array = [
		Vector2(-hw - 10.0, -22.0),
		Vector2(-hw, -16.0),
		Vector2(hw, -16.0),
		Vector2(hw + 10.0, -22.0),
		Vector2(hw + 14.0, -18.0),
		Vector2(hw + 4.0, -10.0),
		Vector2(-hw - 4.0, -10.0),
		Vector2(-hw - 14.0, -18.0)
	]
	draw_colored_polygon(lintel_pts, VERMILLION)

	# Lintel upper highlight ridge
	draw_line(Vector2(-hw - 6.0, -19.0), Vector2(hw + 6.0, -19.0), VERMILLION_BRIGHT, 1.8)

	# Black ends of lintel
	draw_colored_polygon([Vector2(-hw - 14.0, -18.0), Vector2(-hw - 10.0, -22.0), Vector2(-hw - 3.0, -18.0), Vector2(-hw - 7.0, -12.0)], LACQUER_BLACK)
	draw_colored_polygon([Vector2(hw + 14.0, -18.0), Vector2(hw + 10.0, -22.0), Vector2(hw + 3.0, -18.0), Vector2(hw + 7.0, -12.0)], LACQUER_BLACK)

	# 5. Central tablet plaque (Gakuzuka)
	draw_rect(Rect2(-6.0, -16.0, 12.0, 14.0), LACQUER_BLACK)
	draw_rect(Rect2(-4.0, -14.0, 8.0, 10.0), GOLD_ACCENT)

	# 6. Pillar contour outlines with bounce flash
	var sides: int = left_pillar_pts.size()
	for i in range(sides):
		var f_val: float = segment_flashes[i] if i < segment_flashes.size() else 0.0
		var col: Color = Palette.CONTOUR_FLASH if f_val > 0.02 else VERMILLION_BRIGHT
		draw_line(left_pillar_pts[i], left_pillar_pts[(i + 1) % sides], col, 2.0 + f_val * 1.5, true)

	for i in range(sides):
		var f_val: float = segment_flashes[sides + i] if (sides + i) < segment_flashes.size() else 0.0
		var col: Color = Palette.CONTOUR_FLASH if f_val > 0.02 else VERMILLION_BRIGHT
		draw_line(right_pillar_pts[i], right_pillar_pts[(i + 1) % sides], col, 2.0 + f_val * 1.5, true)
