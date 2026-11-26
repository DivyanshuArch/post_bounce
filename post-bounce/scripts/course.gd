@tool
class_name Course
extends Node2D

## Course node containing floor facets, flora, boundary walls, obstacles,
## start marker, finish line, diamonds, and ledge trees.
## Marked @tool so that levels and level_template render with FULL visual preview
## in the Godot 2D editor!

@export_enum("Moonlit Forest", "Bihar Heritage", "Japan Sakura", "Himalayas Alpine") var theme: String = "Moonlit Forest":
	set(val):
		theme = val
		if Engine.is_editor_hint():
			var seed_int: int = int(abs(hash(course_name))) & 0x7FFFFFFF
			generate_decorations(seed_int if seed_int != 0 else 12345)
			queue_redraw()

@export var course_name: String = "MOONLIT BEND":
	set(val):
		course_name = val
		if Engine.is_editor_hint():
			var seed_int: int = int(abs(hash(course_name))) & 0x7FFFFFFF
			generate_decorations(seed_int if seed_int != 0 else 12345)
			queue_redraw()

@export var par: int = 2


@export var boundary_path: Path2D:
	set(val):
		if boundary_path and is_instance_valid(boundary_path) and boundary_path.curve:
			if boundary_path.curve.changed.is_connected(_on_boundary_curve_changed):
				boundary_path.curve.changed.disconnect(_on_boundary_curve_changed)
		boundary_path = val
		_connect_boundary_path()
		_update_from_boundary_path()

@export var outer_poly: PackedVector2Array = [
	Vector2(100.0, 400.0),
	Vector2(640.0, 400.0),
	Vector2(760.0, 280.0),
	Vector2(760.0, 90.0),
	Vector2(560.0, 90.0),
	Vector2(560.0, 240.0),
	Vector2(100.0, 240.0)
]:
	set(val):
		outer_poly = val
		_compute_bounds()
		_build_outer_segments()
		if Engine.is_editor_hint():
			var seed_int: int = int(abs(hash(course_name))) & 0x7FFFFFFF
			generate_decorations(seed_int if seed_int != 0 else 12345)
		queue_redraw()

@export var start_position: Vector2 = Vector2(190.0, 320.0):
	set(val):
		start_position = val
		queue_redraw()

var bounds: Rect2 = Rect2(100.0, 90.0, 660.0, 310.0)
var bounds_center: Vector2 = Vector2(430.0, 245.0)

var outer_segments: Array[Dictionary] = []
var outer_flashes: Array[float] = []

var floor_facets: Array[Dictionary] = []
var grass_tufts: Array[Dictionary] = []
var flowers: Array[Dictionary] = []
var ridge_decor: Array[Dictionary] = []

var obstacles: Array[Node2D] = []
var diamonds: Array[Diamond] = []
var finish_line: FinishLine = null
var trees: Array[Node2D] = []

var time_elapsed: float = 0.0

@onready var obstacles_container: Node2D = $Obstacles if has_node("Obstacles") else null
@onready var diamonds_container: Node2D = $Diamonds if has_node("Diamonds") else null
@onready var trees_container: Node2D = $Trees if has_node("Trees") else null
@onready var finish_line_node: FinishLine = $FinishLine if has_node("FinishLine") else null

const PREFAB_PINE = preload("res://scenes/prefabs/tree_pine.tscn")
const PREFAB_BIRCH = preload("res://scenes/prefabs/tree_birch.tscn")
const PREFAB_OBSTACLE = preload("res://scenes/prefabs/wall_obstacle.tscn")
const PREFAB_DIAMOND = preload("res://scenes/prefabs/diamond.tscn")
const PREFAB_FINISH = preload("res://scenes/prefabs/finish_line.tscn")

