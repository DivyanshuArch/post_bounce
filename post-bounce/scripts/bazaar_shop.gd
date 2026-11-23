@tool
class_name BazaarShop
extends Node2D

## Colorful Indian bazaar shop stall with striped awning, wooden counter,
## hanging clay diyas/lanterns, and collision segments for ricochet bounces.
## Marked @tool for real-time preview in the Godot 2D editor.

@export var shop_size: Vector2 = Vector2(90.0, 56.0):
	set(val):
		shop_size = val
		_rebuild_polygon()
		queue_redraw()

@export var canopy_color_1: Color = Color("#f4a261"): # Saffron / Marigold Orange
	set(val):
		canopy_color_1 = val
		queue_redraw()

@export var canopy_color_2: Color = Color("#e76f51"): # Crimson / Terracotta Red
	set(val):
		canopy_color_2 = val
		queue_redraw()

@export var is_solid: bool = true:
	set(val):
		is_solid = val
		queue_redraw()

var polygon: PackedVector2Array = PackedVector2Array()
var segment_flashes: Array[float] = []
var time_elapsed: float = 0.0

func _ready() -> void:
	_rebuild_polygon()
	queue_redraw()

func _rebuild_polygon() -> void:
	var hw: float = shop_size.x * 0.5
	var hh: float = shop_size.y * 0.5
	polygon = [
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh)
	]
	segment_flashes.resize(4)
	segment_flashes.fill(0.0)

func get_global_segments() -> Array:
	if not is_solid or polygon.size() < 3:
		return []
	var res: Array = []
	var count: int = polygon.size()
	for i in range(count):
		res.append({
			"a": to_global(polygon[i]),
			"b": to_global(polygon[(i + 1) % count]),
			"flash": 0.0,
			"obstacle": self,
			"seg_idx": i
		})
	return res

func trigger_flash(seg_idx: int) -> void:
	if seg_idx >= 0 and seg_idx < segment_flashes.size():
		segment_flashes[seg_idx] = 1.0
		queue_redraw()

func _process(delta: float) -> void:
	time_elapsed += delta
	var needs_redraw: bool = false
	for i in range(segment_flashes.size()):
		if segment_flashes[i] > 0.0:
			segment_flashes[i] = maxf(0.0, segment_flashes[i] - delta * 3.8)
			needs_redraw = true
	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	if polygon.size() < 4:
		_rebuild_polygon()

	var hw: float = shop_size.x * 0.5
	var hh: float = shop_size.y * 0.5

	# 1. Soft ground drop shadow
	var shadow_rect := Rect2(-hw + 6.0, -hh + 8.0, shop_size.x, shop_size.y)
	draw_rect(shadow_rect, Palette.SHADOW)

	# 2. Wooden floor base & counter
	draw_rect(Rect2(-hw, -hh, shop_size.x, shop_size.y), Color("#3e2723")) # Dark teak/rosewood

	# 3. Striped fabric canopy (awning)
	var stripes: int = 7
	var stripe_w: float = shop_size.x / float(stripes)
	var awning_h: float = shop_size.y * 0.72

	for i in range(stripes):
		var sx: float = -hw + float(i) * stripe_w
		var col: Color = canopy_color_1 if (i % 2 == 0) else canopy_color_2
		draw_rect(Rect2(sx, -hh, stripe_w + 0.5, awning_h), col)

		# Scallop border on awning edge
		var scallop_center := Vector2(sx + stripe_w * 0.5, -hh + awning_h)
		draw_circle(scallop_center, stripe_w * 0.5, col)

	# 4. Front display counter (terracotta pots, brass jars, marigolds)
	var counter_rect := Rect2(-hw + 4.0, -hh + awning_h + 2.0, shop_size.x - 8.0, shop_size.y - awning_h - 4.0)
	draw_rect(counter_rect, Color("#5d4037"))

	# Spices / clay pots on counter
	var pot_count: int = 4
	for p in range(pot_count):
		var px: float = -hw + 14.0 + float(p) * ((shop_size.x - 28.0) / float(maxi(1, pot_count - 1)))
		var py: float = -hh + awning_h + 8.0
		var pot_col: Color = [Color("#d97706"), Color("#b45309"), Color("#e63946"), Color("#ffd166")][p % 4]
		draw_circle(Vector2(px, py), 4.0, pot_col)
		draw_circle(Vector2(px, py), 2.0, Color("#fff3b0"))

	# 5. Glowing clay diyas / lanterns at front corners
	var flicker: float = 0.8 + 0.2 * sin(time_elapsed * 7.0) if not Engine.is_editor_hint() else 0.95
	for cx: float in [-hw + 2.0, hw - 2.0]:
		var lamp_pos := Vector2(cx, hh - 2.0)
		draw_circle(lamp_pos, 9.0 * flicker, Color(1.0, 0.75, 0.2, 0.25))
		draw_circle(lamp_pos, 3.5, Color("#d97706")) # Clay diya
		draw_circle(lamp_pos, 1.8 * flicker, Color("#fff8c7")) # Flame

	# 6. Obstacle contour outline (with hit flash)
	for i in range(4):
		var a: Vector2 = polygon[i]
		var b: Vector2 = polygon[(i + 1) % 4]
		var f_val: float = segment_flashes[i] if i < segment_flashes.size() else 0.0
		var col: Color = Palette.CONTOUR_FLASH if f_val > 0.02 else Color("#ffb703")
		var width: float = 2.4 + f_val * 1.8 if f_val > 0.02 else 1.8
		draw_line(a, b, col, width, true)
