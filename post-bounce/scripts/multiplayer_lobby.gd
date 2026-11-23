class_name MultiplayerLobby
extends Control

## Room-based Multiplayer Lobby powered by Photon Fusion.
## Allows joining or creating rooms by room name/code, with auto-start as soon as 2 players are in the room.

# Browser View
@onready var browser_layout: HBoxContainer = %MainLayout
@onready var back_btn: Button = %BackButton
@onready var join_room_btn: Button = %JoinRoomButton
@onready var quick_match_btn: Button = %QuickMatchButton
@onready var refresh_btn: Button = %RefreshButton

@onready var player_name_input: LineEdit = %PlayerNameInput
@onready var room_name_input: LineEdit = %RoomNameInput
@onready var room_list_container: VBoxContainer = %RoomListContainer
@onready var status_label: Label = %StatusLabel
@onready var backend_badge: Label = %BackendBadge

# Room View
@onready var room_panel: PanelContainer = %RoomPanel
@onready var room_title_label: Label = %RoomTitleLabel
@onready var room_info_label: Label = %RoomInfoLabel
@onready var slot1_label: Label = %Slot1Label
@onready var slot1_status: Label = %Slot1Status
@onready var slot2_label: Label = %Slot2Label
@onready var slot2_status: Label = %Slot2Status
@onready var auto_start_banner: Label = %AutoStartBanner
@onready var leave_room_btn: Button = %LeaveRoomButton

var discovered_rooms: Dictionary = {}

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)
	join_room_btn.pressed.connect(_on_join_room_pressed)
	quick_match_btn.pressed.connect(_on_quick_match_pressed)
	refresh_btn.pressed.connect(_on_refresh_pressed)
	leave_room_btn.pressed.connect(_on_leave_room_pressed)

	if NetworkManager:
		NetworkManager.room_joined.connect(_on_room_joined)
		NetworkManager.room_created.connect(_on_room_created)
		NetworkManager.room_ready_changed.connect(_on_room_ready_changed)
		NetworkManager.player_joined.connect(_on_player_joined)
		NetworkManager.player_left.connect(_on_player_left)
		NetworkManager.connection_failed.connect(_on_connection_failed)
		NetworkManager.server_disconnected.connect(_on_server_disconnected)
		NetworkManager.active_rooms_updated.connect(_on_active_rooms_updated)

		if NetworkManager.is_using_photon:
			backend_badge.text = "PHOTON FUSION CLOUD"
			backend_badge.modulate = Color(0.4, 0.9, 0.55)
		elif NetworkManager.is_web:
			backend_badge.text = "WEB / ITCH.IO MULTIPLAYER"
			backend_badge.modulate = Color(0.35, 0.85, 0.95)
		else:
			backend_badge.text = "LOCAL / WI-FI ROOM MATCHMAKER"
			backend_badge.modulate = Color(0.65, 0.85, 0.75)


		NetworkManager.refresh_rooms()
		discovered_rooms = NetworkManager.get_all_active_rooms()
		_rebuild_room_list()

		var poll_timer := Timer.new()
		poll_timer.wait_time = 1.0
		poll_timer.timeout.connect(func():
			if browser_layout.visible and NetworkManager:
				NetworkManager.refresh_rooms()
				discovered_rooms = NetworkManager.get_all_active_rooms()
				_rebuild_room_list()
		)
		add_child(poll_timer)
		poll_timer.start()

	_show_browser_view()

func _on_active_rooms_updated(rooms: Dictionary) -> void:
	discovered_rooms = rooms
	_rebuild_room_list()

func _rebuild_room_list() -> void:
	for child in room_list_container.get_children():
		child.queue_free()

	if discovered_rooms.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No open rooms discovered yet.\nType a room name above and tap Join or Create!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.65, 0.78, 0.7, 0.7)
		room_list_container.add_child(empty_lbl)
		return

	for key in discovered_rooms.keys():
		var r_data: Dictionary = discovered_rooms[key]
		var r_name: String = str(r_data.get("name", key))
		var r_players: String = str(r_data.get("players", "1/2"))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var info_lbl := Label.new()
		info_lbl.text = "[ROOM] %s   (%s)" % [r_name, r_players]
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_lbl.modulate = Color(0.88, 0.94, 0.9, 1.0)
		row.add_child(info_lbl)

		var join_btn := Button.new()
		join_btn.text = "JOIN"
		join_btn.custom_minimum_size = Vector2(80, 32)
		join_btn.pressed.connect(_join_selected_room.bind(r_name))
		row.add_child(join_btn)

		room_list_container.add_child(row)

func _get_player_name() -> String:
	var n := player_name_input.text.strip_edges()
	return n if not n.is_empty() else "Player"

