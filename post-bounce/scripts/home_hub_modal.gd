class_name HomeHubModal
extends Control

## Central Home Hub modal opened from the in-game Home button.
## Contains Ball Bazaar Shop, Course Selection, and Settings.

signal level_selected(course_index: int)
signal closed()

@onready var panel_card: PanelContainer = $CenterContainer/PanelCard
@onready var close_btn: Button = %CloseButton

# Top Bar Counters
@onready var gems_label: Label = %GemsCounterLabel
@onready var stars_label: Label = %StarsCounterLabel

# Navigation Tabs
@onready var tab_shop_btn: Button = %TabShopBtn
@onready var tab_levels_btn: Button = %TabLevelsBtn
@onready var tab_settings_btn: Button = %TabSettingsBtn

@onready var shop_panel: Control = %ShopPanel
@onready var levels_panel: Control = %LevelsPanel
@onready var settings_panel: Control = %SettingsPanel

# Shop Elements
@onready var preview_control: Control = %BallPreviewControl
@onready var skin_name_label: Label = %SkinNameLabel
@onready var skin_rarity_label: Label = %SkinRarityLabel
@onready var skin_desc_label: Label = %SkinDescLabel
@onready var skin_action_btn: Button = %SkinActionBtn
@onready var skins_grid_container: GridContainer = %SkinsGridContainer

# Settings Elements
@onready var sfx_slider: HSlider = %SfxSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sens_slider: HSlider = %SensitivitySlider
@onready var shake_toggle: CheckButton = %ShakeToggle
@onready var traj_full_btn: Button = %TrajFullBtn
@onready var traj_short_btn: Button = %TrajShortBtn
@onready var traj_off_btn: Button = %TrajOffBtn

# Levels Elements
@onready var levels_grid_container: GridContainer = %LevelsGridContainer

var selected_skin_id: String = "moonlit_pearl"
var preview_basis: Basis = Basis.IDENTITY
var preview_anim_time: float = 0.0
var active_tab: String = "SHOP"
var is_open: bool = false

func _ready() -> void:
	visible = false
	modulate.a = 0.0

	close_btn.pressed.connect(close)

	tab_shop_btn.pressed.connect(func(): _switch_tab("SHOP"))
	tab_levels_btn.pressed.connect(func(): _switch_tab("LEVELS"))
	tab_settings_btn.pressed.connect(func(): _switch_tab("SETTINGS"))

	skin_action_btn.pressed.connect(_on_skin_action_pressed)

	if preview_control:
		preview_control.draw.connect(_on_draw_ball_preview)

	_setup_settings_listeners()

	if GameSettings:
		GameSettings.gems_changed.connect(func(_val): _update_counters())
		GameSettings.progression_updated.connect(_update_counters)
		GameSettings.skin_equipped.connect(func(_id): _refresh_shop_ui())

func _process(delta: float) -> void:
	if not is_open:
		return
	preview_anim_time += delta
	# Rotate 3D preview sphere
	var rot_axis := Vector3(0.4, 1.0, 0.2).normalized()
	preview_basis = Basis(rot_axis, delta * 1.8) * preview_basis
	preview_basis = preview_basis.orthonormalized()
	if preview_control:
		preview_control.queue_redraw()