func _ready() -> void:
	# 1. Read in-editor placed children if present
	if has_node("StartPoint"):
		var sp = get_node("StartPoint")
		if sp is Node2D:
			start_position = sp.position

	if has_node("FinishLine"):
		var fl = get_node("FinishLine")
		if fl is FinishLine:
			finish_line = fl

	if has_node("Obstacles"):
		obstacles.clear()
		for child in $Obstacles.get_children():
			if child.has_method("get_global_segments"):
				obstacles.append(child)

	if has_node("Diamonds"):
		diamonds.clear()
		for child in $Diamonds.get_children():
			if child is Diamond:
				diamonds.append(child)

	if has_node("Trees"):
		trees.clear()
		for child in $Trees.get_children():
			if child is Node2D:
				trees.append(child)

	# 0. Connect Path2D boundary if present
	_connect_boundary_path()
	if is_instance_valid(boundary_path) and boundary_path.curve and boundary_path.curve.point_count >= 3:
		_update_from_boundary_path()

	# 2. Build geometry & preview
	if not outer_poly.is_empty():
		_compute_bounds()
		_build_outer_segments()
		if floor_facets.is_empty():
			var seed_int: int = int(abs(hash(course_name))) & 0x7FFFFFFF
			generate_decorations(seed_int if seed_int != 0 else 12345)

	queue_redraw()

func _connect_boundary_path() -> void:
	if not is_instance_valid(boundary_path):
		if has_node("Boundary"):
			var b = get_node("Boundary")
			if b is Path2D:
				boundary_path = b
		elif has_node("Path2D"):
			var b = get_node("Path2D")
			if b is Path2D:
				boundary_path = b

	if is_instance_valid(boundary_path) and boundary_path.curve:
		if not boundary_path.curve.changed.is_connected(_on_boundary_curve_changed):
			boundary_path.curve.changed.connect(_on_boundary_curve_changed)

func _on_boundary_curve_changed() -> void:
	_update_from_boundary_path()

func _update_from_boundary_path() -> void:
	if not is_instance_valid(boundary_path) or not boundary_path.curve:
		return
	var curve: Curve2D = boundary_path.curve
	if curve.point_count < 3:
		return

	var pts: PackedVector2Array = PackedVector2Array()
	var has_beziers: bool = false
	for i in range(curve.point_count):
		if curve.get_point_in(i) != Vector2.ZERO or curve.get_point_out(i) != Vector2.ZERO:
			has_beziers = true
			break

	if has_beziers:
		pts = curve.get_baked_points()
	else:
		for i in range(curve.point_count):
			pts.append(curve.get_point_position(i))

	# If closed loop or duplicate end point, sanitize
	if pts.size() >= 4 and pts[0].distance_to(pts[pts.size() - 1]) < 8.0:
		pts.remove_at(pts.size() - 1)

	var offset: Vector2 = boundary_path.position
	if offset != Vector2.ZERO:
		var shifted := PackedVector2Array()
		for p in pts:
			shifted.append(p + offset)
		pts = shifted

	outer_poly = pts

func _compute_bounds() -> void:
	if outer_poly.is_empty():
		return
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for p: Vector2 in outer_poly:
		min_p.x = minf(min_p.x, p.x)
		min_p.y = minf(min_p.y, p.y)
		max_p.x = maxf(max_p.x, p.x)
		max_p.y = maxf(max_p.y, p.y)

	bounds = Rect2(min_p, max_p - min_p)
	bounds_center = min_p + (max_p - min_p) * 0.5

func _build_outer_segments() -> void:
	outer_segments.clear()
	outer_flashes.clear()
	var count: int = outer_poly.size()
	for i in range(count):
		outer_segments.append({
			"a": outer_poly[i],
			"b": outer_poly[(i + 1) % count],
			"flash": 0.0,
			"is_outer": true,
			"idx": i
		})
		outer_flashes.append(0.0)

