class_name CourseManager
extends RefCounted

## Handcrafted courses 1-6 + endless procedural generator (7+).

static func get_course_par(index: int) -> int:
	var pars: Array[int] = [1, 2, 2, 3, 2, 2, 3, 2, 3]
	if index >= 0 and index < pars.size():
		return pars[index]
	return 2 + (index % 2)

static func get_handcrafted_course(index: int) -> Dictionary:
	var defs: Array = [
		# COURSE 1: MOONLIT BEND
		{
			"name": "MOONLIT BEND",
			"outerPoly": [
				Vector2(100.0, 400.0),
				Vector2(640.0, 400.0),
				Vector2(760.0, 280.0),
				Vector2(760.0, 90.0),
				Vector2(560.0, 90.0),
				Vector2(560.0, 240.0),
				Vector2(100.0, 240.0)
			],
			"obstacles": [],
			"start": Vector2(190.0, 320.0),
			"finish": { "x1": 572.0, "y1": 122.0, "x2": 748.0, "y2": 122.0 },
			"diamonds": [
				{ "x": 655.0, "y": 315.0 }
			]
		},

		# COURSE 2: TWIN PINE SPLIT
		{
			"name": "TWIN PINE SPLIT",
			"outerPoly": [
				Vector2(80.0, 260.0),
				Vector2(240.0, 110.0),
				Vector2(680.0, 110.0),
				Vector2(840.0, 260.0),
				Vector2(840.0, 360.0),
				Vector2(680.0, 510.0),
				Vector2(240.0, 510.0),
				Vector2(80.0, 360.0)
			],
			"obstacles": [
				[
					Vector2(460.0, 205.0),
					Vector2(575.0, 310.0),
					Vector2(460.0, 415.0),
					Vector2(345.0, 310.0)
				]
			],
			"start": Vector2(175.0, 310.0),
			"finish": { "x1": 790.0, "y1": 252.0, "x2": 790.0, "y2": 368.0 },
			"diamonds": [
				{ "x": 460.0, "y": 158.0 },
				{ "x": 460.0, "y": 462.0 }
			]
		},

		# COURSE 3: ZIG-ZAG GORGE
		{
			"name": "ZIG-ZAG GORGE",
			"outerPoly": [
				Vector2(70.0, 410.0),
				Vector2(460.0, 410.0),
				Vector2(550.0, 320.0),
				Vector2(550.0, 240.0),
				Vector2(860.0, 240.0),
				Vector2(860.0, 90.0),
				Vector2(450.0, 90.0),
				Vector2(360.0, 180.0),
				Vector2(360.0, 265.0),
				Vector2(70.0, 265.0)
			],
			"obstacles": [],
			"start": Vector2(145.0, 338.0),
			"finish": { "x1": 825.0, "y1": 98.0, "x2": 825.0, "y2": 232.0 },
			"diamonds": [
				{ "x": 465.0, "y": 335.0 },
				{ "x": 455.0, "y": 165.0 }
			]
		},

		# COURSE 4: SHATTERED GLADE
		{
			"name": "SHATTERED GLADE",
			"outerPoly": [
				Vector2(90.0, 200.0),
				Vector2(220.0, 80.0),
				Vector2(700.0, 80.0),
				Vector2(830.0, 200.0),
				Vector2(830.0, 440.0),
				Vector2(700.0, 560.0),
				Vector2(220.0, 560.0),
				Vector2(90.0, 440.0)
			],
			"obstacles": [
				[
					Vector2(310.0, 195.0),
					Vector2(405.0, 245.0),
					Vector2(325.0, 320.0),
					Vector2(255.0, 255.0)
				],
				[
					Vector2(545.0, 175.0),
					Vector2(645.0, 220.0),
					Vector2(590.0, 315.0),
					Vector2(505.0, 265.0)
				],
				[
					Vector2(430.0, 365.0),
					Vector2(535.0, 410.0),
					Vector2(470.0, 485.0),
					Vector2(375.0, 435.0)
				]
			],
			"start": Vector2(170.0, 380.0),
			"finish": { "x1": 775.0, "y1": 180.0, "x2": 775.0, "y2": 300.0 },
			"diamonds": [
				{ "x": 450.0, "y": 132.0 },
				{ "x": 655.0, "y": 435.0 }
			]
		},

		# COURSE 5: CRESCENT RICOCHET
		{
			"name": "CRESCENT RICOCHET",
			"outerPoly": [
				Vector2(110.0, 470.0),
				Vector2(110.0, 250.0),
				Vector2(250.0, 100.0),
				Vector2(650.0, 100.0),
				Vector2(790.0, 250.0),
				Vector2(790.0, 470.0),
				Vector2(610.0, 470.0),
				Vector2(610.0, 310.0),
				Vector2(525.0, 245.0),
				Vector2(375.0, 245.0),
				Vector2(290.0, 310.0),
				Vector2(290.0, 470.0)
			],
			"obstacles": [],
			"start": Vector2(200.0, 405.0),
			"finish": { "x1": 622.0, "y1": 430.0, "x2": 778.0, "y2": 430.0 },
			"diamonds": [
				{ "x": 290.0, "y": 175.0 },
				{ "x": 610.0, "y": 175.0 }
			]
		},

		# COURSE 6: MOONLIT FUNNEL
		{
			"name": "MOONLIT FUNNEL",
			"theme": "Moonlit Forest",
			"outerPoly": [
				Vector2(80.0, 130.0),
				Vector2(820.0, 130.0),
				Vector2(820.0, 520.0),
				Vector2(540.0, 520.0),
				Vector2(540.0, 365.0),
				Vector2(80.0, 365.0)
			],
			"obstacles": [
				[
					Vector2(410.0, 130.0),
					Vector2(470.0, 130.0),
					Vector2(470.0, 265.0),
					Vector2(410.0, 235.0)
				],
				[
					Vector2(570.0, 260.0),
					Vector2(685.0, 280.0),
					Vector2(650.0, 365.0),
					Vector2(560.0, 335.0)
				]
			],
			"start": Vector2(170.0, 248.0),
			"finish": { "x1": 552.0, "y1": 482.0, "x2": 808.0, "y2": 482.0 },
			"diamonds": [
				{ "x": 325.0, "y": 310.0 },
				{ "x": 750.0, "y": 215.0 }
			]
		},

		# COURSE 7: NALANDA BAZAAR (Bihar Heritage)
		{
			"name": "NALANDA BAZAAR",
			"theme": "Bihar Heritage",
			"outerPoly": [
				Vector2(80.0, 480.0),
				Vector2(820.0, 480.0),
				Vector2(880.0, 340.0),
				Vector2(880.0, 120.0),
				Vector2(620.0, 120.0),
				Vector2(540.0, 230.0),
				Vector2(80.0, 230.0)
			],
			"obstacles": [
				[
					Vector2(285.0, 255.0),
					Vector2(375.0, 255.0),
					Vector2(375.0, 305.0),
					Vector2(285.0, 305.0)
				],
				[
					Vector2(535.0, 390.0),
					Vector2(625.0, 390.0),
					Vector2(625.0, 440.0),
					Vector2(535.0, 440.0)
				]
			],
			"start": Vector2(170.0, 355.0),
			"finish": { "x1": 640.0, "y1": 140.0, "x2": 860.0, "y2": 140.0 },
			"diamonds": [
				{ "x": 330.0, "y": 420.0 },
				{ "x": 460.0, "y": 260.0 },
				{ "x": 760.0, "y": 290.0 }
			]
		},

		# COURSE 8: KYOTO SAKURA SHRINE (Japan Sakura)
		{
			"name": "KYOTO SAKURA SHRINE",
			"theme": "Japan Sakura",
			"outerPoly": [
				Vector2(70.0, 260.0),
				Vector2(240.0, 100.0),
				Vector2(720.0, 100.0),
				Vector2(880.0, 260.0),
				Vector2(880.0, 420.0),
				Vector2(720.0, 560.0),
				Vector2(240.0, 560.0),
				Vector2(70.0, 420.0)
			],
			"obstacles": [
				[
					Vector2(400.0, 332.0),
					Vector2(418.0, 332.0),
					Vector2(418.0, 350.0),
					Vector2(400.0, 350.0)
				],
				[
					Vector2(502.0, 332.0),
					Vector2(520.0, 332.0),
					Vector2(520.0, 350.0),
					Vector2(502.0, 350.0)
				]
			],
			"start": Vector2(160.0, 340.0),
			"finish": { "x1": 810.0, "y1": 260.0, "x2": 810.0, "y2": 420.0 },
			"diamonds": [
				{ "x": 460.0, "y": 210.0 },
				{ "x": 460.0, "y": 470.0 },
				{ "x": 460.0, "y": 340.0 }
			]
		},

		# COURSE 9: HIMALAYAN PASS (Himalayas Alpine)
		{
			"name": "HIMALAYAN PASS",
			"theme": "Himalayas Alpine",
			"outerPoly": [
				Vector2(80.0, 420.0),
				Vector2(380.0, 420.0),
				Vector2(490.0, 520.0),
				Vector2(880.0, 520.0),
				Vector2(880.0, 330.0),
				Vector2(620.0, 330.0),
				Vector2(560.0, 150.0),
				Vector2(220.0, 150.0),
				Vector2(140.0, 260.0),
				Vector2(80.0, 260.0)
			],
			"obstacles": [
				[
					Vector2(330.0, 250.0),
					Vector2(390.0, 250.0),
					Vector2(390.0, 310.0),
					Vector2(330.0, 310.0)
				],
				[
					Vector2(660.0, 395.0),
					Vector2(720.0, 395.0),
					Vector2(720.0, 455.0),
					Vector2(660.0, 455.0)
				]
			],
			"start": Vector2(150.0, 340.0),
			"finish": { "x1": 840.0, "y1": 345.0, "x2": 840.0, "y2": 505.0 },
			"diamonds": [
				{ "x": 280.0, "y": 220.0 },
				{ "x": 490.0, "y": 220.0 },
				{ "x": 530.0, "y": 440.0 }
			]
		}
	]

	if index >= 0 and index < defs.size():
		return defs[index]
	return defs[0]

