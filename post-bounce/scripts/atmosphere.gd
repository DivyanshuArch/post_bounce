class_name Atmosphere
extends CanvasLayer

## Overhead looped line-art clouds, grey wisps, gliding birds, fireflies,
## and moonlit vignette matching the HTML5 canvas presentation.

var clouds: Array[Dictionary] = []
var wisps: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var fireflies: Array[Dictionary] = []
var theme_particles: Array[Dictionary] = []

var time_elapsed: float = 0.0
var camera_offset: Vector2 = Vector2.ZERO
var current_theme: String = "Moonlit Forest"

@onready var visual: Control = $Visual
@onready var vignette_rect: ColorRect = $Vignette if has_node("Vignette") else null

func set_theme(theme_name: String) -> void:
	current_theme = theme_name
	var theme_colors := Palette.get_theme_colors(theme_name)
	if vignette_rect and vignette_rect.material is ShaderMaterial:
		var mat := vignette_rect.material as ShaderMaterial
		var vig_col: Color = theme_colors.get("vignette", Color(0.047, 0.071, 0.059, 0.44))
		mat.set_shader_parameter("vignette_color", vig_col)

		match theme_name:
			"Bihar Heritage":
				mat.set_shader_parameter("moon_color", Color(1.0, 0.82, 0.55, 0.18))
			"Japan Sakura":
				mat.set_shader_parameter("moon_color", Color(1.0, 0.78, 0.88, 0.18))
			"Himalayas Alpine":
				mat.set_shader_parameter("moon_color", Color(0.72, 0.88, 1.0, 0.18))
			_:
				mat.set_shader_parameter("moon_color", Color(0.91, 0.89, 0.83, 0.08))

	_init_theme_particles()
	if visual:
		visual.queue_redraw()

func _init_theme_particles() -> void:
	theme_particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 98127 + int(abs(hash(current_theme)))

	var count: int = 36
	for i in range(count):
		theme_particles.append({
			"pos": Vector2(rng.randf() * 1600.0 - 100.0, rng.randf() * 1000.0 - 50.0),
			"vel": Vector2(18.0 + rng.randf() * 26.0, 24.0 + rng.randf() * 30.0),
			"size": 3.0 + rng.randf() * 3.5,
			"rot": rng.randf() * TAU,
			"rot_speed": (rng.randf() - 0.5) * 3.5,
			"sway_phase": rng.randf() * TAU,
			"opacity": 0.45 + rng.randf() * 0.45
		})

func _ready() -> void:
	if visual:
		visual.draw.connect(_on_visual_draw)

	_init_theme_particles()

	var rng := RandomNumberGenerator.new()
	rng.seed = 77123

	# 1. Signature looped line-art clouds
	for i in range(6):
		clouds.append(_create_looped_cloud(rng, rng.randf() * 1800.0 - 200.0, rng.randf() * 1000.0))

	# 2. Translucent grey cloud wisps
	for i in range(6):
		wisps.append({
			"pos": Vector2(rng.randf() * 1800.0 - 200.0, rng.randf() * 1000.0),
			"w": 190.0 + rng.randf() * 220.0,
			"h": 12.0 + rng.randf() * 12.0,
			"speed": 7.0 + rng.randf() * 9.0
		})

	# 3. Tiny gliding bird silhouettes
	for i in range(3):
		var dir_x: float = 1.0 if rng.randf() > 0.5 else -1.0
		birds.append({
			"pos": Vector2(rng.randf() * 1400.0, rng.randf() * 800.0),
			"vel": Vector2((22.0 + rng.randf() * 20.0) * dir_x, (rng.randf() - 0.5) * 14.0),
			"flap_phase": rng.randf() * TAU,
			"size": 5.0 + rng.randf() * 2.5
		})

	# 4. Drifting green-yellow firefly specks
	for i in range(48):
		fireflies.append({
			"pos": Vector2(rng.randf() * 1600.0, rng.randf() * 1000.0),
			"vel": Vector2((rng.randf() - 0.5) * 14.0, (rng.randf() - 0.5) * 14.0),
			"phase": rng.randf() * TAU,
			"speed": 1.4 + rng.randf() * 2.0,
			"size": 1.4 + rng.randf() * 1.4
		})

