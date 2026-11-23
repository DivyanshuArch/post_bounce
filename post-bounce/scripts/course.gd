class_name Course
extends Node2D

## Course node containing floor facets, flora, boundary walls, obstacles,
## start marker, finish line, diamonds, and ledge trees.

@export var course_name: String = "MOONLIT BEND"
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
		queue_redraw()

@export var start_position: Vector2 = Vector2(190.0, 320.0)

var bounds: Rect2 = Rect2(100.0, 90.0, 660.0, 310.0)
var bounds_center: Vector2 = Vector2(430.0, 245.0)

var outer_segments: Array[Dictionary] = []
var outer_flashes: Array[float] = []

var floor_facets: Array[Dictionary] = []
var grass_tufts: Array[Dictionary] = []
var flowers: Array[Dictionary] = []
var ridge_decor: Array[Dictionary] = []

var obstacles: Array[WallObstacle] = []
var diamonds: Array[Diamond] = []
var finish_line: FinishLine = null
var trees: Array[Node2D] = []

var time_elapsed: float = 0.0

@onready var obstacles_container: Node2D = $Obstacles
@onready var diamonds_container: Node2D = $Diamonds
@onready var trees_container: Node2D = $Trees
@onready var finish_line_node: FinishLine = $FinishLine

const PREFAB_PINE = preload("res://scenes/prefabs/tree_pine.tscn")
const PREFAB_BIRCH = preload("res://scenes/prefabs/tree_birch.tscn")
const PREFAB_OBSTACLE = preload("res://scenes/prefabs/wall_obstacle.tscn")
const PREFAB_DIAMOND = preload("res://scenes/prefabs/diamond.tscn")
const PREFAB_FINISH = preload("res://scenes/prefabs/finish_line.tscn")

func _ready() -> void:
	if not outer_poly.is_empty():
		_compute_bounds()
		_build_outer_segments()

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
	outer_poly = PackedVector2Array(def["outerPoly"])
	start_position = def["start"]
	_compute_bounds()
	_build_outer_segments()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# Clear previous instances
	for child in obstacles_container.get_children():
		child.queue_free()
	for child in diamonds_container.get_children():
		child.queue_free()
	for child in trees_container.get_children():
		child.queue_free()

	obstacles.clear()
	diamonds.clear()
	trees.clear()

	# Create Obstacles
	if def.has("obstacles"):
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
	if def.has("diamonds"):
		for d in def["diamonds"]:
			var dm: Diamond = PREFAB_DIAMOND.instantiate()
			dm.position = Vector2(d["x"], d["y"])
			dm.phase_offset = rng.randf() * TAU
			diamonds_container.add_child(dm)
			diamonds.append(dm)

	# Generate low-poly floor facets
	floor_facets.clear()
	var facet_colors: Array[Color] = [Palette.FLOOR_FACET_A, Palette.FLOOR_FACET_B, Palette.FLOOR_FACET_DARK]
	for i in range(16):
		var fx: float = bounds.position.x + rng.randf() * bounds.size.x
		var fy: float = bounds.position.y + rng.randf() * bounds.size.y
		floor_facets.append({
			"pos": Vector2(fx, fy),
			"pts": GeometryUtils.make_jagged_polygon(rng, 5 + rng.randi() % 3, 75.0 + rng.randf() * 110.0, 65.0 + rng.randf() * 95.0, 0.25, rng.randf() * PI),
			"color": facet_colors[rng.randi() % facet_colors.size()]
		})

	# Generate edge grass tufts and wildflowers
	grass_tufts.clear()
	flowers.clear()
	var flower_colors: Array[Color] = [Palette.FLOWER_WHITE, Palette.FLOWER_YELLOW, Palette.FLOWER_LAVENDER]

	for i in range(160):
		var px: float = bounds.position.x + rng.randf() * bounds.size.x
		var py: float = bounds.position.y + rng.randf() * bounds.size.y
		var p := Vector2(px, py)
		if not GeometryUtils.point_in_polygon(p, outer_poly):
			continue

		var inside_obs: bool = false
		for obs in obstacles:
			if GeometryUtils.point_in_polygon(p, obs.polygon):
				inside_obs = true
				break
		if inside_obs:
			continue

		var edge_dist: float = GeometryUtils.dist_to_polygon_edges(p, outer_poly)
		for obs in obstacles:
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
					"color": Palette.GRASS_BLADE_1 if rng.randf() > 0.5 else Palette.GRASS_BLADE_2,
					"phase": rng.randf() * TAU
				})
			else:
				flowers.append({
					"pos": p,
					"size": 3.0 if rng.randf() > 0.6 else 2.0,
					"color": flower_colors[rng.randi() % flower_colors.size()]
				})

	# Generate background ridge decor facets
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
			"color": Palette.WALL_RIDGE_MID if rng.randf() > 0.5 else Palette.WALL_RIDGE_TOP
		})

	# Generate top-down pine & birch trees
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

	# Place tree on large obstacles
	for obs in obstacles:
		var c := Vector2.ZERO
		for p: Vector2 in obs.polygon:
			c += p
		c /= float(obs.polygon.size())
		var clearance: float = GeometryUtils.dist_to_polygon_edges(c, obs.polygon)
		if GeometryUtils.point_in_polygon(c, obs.polygon) and clearance > 26.0:
			var tree_inst: Node2D = PREFAB_PINE.instantiate()
			tree_inst.position = obs.to_global(c)
			tree_inst.set("tree_scale", clampf(clearance / 44.0, 0.58, 0.88))
			trees_container.add_child(tree_inst)
			trees.append(tree_inst)

	queue_redraw()

func get_all_segments() -> Array:
	var list: Array = []
	for i in range(outer_segments.size()):
		var seg = outer_segments[i]
		list.append({
			"a": seg["a"],
			"b": seg["b"],
			"flash": outer_flashes[i],
			"is_outer": true,
			"outer_idx": i,
			"course": self
		})
	for obs in obstacles:
		if is_instance_valid(obs):
			list.append_array(obs.get_global_segments())
	return list

func trigger_segment_flash(seg: Dictionary) -> void:
	if seg.has("is_outer") and seg["is_outer"]:
		var idx: int = seg["outer_idx"]
		if idx >= 0 and idx < outer_flashes.size():
			outer_flashes[idx] = 1.0
			queue_redraw()
	elif seg.has("obstacle") and is_instance_valid(seg["obstacle"]):
		seg["obstacle"].trigger_flash(seg["seg_idx"])

func _process(delta: float) -> void:
	time_elapsed += delta
	var needs_redraw: bool = false
	for i in range(outer_flashes.size()):
		if outer_flashes[i] > 0.0:
			outer_flashes[i] = maxf(0.0, outer_flashes[i] - delta * 3.8)
			needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	# 1. Background ridge decor facets
	for rd in ridge_decor:
		var pts: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in rd["pts"]:
			pts.append(p + rd["pos"])
		if pts.size() >= 3:
			draw_colored_polygon(pts, rd["color"])

	# 2. Corridor floor
	if not outer_poly.is_empty() and outer_poly.size() >= 3:
		draw_colored_polygon(outer_poly, Palette.FLOOR_BASE)

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
			var sway: float = sin(time_elapsed * 1.8 + g["phase"]) * 1.1
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
			var col: Color = Palette.CONTOUR_FLASH if f_val > 0.02 else Palette.CONTOUR_LINE
			var width: float = 2.4 + f_val * 1.8 if f_val > 0.02 else 2.2
			draw_line(a, b, col, width, true)