func open(initial_tab: String = "SHOP") -> void:
	is_open = true
	visible = true
	panel_card.scale = Vector2(0.92, 0.92)
	panel_card.pivot_offset = panel_card.size * 0.5

	if GameSettings:
		selected_skin_id = GameSettings.equipped_skin

	_update_counters()
	_populate_skins_grid()
	_populate_levels_grid()
	_sync_settings_values()
	_switch_tab(initial_tab)
	_refresh_skin_preview()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE)
	tw.tween_property(panel_card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if not is_open:
		return
	if SoundManager:
		SoundManager.play_ui_click()
	is_open = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(panel_card, "scale", Vector2(0.92, 0.92), 0.18)
	await tw.finished
	visible = false
	closed.emit()

func _update_counters() -> void:
	if GameSettings:
		gems_label.text = str(GameSettings.gems)
		stars_label.text = str(GameSettings.get_total_stars())

func _switch_tab(tab_name: String) -> void:
	active_tab = tab_name
	if SoundManager:
		SoundManager.play_ui_click()

	shop_panel.visible = (tab_name == "SHOP")
	levels_panel.visible = (tab_name == "LEVELS")
	settings_panel.visible = (tab_name == "SETTINGS")

	_style_tab_btn(tab_shop_btn, tab_name == "SHOP")
	_style_tab_btn(tab_levels_btn, tab_name == "LEVELS")
	_style_tab_btn(tab_settings_btn, tab_name == "SETTINGS")

func _style_tab_btn(btn: Button, is_active: bool) -> void:
	if is_active:
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		btn.modulate = Color(0.65, 0.75, 0.7, 0.6)

# -------------------------------------------------------------
# SHOP (BALL BAZAAR) LOGIC
# -------------------------------------------------------------

func _populate_skins_grid() -> void:
	for child in skins_grid_container.get_children():
		child.queue_free()

	var all_skins := SkinManager.get_all_skins()
	for skin_dict in all_skins:
		var card := Button.new()
		card.custom_minimum_size = Vector2(88, 88)
		card.focus_mode = Control.FOCUS_NONE
		card.flat = true

		var skin_id: String = skin_dict["id"]
		var is_unlocked: bool = GameSettings.is_skin_unlocked(skin_id) if GameSettings else (skin_id == "moonlit_pearl")
		var is_equipped: bool = GameSettings and GameSettings.equipped_skin == skin_id

		# Stylebox for skin card
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.bg_color = Color(0.12, 0.17, 0.14, 0.75)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2

		if is_equipped:
			sb.border_color = Color("#4ade80")
		elif skin_id == selected_skin_id:
			sb.border_color = Color("#fbbf24")
		else:
			sb.border_color = Color(0.35, 0.48, 0.4, 0.4)

		card.add_theme_stylebox_override("normal", sb)

		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Mini color circle indicator
		var dot_ctrl := Control.new()
		dot_ctrl.custom_minimum_size = Vector2(34, 34)
		dot_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c_col: Color = skin_dict["core_color"]
		dot_ctrl.draw.connect(func():
			dot_ctrl.draw_circle(Vector2(17, 17), 14.0, c_col)
			dot_ctrl.draw_circle(Vector2(14, 14), 4.5, Color.WHITE)
		)
		v.add_child(dot_ctrl)

		# Label
		var lbl := Label.new()
		lbl.text = skin_dict["name"]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", SkinManager.get_rarity_color(skin_dict["rarity"]))
		v.add_child(lbl)

		# Status or cost
		var sub_lbl := Label.new()
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.add_theme_font_size_override("font_size", 9)
		if is_equipped:
			sub_lbl.text = "EQUIPPED"
			sub_lbl.add_theme_color_override("font_color", Color("#4ade80"))
		elif is_unlocked:
			sub_lbl.text = "OWNED"
			sub_lbl.add_theme_color_override("font_color", Color("#cbd5e1"))
		else:
			sub_lbl.text = "%d GEMS" % skin_dict["cost"]
			sub_lbl.add_theme_color_override("font_color", Color("#fbbf24"))
		v.add_child(sub_lbl)

		card.add_child(v)

		card.pressed.connect(func():
			if SoundManager:
				SoundManager.play_ui_click()
			selected_skin_id = skin_id
			_refresh_skin_preview()
			_populate_skins_grid()
		)
		card.mouse_entered.connect(func():
			if SoundManager:
				SoundManager.play_ui_hover()
		)

		skins_grid_container.add_child(card)

func _refresh_skin_preview() -> void:
	var skin: Dictionary = SkinManager.get_skin_by_id(selected_skin_id)
	skin_name_label.text = skin["name"].to_upper()
	skin_rarity_label.text = skin["rarity"].to_upper()
	skin_rarity_label.add_theme_color_override("font_color", SkinManager.get_rarity_color(skin["rarity"]))
	skin_desc_label.text = skin["desc"]

	var is_unlocked: bool = GameSettings.is_skin_unlocked(selected_skin_id) if GameSettings else true
	var is_equipped: bool = GameSettings and GameSettings.equipped_skin == selected_skin_id

	if is_equipped:
		skin_action_btn.text = "EQUIPPED"
		skin_action_btn.disabled = true
		skin_action_btn.modulate = Color(0.7, 0.9, 0.75, 0.8)
	elif is_unlocked:
		skin_action_btn.text = "EQUIP SKIN"
		skin_action_btn.disabled = false
		skin_action_btn.modulate = Color("#4ade80")
	else:
		skin_action_btn.text = "BUY: %d GEMS" % skin["cost"]
		skin_action_btn.disabled = false
		skin_action_btn.modulate = Color("#fbbf24")

	if preview_control:
		preview_control.queue_redraw()

func _on_skin_action_pressed() -> void:
	if not GameSettings:
		return

	var is_unlocked: bool = GameSettings.is_skin_unlocked(selected_skin_id)
	if is_unlocked:
		GameSettings.equip_skin(selected_skin_id)
		if SoundManager:
			SoundManager.play_diamond_chime()
		_refresh_shop_ui()
	else:
		var skin := SkinManager.get_skin_by_id(selected_skin_id)
		var cost: int = skin["cost"]
		if GameSettings.gems >= cost:
			if GameSettings.spend_gems(cost):
				GameSettings.unlock_skin(selected_skin_id)
				GameSettings.equip_skin(selected_skin_id)
				if SoundManager:
					SoundManager.play_finish_fanfare()
				_refresh_shop_ui()
		else:
			# Not enough gems: shake button feedback
			if SoundManager:
				SoundManager.play_out_of_bounds()
			var tw := create_tween()
			tw.tween_property(skin_action_btn, "position:x", skin_action_btn.position.x - 6.0, 0.05)
			tw.tween_property(skin_action_btn, "position:x", skin_action_btn.position.x + 6.0, 0.05)
			tw.tween_property(skin_action_btn, "position:x", skin_action_btn.position.x, 0.05)

func _refresh_shop_ui() -> void:
	_update_counters()
	_refresh_skin_preview()
	_populate_skins_grid()

func _on_draw_ball_preview() -> void:
	if not preview_control:
		return
	var center: Vector2 = preview_control.size * 0.5
	var r: float = 38.0
	var skin := SkinManager.get_skin_by_id(selected_skin_id)
	var core_col: Color = skin["core_color"]
	var halo_col: Color = skin.get("halo_color", Color(core_col.r, core_col.g, core_col.b, 0.3))
	var motif: String = skin.get("motif", "lunar")

	# Halo pulse
	var pulse: float = 0.5 + 0.5 * sin(preview_anim_time * 3.2)
	var cur_halo := Color(halo_col.r, halo_col.g, halo_col.b, halo_col.a * (0.6 + pulse * 0.4))
	preview_control.draw_arc(center, r + 7.0 + pulse * 4.0, 0.0, TAU, 36, cur_halo, 2.2, true)

	if motif == "solar":
		for i in range(8):
			var a: float = float(i) * TAU / 8.0 + preview_anim_time * 1.5
			var p1 := center + Vector2(cos(a), sin(a)) * (r + 7.0)
			var p2 := center + Vector2(cos(a), sin(a)) * (r + 14.0 + pulse * 3.0)
			preview_control.draw_line(p1, p2, cur_halo, 2.0)
	elif motif == "rainbow":
		var hue: float = fmod(preview_anim_time * 0.3, 1.0)
		preview_control.draw_arc(center, r + 11.0, 0.0, TAU, 36, Color.from_hsv(hue, 0.8, 1.0, 0.5), 2.0, true)

	# Shadow
	preview_control.draw_circle(center + Vector2(4.0, 6.0), r * 1.02, Color(0.04, 0.07, 0.05, 0.5))

	# Shaded base
	var shade_col: Color = skin.get("shade_color", core_col.darkened(0.35))
	preview_control.draw_circle(center, r, shade_col)

	# Core body
	preview_control.draw_circle(center + Vector2(-1.5, -1.5), r * 0.9, core_col)

	# 3D Equator Seam
	var seam_pts: PackedVector2Array = PackedVector2Array()
	var seam_col: Color = skin.get("seam_color", Color(core_col.r * 1.25, core_col.g * 1.25, core_col.b * 1.25, 0.6))
	for i in range(25):
		var t: float = float(i) * TAU / 24.0
		var local_pt := Vector3(cos(t), sin(t), 0.0)
		var world_pt := preview_basis * local_pt
		if world_pt.z > 0.05:
			seam_pts.append(center + Vector2(world_pt.x, world_pt.y) * (r * 0.92))
		else:
			if seam_pts.size() >= 2:
				preview_control.draw_polyline(seam_pts, seam_col, 2.2, true)
			seam_pts.clear()
	if seam_pts.size() >= 2:
		preview_control.draw_polyline(seam_pts, seam_col, 2.2, true)

	# 3D Rotating Markers
	const MARKERS: Array[Vector3] = [
		Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0),
		Vector3(0.0, 1.0, 0.0), Vector3(0.0, -1.0, 0.0),
		Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0),
		Vector3(0.577, 0.577, 0.577), Vector3(-0.577, -0.577, 0.577)
	]
	var dot_col: Color = skin.get("dot_color", Color(core_col.r * 0.65, core_col.g * 0.65, core_col.b * 0.65, 0.8))
	for p: Vector3 in MARKERS:
		var wp: Vector3 = preview_basis * p
		if wp.z > 0.08:
			var p2d := center + Vector2(wp.x, wp.y) * (r * 0.86)
			var d_size: float = r * 0.18 * wp.z
			if motif == "cyber":
				var rect := Rect2(p2d - Vector2(d_size * 0.6, d_size * 0.6), Vector2(d_size * 1.2, d_size * 1.2))
				preview_control.draw_rect(rect, dot_col)
			elif motif == "sakura":
				preview_control.draw_circle(p2d, d_size * 0.9, dot_col)
				preview_control.draw_circle(p2d + Vector2(1.0, 0.0), d_size * 0.45, Color("#fce7f3"))
			else:
				preview_control.draw_circle(p2d, d_size, dot_col)
				preview_control.draw_circle(p2d, d_size * 0.5, Color(1.0, 1.0, 1.0, wp.z * 0.8))

	# Specular highlight
	var hl_pos := center + Vector2(-r * 0.32, -r * 0.32)
	if motif == "gold":
		preview_control.draw_circle(hl_pos, r * 0.28, Color(1.0, 1.0, 0.9, 0.95))
		preview_control.draw_line(hl_pos + Vector2(-6.0, 0.0), hl_pos + Vector2(6.0, 0.0), Color.WHITE, 1.8)
		preview_control.draw_line(hl_pos + Vector2(0.0, -6.0), hl_pos + Vector2(0.0, 6.0), Color.WHITE, 1.8)
	else:
		preview_control.draw_circle(hl_pos, r * 0.28, Color(1.0, 1.0, 1.0, 0.92))

