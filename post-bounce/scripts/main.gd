class_name Main
extends Node2D

## Main scene controller for Moonlit Ricochet.
## Coordinates courses, slingshot aim-and-shoot, camera framing, particles, and HUD.

@export var current_course_index: int = 0

var shots_taken: int = 0
var course_cleared: bool = false
var clear_timer: float = 0.0

var aim_active: bool = false
var aim_start: Vector2 = Vector2.ZERO
var aim_curr: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.ZERO
var aim_power: float = 0.0

var shake_mag: float = 0.0
var target_cam_pos: Vector2 = Vector2(400.0, 300.0)
var target_zoom: float = 1.0

@onready var course: Course = $World/Course
@onready var ball: Ball = $World/Ball
@onready var aim_guide: AimGuide = $World/AimGuide
@onready var particle_manager: ParticleManager = $World/ParticleManager
@onready var camera: Camera2D = $World/Camera2D
@onready var atmosphere: Atmosphere = $Atmosphere
@onready var hud: HUD = $HUD

func _ready() -> void:
	ball.bounced.connect(_on_ball_bounced)
	ball.diamond_hit.connect(_on_diamond_hit)
	ball.finish_reached.connect(_on_finish_reached)

	hud.reset_requested.connect(func(): load_course(current_course_index, false))
	hud.skip_requested.connect(func(): load_course(current_course_index + 1, false))
	hud.sound_toggled.connect(_on_sound_toggled)

	get_viewport().size_changed.connect(_on_viewport_resized)

	load_course(0, true)

func load_course(index: int, snap_cam: bool = false) -> void:
	current_course_index = index
	shots_taken = 0
	course_cleared = false
	clear_timer = 0.0
	aim_active = false
	shake_mag = 0.0

	var def: Dictionary
	if index < 6:
		def = CourseManager.get_handcrafted_course(index)
	else:
		def = CourseManager.generate_procedural_course(index + 1)

	var seed_val: int = (index + 1) * 53993 + 911
	course.setup_from_def(def, seed_val)

	ball.reset_to(course.start_position)
	hud.update_course_info(index + 1, shots_taken)
	hud.hide_course_clear()

	_compute_camera_framing(snap_cam)

func _compute_camera_framing(snap: bool = false) -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var pad_x: float = maxf(76.0, vp_size.x * 0.1)
	var pad_y: float = maxf(105.0, vp_size.y * 0.14)
	var avail_w: float = maxf(200.0, vp_size.x - pad_x * 2.0)
	var avail_h: float = maxf(200.0, vp_size.y - pad_y * 2.0)

	var bw: float = maxf(100.0, course.bounds.size.x)
	var bh: float = maxf(100.0, course.bounds.size.y)
	var fit_zoom: float = minf(avail_w / bw, avail_h / bh)

	target_zoom = clampf(fit_zoom, 0.42, 1.25)
	target_cam_pos = course.bounds_center

	if snap:
		camera.position = target_cam_pos
		camera.zoom = Vector2(target_zoom, target_zoom)

