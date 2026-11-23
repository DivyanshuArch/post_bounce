@tool
class_name Ball
extends Node2D

## The Moonlit Ricochet Ball with sub-stepped zero-tunneling collision,
## realistic bank reflection, trail, hit flash, and ready halo.
## Marked @tool so it previews in the editor.

signal bounced(pos: Vector2, normal: Vector2, speed: float, count: int)
signal stopped()
signal diamond_hit(diamond: Node2D)
signal finish_reached()
signal out_of_bounds()


@export var radius: float = PhysicsConstants.BALL_RADIUS
@export var restitution: float = PhysicsConstants.RESTITUTION
@export var damping: float = PhysicsConstants.DAMPING
@export var linear_drag: float = PhysicsConstants.LINEAR_DRAG
@export var stop_speed: float = PhysicsConstants.STOP_SPEED

var velocity: Vector2 = Vector2.ZERO
var is_moving: bool = false
var bounce_count: int = 0
var hit_flash: float = 0.0
var time_elapsed: float = 0.0

# 3D Rolling Sphere Simulation
var ball_basis: Basis = Basis.IDENTITY

const SPHERE_MARKERS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0),
	Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, -1.0, 0.0),
	Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 0.0, -1.0),
	Vector3(0.577, 0.577, 0.577),
	Vector3(-0.577, -0.577, 0.577),
	Vector3(-0.577, 0.577, -0.577),
	Vector3(0.577, -0.577, -0.577)
]

# Boundary Bounce Color Cycling (Luminous Gemstone Spectrum)
const BOUNCE_PALETTE: Array[Color] = [
	Color("#f4f2ec"), # 0: Moonlit Pearl
	Color("#38bdf8"), # 1: Electric Azure
	Color("#fb7185"), # 2: Sakura Rose
	Color("#facc15"), # 3: Radiant Amber Gold
	Color("#4ade80"), # 4: Vivid Emerald
	Color("#c084fc"), # 5: Luminous Orchid
	Color("#f97316"), # 6: Saffron Orange
	Color("#22d3ee"), # 7: Celestial Turquoise
	Color("#ec4899"), # 8: Bright Magenta
	Color("#a855f7")  # 9: Royal Violet
]
var color_index: int = 0
var current_color: Color = Color("#f4f2ec")
var target_color: Color = Color("#f4f2ec")

# Smooth top-level ribbon trail
var trail_line: Line2D
var trail_points: Array[Vector2] = []
var trail_lifetimes: Array[float] = []
const TRAIL_LIFETIME: float = 0.32
const MIN_TRAIL_DIST: float = 3.5

func _ready() -> void:
	if not Engine.is_editor_hint():
		_setup_trail_line()
	queue_redraw()

func _setup_trail_line() -> void:
	trail_line = Line2D.new()
	trail_line.name = "SmoothTrail"
	trail_line.top_level = true
	trail_line.z_index = -1
	trail_line.width = radius * 1.8
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.antialiased = true

	# Width curve: smooth taper from head to tail
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0), 0.0, -0.3)
	curve.add_point(Vector2(1.0, 0.0), -1.8, 0.0)
	trail_line.width_curve = curve

	# Gradient: translucent moonlit ivory fading to zero alpha
	var grad := Gradient.new()
	grad.set_color(0, Color(current_color.r, current_color.g, current_color.b, 0.55))
	grad.set_color(1, Color(current_color.r, current_color.g, current_color.b, 0.0))
	trail_line.gradient = grad

	add_child(trail_line)

func _update_trail_color(new_col: Color) -> void:
	if is_instance_valid(trail_line) and trail_line.gradient:
		trail_line.gradient.set_color(0, Color(new_col.r, new_col.g, new_col.b, 0.62))
		trail_line.gradient.set_color(1, Color(new_col.r, new_col.g, new_col.b, 0.0))

func _update_rolling(delta: float) -> void:
	if not is_moving or velocity.length_squared() < 1e-4:
		return
	var speed: float = velocity.length()
	var roll_angle: float = (speed * delta) / radius
	# Axis perpendicular to velocity in XY plane: up(0,0,1) x vel(vx,vy,0) = (-vy, vx, 0)
	var axis := Vector3(-velocity.y, velocity.x, 0.0).normalized()
	if axis.length_squared() > 0.5:
		ball_basis = Basis(axis, roll_angle) * ball_basis
		ball_basis = ball_basis.orthonormalized()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	time_elapsed += delta
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta * 5.0)

	current_color = current_color.lerp(target_color, delta * 14.0)
	_update_rolling(delta)
	_update_trail(delta)
	queue_redraw()

