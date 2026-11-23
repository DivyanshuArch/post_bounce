class_name MultiplayerGame
extends Node2D

## 2-Player Local Wi-Fi & Hotspot Multiplayer Match Controller.
## Coordinates synchronized course loading, dual ball spawning with deterministic paths,
## live aiming replication, real-time scorecard HUD, waiting spectate state,
## and full hole victory / advancement evaluation.

var current_course_index: int = 0
var course: Course

var local_ball: NetworkBall
var remote_ball: NetworkBall
var balls_by_peer: Dictionary = {} # peer_id -> NetworkBall

var aim_active: bool = false
var aim_start: Vector2 = Vector2.ZERO
var aim_curr: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.ZERO
var aim_power: float = 0.0

var trauma: float = 0.0
const MAX_SHAKE_OFFSET: float = 12.0
const MAX_SHAKE_ROLL: float = 0.06

var target_cam_pos: Vector2 = Vector2(400.0, 300.0)
var target_zoom: float = 1.0

# Match cumulative scores (holes won)
static var match_holes_won: Dictionary = {} # peer_id -> int

# State flags
var hole_completed_by_both: bool = false
var toast_timer: float = 0.0

# Nodes
@onready var world: Node2D = $World
@onready var camera: Camera2D = $World/Camera2D
@onready var aim_guide: AimGuide = $World/AimGuide
@onready var particle_manager: ParticleManager = $World/ParticleManager
@onready var atmosphere: Atmosphere = $Atmosphere

# Top HUD Nodes
@onready var p1_name_lbl: Label = %P1NameLabel
@onready var p1_shots_lbl: Label = %P1ShotsLabel
@onready var p1_status_lbl: Label = %P1StatusLabel

@onready var p2_name_lbl: Label = %P2NameLabel
@onready var p2_shots_lbl: Label = %P2ShotsLabel
@onready var p2_status_lbl: Label = %P2StatusLabel

@onready var course_title_lbl: Label = %CourseTitleLabel

# Toast
@onready var toast_banner: PanelContainer = %ToastBanner
@onready var toast_lbl: Label = %ToastLabel

# Waiting Banner (Shows when local player has finished, waiting for opponent)
@onready var waiting_banner: PanelContainer = %WaitingBanner
@onready var waiting_title_lbl: Label = %WaitingTitleLabel
@onready var waiting_subtitle_lbl: Label = %WaitingSubtitleLabel
@onready var waiting_p1_lbl: Label = %WaitingP1Label
@onready var waiting_p2_lbl: Label = %WaitingP2Label
@onready var waiting_status_lbl: Label = %WaitingStatusLabel

# Winner / Result Banner (Shows when BOTH players complete the hole)
@onready var winner_banner: PanelContainer = %WinnerBanner
@onready var winner_text_lbl: Label = %WinnerTextLabel
@onready var winner_sub_lbl: Label = %WinnerSubLabel
@onready var winner_p1_lbl: Label = %WinnerP1Label
@onready var winner_p2_lbl: Label = %WinnerP2Label
@onready var match_score_lbl: Label = %MatchScoreLabel
@onready var next_course_btn: Button = %NextCourseButton
@onready var leave_match_btn: Button = %LeaveMatchButton

func _ready() -> void:
	waiting_banner.visible = false
	winner_banner.visible = false
	toast_banner.visible = false
	next_course_btn.pressed.connect(_on_next_course_pressed)
	leave_match_btn.pressed.connect(_on_leave_match_pressed)

	if NetworkManager:
		NetworkManager.course_changed.connect(_on_network_course_changed)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
		current_course_index = NetworkManager.current_course_index

	load_multiplayer_course(current_course_index)