# -------------------------------------------------------------
# LEVELS (COURSE SELECT) LOGIC
# -------------------------------------------------------------

func _populate_levels_grid() -> void:
	for child in levels_grid_container.get_children():
		child.queue_free()

	var unlocked_lvl: int = GameSettings.unlocked_level if GameSettings else 1

	for lvl in range(1, 31):
		var is_unlocked: bool = (lvl <= unlocked_lvl)
		var stars: int = GameSettings.get_level_stars(lvl) if GameSettings else 0
		var best_shots: int = GameSettings.get_level_best_shots(lvl) if GameSettings else 0

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 68)
		btn.focus_mode = Control.FOCUS_NONE

		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1

		if is_unlocked:
			sb.bg_color = Color(0.12, 0.17, 0.14, 0.85)
			sb.border_color = Color("#4ade80") if stars == 3 else Color(0.42, 0.56, 0.47, 0.6)
		else:
			sb.bg_color = Color(0.08, 0.11, 0.09, 0.55)
			sb.border_color = Color(0.2, 0.28, 0.24, 0.4)
		btn.add_theme_stylebox_override("normal", sb)

		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var num_lbl := Label.new()
		num_lbl.text = str(lvl)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 16)
		num_lbl.add_theme_color_override("font_color", Color("#f4f2ec") if is_unlocked else Color(0.45, 0.52, 0.48, 0.6))
		v.add_child(num_lbl)

		if is_unlocked:
			if stars > 0:
				var s_row := HBoxContainer.new()
				s_row.alignment = BoxContainer.ALIGNMENT_CENTER
				s_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				s_row.add_theme_constant_override("separation", 2)
				for s in range(stars):
					var s_tex := TextureRect.new()
					s_tex.texture = preload("res://assets/icons/icon_star.svg")
					s_tex.custom_minimum_size = Vector2(10, 10)
					s_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					s_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					s_row.add_child(s_tex)
				v.add_child(s_row)
			else:
				var star_lbl := Label.new()
				star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				star_lbl.add_theme_font_size_override("font_size", 10)
				star_lbl.text = "READY"
				star_lbl.add_theme_color_override("font_color", Color("#4ade80"))
				v.add_child(star_lbl)
		else:
			var l_icon := TextureRect.new()
			l_icon.texture = preload("res://assets/icons/icon_lock.svg")
			l_icon.custom_minimum_size = Vector2(14, 14)
			l_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			l_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			l_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			v.add_child(l_icon)

		btn.add_child(v)

		if is_unlocked:
			btn.pressed.connect(func():
				if SoundManager:
					SoundManager.play_ui_click()
				close()
				level_selected.emit(lvl - 1)
			)
			btn.mouse_entered.connect(func():
				if SoundManager:
					SoundManager.play_ui_hover()
			)
		else:
			btn.disabled = true

		levels_grid_container.add_child(btn)

