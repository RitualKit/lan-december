class_name Themes
extends RefCounted
## Island themes: ground and cliff textures, trees and props, water colours, light,
## weather and moving scenery. Each round picks one so the matches feel varied.

const ALL := {
	"blossom": {
		"label": "Blossom Isles",
		"ground": "grass", "lip": "cliff_top", "side": "cliff",
		"trees": ["round:blossom", "round:blossom", "round:leaves"],
		"props": ["rock", "bush", "tent", "lamp"],
		"details": [["tuft", "5e9a45"], ["bloom", "f4a6c8"], ["bloom", "ffffff"]],
		"bg": "6fa4bb", "ambient": "b4c8e8", "ambient_energy": 0.6,
		"sun": "fff0d8", "sun_energy": 1.15, "sun_rot": Vector3(-52, -38, 0),
		"shallow": Color(0.27, 0.53, 0.58), "deep": Color(0.12, 0.29, 0.40),
		"weather": "petals",
		"extras": ["boats", "birds", "lily_pads", "fish"],
	},
	"autumn": {
		"label": "Maple Bay",
		"ground": "grass_autumn", "lip": "cliff_top_autumn", "side": "cliff",
		"trees": ["round:maple", "round:maple", "round:leaves", "pine:pine"],
		"props": ["rock", "pumpkin", "pumpkin", "lamp", "tent"],
		"details": [["leafpile", "e8803a"], ["leafpile", "c0502a"], ["tuft", "8a7e36"]],
		"bg": "8a9fae", "ambient": "e0c8b0", "ambient_energy": 0.55,
		"sun": "ffd8a0", "sun_energy": 1.15, "sun_rot": Vector3(-38, -55, 0),
		"shallow": Color(0.30, 0.50, 0.52), "deep": Color(0.14, 0.27, 0.34),
		"weather": "leaves",
		"extras": ["boats", "birds", "fish"],
	},
	"winter": {
		"label": "Frost Peaks",
		"ground": "snow", "lip": "cliff_top_snow", "side": "cliff_cold",
		"trees": ["pine:pine_snow", "pine:pine_snow", "pine:pine"],
		"props": ["snowman", "rock", "snowman", "lamp"],
		"details": [["pebble", "c8d4e0"], ["tuft", "8aa0b4"]],
		"bg": "9ab4c8", "ambient": "c8d8f0", "ambient_energy": 0.6,
		"sun": "f0f6ff", "sun_energy": 1.05, "sun_rot": Vector3(-42, -30, 0),
		"shallow": Color(0.42, 0.60, 0.68), "deep": Color(0.20, 0.34, 0.46),
		"weather": "snow",
		"extras": ["ice_floes", "birds"],
	},
	"tropical": {
		"label": "Sunny Atoll",
		"ground": "sand", "lip": "cliff_top_sand", "side": "cliff_warm",
		"trees": ["palm:palm", "palm:palm", "round:leaves"],
		"props": ["rock", "bush", "lighthouse", "tent"],
		"details": [["shell", "f6c8b8"], ["shell", "fff0d0"], ["tuft", "6aa848"]],
		"bg": "5cc0d0", "ambient": "c0e8f0", "ambient_energy": 0.6,
		"sun": "fff4dc", "sun_energy": 1.2, "sun_rot": Vector3(-62, -30, 0),
		"shallow": Color(0.25, 0.70, 0.72), "deep": Color(0.08, 0.38, 0.52),
		"weather": "",
		"extras": ["boats", "boats", "birds", "fish"],
	},
	"night": {
		"label": "Lantern Night",
		"ground": "grass_dark", "lip": "cliff_top_night", "side": "cliff_night",
		"trees": ["round:blossom", "round:leaves", "pine:pine"],
		"props": ["lamp", "lamp", "campfire", "tent", "rock"],
		"details": [["bloom", "ffe08a"], ["tuft", "3f7a3a"]],
		"bg": "1c2440", "ambient": "8090c8", "ambient_energy": 0.75,
		"sun": "a8c0ff", "sun_energy": 0.55, "sun_rot": Vector3(-58, 30, 0),
		"shallow": Color(0.14, 0.24, 0.40), "deep": Color(0.05, 0.10, 0.22),
		"weather": "fireflies",
		"extras": ["sky_lanterns", "boats", "fish"],
	},
}

const ORDER: Array[String] = ["blossom", "autumn", "winter", "tropical", "night"]


static func get_theme(theme_name: String) -> Dictionary:
	return ALL.get(theme_name, ALL.blossom)
