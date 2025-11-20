# Map Generator - Run this once to create comprehensive Earth Realm map
# This creates 22 nodes with branching paths, shops, rest sites, elites, and a boss
@tool
extends Node

const MapNode = preload("res://World/MAP/map_node.tscn")

func _ready():
	if Engine.is_editor_hint():
		print("🗺️ Map Generator: Script loaded")

		# Wait a frame for scene to fully load
		await get_tree().process_frame

		var node_layer = get_node_or_null("MapRoot/NodeLayer")

		if node_layer == null:
			print("❌ ERROR: Could not find MapRoot/NodeLayer")
			print("   Make sure this script is attached to EarthMapScene root node")
			print("   Current node: ", name)
			return

		print("✅ Found NodeLayer at: ", node_layer.get_path())
		print("🗺️ Starting map generation...")

		# Clear old nodes first
		clear_old_nodes(node_layer)
		await get_tree().create_timer(0.5).timeout

		# Generate new map
		generate_map(node_layer)

		print("🎉 Map generation complete! Check the NodeLayer in the scene tree.")

# Node positions and configuration
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

# Card database references for enemy decks
var card_paths = {
	"Dirt": "res://Cards/Monster Cards/Dirt.tres",
	"Fungoo": "res://Cards/Monster Cards/Fungoo.tres",
	"Goblin": "res://Cards/Monster Cards/Goblin.tres",
	"Imp": "res://Cards/Monster Cards/Imp.tres",
	"Falcreep": "res://Cards/Monster Cards/Falcreep.tres"
}

func generate_map(node_layer: Node2D):
	"""Call this function to populate the NodeLayer with all nodes"""
	var created_nodes = {}
	var scene_root = get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene

	print("📋 Generating ", node_config.size(), " nodes...")

	# First pass: Create all nodes
	for node_name in node_config:
		var config = node_config[node_name]

		# Update PortalHub if it exists
		if node_name == "PortalHub":
			var existing = node_layer.get_node_or_null("PortalHub")
			if existing:
				# Reset PortalHub anchors and position properly
				existing.set_anchors_preset(Control.PRESET_TOP_LEFT)
				existing.anchor_left = 0.0
				existing.anchor_top = 0.0
				existing.anchor_right = 0.0
				existing.anchor_bottom = 0.0

				var node_width = 50
				var node_height = 50
				existing.offset_left = config.pos.x
				existing.offset_top = config.pos.y
				existing.offset_right = config.pos.x + node_width
				existing.offset_bottom = config.pos.y + node_height

				created_nodes[node_name] = existing
				print("  ✓ Updated existing PortalHub position")
			else:
				print("  ⚠️ WARNING: PortalHub not found!")
			continue

		# Instantiate node
		var node_instance = MapNode.instantiate()
		if node_instance == null:
			print("  ❌ ERROR: Failed to instantiate MapNode for ", node_name)
			continue

		node_instance.name = node_name

		# Set anchors preset to top-left (0,0,0,0)
		node_instance.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node_instance.anchor_left = 0.0
		node_instance.anchor_top = 0.0
		node_instance.anchor_right = 0.0
		node_instance.anchor_bottom = 0.0

		# Set position using offsets (for Control nodes with 0,0,0,0 anchors)
		var node_width = 50
		var node_height = 50
		node_instance.offset_left = config.pos.x
		node_instance.offset_top = config.pos.y
		node_instance.offset_right = config.pos.x + node_width
		node_instance.offset_bottom = config.pos.y + node_height

		# Set node properties
		node_instance.encounter_type = config.type
		node_instance.enemy_name = config.enemy
		node_instance.description = config.description

		# Set difficulty
		if config.has("difficulty"):
			node_instance.difficulty = config.difficulty

		# Load enemy deck
		if config.has("deck"):
			var deck_array: Array[CardData] = []
			for card_name in config.deck:
				if card_paths.has(card_name):
					var card_resource = load(card_paths[card_name])
					if card_resource:
						deck_array.append(card_resource)
			node_instance.enemy_deck = deck_array

		# Add to scene
		node_layer.add_child(node_instance, true)  # true = force_readable_name

		# Set owner for editor
		if Engine.is_editor_hint() and scene_root:
			node_instance.owner = scene_root

		created_nodes[node_name] = node_instance
		print("  ✓ Created: ", node_name, " (", config.type, ") at ", config.pos)

	# Second pass: Set up connections
	print("\n🔗 Setting up connections...")
	for node_name in node_config:
		var config = node_config[node_name]
		var node = created_nodes.get(node_name)

		if node and config.has("connections"):
			node.connected_nodes = _get_node_paths(node_name, config.connections, node_layer)
			print("  ✓ ", node_name, " → ", config.connections)

	print("\n✅ Map generation complete! Created ", created_nodes.size(), " nodes")

func _get_node_paths(from_name: String, connection_names: Array, node_layer: Node2D) -> Array[NodePath]:
	"""Convert node name strings to NodePaths"""
	var paths: Array[NodePath] = []
	for conn_name in connection_names:
		var target_node = node_layer.get_node_or_null(conn_name)
		if target_node:
			paths.append(NodePath("../" + conn_name))
		else:
			print("Warning: Could not find connection target: ", conn_name)
	return paths

# Optional: Clean up old nodes before regenerating
func clear_old_nodes(node_layer: Node2D):
	"""Remove all existing map nodes except PortalHub and Player"""
	var cleared_count = 0
	var children_to_remove = []

	for child in node_layer.get_children():
		if child.name != "PortalHub" and child.name != "Player":
			children_to_remove.append(child)

	print("🧹 Clearing ", children_to_remove.size(), " old nodes...")

	for child in children_to_remove:
		print("  - Removing: ", child.name)
		child.queue_free()
		cleared_count += 1

	if cleared_count > 0:
		await get_tree().process_frame
		print("✅ Cleared ", cleared_count, " old nodes")
	else:
		print("✅ No old nodes to clear")
