class_name NetworkManagerNode
extends Node

## Global Network Manager for Moonlit Ricochet / Post Bounce.
## Features Room-Based Matchmaking with Instant Auto-Start:
## When a player creates/joins a room, and a second player enters the same room,
## the game automatically launches!
##
## Triple-Engine Resilience:
## 1. WebRTC + BroadcastChannel (Active on Web / Itch.io: zero-latency P2P between browser tabs & sessions)
## 2. Local Wi-Fi / Hotspot Room Matchmaker (Active on native desktop/mobile: ENet + UDP beacons + OS registry)
## 3. Photon Fusion Cloud (Active whenever fusion/connection/app_id is configured)

signal room_created(room_name: String)
signal room_joined()
signal player_joined(peer_id: int, player_info: Dictionary)
signal player_left(peer_id: int)
signal room_ready_changed(is_full: bool)
signal match_started(course_index: int)
signal course_changed(course_index: int)
signal returned_to_lobby()
signal connection_failed()
signal server_disconnected()
signal active_rooms_updated(rooms: Dictionary)

const DEFAULT_PORT: int = 7777
const BROADCAST_PORT: int = 7778
const MAX_PLAYERS: int = 2
const WEB_ICE_SERVERS: Array = [
	{ "urls": ["stun:stun.l.google.com:19302", "stun:stun1.l.google.com:19302"] },
	{ "urls": ["stun:stun.cloudflare.com:3478"] }
]

# Web / Itch.io Browser Networking (WebRTC + BroadcastChannel)
var is_web: bool = false
var webrtc_peer: WebRTCMultiplayerPeer
var webrtc_connections: Dictionary = {} # peer_id -> WebRTCPeerConnection
var web_client_peer_id: int = 0
var js_dispatch_callback: JavaScriptObject = null
var hosted_time: float = 0.0
var remote_description_set: Dictionary = {} # peer_id -> bool
var pending_ice_candidates: Dictionary = {} # peer_id -> Array

# Photon Fusion Engine
var fusion: Object = null
var is_using_photon: bool = false
var photon_app_id: String = ""

# Local Networking (ENet)
var enet_peer: ENetMultiplayerPeer
var hosted_port: int = DEFAULT_PORT

var players: Dictionary = {} # peer_id -> { "name": String, "color": Color, "is_host": bool, "shots": int, "diamonds": int, "finished": bool }
var is_host: bool = false
var local_player_name: String = "Player"
var current_room_name: String = ""
var current_course_index: int = 0
var in_match: bool = false

# Discovery & Active Rooms
var discovered_lan_rooms: Dictionary = {} # name -> { name, host, ip, port, players, time }
var broadcast_timer: Timer
var broadcast_peer: PacketPeerUDP
var udp_receiver: PacketPeerUDP
var registry_poll_timer: Timer

const LOCAL_REGISTRY_PATH := "/tmp/post_bounce_rooms.json"

func _ready() -> void:
	is_web = OS.has_feature("web")

	broadcast_timer = Timer.new()
	broadcast_timer.wait_time = 0.5
	broadcast_timer.timeout.connect(_on_broadcast_tick)
	add_child(broadcast_timer)

	registry_poll_timer = Timer.new()
	registry_poll_timer.wait_time = 0.4
	registry_poll_timer.timeout.connect(_on_registry_poll_tick)
	add_child(registry_poll_timer)
	registry_poll_timer.start()

	if is_web:
		_setup_web_networking()
	else:
		_setup_lan_udp_receiver()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_check_photon_config()

func _process(_delta: float) -> void:
	if is_web:
		_poll_webrtc_connections()
	else:
		_poll_lan_udp_discovery()

# ----------------- Web / Itch.io Networking (BroadcastChannel + WebRTC) -----------------