func setup_from_def(def: Dictionary, seed_val: int) -> void:
	course_name = def["name"]
	if def.has("theme"):
		theme = def["theme"]
	if def.has("par"):
		par = int(def["par"])
	else:
		par = 2 + (1 if def.get("diamonds", []).size() >= 2 else 0)
	outer_poly = PackedVector2Array(def["outerPoly"])
	start_position = def["start"]
	_compute_bounds()
	_build_outer_segments()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Clear previous instances
	if is_instance_valid(obstacles_container):
		for child in obstacles_container.get_children():
			child.queue_free()
	if is_instance_valid(diamonds_container):
		for child in diamonds_container.get_children():
			child.queue_free()
	if is_instance_valid(trees_container):
		for child in trees_container.get_children():
			child.queue_free()

	obstacles.clear()
	diamonds.clear()
	trees.clear()

	# Create Obstacles
	if def.has("obstacles") and is_instance_valid(obstacles_container):
		for obs_pts in def["obstacles"]:
			var obs: WallObstacle = PREFAB_OBSTACLE.instantiate()
			obs.polygon = PackedVector2Array(obs_pts)
			obstacles_container.add_child(obs)
			obstacles.append(obs)

	# Setup Finish Line
	if def.has("finish"):
		var f: Dictionary = def["finish"]
		if is_instance_valid(finish_line_node):
			finish_line_node.point_a = Vector2(f["x1"], f["y1"])
			finish_line_node.point_b = Vector2(f["x2"], f["y2"])
			finish_line = finish_line_node

	# Create Diamonds
	if def.has("diamonds") and is_instance_valid(diamonds_container):
		for d in def["diamonds"]:
			var dm: Diamond = PREFAB_DIAMOND.instantiate()
			dm.position = Vector2(d["x"], d["y"])
			dm.phase_offset = rng.randf() * TAU
			diamonds_container.add_child(dm)
			diamonds.append(dm)

	generate_decorations(seed_val)

