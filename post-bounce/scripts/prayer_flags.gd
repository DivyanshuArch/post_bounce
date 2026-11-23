@tool
class_name PrayerFlags
extends Node2D

## Himalayan Tibetan Lung-Ta prayer flags strung between two mountain posts.
## Displays the 5 sacred traditional colors (Blue, White, Red, Green, Yellow)
## fluttering in high-altitude mountain winds along a natural catenary sag curve.
## Marked @tool for real-time preview in the Godot 2D editor.

@export var point_a: Vector2 = Vector2(-70.0, 0.0):
	set(val):
		point_a = val
		queue_redraw()

@export var point_b: Vector2 = Vector2(70.0, 0.0):
	set(val):
		point_b = val
		queue_redraw()

@export var sag: float = 14.0:
	set(val):
		sag = val
		queue_redraw()

@export var flag_count: int = 15:
	set(val):
		flag_count = clampi(val, 5, 30)
		queue_redraw()

var time_elapsed: float = 0.0

# Traditional 5 Buddhist elements:
const PRAYER_COLORS: Array[Color] = [
	Color("#2563eb"), # 1. Blue  (Sky / Space)
	Color("#f8fafc"), # 2. White (Air / Wind)
	Color("#dc2626"), # 3. Red   (Fire)
	Color("#16a34a"), # 4. Green (Water)
	Color("#eab308")  # 5. Yellow (Earth)
]

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time_elapsed += delta
	queue_redraw()

func _draw() -> void:
	var span_vec: Vector2 = point_b - point_a
	var dist: float = span_vec.length()
	if dist < 5.0:
		return

	# 1. Ground drop shadow of cord
	var shadow_a := point_a + Vector2(6.0, 8.0)
	var shadow_b := point_b + Vector2(6.0, 8.0)
	draw_line(shadow_a, shadow_b, Palette.SHADOW_SOFT, 2.0)

	# 2. Wooden support posts at ends
	for pt: Vector2 in [point_a, point_b]:
		draw_circle(pt + Vector2(3.0, 4.0), 5.0, Palette.SHADOW)
		draw_circle(pt, 4.5, Color("#422006")) # Dark pine/yak pole
		draw_circle(pt, 2.0, Color("#ca8a04")) # Golden post cap

	# 3. Cord line with catenary droop & flags
	var segments: int = maxi(10, flag_count * 2)
	var cord_pts: PackedVector2Array = PackedVector2Array()

	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector2 = point_a.lerp(point_b, t)
		var droop: float = 4.0 * sag * t * (1.0 - t)
		cord_pts.append(p + Vector2(0.0, droop))

	draw_polyline(cord_pts, Color(0.85, 0.88, 0.86, 0.75), 1.25, true)

	# 4. Fluttering rectangular flags along cord
	var normal_step := span_vec.orthogonal().normalized()
	var flag_w: float = (dist / float(flag_count)) * 0.75
	var flag_h: float = 12.0

	for f in range(flag_count):
		var t: float = (float(f) + 0.5) / float(flag_count)
		var base_p: Vector2 = point_a.lerp(point_b, t)
		var droop: float = 4.0 * sag * t * (1.0 - t)
		var anchor: Vector2 = base_p + Vector2(0.0, droop)

		var color_idx: int = f % PRAYER_COLORS.size()
		var flag_color: Color = PRAYER_COLORS[color_idx]

		# Wind flutter displacement
		var flutter_phase: float = time_elapsed * 6.5 + float(f) * 0.95 if not Engine.is_editor_hint() else float(f) * 0.95
		var flutter_x: float = sin(flutter_phase) * 3.5
		var flutter_y: float = cos(flutter_phase * 0.8) * 2.5

		var p1: Vector2 = anchor + Vector2(-flag_w * 0.5, 0.0)
		var p2: Vector2 = anchor + Vector2(flag_w * 0.5, 0.0)
		var p3: Vector2 = p2 + Vector2(flutter_x, flag_h + flutter_y)
		var p4: Vector2 = p1 + Vector2(flutter_x, flag_h + flutter_y)

		draw_colored_polygon([p1, p2, p3, p4], flag_color)
		draw_polyline([p1, p2, p3, p4, p1], Color(flag_color.r * 0.7, flag_color.g * 0.7, flag_color.b * 0.7, 0.45), 1.0)
