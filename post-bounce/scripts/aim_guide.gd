class_name AimGuide
extends Node2D

## Visual aiming guide with power ring, slingshot tether, primary dashed line,
## and real-time first-bounce reflection preview with zero latency.

var is_aiming: bool = false
var ball_pos: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.ZERO
var power_ratio: float = 0.0
var time_elapsed: float = 0.0

var segments: Array = []
var finish_data: Dictionary = {}

func set_aim_state(aiming: bool, b_pos: Vector2, dir: Vector2, p_ratio: float, segs: Array, f_data: Dictionary) -> void:
	is_aiming = aiming
	ball_pos = b_pos
	aim_dir = dir
	power_ratio = p_ratio
	segments = segs
	finish_data = f_data
	queue_redraw()

func _process(delta: float) -> void:
	if is_aiming:
		time_elapsed += delta
		queue_redraw()

func _draw() -> void:
	if not is_aiming or power_ratio < (PhysicsConstants.MIN_PULL / PhysicsConstants.MAX_PULL):
		return

	var radius: float = PhysicsConstants.BALL_RADIUS
	var dir_x: float = aim_dir.x
	var dir_y: float = aim_dir.y

	# 1. Power indicator ring around the ball
	var ring_r: float = radius + 10.0 + power_ratio * 14.0
	var ring_col: Color
	if power_ratio > 0.78:
		ring_col = Color(0.98, 0.89, 0.4, 0.45 + power_ratio * 0.35)
	else:
		ring_col = Color(0.957, 0.969, 0.961, 0.32 + power_ratio * 0.35)

	draw_arc(ball_pos, ring_r, -PI * 0.5, -PI * 0.5 + TAU * power_ratio, 32, ring_col, 2.0, true)

	# 2. Slingshot tether line
	var tether_len: float = 22.0 + power_ratio * 56.0
	var tether_end: Vector2 = ball_pos - aim_dir * tether_len
	draw_line(ball_pos, tether_end, Color(0.957, 0.969, 0.961, 0.22), 1.5, true)

	# 3. Raycast against all wall segments and finish line
	var max_primary_len: float = 190.0 + power_ratio * 340.0
	var best_hit = null
	var best_t: float = max_primary_len

	for seg: Dictionary in segments:
		var hit = GeometryUtils.sweep_circle_against_segment(
			ball_pos.x, ball_pos.y, dir_x, dir_y, radius,
			seg["a"].x, seg["a"].y, seg["b"].x, seg["b"].y
		)
		if hit != null and hit["t"] < best_t:
			best_t = hit["t"]
			best_hit = hit

	if not finish_data.is_empty():
		var fin_hit = GeometryUtils.ray_segment_intersect(
			ball_pos.x, ball_pos.y, dir_x, dir_y,
			finish_data["p1"].x, finish_data["p1"].y,
			finish_data["p2"].x, finish_data["p2"].y
		)
		if fin_hit != null and fin_hit["t"] < best_t:
			best_t = fin_hit["t"]
			best_hit = null

	var start_pt: Vector2 = ball_pos + aim_dir * (radius + 4.0)
	var end_pt: Vector2 = ball_pos + aim_dir * best_t

	# Draw dashed primary line
	_draw_dashed_line(start_pt, end_pt, Color(0.957, 0.969, 0.961, 0.84), 2.2, 7.0, 7.0, time_elapsed * 28.0)

	# 4. First-bounce reflection preview
	if best_hit != null:
		var hit_pt: Vector2 = best_hit["point"]
		var normal: Vector2 = best_hit["normal"]

		# Yellow impact marker
		draw_circle(hit_pt, 3.8, Palette.DIAMOND_CORE)

		# Reflected direction
		var dot: float = aim_dir.dot(normal)
		var r_dir: Vector2 = (aim_dir - 2.0 * dot * normal).normalized()
		var refl_max_len: float = 90.0 + power_ratio * 145.0
		var refl_t: float = refl_max_len
		var ox: float = hit_pt.x + normal.x * 0.5
		var oy: float = hit_pt.y + normal.y * 0.5

		for seg: Dictionary in segments:
			var hit2 = GeometryUtils.sweep_circle_against_segment(
				ox, oy, r_dir.x, r_dir.y, radius,
				seg["a"].x, seg["a"].y, seg["b"].x, seg["b"].y
			)
			if hit2 != null and hit2["t"] < refl_t:
				refl_t = hit2["t"]

		var refl_start := Vector2(ox, oy)
		var refl_end: Vector2 = refl_start + r_dir * refl_t
		_draw_dashed_line(refl_start, refl_end, Color(0.98, 0.89, 0.4, 0.72), 2.0, 5.0, 6.0, time_elapsed * 28.0)

func _draw_dashed_line(p1: Vector2, p2: Vector2, color: Color, width: float, dash_len: float, gap_len: float, offset: float) -> void:
	var total_len: float = p1.distance_to(p2)
	if total_len <= 1.0:
		return

	var dir: Vector2 = (p2 - p1) / total_len
	var pattern_len: float = dash_len + gap_len
	var shift: float = fmod(offset, pattern_len)

	var cur: float = -shift
	while cur < total_len:
		var s: float = maxf(0.0, cur)
		var e: float = minf(total_len, cur + dash_len)
		if e > s:
			draw_line(p1 + dir * s, p1 + dir * e, color, width, true)
		cur += pattern_len
