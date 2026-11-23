@tool
class_name FinishLine
extends Node2D

## Glowing top-down checkered finish line with pulsing lantern posts.
## Marked @tool so it renders live in the Godot 2D editor.

@export_enum("Inherit", "Moonlit Forest", "Bihar Heritage", "Japan Sakura", "Himalayas Alpine") var theme: String = "Inherit":
	set(val):
		theme = val
		queue_redraw()

@export var point_a: Vector2 = Vector2(-75.0, 0.0):
	set(val):
		point_a = val
		queue_redraw()

@export var point_b: Vector2 = Vector2(75.0, 0.0):
	set(val):
		point_b = val
		queue_redraw()

@export var strip_thickness: float = 16.0:
	set(val):
		strip_thickness = val
		queue_redraw()

var time_elapsed: float = 0.0

func get_effective_theme() -> String:
	if theme != "Inherit":
		return theme
	var p := get_parent()
	while p:
		if "theme" in p:
			return p.theme
		p = p.get_parent()
	return "Moonlit Forest"

func _process(delta: float) -> void:
	time_elapsed += delta
	queue_redraw()

func get_global_segment() -> Dictionary:
	return {
		"p1": to_global(point_a),
		"p2": to_global(point_b),
		"length": point_a.distance_to(point_b)
	}

func _draw() -> void:
	var delta_vec: Vector2 = point_b - point_a
	var length: float = delta_vec.length()
	if length < 1.0:
		return

	var angle: float = delta_vec.angle()
	var pulse: float = 0.5 + 0.5 * sin(time_elapsed * 3.2) if not Engine.is_editor_hint() else 0.8

	var theme_colors := Palette.get_theme_colors(get_effective_theme())
	var f_light: Color = theme_colors.get("finish_light", Palette.FINISH_LIGHT)
	var f_dark: Color = theme_colors.get("finish_dark", Palette.FINISH_DARK)
	var c_bright: Color = theme_colors.get("contour_bright", Palette.CONTOUR_BRIGHT)

	draw_set_transform(point_a, angle, Vector2.ONE)

	# 1. Soft pulsing outer glow
	var glow_col := Color(c_bright.r, c_bright.g, c_bright.b, 0.18 + pulse * 0.12)
	draw_rect(Rect2(0, -strip_thickness * 1.4, length, strip_thickness * 2.8), glow_col)

	# 2. Checkered two-row strip
	var cell: float = 8.0
	var cols: int = maxi(2, int(length / cell))
	var actual_cell: float = length / float(cols)
	var half_thick: float = strip_thickness * 0.5

	for r in range(2):
		for c in range(cols):
			var is_light: bool = ((r + c) % 2 == 0)
			var col: Color = f_light if is_light else f_dark
			var rx: float = float(c) * actual_cell
			var ry: float = -half_thick + float(r) * half_thick
			draw_rect(Rect2(rx, ry, actual_cell + 0.5, half_thick + 0.5), col)

	# 3. Glowing border
	var border_col := Color(f_light.r, f_light.g, f_light.b, 0.55 + pulse * 0.3)
	draw_rect(Rect2(0, -half_thick, length, strip_thickness), border_col, false, 1.4)

	# 4. Glowing lantern end posts
	for px: float in [0.0, length]:
		draw_circle(Vector2(px, 0.0), 12.0 + pulse * 2.5, Color(0.98, 0.89, 0.4, 0.22 + pulse * 0.14))
		draw_circle(Vector2(px, 0.0), 4.5, Palette.BALL_BODY)
		draw_circle(Vector2(px, 0.0), 2.2, Palette.DIAMOND_CORE)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
