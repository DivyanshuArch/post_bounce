class_name Palette
extends RefCounted

## Color palette for Moonlit Ricochet with regional and cultural map themes.

# 1. Classic Moonlit Forest Palette
const WALL_VOID := Color("#212c26")
const WALL_RIDGE_MID := Color("#26342c")
const WALL_RIDGE_TOP := Color("#2b3a31")
const FLOOR_BASE := Color("#2c3931")
const FLOOR_FACET_A := Color("#314037")
const FLOOR_FACET_B := Color("#36473d")
const FLOOR_FACET_DARK := Color("#27342c")
const CONTOUR_LINE := Color("#7f9484")
const CONTOUR_BRIGHT := Color("#a2b8a8")
const CONTOUR_FLASH := Color("#e6f2e8")
const SHADOW := Color(0.047, 0.071, 0.059, 0.42)
const SHADOW_SOFT := Color(0.047, 0.071, 0.059, 0.24)
const PINE_DARK := Color("#1f2e25")
const PINE_MID := Color("#2a3d31")
const PINE_LIGHT := Color("#374e40")
const BIRCH_TRUNK := Color("#eae6de")
const BIRCH_STRIPE := Color("#222b25")
const BIRCH_DARK := Color("#4a6452")
const BIRCH_LIGHT := Color("#5b7864")
const FLOWER_WHITE := Color("#f0f4f1")
const FLOWER_YELLOW := Color("#e8d874")
const FLOWER_LAVENDER := Color("#b89ec9")
const GRASS_BLADE_1 := Color("#496152")
const GRASS_BLADE_2 := Color("#627c6b")
const DIAMOND_CORE := Color("#fae366")
const DIAMOND_HIGHLIGHT := Color("#fff8c7")
const BALL_BODY := Color("#f4f2ec")
const BALL_SHADE := Color("#d8d5cc")
const FINISH_LIGHT := Color("#eef3ef")
const FINISH_DARK := Color("#496152")
const FINISH_GLOW := Color("#c7e3cf")
const CLOUD_LINE := Color(0.925, 0.949, 0.941, 0.42)
const CLOUD_WISP := Color(0.769, 0.816, 0.804, 0.14)
const BIRD := Color("#2a3531")
const FIREFLY := Color("#cade80")

# 2. Regional Theme Schemes
static func get_theme_colors(theme_name: String) -> Dictionary:
	match theme_name:
		"Bihar Heritage":
			return {
				"wall_void": Color("#3d1d14"),
				"wall_ridge_mid": Color("#54281b"),
				"wall_ridge_top": Color("#6e3524"),
				"floor_base": Color("#934b35"),
				"facets": [Color("#a8563d"), Color("#b86248"), Color("#7a3b29"), Color("#c26c50"), Color("#cc785c")],
				"contour_line": Color("#f59e0b"),
				"contour_bright": Color("#fbbf24"),
				"contour_flash": Color("#fffbeb"),
				"flowers": [Color("#fbbf24"), Color("#f97316"), Color("#ef4444"), Color("#ffd166"), Color("#ffffff")],
				"grass": [Color("#84a958"), Color("#a3c76d")],
				"finish_light": Color("#fef3c7"),
				"finish_dark": Color("#c2410c"),
				"vignette": Color(0.18, 0.08, 0.05, 0.32)
			}
		"Japan Sakura":
			return {
				"wall_void": Color("#272438"),
				"wall_ridge_mid": Color("#38344e"),
				"wall_ridge_top": Color("#474263"),
				"floor_base": Color("#544c6c"),
				"facets": [Color("#665c82"), Color("#736994"), Color("#463e5c"), Color("#8277a3"), Color("#9186b5")],
				"contour_line": Color("#fb7185"),
				"contour_bright": Color("#f43f5e"),
				"contour_flash": Color("#fff1f2"),
				"flowers": [Color("#f472b6"), Color("#fb7185"), Color("#ffffff"), Color("#fbcfe8"), Color("#fda4af")],
				"grass": [Color("#4ade80"), Color("#22c55e")],
				"finish_light": Color("#ffffff"),
				"finish_dark": Color("#e11d48"),
				"vignette": Color(0.1, 0.07, 0.14, 0.3)
			}
		"Himalayas Alpine":
			return {
				"wall_void": Color("#0f172a"),
				"wall_ridge_mid": Color("#1a263e"),
				"wall_ridge_top": Color("#243350"),
				"floor_base": Color("#1e293b"),
				"facets": [Color("#334155"), Color("#475569"), Color("#cbd5e1"), Color("#2d3b4e")],
				"contour_line": Color("#38bdf8"),
				"contour_bright": Color("#7dd3fc"),
				"contour_flash": Color("#f0f9ff"),
				"flowers": [Color("#ec4899"), Color("#38bdf8"), Color("#e2e8f0"), Color("#fbcfe8")],
				"grass": [Color("#334e68"), Color("#486581")],
				"finish_light": Color("#f8fafc"),
				"finish_dark": Color("#0284c7"),
				"vignette": Color(0.04, 0.07, 0.14, 0.45)
			}
		_:
			# Default Moonlit Forest
			return {
				"wall_void": WALL_VOID,
				"wall_ridge_mid": WALL_RIDGE_MID,
				"wall_ridge_top": WALL_RIDGE_TOP,
				"floor_base": FLOOR_BASE,
				"facets": [FLOOR_FACET_A, FLOOR_FACET_B, FLOOR_FACET_DARK],
				"contour_line": CONTOUR_LINE,
				"contour_bright": CONTOUR_BRIGHT,
				"contour_flash": CONTOUR_FLASH,
				"flowers": [FLOWER_WHITE, FLOWER_YELLOW, FLOWER_LAVENDER],
				"grass": [GRASS_BLADE_1, GRASS_BLADE_2],
				"finish_light": FINISH_LIGHT,
				"finish_dark": FINISH_DARK,
				"vignette": Color(0.047, 0.071, 0.059, 0.44)
			}
