class_name ParticleManager
extends Node2D

## Handles particle bursts, expanding rings, and impact dust matching the HTML5 visual effects.

var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []

func _process(delta: float) -> void:
	var needs_redraw: bool = false

	# Update particles
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["life"] -= delta
		if p["life"] <= 0.0:
			particles.remove_at(i)
			needs_redraw = true
			continue

		p["pos"] += p["vel"] * delta
		p["vel"] *= exp(-3.8 * delta)
		needs_redraw = true

	# Update rings
	for i in range(rings.size() - 1, -1, -1):
		var r: Dictionary = rings[i]
		r["life"] -= delta
		if r["life"] <= 0.0:
			rings.remove_at(i)
			needs_redraw = true
			continue

		var t: float = 1.0 - (r["life"] / r["max_life"])
		r["radius"] = lerpf(6.0, r["max_radius"], 1.0 - pow(1.0 - t, 3.0))
		needs_redraw = true

	if needs_redraw or not particles.is_empty() or not rings.is_empty():
		queue_redraw()

func spawn_bounce_dust(pos: Vector2, normal: Vector2, speed: float) -> void:
	var count: int = mini(10, 4 + int(speed / 140.0))
	var base_ang: float = normal.angle()
	for i in range(count):
		var ang: float = base_ang + (randf() - 0.5) * 1.65
		var spd: float = 25.0 + randf() * minf(140.0, speed * 0.25)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(ang) * spd, sin(ang) * spd),
			"life": 0.24 + randf() * 0.24,
			"max_life": 0.48,
			"size": 1.8 + randf() * 2.4,
			"color": Palette.CONTOUR_BRIGHT if (i % 2 == 0) else Color("#d5dfd8"),
			"shape": "circle"
		})
	queue_redraw()

func spawn_diamond_burst(pos: Vector2) -> void:
	rings.append({
		"pos": pos,
		"radius": 7.0,
		"max_radius": 52.0,
		"life": 0.48,
		"max_life": 0.48,
		"color": Color(0.98, 0.89, 0.4)
	})
	for i in range(16):
		var ang: float = (float(i) / 16.0) * TAU + (randf() - 0.5) * 0.25
		var spd: float = 45.0 + randf() * 115.0
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(ang) * spd, sin(ang) * spd),
			"life": 0.42 + randf() * 0.4,
			"max_life": 0.82,
			"size": 2.6 + randf() * 2.8,
			"color": Palette.DIAMOND_HIGHLIGHT if (i % 3 == 0) else Palette.DIAMOND_CORE,
			"shape": "diamond" if (i % 2 == 0) else "circle"
		})
	queue_redraw()

func spawn_finish_celebration(pos: Vector2) -> void:
	rings.append({
		"pos": pos,
		"radius": 10.0,
		"max_radius": 88.0,
		"life": 0.65,
		"max_life": 0.65,
		"color": Color(0.933, 0.953, 0.937)
	})
	rings.append({
		"pos": pos,
		"radius": 6.0,
		"max_radius": 62.0,
		"life": 0.55,
		"max_life": 0.55,
		"color": Palette.DIAMOND_CORE
	})
	for i in range(28):
		var ang: float = randf() * TAU
		var spd: float = 60.0 + randf() * 190.0
		var col: Color = Palette.DIAMOND_CORE if (i % 3 == 0) else (Color("#f4f7f5") if (i % 3 == 1) else Palette.CONTOUR_BRIGHT)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(ang) * spd, sin(ang) * spd),
			"life": 0.55 + randf() * 0.55,
			"max_life": 1.1,
			"size": 2.5 + randf() * 3.5,
			"color": col,
			"shape": "diamond" if (i % 2 == 0) else "circle"
		})
	queue_redraw()

func _draw() -> void:
	# Draw rings
	for r in rings:
		var alpha: float = (r["life"] / r["max_life"]) * 0.65
		var col: Color = r["color"]
		col.a = alpha
		draw_arc(r["pos"], r["radius"], 0.0, TAU, 32, col, 2.0, true)

	# Draw particles
	for p in particles:
		var alpha: float = clampf(p["life"] / p["max_life"], 0.0, 1.0)
		var col: Color = p["color"]
		col.a = alpha

		if p["shape"] == "diamond":
			var s: float = p["size"]
			var d_pts: PackedVector2Array = [
				p["pos"] + Vector2(0.0, -s),
				p["pos"] + Vector2(s, 0.0),
				p["pos"] + Vector2(0.0, s),
				p["pos"] + Vector2(-s, 0.0)
			]
			draw_colored_polygon(d_pts, col)
		else:
			draw_circle(p["pos"], p["size"] * 0.55, col)