func _create_looped_cloud(rng: RandomNumberGenerator, x: float, y: float) -> Dictionary:
	var loop_count: int = 4 + (rng.randi() % 3)
	var scale_val: float = 0.72 + rng.randf() * 0.45
	var loops: Array = []
	var cx: float = 0.0

	for i in range(loop_count):
		var norm: float = float(i) / float(maxi(1, loop_count - 1))
		var arch_factor: float = 1.0 - absf(norm - 0.45) * 0.88
		var w: float = (36.0 + rng.randf() * 22.0) * scale_val * (0.68 + arch_factor * 0.46)
		var h: float = (20.0 + rng.randf() * 20.0) * scale_val * (0.55 + arch_factor * 0.62)
		var overlap: float = w * (0.18 + rng.randf() * 0.14)

		loops.append([
			Vector2(cx, (rng.randf() - 0.5) * 5.0),
			Vector2(cx + w * 0.15, -h * 0.58),
			Vector2(cx + w * 0.46, -h),
			Vector2(cx + w * 0.82, -h * 0.66),
			Vector2(cx + w, -h * 0.14)
		])
		cx += w - overlap

	return {
		"pos": Vector2(x, y),
		"loops": loops,
		"total_width": cx + 40.0 * scale_val,
		"speed": 9.0 + rng.randf() * 10.0
	}

func update_atmosphere(delta: float, cam_offset: Vector2) -> void:
	time_elapsed += delta
	camera_offset = cam_offset

	var vp_size: Vector2 = visual.get_viewport_rect().size
	var wrap_w: float = maxf(1400.0, vp_size.x + 320.0)
	var wrap_h: float = maxf(900.0, vp_size.y + 160.0)

	for c in clouds:
		c["pos"].x += c["speed"] * delta
		if c["pos"].x > wrap_w:
			c["pos"].x = -c["total_width"] - 80.0

	for w in wisps:
		w["pos"].x += w["speed"] * delta
		if w["pos"].x > wrap_w:
			w["pos"].x = -w["w"] - 80.0

	for b in birds:
		b["pos"] += b["vel"] * delta
		b["flap_phase"] += delta * 6.5
		if b["pos"].x > wrap_w: b["pos"].x = -80.0
		if b["pos"].x < -100.0: b["pos"].x = wrap_w - 20.0
		if b["pos"].y > wrap_h: b["pos"].y = -40.0
		if b["pos"].y < -60.0: b["pos"].y = wrap_h - 20.0

	for f in fireflies:
		f["phase"] += delta * f["speed"]
		f["pos"].x += (f["vel"].x + sin(f["phase"] * 0.7) * 5.0) * delta
		f["pos"].y += (f["vel"].y + cos(f["phase"] * 0.6) * 5.0) * delta
		if f["pos"].x < -20.0: f["pos"].x = vp_size.x + 20.0
		if f["pos"].x > vp_size.x + 20.0: f["pos"].x = -20.0
		if f["pos"].y < -20.0: f["pos"].y = vp_size.y + 20.0
		if f["pos"].y > vp_size.y + 20.0: f["pos"].y = -20.0

	# 5. Themed atmospheric particles (sakura, embers, snowflakes)
	for p in theme_particles:
		p["sway_phase"] += delta * 2.2
		var sway_x: float = sin(p["sway_phase"]) * 14.0 * delta
		p["pos"].x += (p["vel"].x + sway_x) * delta
		p["pos"].y += p["vel"].y * delta
		p["rot"] += p["rot_speed"] * delta
		if p["pos"].y > wrap_h + 30.0:
			p["pos"].y = -30.0
			p["pos"].x = randf() * wrap_w
		if p["pos"].x > wrap_w + 30.0:
			p["pos"].x = -20.0

	visual.queue_redraw()