func load_multiplayer_course(index: int) -> void:
	current_course_index = index
	hole_completed_by_both = false
	waiting_banner.visible = false
	winner_banner.visible = false
	toast_banner.visible = false
	aim_active = false
	trauma = 0.0
	Engine.time_scale = 1.0

	# 1. Clean up old course & balls
	if is_instance_valid(course):
		course.queue_free()
	for b in balls_by_peer.values():
		if is_instance_valid(b):
			b.queue_free()
	balls_by_peer.clear()

	# 2. Reset hole stats in NetworkManager
	if NetworkManager:
		for p_id in NetworkManager.players.keys():
			NetworkManager.players[p_id]["shots"] = 0
			NetworkManager.players[p_id]["diamonds"] = 0
			NetworkManager.players[p_id]["finished"] = false
			if not match_holes_won.has(p_id):
				match_holes_won[p_id] = 0

	# 3. Instantiate Course (Deterministic handcrafted 1-6 or procedural 7+)
	var level_path := "res://levels/level_%d.tscn" % (index + 1)
	if ResourceLoader.exists(level_path):
		var scene = load(level_path)
		if scene is PackedScene:
			course = scene.instantiate()
			world.add_child(course)
	else:
		var base_course_scene = preload("res://scenes/prefabs/course.tscn")
		course = base_course_scene.instantiate()
		world.add_child(course)
		var def := CourseManager.get_handcrafted_course(index) if index < 6 else CourseManager.generate_procedural_course(index + 1)
		var seed_val: int = (index + 1) * 53993 + 911
		course.setup_from_def(def, seed_val)

	course_title_lbl.text = "HOLE %d" % (index + 1)

	# 4. Spawn Network Balls with deterministic node names
	_spawn_player_balls()

	# 5. Camera Framing
	_compute_camera_framing(true)

	# 6. Update HUD Scorecards
	_update_hud_scorecards()

func _spawn_player_balls() -> void:
	if not NetworkManager:
		return

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var start_pos := course.start_position

	var peer_ids := NetworkManager.players.keys()
	peer_ids.sort() # P1 (1) first, P2 second

	for i in range(peer_ids.size()):
		var p_id: int = peer_ids[i]
		var p_info: Dictionary = NetworkManager.players[p_id]
		var is_local_player := (p_id == my_id)

		var ball_node: NetworkBall = NetworkBall.new()
		# Deterministic node name so RPCs route across host and client perfectly!
		ball_node.name = "Ball_%d" % p_id

		# Slight tee offset so balls don't directly overlap
		var offset := Vector2(-14.0 if i == 0 else 14.0, 0.0)
		ball_node.position = start_pos + offset
		world.add_child(ball_node)

		var p_color: Color = p_info.get("color", Color("#88ddaa") if i == 0 else Color("#fae366"))
		ball_node.setup_player(p_id, p_info.get("name", "Player %d" % (i + 1)), p_color, is_local_player)

		ball_node.bounced.connect(func(pos, norm, spd, cnt): _on_ball_bounced(ball_node, pos, norm, spd, cnt))
		ball_node.diamond_hit.connect(func(d): _on_ball_diamond_hit(ball_node, d))
		ball_node.finish_reached.connect(func(): _on_ball_finish_reached(ball_node))

		balls_by_peer[p_id] = ball_node
		if is_local_player:
			local_ball = ball_node
		else:
			remote_ball = ball_node

func _compute_camera_framing(snap: bool = false) -> void:
	if not is_instance_valid(course):
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var pad_x: float = maxf(76.0, vp_size.x * 0.1)
	var pad_y: float = maxf(110.0, vp_size.y * 0.15)
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

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(local_ball) or local_ball.has_finished or local_ball.is_moving:
		return

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if NetworkManager and NetworkManager.players.has(my_id) and NetworkManager.players[my_id].get("finished", false):
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			aim_active = false
			local_ball.local_set_aim(Vector2.ZERO, 0.0)
			_update_aim_guide()
			return

		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
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
			var pull := aim_start - aim_curr
			var pull_len := pull.length()
			if pull_len > 1.0:
				aim_dir = pull.normalized()
				aim_power = clampf(pull_len / PhysicsConstants.MAX_PULL, 0.0, 1.0)
			else:
				aim_power = 0.0
			local_ball.local_set_aim(aim_dir, aim_power)
			_update_aim_guide()