# -------------------------------------------------------------
# SETTINGS LOGIC
# -------------------------------------------------------------

func _setup_settings_listeners() -> void:
	sfx_slider.value_changed.connect(func(val):
		if GameSettings:
			GameSettings.set_sfx_volume(val / 100.0)
	)
	music_slider.value_changed.connect(func(val):
		if GameSettings:
			GameSettings.set_music_volume(val / 100.0)
	)
	sens_slider.value_changed.connect(func(val):
		if GameSettings:
			GameSettings.set_aim_sensitivity(val / 100.0)
	)
	shake_toggle.toggled.connect(func(val):
		if GameSettings:
			GameSettings.set_screen_shake(val)
	)

	traj_full_btn.pressed.connect(func(): _set_traj("FULL"))
	traj_short_btn.pressed.connect(func(): _set_traj("SHORT"))
	traj_off_btn.pressed.connect(func(): _set_traj("OFF"))

func _sync_settings_values() -> void:
	if not GameSettings:
		return
	sfx_slider.value = GameSettings.sfx_volume * 100.0
	music_slider.value = GameSettings.music_volume * 100.0
	sens_slider.value = GameSettings.aim_sensitivity * 100.0
	shake_toggle.button_pressed = GameSettings.screen_shake_enabled
	_set_traj(GameSettings.trajectory_mode)

func _set_traj(mode: String) -> void:
	if GameSettings:
		GameSettings.set_trajectory_mode(mode)
	traj_full_btn.modulate = Color.WHITE if mode == "FULL" else Color(0.65, 0.75, 0.7, 0.6)
	traj_short_btn.modulate = Color.WHITE if mode == "SHORT" else Color(0.65, 0.75, 0.7, 0.6)
	traj_off_btn.modulate = Color.WHITE if mode == "OFF" else Color(0.65, 0.75, 0.7, 0.6)

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
