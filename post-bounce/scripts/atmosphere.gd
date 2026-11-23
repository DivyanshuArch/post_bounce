class_name Atmosphere
extends CanvasLayer

## Overhead looped line-art clouds, grey wisps, gliding birds, fireflies,
## and moonlit vignette matching the HTML5 canvas presentation.

var clouds: Array[Dictionary] = []
var wisps: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var fireflies: Array[Dictionary] = []

var time_elapsed: float = 0.0
var camera_offset: Vector2 = Vector2.ZERO

@onready var visual: Control = $Visual

func _ready() -> void:
	if visual:
		visual.draw.connect(_on_visual_draw)

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

	# 4. Drifting green-yellow firefly specks
	for f in fireflies:
		var twinkle: float = 0.18 + 0.58 * (0.5 + 0.5 * sin(f["phase"]))
		var col := Color(Palette.FIREFLY.r, Palette.FIREFLY.g, Palette.FIREFLY.b, twinkle)
		var s: float = f["size"]
		ctrl.draw_rect(Rect2(f["pos"].x, f["pos"].y, s, s), col)

func _on_visual_draw() -> void:
	if visual:
		draw_atmosphere(visual)
