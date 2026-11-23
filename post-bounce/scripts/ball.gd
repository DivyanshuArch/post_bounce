class_name Ball
extends Node2D

## The Moonlit Ricochet Ball with sub-stepped zero-tunneling collision,
## realistic bank reflection, trail, hit flash, and ready halo.

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

# Motion trail entries: [{"pos": Vector2, "life": float, "max_life": float}]
var trail: Array[Dictionary] = []

func _process(delta: float) -> void:
	time_elapsed += delta
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta * 5.0)

	for i in range(trail.size() - 1, -1, -1):
		trail[i]["life"] -= delta
		if trail[i]["life"] <= 0.0:
			trail.remove_at(i)

	queue_redraw()

func launch(dir: Vector2, speed: float) -> void:
	velocity = dir.normalized() * speed
	is_moving = true
	bounce_count = 0
	trail.clear()

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	is_moving = false
	bounce_count = 0
	hit_flash = 0.0
	trail.clear()
	queue_redraw()

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

	# Record motion trail point
	trail.append({"pos": global_position, "life": 0.34, "max_life": 0.34})

func _draw() -> void:
	# 0. Motion trail
	for pt in trail:
		var ratio: float = clampf(pt["life"] / pt["max_life"], 0.0, 1.0)
		var t_col := Color(0.957, 0.949, 0.925, ratio * 0.28)
		var local_p: Vector2 = to_local(pt["pos"])
		draw_circle(local_p, radius * (0.3 + ratio * 0.55), t_col)

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
