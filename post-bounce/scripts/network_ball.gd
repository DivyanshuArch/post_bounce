class_name NetworkBall
extends Ball

## Networked Ball for 2-Player Multiplayer Moonlit Ricochet.
## Features rock-solid movement synchronization with deterministic sub-step prediction,
## real-time aiming stretch replication, continuous position & velocity sync,
## and finish-line state management.

@export var peer_id: int = 1
@export var is_local: bool = false
@export var player_display_name: String = "Player"
var has_finished: bool = false

var overhead_label: Label
var halo_color: Color = Color("#88ddaa")
var sync_timer: float = 0.0
const SYNC_INTERVAL: float = 0.04 # 25 Hz position sync broadcast

# Remote interpolation targets
var target_sync_pos: Vector2 = Vector2.ZERO
var target_sync_vel: Vector2 = Vector2.ZERO
var is_remote_moving: bool = false

func _ready() -> void:
	super._ready()
	_setup_overhead_label()
	target_sync_pos = global_position
	stopped.connect(_on_self_stopped)
	finish_reached.connect(_on_self_finish_reached)

func setup_player(p_id: int, p_name: String, p_color: Color, p_is_local: bool) -> void:
	peer_id = p_id
	player_display_name = p_name
	halo_color = p_color
	is_local = p_is_local
	has_finished = false

	target_color = p_color
	current_color = p_color
	_update_trail_color(p_color)

	if overhead_label:
		overhead_label.text = player_display_name
		overhead_label.modulate = p_color

	target_sync_pos = global_position
	queue_redraw()

func _setup_overhead_label() -> void:
	overhead_label = Label.new()
	overhead_label.text = player_display_name
	overhead_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overhead_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overhead_label.add_theme_font_size_override("font_size", 11)
	overhead_label.modulate = halo_color
	overhead_label.size = Vector2(100, 20)
	overhead_label.position = Vector2(-50, -32)
	add_child(overhead_label)

func local_set_aim(dir: Vector2, power: float) -> void:
	if not is_local or has_finished or is_moving:
		return
	set_aim_stretch(dir, power)
	rpc("rpc_aim_update", dir, power)

func local_launch(dir: Vector2, speed: float) -> void:
	if not is_local or has_finished or is_moving:
		return
	launch(dir, speed)
	sync_timer = 0.0
	rpc("rpc_launch_ball", dir, speed, global_position)

func local_step_physics(delta: float, segments: Array, finish_data: Dictionary, diamonds: Array) -> void:
	if has_finished or not is_moving:
		return

	step_physics(delta, segments, finish_data, diamonds)

	# Broadcast periodic position sync while moving
	sync_timer += delta
	if sync_timer >= SYNC_INTERVAL:
		sync_timer = 0.0
		rpc("rpc_sync_ball", global_position, velocity, is_moving)

func remote_step_physics(delta: float, segments: Array, finish_data: Dictionary, diamonds: Array) -> void:
	if has_finished:
		is_moving = false
		velocity = Vector2.ZERO
		return

	if is_moving:
		step_physics(delta, segments, finish_data, diamonds)
		# Smoothly converge remote position towards synced target
		var dist := global_position.distance_to(target_sync_pos)
		if dist > 35.0:
			global_position = target_sync_pos
		elif dist > 1.0:
			global_position = global_position.lerp(target_sync_pos, 0.35)

func _on_self_stopped() -> void:
	if is_local and not has_finished:
		rpc("rpc_stop_ball", global_position)

func _on_self_finish_reached() -> void:
	if has_finished:
		return
	has_finished = true
	is_moving = false
	velocity = Vector2.ZERO
	if is_local:
		rpc("rpc_ball_finished", global_position)

# ----------------- Remote Procedure Calls -----------------

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_aim_update(dir: Vector2, power: float) -> void:
	if is_local or has_finished:
		return
	set_aim_stretch(dir, power)

@rpc("any_peer", "call_remote", "reliable")
func rpc_launch_ball(dir: Vector2, speed: float, origin: Vector2) -> void:
	if is_local or has_finished:
		return
	global_position = origin
	target_sync_pos = origin
	target_sync_vel = dir * speed
	set_aim_stretch(Vector2.ZERO, 0.0)
	launch(dir, speed)
	SoundManager.play_shoot(clampf(speed / PhysicsConstants.MAX_LAUNCH_SPEED, 0.2, 1.0))

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_sync_ball(pos: Vector2, vel: Vector2, moving: bool) -> void:
	if is_local or has_finished:
		return
	target_sync_pos = pos
	target_sync_vel = vel
	is_moving = moving

	var dist := global_position.distance_to(pos)
	if dist > 35.0:
		global_position = pos
	elif dist > 1.5:
		global_position = global_position.lerp(pos, 0.4)
	velocity = vel

@rpc("any_peer", "call_remote", "reliable")
func rpc_stop_ball(final_pos: Vector2) -> void:
	if is_local or has_finished:
		return
	global_position = final_pos
	target_sync_pos = final_pos
	velocity = Vector2.ZERO
	is_moving = false
	stopped.emit()

@rpc("any_peer", "call_remote", "reliable")
func rpc_ball_finished(finish_pos: Vector2) -> void:
	if has_finished:
		return
	has_finished = true
	global_position = finish_pos
	target_sync_pos = finish_pos
	velocity = Vector2.ZERO
	is_moving = false
	finish_reached.emit()

func _draw() -> void:
	super._draw()
	# Draw subtle colored player halo ring around ball
	var halo_alpha := 0.25 if has_finished else 0.55
	draw_arc(Vector2.ZERO, radius + 3.0, 0, TAU, 24, Color(halo_color.r, halo_color.g, halo_color.b, halo_alpha), 1.5)