func _update_trail(delta: float) -> void:
	if not is_instance_valid(trail_line):
		return

	# Age active trail points
	for i in range(trail_lifetimes.size() - 1, -1, -1):
		trail_lifetimes[i] -= delta
		if trail_lifetimes[i] <= 0.0:
			trail_lifetimes.remove_at(i)
			trail_points.remove_at(i)

	# Sample new trail points while moving
	if is_moving:
		if trail_points.is_empty() or global_position.distance_to(trail_points[0]) >= MIN_TRAIL_DIST:
			trail_points.push_front(global_position)
			trail_lifetimes.push_front(TRAIL_LIFETIME)

	# Update the Line2D geometry
	if trail_points.size() >= 1:
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(global_position)
		for p: Vector2 in trail_points:
			pts.append(p)
		trail_line.points = pts
	else:
		trail_line.clear_points()

func launch(dir: Vector2, speed: float) -> void:
	velocity = dir.normalized() * speed
	is_moving = true
	bounce_count = 0
	trail_points.clear()
	trail_lifetimes.clear()
	if is_instance_valid(trail_line):
		trail_line.clear_points()

	# Elastic snap back from slingshot pull
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 0.8), 0.05)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "rotation", 0.0, 0.12)

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	is_moving = false
	bounce_count = 0
	hit_flash = 0.0
	color_index = 0
	target_color = BOUNCE_PALETTE[0]
	current_color = target_color
	_update_trail_color(target_color)
	ball_basis = Basis.IDENTITY
	trail_points.clear()
	trail_lifetimes.clear()
	if is_instance_valid(trail_line):
		trail_line.clear_points()
	scale = Vector2.ONE
	rotation = 0.0
	queue_redraw()

func set_aim_stretch(dir: Vector2, power: float) -> void:
	if is_moving:
		return
	if power > 0.05:
		rotation = dir.angle()
		scale = Vector2(1.0 + power * 0.4, 1.0 - power * 0.25)
	else:
		scale = Vector2.ONE
		rotation = 0.0

func apply_impact_squash(normal: Vector2, impact_speed: float) -> void:
	var norm_speed: float = clampf(impact_speed / 700.0, 0.15, 0.85)
	rotation = normal.angle()
	scale = Vector2(1.0 - norm_speed * 0.45, 1.0 + norm_speed * 0.45)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.1, 0.9), 0.06).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SPRING)
	tw.parallel().tween_property(self, "rotation", 0.0, 0.14)

