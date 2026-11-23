class_name Ball
extends Node2D

## The Moonlit Ricochet Ball with sub-stepped zero-tunneling collision,
## realistic bank reflection, trail, hit flash, and ready halo.

signal bounced(pos: Vector2, normal: Vector2, speed: float, count: int)
signal stopped()
signal diamond_hit(diamond: Node2D)
signal finish_reached()

# --- New Texture Properties ---
@export_group("Visuals")
## The main base texture of the ball.
@export var ball_texture: Texture2D
## Optional emission/glow overlay (e.g. for neon or moonlit rim effect).
@export var glow_overlay: Texture2D
## Modulate color for player visual variations.
@export var base_color: Color = Color.WHITE
## Flash color overlay used on collision bounce.
@export var flash_color: Color = Color.WHITE

@export_group("Dampers & Physics")
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

# squash and stretch dynamics
var current_scale: Vector2 = Vector2.ONE

# Motion trail entries: [{"pos": Vector2, "life": float, "max_life": float, "rotation": float}]
var trail: Array[Dictionary] = []

func _process(delta: float) -> void:
	time_elapsed += delta
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta * 5.0)

	# Smooth visual recovery from squashing/bouncing
	current_scale = current_scale.lerp(Vector2.ONE, delta * 12.0)

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
	# Apply launch stretch
	current_scale = Vector2(1.25, 0.75)

func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	is_moving = false
	bounce_count = 0
	hit_flash = 0.0
	current_scale = Vector2.ONE
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
					
					# High-speed squash and stretch on bounce normal
					current_scale = Vector2(0.7, 1.3)
					
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
	var t_rotation: float = velocity.angle() if is_moving else 0.0
	trail.append({"pos": global_position, "life": 0.34, "max_life": 0.34, "rotation": t_rotation})

func _draw() -> void:
	# 0. Render Texturized Motion Trail
	if ball_texture:
		for pt in trail:
			var ratio: float = clampf(pt["life"] / pt["max_life"], 0.0, 1.0)
			var trail_col := base_color
			trail_col.a = ratio * 0.28
			
			var local_pos: Vector2 = to_local(pt["pos"])
			var trail_size: Vector2 = Vector2(radius * 2.0, radius * 2.0) * (0.3 + ratio * 0.55)
			var rect = Rect2(-trail_size / 2.0 + local_pos, trail_size)
			
			# Draw rotated/scale fading ghosts
			draw_set_transform(local_pos, pt["rotation"], Vector2.ONE)
			draw_texture_rect(ball_texture, Rect2(-trail_size / 2.0, trail_size), false, trail_col)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE) # Reset transforms

	# 1. Stationary Ready Pulse Halo (Texture boundary or outer ring)
	if not is_moving:
		var pulse: float = 0.5 + 0.5 * sin(time_elapsed * 3.4)
		var halo_col := base_color
		halo_col.a = 0.18 + pulse * 0.18
		draw_arc(Vector2.ZERO, radius + 5.0 + pulse * 3.0, 0.0, TAU, 32, halo_col, 1.5, true)

	# 2. Setup Squashing/Spinning Transformations
	var transform_angle = velocity.angle() if is_moving else 0.0
	draw_set_transform(Vector2.ZERO, transform_angle, current_scale)

	# Determine final size/boundaries
	var target_rect = Rect2(-radius, -radius, radius * 2, radius * 2)

	# 3. Drop Shadow Offset
	if not is_moving:
		draw_circle(Vector2(2.5, 3.5), radius * 1.02, Palette.SHADOW)

	# 4. Draw Main Ball Texture (Using Color Modulation & Blend Options)
	if ball_texture:
		# Flash Overlay or base tint modulate
		var final_modulate: Color = base_color.lerp(flash_color, hit_flash)
		draw_texture_rect(ball_texture, target_rect, false, final_modulate)
	else:
		# Fallback procedural draw if texture unassigned
		var body_col = Color("fc0035ff") if hit_flash > 0.1 else Palette.BALL_BODY
		draw_circle(Vector2.ZERO, radius, body_col)

	# 5. Optional Emit/Neon Glow Overlay
	if glow_overlay:
		var glow_col = Color.WHITE
		glow_col.a = 0.5 + 0.5 * sin(time_elapsed * 2.0) # Pulses visual intensity
		draw_texture_rect(glow_overlay, target_rect, false, glow_col)

	# Restore Default View transform to protect any sub-nodes
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