func _setup_web_networking() -> void:
	if not is_web:
		return

	print("[NetworkManager] Running in Web Browser (Itch.io). Setting up BroadcastChannel, localStorage & WebRTC...")

	JavaScriptBridge.eval("""
	(function() {
		window._godot_pb_dispatch = null;
		window._setPbHandler = function(fn) {
			window._godot_pb_dispatch = fn;
			console.log('[PostBounce Web] Godot dispatch handler attached successfully.');
		};

		function onMsgReceived(dataStr) {
			if (window._godot_pb_dispatch) {
				try {
					window._godot_pb_dispatch([dataStr]);
				} catch(e) {
					console.error('[PostBounce Web] Dispatch error:', e);
				}
			}
		}

		if (!window._pb_channel) {
			try {
				window._pb_channel = new BroadcastChannel('post_bounce_itch_rooms');
				window._pb_channel.onmessage = function(event) {
					try {
						var str = typeof event.data === 'string' ? event.data : JSON.stringify(event.data);
						onMsgReceived(str);
					} catch(e) {}
				};
				console.log('[PostBounce Web] BroadcastChannel registered.');
			} catch(e) {
				console.warn('[PostBounce Web] BroadcastChannel init error:', e);
			}
		}

		window.addEventListener('storage', function(e) {
			if (e.key === 'post_bounce_sync' && e.newValue) {
				try {
					var envelope = JSON.parse(e.newValue);
					if (envelope && envelope.msg) {
						onMsgReceived(envelope.msg);
					}
				} catch(e) {}
			}
		});

		window._pb_post = function(jsonStr) {
			try {
				var obj = JSON.parse(jsonStr);
				if (window._pb_channel) {
					window._pb_channel.postMessage(obj);
				}
				try {
					localStorage.setItem('post_bounce_sync', JSON.stringify({ ts: Date.now(), msg: jsonStr }));
				} catch(e) {}
			} catch(err) {
				console.error('[PostBounce Web] Post error:', err);
			}
		};

		window.addEventListener('beforeunload', function() {
			if (window._pb_post) {
				window._pb_post(JSON.stringify({ app: 'post_bounce', type: 'query_rooms' }));
			}
		});
	})();
	""")

	js_dispatch_callback = JavaScriptBridge.create_callback(_on_web_broadcast_message)
	var win = JavaScriptBridge.get_interface("window")
	if win and win._setPbHandler:
		win._setPbHandler(js_dispatch_callback)

	# Query open rooms from other browser tabs
	refresh_rooms()

func _broadcast_web_packet(data: Dictionary) -> void:
	if not is_web:
		return
	var json_str := JSON.stringify(data)
	var win = JavaScriptBridge.get_interface("window")
	if win and win._pb_post:
		win._pb_post(json_str)

func _on_web_broadcast_message(args: Array) -> void:
	if args.is_empty():
		return
	var raw = args[0]
	var msg_str := ""
	if raw is Array and not raw.is_empty():
		msg_str = str(raw[0])
	else:
		msg_str = str(raw)

	var json := JSON.new()
	if json.parse(msg_str) != OK or not (json.data is Dictionary):
		return

	var data: Dictionary = json.data
	if data.get("app") != "post_bounce":
		return

	var msg_type := str(data.get("type", ""))

	match msg_type:
		"room_beacon":
			var r_name := str(data.get("name", ""))
			if not r_name.is_empty():
				discovered_lan_rooms[r_name] = {
					"name": r_name,
					"host": str(data.get("host", "Player")),
					"players": str(data.get("players", "1/2")),
					"ip": "web_webrtc",
					"port": 0,
					"time": Time.get_unix_time_from_system()
				}
				active_rooms_updated.emit(get_all_active_rooms())

				# Collision resolution: If another tab already hosts this room and we are alone in it, convert to client
				if is_host and current_room_name == r_name and players.size() < 2 and not in_match:
					var other_host_time := float(data.get("time", 0.0))
					var other_host_name := str(data.get("host", ""))
					if other_host_name != local_player_name or other_host_time < hosted_time:
						print("[NetworkManager Web] Found existing host for '%s'. Converting to client..." % r_name)
						join_web_room(r_name, local_player_name)

		"query_rooms":
			if is_host and not current_room_name.is_empty() and players.size() < 2:
				_send_web_room_beacon()

		"room_closed":
			var r_name := str(data.get("room", ""))
			if discovered_lan_rooms.has(r_name):
				discovered_lan_rooms.erase(r_name)
				active_rooms_updated.emit(get_all_active_rooms())

		"join_request":
			if is_host and data.get("room") == current_room_name:
				_handle_web_join_request(data)

		"sdp_offer":
			if not is_host and data.get("room") == current_room_name:
				var target_id := int(data.get("target", 0))
				if target_id == web_client_peer_id:
					_handle_web_sdp_offer(data)

		"sdp_answer":
			if is_host and data.get("room") == current_room_name:
				_handle_web_sdp_answer(data)

		"ice_candidate":
			if data.get("room") == current_room_name:
				_handle_web_ice_candidate(data)