static func generate_procedural_course(course_num: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = course_num * 92821 + 1337
	var template: int = course_num % 3
	var theme_list: Array[String] = ["Moonlit Forest", "Bihar Heritage", "Japan Sakura", "Himalayas Alpine"]
	var selected_theme: String = theme_list[course_num % theme_list.size()]

	if template == 0:
		var w: float = 780.0 + float(rng.randi() % 140)
		var h: float = 440.0 + float(rng.randi() % 100)
		var ch: float = 90.0 + float(rng.randi() % 35)
		var outer_poly: Array = [
			Vector2(ch, 0.0),
			Vector2(w - ch, 0.0),
			Vector2(w, ch),
			Vector2(w, h - ch),
			Vector2(w - ch, h),
			Vector2(ch, h),
			Vector2(0.0, h - ch),
			Vector2(0.0, ch)
		]

		var start := Vector2(95.0, h * (0.28 + rng.randf() * 0.44))
		var finish_y: float = h * (0.25 + rng.randf() * 0.5)
		var finish_half: float = 58.0
		var finish := {
			"x1": w - 42.0,
			"y1": clampf(finish_y - finish_half, ch + 10.0, h - ch - 120.0),
			"x2": w - 42.0,
			"y2": clampf(finish_y + finish_half, ch + 130.0, h - ch - 10.0)
		}

		var obstacles: Array = []
		var obs_centers: Array = []
		var target_obs: int = 2 + (rng.randi() % 3)

		for tries in range(90):
			if obstacles.size() >= target_obs:
				break
			var cx: float = 220.0 + rng.randf() * (w - 440.0)
			var cy: float = 95.0 + rng.randf() * (h - 190.0)
			var rx: float = 44.0 + rng.randf() * 32.0
			var ry: float = 40.0 + rng.randf() * 28.0
			var rad: float = maxf(rx, ry)
			var c_pt := Vector2(cx, cy)

			if c_pt.distance_to(start) < rad + 95.0:
				continue
			if c_pt.distance_to(Vector2(finish["x1"], (finish["y1"] + finish["y2"]) * 0.5)) < rad + 105.0:
				continue

			var overlap: bool = false
			for o in obs_centers:
				if c_pt.distance_to(o["pos"]) < rad + o["r"] + 75.0:
					overlap = true
					break
			if overlap:
				continue

			var sides: int = 4 + (rng.randi() % 3)
			var local_pts: PackedVector2Array = GeometryUtils.make_jagged_polygon(rng, sides, rx, ry, 0.16, rng.randf() * PI)
			var world_pts: Array = []
			for p: Vector2 in local_pts:
				world_pts.append(c_pt + p)
			obstacles.append(world_pts)
			obs_centers.append({ "pos": c_pt, "r": rad })

		var diamonds: Array = []
		var packed_outer := PackedVector2Array(outer_poly)
		for tries in range(80):
			if diamonds.size() >= 2:
				break
			var dx: float = 180.0 + rng.randf() * (w - 360.0)
			var dy: float = 70.0 + rng.randf() * (h - 140.0)
			var dp := Vector2(dx, dy)
			if not GeometryUtils.point_in_polygon(dp, packed_outer):
				continue
			if GeometryUtils.dist_to_polygon_edges(dp, packed_outer) < 42.0:
				continue
			if dp.distance_to(start) < 110.0:
				continue

			var inside_any_obs: bool = false
			for obs in obstacles:
				var p_obs := PackedVector2Array(obs)
				if GeometryUtils.point_in_polygon(dp, p_obs) or GeometryUtils.dist_to_polygon_edges(dp, p_obs) < 36.0:
					inside_any_obs = true
					break
			if inside_any_obs:
				continue

			var too_close_dm: bool = false
			for dm in diamonds:
				if dp.distance_to(Vector2(dm["x"], dm["y"])) < 160.0:
					too_close_dm = true
					break
			if too_close_dm:
				continue

			diamonds.append({ "x": dx, "y": dy })

		return {
			"name": "FOREST GLADE %d" % course_num,
			"theme": selected_theme,
			"outerPoly": outer_poly,
			"obstacles": obstacles,
			"start": start,
			"finish": finish,
			"diamonds": diamonds
		}

	elif template == 1:
		var flip_y: bool = (rng.randf() > 0.5)
		var leg1: float = 360.0 + float(rng.randi() % 90)
		var leg2: float = 300.0 + float(rng.randi() % 80)
		var cw: float = 135.0 + float(rng.randi() % 25)
		var drop: float = 155.0 + float(rng.randi() % 55)

		var raw_pts: Array = [
			Vector2(0.0, drop + cw),
			Vector2(leg1 + cw * 0.5, drop + cw),
			Vector2(leg1 + cw, drop + cw * 0.5),
			Vector2(leg1 + cw, cw),
			Vector2(leg1 + cw + leg2, cw),
			Vector2(leg1 + cw + leg2, 0.0),
			Vector2(leg1 + cw * 0.35, 0.0),
			Vector2(leg1, cw * 0.35),
			Vector2(leg1, drop),
			Vector2(0.0, drop)
		]
		var max_y: float = drop + cw
		var map_y = func(y: float) -> float: return (max_y - y) if flip_y else y

		var outer_poly: Array = []
		for p: Vector2 in raw_pts:
			outer_poly.append(Vector2(p.x, map_y.call(p.y)))
		if flip_y:
			outer_poly.reverse()

		var start := Vector2(75.0, map_y.call(drop + cw * 0.5))
		var finish_x: float = leg1 + cw + leg2 - 36.0
		var finish := {
			"x1": finish_x,
			"y1": map_y.call(10.0),
			"x2": finish_x,
			"y2": map_y.call(cw - 10.0)
		}
		var diamonds: Array = [
			{ "x": leg1 + cw * 0.45, "y": map_y.call(drop + cw * 0.52) },
			{ "x": leg1 + cw * 0.55, "y": map_y.call(cw * 0.52) }
		]

		return {
			"name": "RICOCHET CANYON %d" % course_num,
			"theme": selected_theme,
			"outerPoly": outer_poly,
			"obstacles": [],
			"start": start,
			"finish": finish,
			"diamonds": diamonds
		}

	else:
		var w: float = 740.0 + float(rng.randi() % 90)
		var h: float = 440.0 + float(rng.randi() % 60)
		var ch: float = 85.0
		var outer_poly: Array = [
			Vector2(0.0, 0.0),
			Vector2(w - ch, 0.0),
			Vector2(w, ch),
			Vector2(w, h - ch),
			Vector2(w - ch, h),
			Vector2(0.0, h)
		]

		var wall_len: float = w * (0.56 + rng.randf() * 0.12)
		var mid_y: float = h * 0.5
		var wall_thick: float = 34.0
		var obstacles: Array = [
			[
				Vector2(0.0, mid_y - wall_thick),
				Vector2(wall_len, mid_y - wall_thick),
				Vector2(wall_len + 26.0, mid_y),
				Vector2(wall_len, mid_y + wall_thick),
				Vector2(0.0, mid_y + wall_thick)
			]
		]

		var start := Vector2(85.0, h * 0.76)
		var finish := {
			"x1": 42.0,
			"y1": 16.0,
			"x2": 42.0,
			"y2": mid_y - wall_thick - 14.0
		}
		var diamonds: Array = [
			{ "x": w - 88.0, "y": h * 0.72 },
			{ "x": w - 88.0, "y": h * 0.28 }
		]

		return {
			"name": "MOONLIT LOOP %d" % course_num,
			"theme": selected_theme,
			"outerPoly": outer_poly,
			"obstacles": obstacles,
			"start": start,
			"finish": finish,
			"diamonds": diamonds
		}
