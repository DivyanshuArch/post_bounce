class_name SkinManager
extends RefCounted

## SkinManager manages the catalogue of ball skins, color palettes,
## trail configurations, and visual decoration motifs for Moonlit Ricochet.

const SKINS: Array[Dictionary] = [
	{
		"id": "moonlit_pearl",
		"name": "Moonlit Pearl",
		"rarity": "Common",
		"cost": 0,
		"desc": "Classic luminescent ivory sphere with soft lunar aura and silver stardust trail.",
		"core_color": Color("#f4f2ec"),
		"shade_color": Color("#9e9c96"),
		"halo_color": Color(0.96, 0.95, 0.92, 0.28),
		"seam_color": Color(1.0, 1.0, 1.0, 0.55),
		"dot_color": Color(0.65, 0.64, 0.62, 0.75),
		"trail_color": Color(0.96, 0.95, 0.92, 0.65),
		"trail_width_scale": 1.0,
		"motif": "lunar"
	},
	{
		"id": "solar_flare",
		"name": "Solar Flare",
		"rarity": "Rare",
		"cost": 40,
		"desc": "Blazing amber sunburst with radiating solar corona and burning meteor trail.",
		"core_color": Color("#f97316"),
		"shade_color": Color("#9a3412"),
		"halo_color": Color(1.0, 0.5, 0.1, 0.38),
		"seam_color": Color("#fdba74"),
		"dot_color": Color("#c2410c"),
		"trail_color": Color("#fb923c"),
		"trail_width_scale": 1.25,
		"motif": "solar"
	},
	{
		"id": "sakura_bloom",
		"name": "Sakura Bloom",
		"rarity": "Rare",
		"cost": 60,
		"desc": "Delicate cherry blossom petal sphere with soft floral aura and drifting pink trail.",
		"core_color": Color("#f472b6"),
		"shade_color": Color("#9d174d"),
		"halo_color": Color(0.96, 0.45, 0.72, 0.35),
		"seam_color": Color("#fbcfe8"),
		"dot_color": Color("#db2777"),
		"trail_color": Color("#f472b6"),
		"trail_width_scale": 1.1,
		"motif": "sakura"
	},
	{
		"id": "cyber_neon",
		"name": "Cyber Neon",
		"rarity": "Epic",
		"cost": 80,
		"desc": "Synthwave cyber sphere with pulsing cyan grid, magenta core, and electric laser trail.",
		"core_color": Color("#06b6d4"),
		"shade_color": Color("#0e7490"),
		"halo_color": Color(0.02, 0.71, 0.83, 0.42),
		"seam_color": Color("#f43f5e"),
		"dot_color": Color("#e11d48"),
		"trail_color": Color("#06b6d4"),
		"trail_width_scale": 1.2,
		"motif": "cyber"
	},
	{
		"id": "imperial_jade",
		"name": "Imperial Jade",
		"rarity": "Epic",
		"cost": 100,
		"desc": "Polished sacred jade gemstone with ancient golden glints and emerald crystal trail.",
		"core_color": Color("#10b981"),
		"shade_color": Color("#064e3b"),
		"halo_color": Color(0.06, 0.73, 0.51, 0.38),
		"seam_color": Color("#fbbf24"),
		"dot_color": Color("#047857"),
		"trail_color": Color("#34d399"),
		"trail_width_scale": 1.15,
		"motif": "jade"
	},
	{
		"id": "cosmic_void",
		"name": "Cosmic Void",
		"rarity": "Epic",
		"cost": 130,
		"desc": "Deep interstellar dark violet sphere with twinkling stellar clusters and nebula trail.",
		"core_color": Color("#8b5cf6"),
		"shade_color": Color("#4c1d95"),
		"halo_color": Color(0.55, 0.36, 0.96, 0.45),
		"seam_color": Color("#c4b5fd"),
		"dot_color": Color("#6d28d9"),
		"trail_color": Color("#a78bfa"),
		"trail_width_scale": 1.3,
		"motif": "void"
	},
	{
		"id": "royal_midas",
		"name": "Royal Midas",
		"rarity": "Legendary",
		"cost": 160,
		"desc": "Solid 24-karat gold mirror sphere with crown sparkle highlights and gilded radiant trail.",
		"core_color": Color("#fbbf24"),
		"shade_color": Color("#b45309"),
		"halo_color": Color(0.98, 0.75, 0.14, 0.5),
		"seam_color": Color("#fef08a"),
		"dot_color": Color("#d97706"),
		"trail_color": Color("#f59e0b"),
		"trail_width_scale": 1.35,
		"motif": "gold"
	},
	{
		"id": "prismatic_rainbow",
		"name": "Prismatic Iris",
		"rarity": "Legendary",
		"cost": 200,
		"desc": "Iridescent crystal prism reflecting dynamic chromatic spectrum aura and rainbow trail.",
		"core_color": Color("#e0e7ff"),
		"shade_color": Color("#6366f1"),
		"halo_color": Color(0.5, 0.8, 1.0, 0.45),
		"seam_color": Color("#f472b6"),
		"dot_color": Color("#38bdf8"),
		"trail_color": Color("#818cf8"),
		"trail_width_scale": 1.4,
		"motif": "rainbow"
	}
]

static func get_skin_by_id(skin_id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == skin_id:
			return s
	return SKINS[0]

static func get_all_skins() -> Array[Dictionary]:
	return SKINS

static func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"Common":
			return Color("#94a3b8")
		"Rare":
			return Color("#38bdf8")
		"Epic":
			return Color("#a855f7")
		"Legendary":
			return Color("#f59e0b")
		_:
			return Color("#94a3b8")