func _poll_webrtc_connections() -> void:
	for conn in webrtc_connections.values():
		if conn and conn is WebRTCPeerConnection:
			conn.poll()

func _send_web_room_beacon() -> void:
	if not is_host or current_room_name.is_empty():
		return
	_broadcast_web_packet({
		"app": "post_bounce",
		"type": "room_beacon",
		"name": current_room_name,
		"host": local_player_name,
		"players": "%d/2" % players.size(),
		"time": hosted_time
	})

func host_web_room(room_name: String, player_name: String) -> Error:
	leave_room(false)
	is_host = true
	current_room_name = room_name
	local_player_name = player_name
	in_match = false
	hosted_time = Time.get_unix_time_from_system()

	webrtc_peer = WebRTCMultiplayerPeer.new()
	var err := webrtc_peer.create_server()
	if err != OK:
		print("[NetworkManager] Failed to create WebRTC server: %d" % err)
		return err

	multiplayer.multiplayer_peer = webrtc_peer

	players.clear()
	players[1] = {
		"name": player_name,
		"color": Color("#88ddaa"),
		"is_host": true,
		"shots": 0,
		"diamonds": 0,
		"finished": false
	}

	broadcast_timer.start()
	_send_web_room_beacon()

	room_created.emit(room_name)
	room_ready_changed.emit(false)
	print("[NetworkManager Web] Hosting Web room '%s' as Host (Peer 1)" % room_name)
	return OK

func join_web_room(room_name: String, player_name: String) -> Error:
	leave_room(false)
	is_host = false
	current_room_name = room_name
	local_player_name = player_name
	in_match = false
	players.clear()
	remote_description_set.clear()
	pending_ice_candidates.clear()

	web_client_peer_id = (randi() % 899999) + 100000
	webrtc_peer = WebRTCMultiplayerPeer.new()
	var err := webrtc_peer.create_client(web_client_peer_id)
	if err != OK:
		print("[NetworkManager] Failed to create WebRTC client: %d" % err)
		connection_failed.emit()
		return err

	multiplayer.multiplayer_peer = webrtc_peer

	var conn := WebRTCPeerConnection.new()
	conn.initialize({ "iceServers": WEB_ICE_SERVERS })
	conn.session_description_created.connect(func(type, sdp): _on_web_client_sdp_created(type, sdp, web_client_peer_id, room_name))
	conn.ice_candidate_created.connect(func(m, i, n): _on_web_ice_candidate_created(m, i, n, 1, web_client_peer_id, room_name))

	webrtc_peer.add_peer(conn, 1)
	webrtc_connections[1] = conn

	_broadcast_web_packet({
		"app": "post_bounce",
		"type": "join_request",
		"room": room_name,
		"client_id": web_client_peer_id,
		"name": player_name
	})

	room_joined.emit()
	print("[NetworkManager Web] Joining Web room '%s' as Client (Peer %d)..." % [room_name, web_client_peer_id])
	return OK

func _handle_web_join_request(data: Dictionary) -> void:
	var client_id: int = int(data.get("client_id", 0))
	if client_id <= 0:
		return

	print("[NetworkManager Web] Host received join request from Client %d" % client_id)

	if webrtc_connections.has(client_id):
		webrtc_connections[client_id].close()
		webrtc_connections.erase(client_id)
	remote_description_set.erase(client_id)
	pending_ice_candidates.erase(client_id)

	var conn := WebRTCPeerConnection.new()
	conn.initialize({ "iceServers": WEB_ICE_SERVERS })
	conn.session_description_created.connect(func(type, sdp): _on_web_host_sdp_created(type, sdp, client_id, current_room_name))
	conn.ice_candidate_created.connect(func(m, i, n): _on_web_ice_candidate_created(m, i, n, client_id, 1, current_room_name))

	webrtc_peer.add_peer(conn, client_id)
	webrtc_connections[client_id] = conn

	conn.create_offer()