func _update_aim_guide() -> void:
	if not is_instance_valid(course) or not is_instance_valid(local_ball) or local_ball.has_finished:
		aim_guide.set_aim_state(false, Vector2.ZERO, Vector2.ZERO, 0.0, [], {})
		return
	var finish_data: Dictionary = course.finish_line.get_global_segment() if is_instance_valid(course.finish_line) else {}
	aim_guide.set_aim_state(aim_active, local_ball.global_position, aim_dir, aim_power, course.get_all_segments(), finish_data)

func _release_shot() -> void:
	if not aim_active or not is_instance_valid(local_ball) or local_ball.has_finished:
		return
	aim_active = false
	local_ball.local_set_aim(Vector2.ZERO, 0.0)
	_update_aim_guide()

	if aim_power < (PhysicsConstants.MIN_PULL / PhysicsConstants.MAX_PULL):
		return

	var eased_power := pow(aim_power, 1.12)
	var launch_speed := PhysicsConstants.MIN_LAUNCH_SPEED + eased_power * (PhysicsConstants.MAX_LAUNCH_SPEED - PhysicsConstants.MIN_LAUNCH_SPEED)

	local_ball.local_launch(aim_dir, launch_speed)

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if NetworkManager and NetworkManager.players.has(my_id):
		NetworkManager.players[my_id]["shots"] += 1
		var s: int = NetworkManager.players[my_id]["shots"]
		rpc("rpc_report_player_shot", my_id, s)

	SoundManager.play_shoot(aim_power)
	var dust_pos: Vector2 = local_ball.global_position - aim_dir * local_ball.radius
	particle_manager.spawn_bounce_dust(dust_pos, -aim_dir, launch_speed * 0.5)
	add_trauma(0.12 + aim_power * 0.15)
	_update_hud_scorecards()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(course):
		return

	var segments := course.get_all_segments()
	var finish_data := course.finish_line.get_global_segment() if is_instance_valid(course.finish_line) else {}

	for b in balls_by_peer.values():
		if is_instance_valid(b) and not b.has_finished:
			if b.is_local:
				b.local_step_physics(delta, segments, finish_data, course.diamonds)
			else:
				b.remote_step_physics(delta, segments, finish_data, course.diamonds)

func _process(delta: float) -> void:
	# Toast timer
	if toast_timer > 0.0:
		toast_timer -= delta
		if toast_timer <= 0.0:
			toast_banner.visible = false

	# Camera follow: follow local ball if playing; if local ball finished, smoothly spectate remote ball!
	if is_instance_valid(course):
		var target_node: Node2D = local_ball
		if is_instance_valid(local_ball) and local_ball.has_finished and is_instance_valid(remote_ball) and not remote_ball.has_finished:
			target_node = remote_ball
		elif not is_instance_valid(target_node):
			target_node = remote_ball

		if is_instance_valid(target_node):
			var desired_pos := course.bounds_center.lerp(target_node.global_position, 0.12)
			camera.position = camera.position.lerp(desired_pos, 1.0 - exp(-6.0 * delta))
			var cur_z := camera.zoom.x
			var next_z := lerpf(cur_z, target_zoom, 1.0 - exp(-6.0 * delta))
			camera.zoom = Vector2(next_z, next_z)

	# Camera trauma shake
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - delta * 1.5)
		var shake := trauma * trauma
		camera.offset = Vector2(
			(randf() - 0.5) * 2.0 * MAX_SHAKE_OFFSET * shake,
			(randf() - 0.5) * 2.0 * MAX_SHAKE_OFFSET * shake
		)
		camera.rotation = (randf() - 0.5) * 2.0 * MAX_SHAKE_ROLL * shake
	else:
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0

	if is_instance_valid(course):
		var cam_offset := camera.position - course.bounds_center
		atmosphere.update_atmosphere(delta, cam_offset)

func add_trauma(amount: float) -> void:
	if GameSettings and not GameSettings.screen_shake_enabled:
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)

func _show_toast(msg: String, duration: float = 3.5) -> void:
	toast_lbl.text = msg
	toast_banner.visible = true
	toast_timer = duration