## Executes sub-stepped collision checking against course wall segments with zero tunneling
func step_physics(delta: float, segments: Array, finish_data: Dictionary, diamonds: Array, course: Course = null) -> void:
	if not is_moving:
		return

	var speed: float = velocity.length()
	if speed < 1e-4:
		is_moving = false
		stopped.emit()
		return

	var steps: int = clampi(int(ceil((speed * delta) / PhysicsConstants.MAX_SUB_STEP_DIST)), 4, 32)
	var sub_dt: float = delta / float(steps)

	for s in range(steps):
		var prev_pos: Vector2 = global_position
		var step_move: Vector2 = velocity * sub_dt
		global_position += step_move

		# 1. Continuous crossing check: did trajectory pass through any wall segment?
		for seg: Dictionary in segments:
			var a: Vector2 = seg["a"]
			var b: Vector2 = seg["b"]
			var x_res = GeometryUtils.ray_segment_intersect(prev_pos.x, prev_pos.y, step_move.x, step_move.y, a.x, a.y, b.x, b.y)
			if x_res != null and x_res["t"] <= 1.0:
				var s_vec: Vector2 = b - a
				var s_len: float = s_vec.length()
				if s_len > 1e-4:
					var n_cand := Vector2(-s_vec.y, s_vec.x) / s_len
					if velocity.dot(n_cand) > 0.0:
						n_cand = -n_cand
					var hit_pt: Vector2 = x_res["point"]
					global_position = hit_pt + n_cand * (radius + 0.1)

					var vn: float = velocity.dot(n_cand)
					if vn < 0.0:
						var impact_speed: float = -vn
						velocity -= (1.0 + restitution) * vn * n_cand
						bounce_count += 1
						hit_flash = 1.0
						seg["flash"] = 1.0

						color_index = (color_index + 1) % BOUNCE_PALETTE.size()
						target_color = BOUNCE_PALETTE[color_index]
						_update_trail_color(target_color)

						if seg.has("course") and is_instance_valid(seg["course"]):
							seg["course"].trigger_segment_flash(seg)
						elif seg.has("obstacle") and is_instance_valid(seg["obstacle"]):
							seg["obstacle"].trigger_flash(seg["seg_idx"])

						if not trail_points.is_empty() and hit_pt.distance_to(trail_points[0]) >= 2.0:
							trail_points.push_front(hit_pt)
							trail_lifetimes.push_front(TRAIL_LIFETIME)

						bounced.emit(hit_pt, n_cand, impact_speed, bounce_count)
						break

		# 2. Discrete proximity & penetration resolution
		for seg: Dictionary in segments:
			var a: Vector2 = seg["a"]
			var b: Vector2 = seg["b"]
			var c_res: Dictionary = GeometryUtils.closest_point_on_segment(global_position, a, b)
			var c: Vector2 = c_res["point"]
			var diff: Vector2 = global_position - c
			var d_sq: float = diff.length_squared()

			if d_sq < radius * radius:
				var d: float = sqrt(d_sq)
				var normal: Vector2 = Vector2.ZERO
				if d > 1e-4:
					normal = diff / d
				else:
					var s_vec: Vector2 = (b - a).normalized()
					normal = Vector2(-s_vec.y, s_vec.x)
					if velocity.dot(normal) > 0.0:
						normal = -normal

				# Push ball away from wall surface
				var overlap: float = radius - d + 0.05
				global_position += normal * overlap

				var vn: float = velocity.dot(normal)
				if vn < 0.0:
					var impact_speed: float = -vn
					velocity -= (1.0 + restitution) * vn * normal
					bounce_count += 1
					hit_flash = 1.0
					seg["flash"] = 1.0

					color_index = (color_index + 1) % BOUNCE_PALETTE.size()
					target_color = BOUNCE_PALETTE[color_index]
					_update_trail_color(target_color)

					if seg.has("course") and is_instance_valid(seg["course"]):
						seg["course"].trigger_segment_flash(seg)
					elif seg.has("obstacle") and is_instance_valid(seg["obstacle"]):
						seg["obstacle"].trigger_flash(seg["seg_idx"])

					if not trail_points.is_empty() and c.distance_to(trail_points[0]) >= 2.0:
						trail_points.push_front(c)
						trail_lifetimes.push_front(TRAIL_LIFETIME)

					bounced.emit(c, normal, impact_speed, bounce_count)

		# 3. Outer boundary containment safety net & Out of Bounds detection
		if is_instance_valid(course):
			var local_pos: Vector2 = course.to_local(global_position)
			if course.outer_poly.size() >= 3:
				if not Geometry2D.is_point_in_polygon(local_pos, course.outer_poly):
					var containment: Dictionary = GeometryUtils.closest_point_on_polygon(local_pos, course.outer_poly)
					var c_edge_local: Vector2 = containment["point"]
					var in_norm: Vector2 = containment["inward_normal"]
					var edge_dist: float = local_pos.distance_to(c_edge_local)

					# If the ball has breached the boundary into the void
					if edge_dist > 5.0 or (velocity.dot(in_norm) < 0.0 and edge_dist > 2.0):
						is_moving = false
						velocity = Vector2.ZERO
						out_of_bounds.emit()
						return
					else:
						# Micro-grazing containment
						var c_edge_global: Vector2 = course.to_global(c_edge_local)
						global_position = c_edge_global + in_norm * (radius + 0.5)
						if velocity.dot(in_norm) < 0.0:
							velocity = velocity.bounce(in_norm) * restitution
						bounce_count += 1
						hit_flash = 1.0
						color_index = (color_index + 1) % BOUNCE_PALETTE.size()
						target_color = BOUNCE_PALETTE[color_index]
						_update_trail_color(target_color)
						bounced.emit(c_edge_global, in_norm, velocity.length(), bounce_count)
			elif not course.bounds.grow(60.0).has_point(local_pos):
				is_moving = false
				velocity = Vector2.ZERO
				out_of_bounds.emit()
				return


		# Check diamond collection
		for dm in diamonds:
			if is_instance_valid(dm) and not dm.is_collected:
				var collect_dist: float = radius + 15.0
				if global_position.distance_squared_to(dm.global_position) < collect_dist * collect_dist:
					dm.collect()
					diamond_hit.emit(dm)

		# Check finish line crossing
		if not finish_data.is_empty():
			var cf_res: Dictionary = GeometryUtils.closest_point_on_segment(
				global_position, finish_data["p1"], finish_data["p2"]
			)
			var cf: Vector2 = cf_res["point"]
			var fin_dist: float = radius + 7.0
			if global_position.distance_squared_to(cf) < fin_dist * fin_dist:
				is_moving = false
				velocity = Vector2.ZERO
				finish_reached.emit()
				break

	# Apply smooth rolling friction
	var cur_speed: float = velocity.length()
	if cur_speed > 0.0:
		var damped: float = cur_speed * exp(-damping * delta) - linear_drag * delta
		if damped <= stop_speed:
			velocity = Vector2.ZERO
			is_moving = false
			bounce_count = 0
			stopped.emit()
		else:
			velocity = (velocity / cur_speed) * damped