func _on_web_host_sdp_created(type: String, sdp: String, client_id: int, room_name: String) -> void:
	if not webrtc_connections.has(client_id):
		return
	var conn: WebRTCPeerConnection = webrtc_connections[client_id]
	conn.set_local_description(type, sdp)

	_broadcast_web_packet({
		"app": "post_bounce",
		"type": "sdp_offer",
		"room": room_name,
		"target": client_id,
		"sdp": sdp
	})

func _handle_web_sdp_offer(data: Dictionary) -> void:
	var sdp := str(data.get("sdp", ""))
	if not webrtc_connections.has(1):
		return
	var conn: WebRTCPeerConnection = webrtc_connections[1]
	conn.set_remote_description("offer", sdp)
	remote_description_set[1] = true
	conn.create_answer()
	_flush_pending_ice(1)

func _on_web_client_sdp_created(type: String, sdp: String, client_id: int, room_name: String) -> void:
	if not webrtc_connections.has(1):
		return
	var conn: WebRTCPeerConnection = webrtc_connections[1]
	conn.set_local_description(type, sdp)

	_broadcast_web_packet({
		"app": "post_bounce",
		"type": "sdp_answer",
		"room": room_name,
		"from": client_id,
		"sdp": sdp
	})

func _handle_web_sdp_answer(data: Dictionary) -> void:
	var client_id: int = int(data.get("from", 0))
	var sdp := str(data.get("sdp", ""))
	if webrtc_connections.has(client_id):
		var conn: WebRTCPeerConnection = webrtc_connections[client_id]
		conn.set_remote_description("answer", sdp)
		remote_description_set[client_id] = true
		_flush_pending_ice(client_id)

func _flush_pending_ice(p_id: int) -> void:
	if not webrtc_connections.has(p_id) or not pending_ice_candidates.has(p_id):
		return
	var conn: WebRTCPeerConnection = webrtc_connections[p_id]
	for c in pending_ice_candidates[p_id]:
		conn.add_ice_candidate(c.media, c.index, c.name)
	pending_ice_candidates[p_id].clear()

func _on_web_ice_candidate_created(media: String, index: int, candidate_name: String, target_id: int, from_id: int, room_name: String) -> void:
	_broadcast_web_packet({
		"app": "post_bounce",
		"type": "ice_candidate",
		"room": room_name,
		"target": target_id,
		"from": from_id,
		"media": media,
		"index": index,
		"name": candidate_name
	})

func _handle_web_ice_candidate(data: Dictionary) -> void:
	var target_id := int(data.get("target", 0))
	var from_id := int(data.get("from", 0))
	var media := str(data.get("media", ""))
	var index := int(data.get("index", 0))
	var c_name := str(data.get("name", ""))

	if is_host:
		if target_id == 1 and webrtc_connections.has(from_id):
			if remote_description_set.get(from_id, false):
				webrtc_connections[from_id].add_ice_candidate(media, index, c_name)
			else:
				if not pending_ice_candidates.has(from_id):
					pending_ice_candidates[from_id] = []
				pending_ice_candidates[from_id].append({"media": media, "index": index, "name": c_name})
	else:
		if target_id == web_client_peer_id and webrtc_connections.has(1):
			if remote_description_set.get(1, false):
				webrtc_connections[1].add_ice_candidate(media, index, c_name)
			else:
				if not pending_ice_candidates.has(1):
					pending_ice_candidates[1] = []
				pending_ice_candidates[1].append({"media": media, "index": index, "name": c_name})

# ----------------- Native Desktop / Mobile Discovery -----------------

func _setup_lan_udp_receiver() -> void:
	udp_receiver = PacketPeerUDP.new()
	var err := udp_receiver.bind(BROADCAST_PORT)
	if err == OK:
		print("[NetworkManager] LAN UDP discovery listener active on port %d." % BROADCAST_PORT)

