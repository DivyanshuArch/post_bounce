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
	grad.set_color(0, Color(0.957, 0.949, 0.925, 0.42))
	grad.set_color(1, Color(0.957, 0.949, 0.925, 0.0))
	trail_line.gradient = grad

	add_child(trail_line)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	time_elapsed += delta
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta * 5.0)

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

## Executes sub-stepped collision checking against course wall segments
func step_physics(delta: float, segments: Array, finish_data: Dictionary, diamonds: Array) -> void:
	if not is_moving:
		return

	var speed: float = velocity.length()
	if speed < 1e-4:
		is_moving = false
		stopped.emit()
		return

	var steps: int = clampi(int(ceil((speed * delta) / PhysicsConstants.MAX_SUB_STEP_DIST)), 2, 24)
	var sub_dt: float = delta / float(steps)

	for s in range(steps):
		global_position += velocity * sub_dt

		# Collision against every polygonal wall segment
		for seg: Dictionary in segments:
			var c_res: Dictionary = GeometryUtils.closest_point_on_segment(global_position, seg["a"], seg["b"])
			var c: Vector2 = c_res["point"]
			var diff: Vector2 = global_position - c
			var d2: float = diff.length_squared()

			if d2 < radius * radius and d2 > 1e-8:
				var d: float = sqrt(d2)
				var normal: Vector2 = diff / d
				var overlap: float = radius - d + 0.02
				global_position += normal * overlap

				var vn: float = velocity.dot(normal)
				if vn < 0.0:
					var impact_speed: float = -vn
					velocity -= (1.0 + restitution) * vn * normal
					bounce_count += 1
					hit_flash = 1.0
					seg["flash"] = 1.0
					if seg.has("course") and is_instance_valid(seg["course"]):
						seg["course"].trigger_segment_flash(seg)
					elif seg.has("obstacle") and is_instance_valid(seg["obstacle"]):
						seg["obstacle"].trigger_flash(seg["seg_idx"])

					# Crisp sharp corner at wall bounce apex
					if not trail_points.is_empty() and c.distance_to(trail_points[0]) >= 2.0:
						trail_points.push_front(c)
						trail_lifetimes.push_front(TRAIL_LIFETIME)

					bounced.emit(c, normal, impact_speed, bounce_count)

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
		var halo_col := Color(0.957, 0.949, 0.925, 0.18 + pulse * 0.18)
		draw_arc(Vector2.ZERO, radius + 5.0 + pulse * 3.0, 0.0, TAU, 32, halo_col, 1.5, true)

	# 2. Ground drop shadow
	draw_circle(Vector2(2.5, 3.5), radius * 1.02, Palette.SHADOW)

	# 3. Base shaded sphere
	draw_circle(Vector2.ZERO, radius, Palette.BALL_SHADE)

	# 4. Moonlit upper-left body
	var body_col: Color = Color("#fff8c7") if hit_flash > 0.1 else Palette.BALL_BODY
	draw_circle(Vector2(-1.0, -1.0), radius * 0.88, body_col)

	# 5. Specular moon highlight
	draw_circle(Vector2(-3.5, -3.5), radius * 0.28, Color.WHITE)
