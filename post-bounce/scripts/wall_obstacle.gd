@tool
class_name WallObstacle
extends Node2D

## Raised cliff island obstacle with drop shadow, inner ridge facet, and contour outline.
## Marked @tool so it renders live in the Godot 2D editor.

@export var polygon: PackedVector2Array = [
	Vector2(-50.0, -50.0),
	Vector2(50.0, -50.0),
	Vector2(50.0, 50.0),
	Vector2(-50.0, 50.0)
]:
	set(val):
		polygon = val
		queue_redraw()

var segment_flashes: Array[float] = []

func _ready() -> void:
	segment_flashes.resize(polygon.size())
	segment_flashes.fill(0.0)
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

func get_global_segments() -> Array:
	var res: Array = []
	var count: int = polygon.size()
	for i in range(count):
		var p1: Vector2 = to_global(polygon[i])
		var p2: Vector2 = to_global(polygon[(i + 1) % count])
		res.append({
			"a": p1,
			"b": p2,
			"flash": 0.0,
			"obstacle": self,
			"seg_idx": i
		})
	return res

func trigger_flash(seg_idx: int) -> void:
	if seg_idx >= 0 and seg_idx < segment_flashes.size():
		segment_flashes[seg_idx] = 1.0
		queue_redraw()

func _draw() -> void:
	var count: int = polygon.size()
	if count < 3:
		return

	if segment_flashes.size() != count:
		segment_flashes.resize(count)
		segment_flashes.fill(0.0)

	# 1. Ground drop shadow
	var shadow_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		shadow_pts.append(p + Vector2(7.0, 9.0))
	draw_colored_polygon(shadow_pts, Palette.SHADOW)

	# 2. Dark slate-green cliff body
	draw_colored_polygon(polygon, Palette.WALL_VOID)

	# 3. Subtle raised inner facet
	var center := Vector2.ZERO
	for p: Vector2 in polygon:
		center += p
	center /= float(count)

	var inner_pts: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in polygon:
		var shifted := center.lerp(p, 0.72) + Vector2(-2.0, -2.5)
		inner_pts.append(shifted)
	draw_colored_polygon(inner_pts, Palette.WALL_RIDGE_MID)
	var loop_inner := inner_pts.duplicate()
	loop_inner.append(inner_pts[0])
	draw_polyline(loop_inner, Color(0.498, 0.58, 0.518, 0.35), 1.0, true)

	# 4. Sage contour line per segment (with hit flash)
	for i in range(count):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % count]
		var flash_val: float = segment_flashes[i] if i < segment_flashes.size() else 0.0
		var col: Color = Palette.CONTOUR_FLASH if flash_val > 0.02 else Palette.CONTOUR_LINE
		var width: float = 2.4 + flash_val * 1.8 if flash_val > 0.02 else 2.2
		draw_line(a, b, col, width, true)