func _poll_lan_udp_discovery() -> void:
	if not udp_receiver or not udp_receiver.is_bound():
		return

	while udp_receiver.get_available_packet_count() > 0:
		var packet := udp_receiver.get_packet()
		var sender_ip := udp_receiver.get_packet_ip()
		var msg_str := packet.get_string_from_utf8()

		var json := JSON.new()
		if json.parse(msg_str) == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			if data.get("app") == "post_bounce":
				var r_name: String = str(data.get("name", "Room-1"))
				discovered_lan_rooms[r_name] = {
					"name": r_name,
					"host": str(data.get("host", "Player")),
					"players": str(data.get("players", "1/2")),
					"port": int(data.get("port", DEFAULT_PORT)),
					"ip": str(data.get("ip", sender_ip)),
					"time": Time.get_unix_time_from_system()
				}

func _check_photon_config() -> void:
	if GameSettings and not GameSettings.photon_app_id.is_empty():
		photon_app_id = GameSettings.photon_app_id.strip_edges()

	if photon_app_id.is_empty() and ProjectSettings.has_setting("fusion/connection/app_id"):
		photon_app_id = str(ProjectSettings.get_setting("fusion/connection/app_id")).strip_edges()

	if Engine.has_singleton("Fusion"):
		fusion = Engine.get_singleton("Fusion")
		if photon_app_id.is_empty() and fusion.has_method("get_configured_app_id"):
			photon_app_id = str(fusion.get_configured_app_id()).strip_edges()

		if not photon_app_id.is_empty():
			is_using_photon = true
			if fusion.has_method("set_app_id"):
				fusion.set_app_id(photon_app_id)
			_connect_fusion_signals()
			print("[NetworkManager] Photon Fusion Cloud enabled with App ID: %s" % photon_app_id)
			return

	is_using_photon = false
	if is_web:
		print("[NetworkManager] WebRTC & BroadcastChannel active for Web/Itch.io.")
	else:
		print("[NetworkManager] Local Wi-Fi / Hotspot Room Matchmaker active.")

func _connect_fusion_signals() -> void:
	if not fusion:
		return
	if fusion.has_signal("room_joined"): fusion.room_joined.connect(_on_fusion_room_joined)
	if fusion.has_signal("player_joined"): fusion.player_joined.connect(_on_fusion_player_joined)
	if fusion.has_signal("player_left"): fusion.player_left.connect(_on_fusion_player_left)
	if fusion.has_signal("room_list_updated"): fusion.room_list_updated.connect(_on_fusion_room_list_updated)
	if fusion.has_signal("connection_failed"): fusion.connection_failed.connect(_on_fusion_connection_failed)

# ----------------- Room Join & Auto-Start -----------------

func refresh_rooms() -> void:
	if is_web:
		_broadcast_web_packet({
			"app": "post_bounce",
			"type": "query_rooms"
		})

func join_or_create_room(room_name: String, player_name: String) -> void:
	local_player_name = player_name
	current_room_name = room_name

	# Check if Photon Cloud is active
	if is_using_photon and fusion:
		if not fusion.is_connected_to_photon():
			fusion.connect_to_photon(player_name, "", "")
		fusion.join_or_create_room(room_name)
		room_joined.emit()
		return

	# Web Browser Matchmaking (Itch.io)
	if is_web:
		var all_rooms := get_all_active_rooms()
		if all_rooms.has(room_name):
			print("[NetworkManager Web] Found active room '%s'. Joining..." % room_name)
			join_web_room(room_name, player_name)
		else:
			print("[NetworkManager Web] Creating new room '%s' as Host..." % room_name)
			host_web_room(room_name, player_name)
		return

	# Native Desktop / Mobile Matchmaking (ENet + LAN)
	var all_rooms := get_all_active_rooms()
	if all_rooms.has(room_name):
		var r_data: Dictionary = all_rooms[room_name]
		var host_ip: String = r_data.get("ip", "127.0.0.1")
		var host_port: int = int(r_data.get("port", DEFAULT_PORT))
		print("[NetworkManager] Found existing room '%s' at %s:%d. Joining..." % [room_name, host_ip, host_port])
		join_room_direct(room_name, host_ip, host_port)
	else:
		print("[NetworkManager] Creating new room '%s' as Host..." % room_name)
		host_room(room_name, player_name)