func _draw() -> void:
	# 1. Stationary ready pulse halo
	if not is_moving:
		var pulse: float = 0.5 + 0.5 * sin(time_elapsed * 3.4)
		var halo_col := Color(current_color.r, current_color.g, current_color.b, 0.18 + pulse * 0.18)
		draw_arc(Vector2.ZERO, radius + 5.0 + pulse * 3.0, 0.0, TAU, 32, halo_col, 1.5, true)

	# 2. Ground drop shadow
	draw_circle(Vector2(2.5, 3.5), radius * 1.02, Palette.SHADOW)

	# 3. Base shaded sphere (darker bottom-right rim)
	var shade_col := current_color.darkened(0.35)
	draw_circle(Vector2.ZERO, radius, shade_col)

	# 4. Main sphere body (color shifts on bounce; white hit-flash)
	var body_col := Color.WHITE if hit_flash > 0.08 else current_color
	draw_circle(Vector2(-0.8, -0.8), radius * 0.9, body_col)

	# 5. 3D Rolling Equator Meridian Seam
	var seam_pts: PackedVector2Array = PackedVector2Array()
	var seam_col := Color(current_color.r * 1.25, current_color.g * 1.25, current_color.b * 1.25, 0.52)
	for i in range(25):
		var t: float = float(i) * TAU / 24.0
		var local_pt := Vector3(cos(t), sin(t), 0.0)
		var world_pt := ball_basis * local_pt
		if world_pt.z > 0.05:
			seam_pts.append(Vector2(world_pt.x, world_pt.y) * (radius * 0.92))
		else:
			if seam_pts.size() >= 2:
				draw_polyline(seam_pts, seam_col, 1.8, true)
			seam_pts.clear()
	if seam_pts.size() >= 2:
		draw_polyline(seam_pts, seam_col, 1.8, true)

	# 6. 3D Rolling Surface Markers (craters / dots rotating around sphere)
	var dot_col := Color(current_color.r * 0.65, current_color.g * 0.65, current_color.b * 0.65, 0.75)
	for p: Vector3 in SPHERE_MARKERS:
		var wp: Vector3 = ball_basis * p
		if wp.z > 0.08:
			var p2d := Vector2(wp.x, wp.y) * (radius * 0.86)
			var d_size: float = radius * 0.18 * wp.z
			draw_circle(p2d, d_size, dot_col)
			draw_circle(p2d, d_size * 0.5, Color(1.0, 1.0, 1.0, wp.z * 0.8))

	# 7. Stationary specular reflection highlight (upper-left)
	draw_circle(Vector2(-3.5, -3.5), radius * 0.28, Color(1.0, 1.0, 1.0, 0.92))