# ----------------- Ball Callbacks -----------------

func _on_ball_bounced(b: NetworkBall, c: Vector2, normal: Vector2, impact_speed: float, count: int) -> void:
	b.apply_impact_squash(normal, impact_speed)
	if impact_speed > 45.0:
		SoundManager.play_bounce(impact_speed, count)
		particle_manager.spawn_bounce_dust(c, normal, impact_speed)
		if b.is_local:
			var norm_speed: float = clampf(impact_speed / 800.0, 0.0, 1.0)
			add_trauma(norm_speed * 0.45)

func _on_ball_diamond_hit(b: NetworkBall, dm: Node2D) -> void:
	SoundManager.play_diamond_chime()
	particle_manager.spawn_diamond_burst(dm.global_position)
	if b.is_local:
		add_trauma(0.18)
		var my_id: int = b.peer_id
		if NetworkManager and NetworkManager.players.has(my_id):
			NetworkManager.players[my_id]["diamonds"] += 1
			var d_count: int = NetworkManager.players[my_id]["diamonds"]
			rpc("rpc_report_player_diamond", my_id, d_count)
	_update_hud_scorecards()

func _on_ball_finish_reached(b: NetworkBall) -> void:
	SoundManager.play_finish_fanfare()
	particle_manager.spawn_finish_celebration(b.global_position)
	add_trauma(0.4)

	var p_id: int = b.peer_id
	if NetworkManager and NetworkManager.players.has(p_id):
		NetworkManager.players[p_id]["finished"] = true

	if b.is_local:
		aim_active = false
		_update_aim_guide()
		var shots: int = NetworkManager.players[p_id]["shots"]
		var diams: int = NetworkManager.players[p_id]["diamonds"]
		rpc("rpc_report_player_finish", p_id, shots, diams)

	_update_hud_scorecards()
	_evaluate_finish_state()

# ----------------- Finish & Win State Management -----------------

func _evaluate_finish_state() -> void:
	if not NetworkManager or hole_completed_by_both:
		return

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var local_finished := false
	if NetworkManager.players.has(my_id):
		local_finished = NetworkManager.players[my_id].get("finished", false)

	# Check if ALL connected players finished
	var all_finished := true
	for p_id in NetworkManager.players.keys():
		if not NetworkManager.players[p_id].get("finished", false):
			all_finished = false
			break

	if all_finished and NetworkManager.players.size() >= 2:
		# BOTH PLAYERS HAVE COMPLETED THE HOLE!
		hole_completed_by_both = true
		waiting_banner.visible = false
		_show_winner_screen()
	elif local_finished:
		# LOCAL PLAYER FINISHED, OPPONENT IS STILL PLAYING
		_show_waiting_screen()