func join_room_direct(room_name: String, target_ip: String, port: int) -> Error:
	leave_room(false)
	is_host = false
	current_room_name = room_name
	in_match = false
	players.clear()

	enet_peer = ENetMultiplayerPeer.new()
	var err := enet_peer.create_client(target_ip, port)
	if err != OK:
		print("[NetworkManager] Error creating client to %s:%d: %d" % [target_ip, port, err])
		connection_failed.emit()
		return err

	multiplayer.multiplayer_peer = enet_peer
	room_joined.emit()
	return OK

func host_room(room_name: String, player_name: String) -> Error:
	leave_room(false)
	is_host = true
	current_room_name = room_name
	local_player_name = player_name
	in_match = false

	enet_peer = ENetMultiplayerPeer.new()
	var port_to_try := DEFAULT_PORT
	var err := enet_peer.create_server(port_to_try, MAX_PLAYERS)
	if err != OK:
		port_to_try = DEFAULT_PORT + (randi() % 50) + 1
		err = enet_peer.create_server(port_to_try, MAX_PLAYERS)

	if err != OK:
		print("[NetworkManager] Failed to create server on port %d: %d" % [port_to_try, err])
		return err

	hosted_port = port_to_try
	multiplayer.multiplayer_peer = enet_peer

	players.clear()
	players[1] = {
		"name": player_name,
		"color": Color("#88ddaa"),
		"is_host": true,
		"shots": 0,
		"diamonds": 0,
		"finished": false
	}

	_write_local_room_registry()
	_start_broadcasting(room_name, hosted_port)

	room_created.emit(room_name)
	room_ready_changed.emit(false)
	return OK

func leave_room(clear_registry: bool = true) -> void:
	if clear_registry and is_host:
		if is_web:
			_broadcast_web_packet({
				"app": "post_bounce",
				"type": "room_closed",
				"room": current_room_name
			})
		else:
			_remove_from_local_registry(current_room_name)

	_stop_broadcasting()

	if is_web:
		for conn in webrtc_connections.values():
			if conn and conn is WebRTCPeerConnection:
				conn.close()
		webrtc_connections.clear()
		if webrtc_peer:
			webrtc_peer.close()
			webrtc_peer = null
		remote_description_set.clear()
		pending_ice_candidates.clear()

	if fusion and is_using_photon:
		fusion.leave_room()

	if enet_peer:
		enet_peer.close()
		enet_peer = null

	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	in_match = false
	current_room_name = ""

# ----------------- Instant Auto-Start -----------------

func _auto_start_match_if_ready() -> void:
	if in_match:
		return
	if is_host and players.size() >= 2:
		print("[NetworkManager] 2 Players connected in room '%s'! Auto-starting match now!" % current_room_name)
		start_match(0)

func start_match(course_index: int = 0) -> void:
	if in_match:
		return
	if is_host:
		rpc("rpc_start_match", course_index)
	else:
		_execute_start_match(course_index)

func _execute_start_match(course_idx: int) -> void:
	in_match = true
	current_course_index = course_idx
	for p_id in players.keys():
		players[p_id]["shots"] = 0
		players[p_id]["diamonds"] = 0
		players[p_id]["finished"] = false
	match_started.emit(course_idx)
	_transition_to_match_scene()

func advance_to_course(course_index: int) -> void:
	if is_host:
		rpc("rpc_load_course", course_index)
	else:
		rpc_id(1, "rpc_request_next_course", course_index)

func return_to_lobby() -> void:
	in_match = false
	if is_host:
		rpc("rpc_return_to_lobby")
	leave_room(true)
	returned_to_lobby.emit()

	if SceneManager:
		SceneManager.change_scene("res://scenes/multiplayer_lobby.tscn", false, 0.2)
	else:
		get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")