func _on_viewport_resized() -> void:
	_compute_camera_framing(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			aim_active = false
			_update_aim_guide()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not ball.is_moving and not course_cleared:
					aim_active = true
					aim_start = mb.position
					aim_curr = mb.position
					aim_power = 0.0
					_update_aim_guide()
			else:
				_release_shot()

	elif event is InputEventMouseMotion:
		if aim_active:
			aim_curr = event.position
			_update_aim_vector()
			_update_aim_guide()

	elif event is InputEventKey and event.pressed:
		var k: InputEventKey = event
		if k.keycode == KEY_R:
			load_course(current_course_index, false)
		elif k.keycode == KEY_ESCAPE:
			aim_active = false
			_update_aim_guide()

func _update_aim_vector() -> void:
	# Slingshot: pulling back shoots in opposite direction
	var pull: Vector2 = aim_start - aim_curr
	var pull_len: float = pull.length()
	if pull_len > 1.0:
		aim_dir = pull.normalized()
		aim_power = clampf(pull_len / PhysicsConstants.MAX_PULL, 0.0, 1.0)
	else:
		aim_power = 0.0

func _update_aim_guide() -> void:
	var finish_data: Dictionary = course.finish_line.get_global_segment() if is_instance_valid(course.finish_line) else {}
	aim_guide.set_aim_state(aim_active, ball.global_position, aim_dir, aim_power, course.get_all_segments(), finish_data)

func _release_shot() -> void:
	if not aim_active:
		return
	aim_active = false
	_update_aim_guide()

	if ball.is_moving or course_cleared:
		return
	if aim_power < (PhysicsConstants.MIN_PULL / PhysicsConstants.MAX_PULL):
		return

	var eased_power: float = pow(aim_power, 1.12)
	var launch_speed: float = PhysicsConstants.MIN_LAUNCH_SPEED + eased_power * (PhysicsConstants.MAX_LAUNCH_SPEED - PhysicsConstants.MIN_LAUNCH_SPEED)

	ball.launch(aim_dir, launch_speed)
	shots_taken += 1
	hud.update_course_info(current_course_index + 1, shots_taken, true)

	SoundManager.play_shoot(aim_power)

	var dust_pos: Vector2 = ball.global_position - aim_dir * ball.radius
	particle_manager.spawn_bounce_dust(dust_pos, -aim_dir, launch_speed * 0.5)
	hud.on_first_shot()

func _physics_process(delta: float) -> void:
	if ball.is_moving and not course_cleared:
		var finish_data: Dictionary = course.finish_line.get_global_segment() if is_instance_valid(course.finish_line) else {}
		ball.step_physics(delta, course.get_all_segments(), finish_data, course.diamonds)

func _process(delta: float) -> void:
	# Course clear countdown
	if course_cleared:
		clear_timer -= delta
		if clear_timer <= 0.0:
			load_course(current_course_index + 1, false)

	# Camera smooth follow + framing
	var follow_bias: float = 0.08
	var desired_pos: Vector2 = course.bounds_center.lerp(ball.global_position, follow_bias)
	camera.position = camera.position.lerp(desired_pos, 1.0 - exp(-6.0 * delta))

	var cur_zoom: float = camera.zoom.x
	var next_zoom: float = lerpf(cur_zoom, target_zoom, 1.0 - exp(-6.0 * delta))
	camera.zoom = Vector2(next_zoom, next_zoom)

	# Micro screenshake
	if shake_mag > 0.05:
		camera.offset = Vector2((randf() - 0.5) * 2.0 * shake_mag, (randf() - 0.5) * 2.0 * shake_mag)
		shake_mag *= exp(-18.0 * delta)
	else:
		camera.offset = Vector2.ZERO
		shake_mag = 0.0

	# Update atmosphere
	var cam_offset: Vector2 = camera.position - course.bounds_center
	atmosphere.update_atmosphere(delta, cam_offset)

func _on_ball_bounced(c: Vector2, normal: Vector2, impact_speed: float, count: int) -> void:
	if impact_speed > 45.0:
		SoundManager.play_bounce(impact_speed, count)
		particle_manager.spawn_bounce_dust(c, normal, impact_speed)
		if impact_speed > 260.0:
			shake_mag = minf(6.5, shake_mag + (impact_speed - 220.0) * 0.0085)

func _on_diamond_hit(dm: Node2D) -> void:
	SoundManager.play_diamond_chime()
	particle_manager.spawn_diamond_burst(dm.global_position)

func _on_finish_reached() -> void:
	if course_cleared:
		return
	course_cleared = true
	clear_timer = 1.45

	SoundManager.play_finish_fanfare()

	particle_manager.spawn_finish_celebration(ball.global_position)

	var collected_count: int = 0
	for d in course.diamonds:
		if is_instance_valid(d) and d.is_collected:
			collected_count += 1

	hud.show_course_clear(shots_taken, collected_count)

func _on_sound_toggled() -> void:
	var muted: bool = SoundManager.toggle_mute()
	hud.update_sound_icon(muted)