## Generates atmospheric floor facets, edge grass blades, wildflowers,
## background ridge facets, and edge ledge trees based on corridor bounds.
func generate_decorations(seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	var theme_colors := Palette.get_theme_colors(theme)
	var facet_colors: Array = theme_colors.get("facets", [Palette.FLOOR_FACET_A, Palette.FLOOR_FACET_B, Palette.FLOOR_FACET_DARK])
	var flower_colors: Array = theme_colors.get("flowers", [Palette.FLOWER_WHITE, Palette.FLOWER_YELLOW, Palette.FLOWER_LAVENDER])
	var grass_colors: Array = theme_colors.get("grass", [Palette.GRASS_BLADE_1, Palette.GRASS_BLADE_2])
	var ridge_mid: Color = theme_colors.get("wall_ridge_mid", Palette.WALL_RIDGE_MID)
	var ridge_top: Color = theme_colors.get("wall_ridge_top", Palette.WALL_RIDGE_TOP)

	# 1. Low-poly floor facets
	floor_facets.clear()
	for i in range(16):
		var fx: float = bounds.position.x + rng.randf() * bounds.size.x
		var fy: float = bounds.position.y + rng.randf() * bounds.size.y
		floor_facets.append({
			"pos": Vector2(fx, fy),
			"pts": GeometryUtils.make_jagged_polygon(rng, 5 + rng.randi() % 3, 75.0 + rng.randf() * 110.0, 65.0 + rng.randf() * 95.0, 0.25, rng.randf() * PI),
			"color": facet_colors[rng.randi() % facet_colors.size()]
		})

	# 2. Edge flora
	grass_tufts.clear()
	flowers.clear()

	for i in range(160):
		var px: float = bounds.position.x + rng.randf() * bounds.size.x
		var py: float = bounds.position.y + rng.randf() * bounds.size.y
		var p := Vector2(px, py)
		if not GeometryUtils.point_in_polygon(p, outer_poly):
			continue

		var inside_obs: bool = false
		for obs in obstacles:
			if is_instance_valid(obs) and "polygon" in obs and GeometryUtils.point_in_polygon(p, obs.polygon):
				inside_obs = true
				break
		if inside_obs:
			continue

		var edge_dist: float = GeometryUtils.dist_to_polygon_edges(p, outer_poly)
		for obs in obstacles:
			if is_instance_valid(obs) and "polygon" in obs:
				var od: float = GeometryUtils.dist_to_polygon_edges(p, obs.polygon)
				if od < edge_dist:
					edge_dist = od

		if edge_dist < 34.0 and edge_dist > 4.0:
			if rng.randf() < 0.65:
				var blades: Array[Dictionary] = []
				var cnt: int = 2 + rng.randi() % 3
				for b in range(cnt):
					blades.append({
						"dx": (rng.randf() - 0.5) * 6.0,
						"h": 4.0 + rng.randf() * 4.5,
						"lean": (rng.randf() - 0.5) * 4.0
					})
				grass_tufts.append({
					"pos": p,
					"blades": blades,
					"color": grass_colors[rng.randi() % grass_colors.size()],
					"phase": rng.randf() * TAU
				})
			else:
				flowers.append({
					"pos": p,
					"size": 3.0 if rng.randf() > 0.6 else 2.0,
					"color": flower_colors[rng.randi() % flower_colors.size()]
				})

	# 3. Background ridge decor facets
	ridge_decor.clear()
	for i in range(22):
		var rx: float = bounds.position.x - 360.0 + rng.randf() * (bounds.size.x + 720.0)
		var ry: float = bounds.position.y - 320.0 + rng.randf() * (bounds.size.y + 640.0)
		var rp := Vector2(rx, ry)
		if GeometryUtils.point_in_polygon(rp, outer_poly) and GeometryUtils.dist_to_polygon_edges(rp, outer_poly) > 40.0:
			continue
		ridge_decor.append({
			"pos": rp,
			"pts": GeometryUtils.make_jagged_polygon(rng, 6 + rng.randi() % 3, 90.0 + rng.randf() * 120.0, 70.0 + rng.randf() * 100.0, 0.28, rng.randf() * PI),
			"color": ridge_mid if rng.randf() > 0.5 else ridge_top
		})

	# 4. Generate trees if container has none placed and not in editor
	if is_instance_valid(trees_container) and trees.is_empty() and not Engine.is_editor_hint():
		for tries in range(420):
			if trees.size() >= 48:
				break
			var tx: float = bounds.position.x - 280.0 + rng.randf() * (bounds.size.x + 560.0)
			var ty: float = bounds.position.y - 240.0 + rng.randf() * (bounds.size.y + 480.0)
			var tp := Vector2(tx, ty)
			if GeometryUtils.point_in_polygon(tp, outer_poly):
				continue
			var d_edge: float = GeometryUtils.dist_to_polygon_edges(tp, outer_poly)
			if d_edge < 32.0 or d_edge > 270.0:
				continue

			var too_close: bool = false
			for t_node in trees:
				if tp.distance_to(t_node.position) < 52.0:
					too_close = true
					break
			if too_close:
				continue

			var scale_val: float = 0.78 + rng.randf() * 0.45
			var is_birch: bool = (rng.randf() < 0.34)
			var tree_inst: Node2D = (PREFAB_BIRCH if is_birch else PREFAB_PINE).instantiate()
			tree_inst.position = tp
			tree_inst.set("tree_scale", scale_val)
			tree_inst.set("seed_val", rng.randi() & 0x7FFFFFFF)
			trees_container.add_child(tree_inst)
			trees.append(tree_inst)

	queue_redraw()

func get_all_segments() -> Array:
	var list: Array = []
	for i in range(outer_segments.size()):
		var seg = outer_segments[i]
		list.append({
			"a": to_global(seg["a"]),
			"b": to_global(seg["b"]),
			"flash": outer_flashes[i],
			"is_outer": true,
			"outer_idx": i,
			"course": self
		})
	for obs in obstacles:
		if is_instance_valid(obs) and obs.has_method("get_global_segments"):
			list.append_array(obs.get_global_segments())
	return list

func trigger_segment_flash(seg: Dictionary) -> void:
	if seg.has("is_outer") and seg["is_outer"]:
		var idx: int = seg["outer_idx"]
		if idx >= 0 and idx < outer_flashes.size():
			outer_flashes[idx] = 1.0
			queue_redraw()
	elif seg.has("obstacle") and is_instance_valid(seg["obstacle"]) and seg["obstacle"].has_method("trigger_flash"):
		seg["obstacle"].trigger_flash(seg["seg_idx"])

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_connect_boundary_path()
		if has_node("StartPoint"):
			var sp = get_node("StartPoint")
			if sp is Node2D and sp.position != start_position:
				start_position = sp.position
				queue_redraw()
		return

	time_elapsed += delta
	var needs_redraw: bool = false
	for i in range(outer_flashes.size()):
		if outer_flashes[i] > 0.0:
			outer_flashes[i] = maxf(0.0, outer_flashes[i] - delta * 3.8)
			needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var theme_colors := Palette.get_theme_colors(theme)
	var floor_col: Color = theme_colors.get("floor_base", Palette.FLOOR_BASE)
	var line_col: Color = theme_colors.get("contour_line", Palette.CONTOUR_LINE)
	var flash_col: Color = theme_colors.get("contour_flash", Palette.CONTOUR_FLASH)

	# 1. Background ridge decor facets
	for rd in ridge_decor:
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in rd["pts"]:
			pts.append(p + rd["pos"])
		if pts.size() >= 3:
			draw_colored_polygon(pts, rd["color"])

	# 2. Corridor floor
	if not outer_poly.is_empty() and outer_poly.size() >= 3:
		draw_colored_polygon(outer_poly, floor_col)

		# Ground low-poly facets
		for facet in floor_facets:
			var f_pts: PackedVector2Array = PackedVector2Array()
			for p: Vector2 in facet["pts"]:
				f_pts.append(p + facet["pos"])
			# Intersect with outer polygon
			var clipped = Geometry2D.intersect_polygons(outer_poly, f_pts)
			for clip_poly in clipped:
				if clip_poly.size() >= 3:
					draw_colored_polygon(clip_poly, facet["color"])

		# Inner cliff shadow
		var shadow_poly: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in outer_poly:
			shadow_poly.append(p + Vector2(4.0, 5.0))
		var loop_shadow := shadow_poly.duplicate()
		loop_shadow.append(shadow_poly[0])
		draw_polyline(loop_shadow, Palette.SHADOW_SOFT, 14.0, true)

		# Edge flora: grass tufts & flowers
		for g in grass_tufts:
			var sway: float = sin(time_elapsed * 1.8 + g["phase"]) * 1.1 if not Engine.is_editor_hint() else 0.0
			for bl in g["blades"]:
				var p1: Vector2 = g["pos"] + Vector2(bl["dx"], 0.0)
				var p2: Vector2 = p1 + Vector2(bl["lean"] + sway, -bl["h"])
				draw_line(p1, p2, g["color"], 1.25, true)

		for fl in flowers:
			var s: float = fl["size"]
			draw_rect(Rect2(fl["pos"].x, fl["pos"].y, s, s), fl["color"])

		# Outer corridor boundary contour line (with hit flash)
		var count: int = outer_poly.size()
		for i in range(count):
			var a: Vector2 = outer_poly[i]
			var b: Vector2 = outer_poly[(i + 1) % count]
			var f_val: float = outer_flashes[i] if i < outer_flashes.size() else 0.0
			var col: Color = flash_col if f_val > 0.02 else line_col
			var width: float = 2.4 + f_val * 1.8 if f_val > 0.02 else 2.2
			draw_line(a, b, col, width, true)

	# 3. In-Editor Ball Spawn Preview
	if Engine.is_editor_hint():
		draw_circle(start_position + Vector2(2, 3), 11.0, Palette.SHADOW)
		draw_circle(start_position, 11.0, Palette.BALL_BODY)
		draw_circle(start_position - Vector2(3, 3), 3.0, Color.WHITE)
		draw_arc(start_position, 16.0, 0.0, TAU, 32, Color(0.98, 0.89, 0.4, 0.75), 1.5, true)