func _transition_to_match_scene() -> void:
	if SceneManager:
		SceneManager.change_scene("res://scenes/multiplayer_game.tscn", false, 0.25)
	else:
		get_tree().change_scene_to_file("res://scenes/multiplayer_game.tscn")

# ----------------- Multiplayer Peer Callbacks -----------------

func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] Peer connected: %d" % id)
	if not is_host:
		rpc_id(1, "rpc_register_player", local_player_name)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] Peer disconnected: %d" % id)
	if players.has(id):
		players.erase(id)
		player_left.emit(id)
		room_ready_changed.emit(players.size() >= 2)
		if is_host:
			rpc("rpc_sync_room", players, current_room_name)

func _on_connected_to_server() -> void:
	print("[NetworkManager] Client successfully connected to host!")
	rpc_id(1, "rpc_register_player", local_player_name)

func _on_connection_failed() -> void:
	print("[NetworkManager] Connection failed.")
	leave_room(true)
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] Server disconnected.")
	leave_room(true)
	server_disconnected.emit()
	if SceneManager:
		SceneManager.change_scene("res://scenes/multiplayer_lobby.tscn", false, 0.2)
	else:
		get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")

# ----------------- Remote Procedure Calls -----------------

@rpc("any_peer", "reliable")
func rpc_register_player(p_name: String) -> void:
	if not is_host:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	players[sender_id] = {
		"name": p_name,
		"color": Color("#fae366"),
		"is_host": false,
		"shots": 0,
		"diamonds": 0,
		"finished": false
	}
	rpc("rpc_sync_room", players, current_room_name)
	room_ready_changed.emit(true)
	_auto_start_match_if_ready()

@rpc("authority", "call_local", "reliable")
func rpc_sync_room(p_players: Dictionary, p_room_name: String) -> void:
	players = p_players
	current_room_name = p_room_name
	var is_ready := (players.size() >= 2)
	room_ready_changed.emit(is_ready)

@rpc("authority", "call_local", "reliable")
func rpc_start_match(course_idx: int) -> void:
	_execute_start_match(course_idx)

@rpc("any_peer", "reliable")
func rpc_request_next_course(course_idx: int) -> void:
	if is_host:
		rpc("rpc_load_course", course_idx)

@rpc("authority", "call_local", "reliable")
func rpc_load_course(course_idx: int) -> void:
	current_course_index = course_idx
	for p_id in players.keys():
		players[p_id]["shots"] = 0
		players[p_id]["diamonds"] = 0
		players[p_id]["finished"] = false
	course_changed.emit(course_idx)

@rpc("authority", "call_local", "reliable")
func rpc_return_to_lobby() -> void:
	in_match = false
	returned_to_lobby.emit()
	if SceneManager:
		SceneManager.change_scene("res://scenes/multiplayer_lobby.tscn", false, 0.2)
	else:
		get_tree().change_scene_to_file("res://scenes/multiplayer_lobby.tscn")

# ----------------- Photon Fusion Callbacks (if active) -----------------

func _on_fusion_room_joined() -> void:
	if fusion:
		is_host = fusion.is_master_client()
		if is_host:
			players[1] = {
				"name": local_player_name,
				"color": Color("#88ddaa"),
				"is_host": true,
				"shots": 0,
				"diamonds": 0,
				"finished": false
			}
	room_joined.emit()
	var room = fusion.get_room() if fusion else null
	var cnt: int = room.get_player_count() if room else 1
	if cnt >= 2:
		_auto_start_match_if_ready()

func _on_fusion_player_joined(p_id: int, p_name: String) -> void:
	if fusion:
		is_host = fusion.is_master_client()
	players[p_id] = {
		"name": p_name if not p_name.is_empty() else "Player 2",
		"color": Color("#fae366"),
		"is_host": false,
		"shots": 0,
		"diamonds": 0,
		"finished": false
	}
	room_ready_changed.emit(true)
	_auto_start_match_if_ready()

func _on_fusion_player_left(p_id: int, _inactive: bool) -> void:
	if players.has(p_id):
		players.erase(p_id)
		player_left.emit(p_id)
		room_ready_changed.emit(false)