func _on_join_room_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()

	var r_name := room_name_input.text.strip_edges()
	if r_name.is_empty():
		r_name = "Room-1"
	var p_name := _get_player_name()

	status_label.text = "Joining room '%s'..." % r_name
	_show_room_view(r_name)
	NetworkManager.join_or_create_room(r_name, p_name)

func _on_quick_match_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()

	var p_name := _get_player_name()
	# Join first discovered room or generate random room
	var r_name := "Room-%d" % (randi() % 99 + 1)
	if not discovered_rooms.is_empty():
		var first_key = discovered_rooms.keys()[0]
		r_name = discovered_rooms[first_key].get("name", r_name)

	room_name_input.text = r_name
	status_label.text = "Quick Match: entering '%s'..." % r_name
	_show_room_view(r_name)
	NetworkManager.join_or_create_room(r_name, p_name)

func _join_selected_room(r_name: String) -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	var p_name := _get_player_name()
	room_name_input.text = r_name
	status_label.text = "Entering '%s'..." % r_name
	_show_room_view(r_name)
	NetworkManager.join_or_create_room(r_name, p_name)

# ----------------- Room View Logic -----------------

func _show_browser_view() -> void:
	browser_layout.visible = true
	room_panel.visible = false
	status_label.text = "Select or enter a room."

func _show_room_view(r_name: String) -> void:
	browser_layout.visible = false
	room_panel.visible = true
	room_title_label.text = "ROOM: %s" % r_name
	room_info_label.text = "Waiting for Player 2 to join... Game begins automatically!"
	auto_start_banner.text = "As soon as another player joins this room, the game starts!"
	auto_start_banner.modulate = Color(0.85, 0.95, 0.88)
	_update_room_slots()

func _update_room_slots() -> void:
	if not NetworkManager:
		return

	var p_count := NetworkManager.players.size()

	# Slot 1
	var p1_found := false
	for p_id in NetworkManager.players.keys():
		var p_info: Dictionary = NetworkManager.players[p_id]
		if p_info.get("is_host", false) or not p1_found:
			slot1_label.text = "[HOST] %s" % p_info.get("name", "Player 1")
			slot1_status.text = "IN ROOM"
			slot1_status.modulate = Color(0.4, 0.9, 0.5)
			p1_found = true
			break

	if not p1_found:
		slot1_label.text = "[HOST] %s" % _get_player_name()
		slot1_status.text = "IN ROOM"
		slot1_status.modulate = Color(0.4, 0.9, 0.5)

	# Slot 2
	if p_count >= 2:
		var p2_name := "Player 2"
		for p_id in NetworkManager.players.keys():
			var p_info: Dictionary = NetworkManager.players[p_id]
			if not p_info.get("is_host", false):
				p2_name = p_info.get("name", "Player 2")
				break
		slot2_label.text = "[P2] %s" % p2_name
		slot2_status.text = "JOINED"
		slot2_status.modulate = Color(0.4, 0.9, 0.5)
		auto_start_banner.text = "PLAYER JOINED! STARTING GAME..."
		auto_start_banner.modulate = Color(0.98, 0.89, 0.4)
	else:
		slot2_label.text = "Waiting for opponent to join..."
		slot2_status.text = "WAITING"
		slot2_status.modulate = Color(0.9, 0.8, 0.3)


func _on_room_joined() -> void:
	_update_room_slots()

func _on_room_created(_r_name: String) -> void:
	_update_room_slots()

func _on_player_joined(_p_id: int, _info: Dictionary) -> void:
	_update_room_slots()

func _on_room_ready_changed(is_full: bool) -> void:
	_update_room_slots()

func _on_player_left(_p_id: int) -> void:
	_update_room_slots()

func _on_photon_room_list_updated(r_list: Array) -> void:
	for room_item in r_list:
		if room_item and room_item.has_method("get_name"):
			var r_name: String = room_item.get_name()
			var p_cnt: int = room_item.get_player_count()
			var max_p: int = room_item.get_max_players()
			discovered_rooms[r_name] = {
				"name": r_name,
				"players": "%d/%d" % [p_cnt, max_p]
			}
	_rebuild_room_list()

func _on_connection_failed() -> void:
	_show_browser_view()
	status_label.text = "Could not connect to room. Try another room name."

func _on_server_disconnected() -> void:
	_show_browser_view()
	status_label.text = "Disconnected from room."

func _on_leave_room_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	if NetworkManager:
		NetworkManager.leave_room()
	_show_browser_view()

func _on_refresh_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	discovered_rooms.clear()
	if NetworkManager:
		NetworkManager.refresh_rooms()
		discovered_rooms = NetworkManager.get_all_active_rooms()
	_rebuild_room_list()
	status_label.text = "Refreshed room listings."

func _on_back_pressed() -> void:
	if SoundManager:
		SoundManager.play_ui_click()
	if NetworkManager:
		NetworkManager.leave_room()
	if SceneManager:
		SceneManager.change_scene("res://scenes/main_menu.tscn", false, 0.25)
	else:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