func draw_atmosphere(ctrl: Control) -> void:
	var vp_size: Vector2 = ctrl.get_viewport_rect().size
	var par: Vector2 = camera_offset * -0.18

	# 1. Translucent grey wisps
	for w in wisps:
		var p: Vector2 = w["pos"] + par
		var ww: float = w["w"]
		var wh: float = w["h"]
		var w_pts: PackedVector2Array = [
			p + Vector2(-ww * 0.5, 0.0),
			p + Vector2(-ww * 0.24, -wh * 0.45),
			p + Vector2(ww * 0.28, -wh * 0.48),
			p + Vector2(ww * 0.5, wh * 0.14),
			p + Vector2(ww * 0.14, wh * 0.45),
			p + Vector2(-ww * 0.3, wh * 0.34)
		]
		ctrl.draw_colored_polygon(w_pts, Palette.CLOUD_WISP)

	# 2. Signature white looped line-art clouds
	for c in clouds:
		var sp: Vector2 = c["pos"] + par * 1.25
		for l_idx in range(c["loops"].size()):
			var arch: Array = c["loops"][l_idx]
			var arch_pts: PackedVector2Array = PackedVector2Array()
			for pt: Vector2 in arch:
				arch_pts.append(sp + pt)
			ctrl.draw_polyline(arch_pts, Palette.CLOUD_LINE, 1.55, true)

	# 3. Tiny gliding bird silhouettes
	for b in birds:
		var wing_y: float = sin(b["flap_phase"]) * 2.4
		var bp: Vector2 = b["pos"] + par
		var s: float = b["size"]
		var ang: float = b["vel"].angle()

		var xf := Transform2D(ang, bp)
		var p_left := xf * Vector2(-s, -s * 0.7 + wing_y)
		var p_mid := xf * Vector2(0.0, 0.0)
		var p_right := xf * Vector2(-s, s * 0.7 - wing_y)
		ctrl.draw_polyline([p_left, p_mid, p_right], Palette.BIRD, 1.5, true)

	# 4. Drifting themed firefly specks
	var firefly_base: Color = Palette.FIREFLY
	match current_theme:
		"Bihar Heritage":
			firefly_base = Color(0.98, 0.76, 0.25)
		"Japan Sakura":
			firefly_base = Color(0.98, 0.65, 0.8)
		"Himalayas Alpine":
			firefly_base = Color(0.55, 0.85, 0.98)

	for f in fireflies:
		var twinkle: float = 0.18 + 0.58 * (0.5 + 0.5 * sin(f["phase"]))
		var col := Color(firefly_base.r, firefly_base.g, firefly_base.b, twinkle)
		var s: float = f["size"]
		ctrl.draw_rect(Rect2(f["pos"].x, f["pos"].y, s, s), col)

	# 5. Themed ambient particles
	match current_theme:
		"Japan Sakura":
			# Floating pink cherry blossom petals
			var petal_col1 := Color(0.98, 0.75, 0.84)
			var petal_col2 := Color(0.94, 0.52, 0.68)
			for p in theme_particles:
				var sp: Vector2 = p["pos"] + par * 0.8
				var col: Color = petal_col1 if int(p["size"] * 10) % 2 == 0 else petal_col2
				col.a = p["opacity"]
				var s: float = p["size"]
				var rot: float = p["rot"]
				var cos_r: float = cos(rot)
				var sin_r: float = sin(rot)
				var pts: PackedVector2Array = [
					sp + Vector2(-s * 0.6 * cos_r, -s * sin_r),
					sp + Vector2(s * cos_r, s * 0.35 * sin_r),
					sp + Vector2(-s * 0.25 * cos_r, s * 0.85 * sin_r)
				]
				ctrl.draw_colored_polygon(pts, col)

		"Bihar Heritage":
			# Drifting warm golden marigold petals and diya sparks
			for p in theme_particles:
				var sp: Vector2 = p["pos"] + par * 0.8
				var col: Color = Color(0.98, 0.68, 0.22, p["opacity"] * 0.85) if int(p["size"] * 10) % 2 == 0 else Color(0.92, 0.32, 0.18, p["opacity"] * 0.75)
				ctrl.draw_circle(sp, p["size"] * 0.55, col)

		"Himalayas Alpine":
			# Soft fluttering snowflakes
			for p in theme_particles:
				var sp: Vector2 = p["pos"] + par * 0.8
				var col := Color(0.92, 0.96, 1.0, p["opacity"] * 0.78)
				ctrl.draw_circle(sp, p["size"] * 0.48, col)

func _on_visual_draw() -> void:
	if visual:
		draw_atmosphere(visual)
