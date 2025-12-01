extends Node
class_name MapGenerator3D

# Uses the same node configuration as the 2D map generator
# but places nodes in 3D space

# Node positions and configuration (same as 2D map generator)
var node_config = {
	# Layer 0: Portal Hub (starting point)
	"PortalHub": {
		"type": "hub",
		"pos": Vector2(343, 472),
		"enemy": "Portal Hub",
		"description": "Return to the central hub",
		"connections": ["Node_1A", "Node_1B", "Node_1C"],
		"completed": true
	},

	# Layer 1: First Encounters (Y: 540-560)
	"Node_1A": {
		"type": "fight",
		"pos": Vector2(240, 550),
		"enemy": "Forest Guardian",
		"deck": ["Dirt", "Fungoo"],
		"difficulty": 1,
		"description": "A small forest guardian blocks your path.",
		"connections": ["Node_2A", "Node_2B"]
	},
	"Node_1B": {
		"type": "fight",
		"pos": Vector2(350, 550),
		"enemy": "Wandering Imp",
		"deck": ["Imp", "Falcreep"],
		"difficulty": 1,
		"description": "A mischievous imp challenges you!",
		"connections": ["Node_2B", "Node_2C"]
	},
	"Node_1C": {
		"type": "fight",
		"pos": Vector2(460, 550),
		"enemy": "Rocky Golem",
		"deck": ["Dirt", "Goblin"],
		"difficulty": 1,
		"description": "An animated rock formation stands in your way.",
		"connections": ["Node_2C", "Node_2D"]
	},

	# Layer 2: Diverging Paths (Y: 640-660)
	"Node_2A": {
		"type": "fireevent",
		"pos": Vector2(200, 650),
		"enemy": "Flame Spirit",
		"description": "A burning shrine radiates intense heat...",
		"connections": ["Node_3A", "Node_3B"]
	},
	"Node_2B": {
		"type": "fight",
		"pos": Vector2(310, 650),
		"enemy": "Goblin Raider",
		"deck": ["Goblin", "Goblin", "Imp"],
		"difficulty": 1,
		"description": "A cunning goblin prepares to raid!",
		"connections": ["Node_3A", "Node_3B", "Node_3C"]
	},
	"Node_2C": {
		"type": "explore",
		"pos": Vector2(420, 650),
		"enemy": "None",
		"description": "A hidden grove filled with mysterious energy...",
		"connections": ["Node_3B", "Node_3C"]
	},
	"Node_2D": {
		"type": "fight",
		"pos": Vector2(520, 650),
		"enemy": "Earth Elemental",
		"deck": ["Dirt", "Dirt", "Fungoo"],
		"difficulty": 1,
		"description": "Pure earth energy coalesces into a guardian.",
		"connections": ["Node_3C"]
	},

	# Layer 3: Mid-Game Choices (Y: 740-760)
	"Node_3A": {
		"type": "shop",
		"pos": Vector2(260, 750),
		"enemy": "Merchant",
		"description": "A traveling merchant offers their wares.",
		"connections": ["Node_4A", "Node_4B"]
	},
	"Node_3B": {
		"type": "fight",
		"pos": Vector2(370, 750),
		"enemy": "Veteran Fighter",
		"deck": ["Goblin", "Falcreep", "Imp"],
		"difficulty": 2,
		"description": "A seasoned warrior tests your skills.",
		"connections": ["Node_4A", "Node_4B", "Node_4C"]
	},
	"Node_3C": {
		"type": "rest",
		"pos": Vector2(470, 750),
		"enemy": "None",
		"description": "An ancient campfire offers respite and rest.",
		"connections": ["Node_4B", "Node_4C"]
	},

	# Layer 4: Escalating Challenge (Y: 840-860)
	"Node_4A": {
		"type": "fight",
		"pos": Vector2(310, 850),
		"enemy": "Beast Tamer",
		"deck": ["Fungoo", "Fungoo", "Falcreep", "Falcreep"],
		"difficulty": 2,
		"description": "A beast tamer commands fierce creatures!",
		"connections": ["Node_5A"]
	},
	"Node_4B": {
		"type": "waterevent",
		"pos": Vector2(420, 850),
		"enemy": "Water Spirit",
		"description": "A mystic pool shimmers with ancient magic...",
		"connections": ["Node_5A", "Node_5B"]
	},
	"Node_4C": {
		"type": "fight",
		"pos": Vector2(520, 850),
		"enemy": "Wind Dancer",
		"deck": ["Falcreep", "Falcreep", "Imp"],
		"difficulty": 2,
		"description": "Swift as the wind, deadly as a blade.",
		"connections": ["Node_5B"]
	},

	# Layer 5: Elite Encounters (Y: 940-960)
	"Node_5A": {
		"type": "elite",
		"pos": Vector2(300, 950),
		"enemy": "Earth Warden",
		"deck": ["Dirt", "Dirt", "Fungoo", "Fungoo", "Goblin"],
		"difficulty": 3,
		"description": "Elite Guardian of the Earth Realm - Prepare yourself!",
		"connections": ["Node_6A", "Node_6B"]
	},
	"Node_5B": {
		"type": "elite",
		"pos": Vector2(440, 950),
		"enemy": "Flame Champion",
		"deck": ["Imp", "Imp", "Falcreep", "Falcreep", "Goblin"],
		"difficulty": 3,
		"description": "Elite Fire Warrior - A formidable challenge!",
		"connections": ["Node_6B", "Node_6C"]
	},

	# Layer 6: Final Preparation (Y: 1040-1060)
	"Node_6A": {
		"type": "shop",
		"pos": Vector2(320, 1050),
		"enemy": "Final Merchant",
		"description": "Last chance to acquire powerful cards before the boss.",
		"connections": ["Node_BOSS"]
	},
	"Node_6B": {
		"type": "rest",
		"pos": Vector2(400, 1050),
		"enemy": "None",
		"description": "Sacred grove - heal and prepare for the final battle.",
		"connections": ["Node_BOSS"]
	},
	"Node_6C": {
		"type": "explore",
		"pos": Vector2(480, 1050),
		"enemy": "None",
		"description": "Ancient ruins hold powerful secrets...",
		"connections": ["Node_BOSS"]
	},

	# Layer 7: Boss Encounter
	"Node_BOSS": {
		"type": "boss",
		"pos": Vector2(380, 1150),
		"enemy": "Terramaw, Guardian of Earth",
		"deck": ["Dirt", "Dirt", "Fungoo", "Fungoo", "Goblin", "Goblin", "Imp"],
		"difficulty": 5,
		"description": "The ultimate guardian of the Earth Realm awaits - Victory brings great rewards!",
		"connections": []
	}
}

func get_map_config() -> Dictionary:
	"""Return the map configuration"""
	return node_config

func generate_3d_map(map_scene: MapScene3D):
	"""Generate the 3D map in the given scene"""
	if map_scene:
		map_scene.generate_map_from_config(node_config)
	else:
		print("❌ ERROR: MapScene3D is null!")
