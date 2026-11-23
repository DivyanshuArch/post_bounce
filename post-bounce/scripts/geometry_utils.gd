class_name GeometryUtils
extends RefCounted

## Utility geometry and raycasting functions for sub-stepped ricochet physics and aim guide.

static func point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)

static func closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Dictionary:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 1e-8:
		return {"point": a, "t": 0.0}
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return {"point": a + ab * t, "t": t}

static func dist_to_polygon_edges(p: Vector2, poly: PackedVector2Array) -> float:
	var min_d: float = INF
	var count: int = poly.size()
	for i in range(count):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % count]
		var res: Dictionary = closest_point_on_segment(p, a, b)
		var d: float = p.distance_to(res["point"])
		if d < min_d:
			min_d = d
	return min_d

static func make_jagged_polygon(rng: RandomNumberGenerator, sides: int, rx: float, ry: float, jitter: float = 0.2, rot: float = 0.0) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(sides):
		var ang: float = (float(i) / float(sides)) * TAU + rot + (rng.randf() - 0.5) * 0.16
		var r_scale: float = 1.0 + (rng.randf() * 2.0 - 1.0) * jitter
		pts.append(Vector2(cos(ang) * rx * r_scale, sin(ang) * ry * r_scale))
	return pts

static func make_pine_tier_polygon(rng: RandomNumberGenerator, points: int, outer_r: float, inner_r: float, rot: float = 0.0) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var total: int = points * 2
	for i in range(total):
		var ang: float = (float(i) / float(total)) * TAU + rot + (rng.randf() - 0.5) * 0.08
		var base_r: float = outer_r if (i % 2 == 0) else inner_r
		var r: float = base_r * (0.88 + rng.randf() * 0.24)
		pts.append(Vector2(cos(ang) * r, sin(ang) * r))
	return pts

## Ray vs capsule/circle-swept segment intersection for accurate aim preview.
## Approximates swept-circle impact cleanly by testing ray against segment
## shifted outward by radius + endpoint circles, returning earliest t >= 0.
static func sweep_circle_against_segment(ox: float, oy: float, dx: float, dy: float, radius: float, ax: float, ay: float, bx: float, by: float):
	var best_t: float = INF
	var best_nx: float = 0.0
	var best_ny: float = 0.0

	var sx: float = bx - ax
	var sy: float = by - ay
	var seg_len: float = sqrt(sx * sx + sy * sy)
	if seg_len < 1e-6:
		return null

	var nx_base: float = -sy / seg_len
	var ny_base: float = sx / seg_len

	for sign_val in [1.0, -1.0]:
		var nx: float = nx_base * sign_val
		var ny: float = ny_base * sign_val
		var denom: float = dx * nx + dy * ny
		if denom >= -1e-6:
			continue

		var dist_plane: float = (ox - ax) * nx + (oy - ay) * ny - radius
		if dist_plane < -0.5:
			continue
		var t: float = maxf(0.0, -dist_plane / denom)
		if t >= best_t:
			continue

		var hx: float = ox + dx * t
		var hy: float = oy + dy * t
		var proj: float = ((hx - ax) * sx + (hy - ay) * sy) / (seg_len * seg_len)
		if proj >= 0.0 and proj <= 1.0:
			best_t = t
			best_nx = nx
			best_ny = ny

	# Endpoint circles test
	var endpoints: Array = [Vector2(ax, ay), Vector2(bx, by)]
	for end_pt: Vector2 in endpoints:
		var fx: float = ox - end_pt.x
		var fy: float = oy - end_pt.y
		var b_val: float = 2.0 * (fx * dx + fy * dy)
		var c_val: float = fx * fx + fy * fy - radius * radius
		var disc: float = b_val * b_val - 4.0 * c_val
		if disc >= 0.0:
			var sqrt_d: float = sqrt(disc)
			var t: float = (-b_val - sqrt_d) * 0.5
			if t >= 0.0 and t < best_t:
				var hx: float = ox + dx * t
				var hy: float = oy + dy * t
				var ep_len: float = sqrt((hx - end_pt.x) * (hx - end_pt.x) + (hy - end_pt.y) * (hy - end_pt.y))
				if ep_len < 1e-6:
					ep_len = 1.0
				best_t = t
				best_nx = (hx - end_pt.x) / ep_len
				best_ny = (hy - end_pt.y) / ep_len

	if best_t == INF:
		return null

	return {
		"t": best_t,
		"point": Vector2(ox + dx * best_t, oy + dy * best_t),
		"normal": Vector2(best_nx, best_ny),
	}

## Ray vs line segment intersection (used to check if aim ray hits finish line first).
static func ray_segment_intersect(ox: float, oy: float, dx: float, dy: float, ax: float, ay: float, bx: float, by: float):
	var sx: float = bx - ax
	var sy: float = by - ay
	var denom: float = dx * sy - dy * sx
	if absf(denom) < 1e-7:
		return null
	var qpx: float = ax - ox
	var qpy: float = ay - oy
	var t: float = (qpx * sy - qpy * sx) / denom
	var u: float = (qpx * dy - qpy * dx) / denom
	if t >= 0.0 and u >= 0.0 and u <= 1.0:
		return {"t": t, "point": Vector2(ox + dx * t, oy + dy * t)}
	return null