func _on_fusion_room_list_updated(r_list: Array) -> void:
	var rooms := {}
	for item in r_list:
		if item and item.has_method("get_name"):
			var r_name: String = item.get_name()
			rooms[r_name] = {
				"name": r_name,
				"players": "%d/%d" % [item.get_player_count(), item.get_max_players()]
			}
	active_rooms_updated.emit(rooms)

func _on_fusion_connection_failed(_reason) -> void:
	connection_failed.emit()

# ----------------- Dual Discovery: Shared Local Registry + UDP -----------------

func get_all_active_rooms() -> Dictionary:
	var result := {}
	if not is_web:
		var local_rooms := _read_local_room_registry()
		for r_name in local_rooms.keys():
			result[r_name] = local_rooms[r_name]

	for r_name in discovered_lan_rooms.keys():
		if not result.has(r_name):
			result[r_name] = discovered_lan_rooms[r_name]

	return result

func _on_registry_poll_tick() -> void:
	var now := Time.get_unix_time_from_system()
	for k in discovered_lan_rooms.keys():
		var r = discovered_lan_rooms[k]
		if (now - float(r.get("time", 0.0))) > 3.0:
			discovered_lan_rooms.erase(k)

	var all_rooms := get_all_active_rooms()
	active_rooms_updated.emit(all_rooms)

func _write_local_room_registry() -> void:
	if not is_host or current_room_name.is_empty():
		return

	var file_data := _read_local_room_registry()
	file_data[current_room_name] = {
		"name": current_room_name,
		"host": local_player_name,
		"ip": "127.0.0.1",
		"port": hosted_port,
		"players": "%d/2" % players.size(),
		"time": Time.get_unix_time_from_system()
	}

	var f := FileAccess.open(LOCAL_REGISTRY_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(file_data))
		f.close()

func _remove_from_local_registry(r_name: String) -> void:
	if r_name.is_empty() or not FileAccess.file_exists(LOCAL_REGISTRY_PATH):
		return
	var file_data := _read_local_room_registry()
	if file_data.has(r_name):
		file_data.erase(r_name)
		var f := FileAccess.open(LOCAL_REGISTRY_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(file_data))
			f.close()

func _read_local_room_registry() -> Dictionary:
	if not FileAccess.file_exists(LOCAL_REGISTRY_PATH):
		return {}

	var f := FileAccess.open(LOCAL_REGISTRY_PATH, FileAccess.READ)
	if not f:
		return {}

	var content := f.get_as_text()
	f.close()

	var json := JSON.new()
	if json.parse(content) != OK or not (json.data is Dictionary):
		return {}

	var res: Dictionary = json.data
	var now := Time.get_unix_time_from_system()
	var clean := {}
	for k in res.keys():
		var r = res[k]
		if r is Dictionary and (now - float(r.get("time", 0.0))) < 4.0:
			clean[k] = r

	return clean

func _start_broadcasting(room_name: String, port: int) -> void:
	if not is_web:
		if not broadcast_peer:
			broadcast_peer = PacketPeerUDP.new()
			broadcast_peer.set_broadcast_enabled(true)
	broadcast_timer.start()

func _stop_broadcasting() -> void:
	if broadcast_timer: broadcast_timer.stop()
	if broadcast_peer:
		broadcast_peer.close()
		broadcast_peer = null

func _on_broadcast_tick() -> void:
	if not is_host or current_room_name.is_empty():
		return

	if is_web:
		_send_web_room_beacon()
		return

	_write_local_room_registry()

	if players.size() >= 2 or not broadcast_peer:
		return

	var my_ips := IP.get_local_addresses()
	var lan_ip := "127.0.0.1"
	for ip_str in my_ips:
		if ip_str.begins_with("192.168.") or ip_str.begins_with("10.") or ip_str.begins_with("172."):
			lan_ip = ip_str
			break

	var packet_data := {
		"app": "post_bounce",
		"name": current_room_name,
		"host": local_player_name,
		"players": "%d/2" % players.size(),
		"port": hosted_port,
		"ip": lan_ip
	}

	broadcast_peer.set_dest_address("255.255.255.255", BROADCAST_PORT)
	broadcast_peer.put_packet(JSON.stringify(packet_data).to_utf8_buffer())