func _show_waiting_screen() -> void:
	if hole_completed_by_both:
		return

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	var my_info: Dictionary = NetworkManager.players.get(my_id, {})
	var my_shots: int = my_info.get("shots", 0)
	var my_diams: int = my_info.get("diamonds", 0)

	waiting_title_lbl.text = "HOLE COMPLETED!"
	waiting_subtitle_lbl.text = "You finished in %d shots with %d stars!" % [my_shots, my_diams]

	# Find opponent info
	var opp_name := "Opponent"
	var opp_shots := 0
	var opp_diams := 0
	for p_id in NetworkManager.players.keys():
		if p_id != my_id:
			var opp_info: Dictionary = NetworkManager.players[p_id]
			opp_name = opp_info.get("name", "Player 2")
			opp_shots = opp_info.get("shots", 0)
			opp_diams = opp_info.get("diamonds", 0)
			break

	waiting_p1_label_update(my_info.get("name", "You"), my_shots, my_diams)
	waiting_p2_label_update(opp_name, opp_shots, opp_diams)
	waiting_status_lbl.text = "Waiting for %s to complete the hole..." % opp_name

	waiting_banner.visible = true
	waiting_banner.modulate.a = 0.0
	waiting_banner.scale = Vector2(0.92, 0.92)
	waiting_banner.pivot_offset = waiting_banner.size * 0.5

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(waiting_banner, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
	tw.tween_property(waiting_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func waiting_p1_label_update(p_name: String, shots: int, diams: int) -> void:
	if is_instance_valid(waiting_p1_lbl):
		waiting_p1_lbl.text = "[HOST] %s: %d Shots | %d Stars (FINISHED)" % [p_name, shots, diams]

func waiting_p2_label_update(opp_name: String, shots: int, diams: int) -> void:
	if is_instance_valid(waiting_p2_lbl):
		waiting_p2_lbl.text = "[P2] %s: %d Shots | %d Stars (PLAYING...)" % [opp_name, shots, diams]

func _show_winner_screen() -> void:
	waiting_banner.visible = false

	var peer_ids := NetworkManager.players.keys()
	peer_ids.sort()
	if peer_ids.size() < 2:
		return

	var p1_id: int = peer_ids[0]
	var p2_id: int = peer_ids[1]
	var p1_info: Dictionary = NetworkManager.players[p1_id]
	var p2_info: Dictionary = NetworkManager.players[p2_id]

	var p1_shots: int = p1_info["shots"]
	var p2_shots: int = p2_info["shots"]
	var p1_diamonds: int = p1_info["diamonds"]
	var p2_diamonds: int = p2_info["diamonds"]

	var winner_id := -1
	var winner_title := ""
	var comp_msg := ""

	if p1_shots < p2_shots:
		winner_id = p1_id
		winner_title = "%s WINS HOLE %d!" % [p1_info["name"].to_upper(), current_course_index + 1]
		comp_msg = "%s won by %d fewer stroke%s!" % [p1_info["name"], p2_shots - p1_shots, "s" if (p2_shots - p1_shots) > 1 else ""]
	elif p2_shots < p1_shots:
		winner_id = p2_id
		winner_title = "%s WINS HOLE %d!" % [p2_info["name"].to_upper(), current_course_index + 1]
		comp_msg = "%s won by %d fewer stroke%s!" % [p2_info["name"], p1_shots - p2_shots, "s" if (p1_shots - p2_shots) > 1 else ""]
	else:
		# Tie breaker: diamonds
		if p1_diamonds > p2_diamonds:
			winner_id = p1_id
			winner_title = "%s WINS ON STARS!" % p1_info["name"].to_upper()
			comp_msg = "Tied at %d shots - %s collected more stars!" % [p1_shots, p1_info["name"]]
		elif p2_diamonds > p1_diamonds:
			winner_id = p2_id
			winner_title = "%s WINS ON STARS!" % p2_info["name"].to_upper()
			comp_msg = "Tied at %d shots - %s collected more stars!" % [p2_shots, p2_info["name"]]
		else:
			winner_id = -1
			winner_title = "IT'S A TIE!"
			comp_msg = "Both finished in %d shots with %d stars!" % [p1_shots, p1_diamonds]

	# Track cumulative match score
	if winner_id != -1:
		match_holes_won[winner_id] = match_holes_won.get(winner_id, 0) + 1

	winner_text_lbl.text = winner_title
	winner_sub_lbl.text = comp_msg

	# Score Rows
	var p1_tag := " [WINNER]" if winner_id == p1_id else ""
	var p2_tag := " [WINNER]" if winner_id == p2_id else ""
	winner_p1_lbl.text = "[HOST] %s: %d Shots | %d Stars%s" % [p1_info["name"], p1_shots, p1_diamonds, p1_tag]
	winner_p2_lbl.text = "[P2] %s: %d Shots | %d Stars%s" % [p2_info["name"], p2_shots, p2_diamonds, p2_tag]

	var p1_wins: int = match_holes_won.get(p1_id, 0)
	var p2_wins: int = match_holes_won.get(p2_id, 0)
	match_score_lbl.text = "MATCH SCORE:  %s (%d)   -   %s (%d)" % [p1_info["name"], p1_wins, p2_info["name"], p2_wins]

	next_course_btn.text = "NEXT HOLE"
	next_course_btn.visible = true

	winner_banner.visible = true
	winner_banner.modulate.a = 0.0
	winner_banner.scale = Vector2(0.9, 0.9)
	winner_banner.pivot_offset = winner_banner.size * 0.5


	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(winner_banner, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(winner_banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ----------------- RPCs & Sync -----------------

@rpc("any_peer", "call_local", "reliable")
func rpc_report_player_shot(p_id: int, shots: int) -> void:
	if NetworkManager and NetworkManager.players.has(p_id):
		NetworkManager.players[p_id]["shots"] = shots
	_update_hud_scorecards()

	# Also update waiting card if visible
	if waiting_banner.visible:
		_refresh_waiting_scores()

@rpc("any_peer", "call_local", "reliable")
func rpc_report_player_diamond(p_id: int, diamonds: int) -> void:
	if NetworkManager and NetworkManager.players.has(p_id):
		NetworkManager.players[p_id]["diamonds"] = diamonds
	_update_hud_scorecards()
	if waiting_banner.visible:
		_refresh_waiting_scores()

@rpc("any_peer", "call_local", "reliable")
func rpc_report_player_finish(p_id: int, shots: int, diamonds: int) -> void:
	if NetworkManager and NetworkManager.players.has(p_id):
		NetworkManager.players[p_id]["shots"] = shots
		NetworkManager.players[p_id]["diamonds"] = diamonds
		NetworkManager.players[p_id]["finished"] = true

	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if p_id != my_id:
		var opp_name: String = NetworkManager.players[p_id].get("name", "Opponent")
		_show_toast("%s finished the hole in %d shots!" % [opp_name, shots])

	_update_hud_scorecards()
	_evaluate_finish_state()

func _refresh_waiting_scores() -> void:
	var my_id := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	for p_id in NetworkManager.players.keys():
		var p_info: Dictionary = NetworkManager.players[p_id]
		var s: int = p_info.get("shots", 0)
		var d: int = p_info.get("diamonds", 0)
		if p_id == my_id:
			waiting_p1_label_update(p_info.get("name", "You"), s, d)
		else:
			waiting_p2_label_update(p_info.get("name", "Opponent"), s, d)

func _update_hud_scorecards() -> void:
	if not NetworkManager:
		return

	# P1
	if NetworkManager.players.has(1):
		var p1 = NetworkManager.players[1]
		p1_name_lbl.text = "[HOST] %s" % p1["name"]
		p1_shots_lbl.text = "%d SHOTS | %d STARS" % [p1["shots"], p1["diamonds"]]
		p1_status_lbl.text = "FINISHED" if p1["finished"] else "PLAYING"
		p1_status_lbl.modulate = Color(0.4, 0.9, 0.5) if p1["finished"] else Color(0.7, 0.82, 0.74)

	# P2
	var client_id := -1
	for id in NetworkManager.players.keys():
		if id != 1:
			client_id = id
			break

	if client_id != -1:
		var p2 = NetworkManager.players[client_id]
		p2_name_lbl.text = "[P2] %s" % p2["name"]
		p2_shots_lbl.text = "%d SHOTS | %d STARS" % [p2["shots"], p2["diamonds"]]
		p2_status_lbl.text = "FINISHED" if p2["finished"] else "PLAYING"
		p2_status_lbl.modulate = Color(0.4, 0.9, 0.5) if p2["finished"] else Color(0.7, 0.82, 0.74)


# ----------------- Advancing to Next Level -----------------

func _on_next_course_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()

	# Both players advance to next course
	if NetworkManager:
		NetworkManager.advance_to_course(current_course_index + 1)

func _on_network_course_changed(course_idx: int) -> void:
	load_multiplayer_course(course_idx)

func _on_leave_match_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	match_holes_won.clear()
	if NetworkManager:
		NetworkManager.return_to_lobby()

func _on_server_disconnected() -> void:
	match_holes_won.clear()
	if SceneManager:
		SceneManager.change_scene("res://scenes/multiplayer_lobby.tscn", false, 0.25)
	else:
		get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")
