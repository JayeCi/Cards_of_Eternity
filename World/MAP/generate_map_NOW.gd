@tool
extends EditorScript

# This script can be run from: File → Run (or Ctrl+Shift+X)
# No need to attach it to anything - just run it directly!

const MapNode = preload("res://World/MAP/map_node.tscn")

# Node positions and configuration
var node_config = {
	# Layer 0: Portal Hub (starting point)
	"PortalHub": {
		"type": "hub",
		"pos": Vector2(343, 472),
		"enemy": "Portal Hub",
		"biome": "MEADOW",
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
		"leader": "Fungoo",
		"difficulty": 1,
		"biome": "FOREST",
		"description": "A small forest guardian blocks your path.",
		"connections": ["Node_2A", "Node_2B"]
	},
	"Node_1B": {
		"type": "fight",
		"pos": Vector2(350, 550),
		"enemy": "Wandering Imp",
		"deck": ["Imp", "Falcreep"],
		"leader": "Imp",
		"difficulty": 1,
		"biome": "VOLCANO",
		"description": "A mischievous imp challenges you!",
		"connections": ["Node_2B", "Node_2C"]
	},
	"Node_1C": {
		"type": "fight",
		"pos": Vector2(460, 550),
		"enemy": "Rocky Golem",
		"deck": ["Dirt", "Goblin"],
		"leader": "Goblin",
		"difficulty": 1,
		"biome": "MOUNTAIN",
		"description": "An animated rock formation stands in your way.",
		"connections": ["Node_2C", "Node_2D"]
	},

	# Layer 2: Diverging Paths (Y: 640-660)
	"Node_2A": {
		"type": "fireevent",
		"pos": Vector2(200, 650),
		"enemy": "Flame Spirit",
		"biome": "VOLCANO",
		"description": "A burning shrine radiates intense heat...",
		"connections": ["Node_3A", "Node_3B"]
	},
	"Node_2B": {
		"type": "fight",
		"pos": Vector2(310, 650),
		"enemy": "Goblin Raider",
		"deck": ["Goblin", "Goblin", "Imp"],
		"leader": "Goblin",
		"difficulty": 1,
		"biome": "MOUNTAIN",
		"description": "A cunning goblin prepares to raid!",
		"connections": ["Node_3A", "Node_3B", "Node_3C"]
	},
	"Node_2C": {
		"type": "explore",
		"pos": Vector2(420, 650),
		"enemy": "None",
		"biome": "FOREST",
		"description": "A hidden grove filled with mysterious energy...",
		"connections": ["Node_3B", "Node_3C"]
	},
	"Node_2D": {
		"type": "fight",
		"pos": Vector2(520, 650),
		"enemy": "Earth Elemental",
		"deck": ["Dirt", "Dirt", "Fungoo"],
		"leader": "Fungoo",
		"difficulty": 1,
		"biome": "MOUNTAIN",
		"description": "Pure earth energy coalesces into a guardian.",
		"connections": ["Node_3C"]
	},

	# Layer 3: Mid-Game Choices (Y: 740-760)
	"Node_3A": {
		"type": "shop",
		"pos": Vector2(260, 750),
		"enemy": "Merchant",
		"biome": "MEADOW",
		"description": "A traveling merchant offers their wares.",
		"connections": ["Node_4A", "Node_4B"]
	},
	"Node_3B": {
		"type": "fight",
		"pos": Vector2(370, 750),
		"enemy": "Veteran Fighter",
		"deck": ["Goblin", "Falcreep", "Imp"],
		"leader": "Falcreep",
		"difficulty": 2,
		"biome": "FOREST",
		"description": "A seasoned warrior tests your skills.",
		"connections": ["Node_4A", "Node_4B", "Node_4C"]
	},
	"Node_3C": {
		"type": "rest",
		"pos": Vector2(470, 750),
		"enemy": "None",
		"biome": "MEADOW",
		"description": "An ancient campfire offers respite and rest.",
		"connections": ["Node_4B", "Node_4C"]
	},

	# Layer 4: Escalating Challenge (Y: 840-860)
	"Node_4A": {
		"type": "fight",
		"pos": Vector2(310, 850),
		"enemy": "Beast Tamer",
		"deck": ["Fungoo", "Fungoo", "Falcreep", "Falcreep"],
		"leader": "Falcreep",
		"difficulty": 2,
		"biome": "FOREST",
		"description": "A beast tamer commands fierce creatures!",
		"connections": ["Node_5A"]
	},
	"Node_4B": {
		"type": "waterevent",
		"pos": Vector2(420, 850),
		"enemy": "Water Spirit",
		"biome": "OCEAN",
		"description": "A mystic pool shimmers with ancient magic...",
		"connections": ["Node_5A", "Node_5B"]
	},
	"Node_4C": {
		"type": "fight",
		"pos": Vector2(520, 850),
		"enemy": "Wind Dancer",
		"deck": ["Falcreep", "Falcreep", "Imp"],
		"leader": "Falcreep",
		"difficulty": 2,
		"biome": "MEADOW",
		"description": "Swift as the wind, deadly as a blade.",
		"connections": ["Node_5B"]
	},

	# Layer 5: Elite Encounters (Y: 940-960)
	"Node_5A": {
		"type": "elite",
		"pos": Vector2(300, 950),
		"enemy": "Earth Warden",
		"deck": ["Dirt", "Dirt", "Fungoo", "Fungoo", "Goblin"],
		"leader": "Goblin",
		"difficulty": 3,
		"biome": "MOUNTAIN",
		"description": "Elite Guardian of the Earth Realm - Prepare yourself!",
		"connections": ["Node_6A", "Node_6B"]
	},
	"Node_5B": {
		"type": "elite",
		"pos": Vector2(440, 950),
		"enemy": "Flame Champion",
		"deck": ["Imp", "Imp", "Falcreep", "Falcreep", "Goblin"],
		"leader": "Goblin",
		"difficulty": 3,
		"biome": "VOLCANO",
		"description": "Elite Fire Warrior - A formidable challenge!",
		"connections": ["Node_6B", "Node_6C"]
	},

	# Layer 6: Final Preparation (Y: 1040-1060)
	"Node_6A": {
		"type": "shop",
		"pos": Vector2(320, 1050),
		"enemy": "Final Merchant",
		"biome": "MEADOW",
		"description": "Last chance to acquire powerful cards before the boss.",
		"connections": ["Node_BOSS"]
	},
	"Node_6B": {
		"type": "rest",
		"pos": Vector2(400, 1050),
		"enemy": "None",
		"biome": "FOREST",
		"description": "Sacred grove - heal and prepare for the final battle.",
		"connections": ["Node_BOSS"]
	},
	"Node_6C": {
		"type": "explore",
		"pos": Vector2(480, 1050),
		"enemy": "None",
		"biome": "MOUNTAIN",
		"description": "Ancient ruins hold powerful secrets...",
		"connections": ["Node_BOSS"]
	},

	# Layer 7: Boss Encounter
	"Node_BOSS": {
		"type": "boss",
		"pos": Vector2(380, 1150),
		"enemy": "Terramaw, Guardian of Earth",
		"deck": ["Dirt", "Dirt", "Fungoo", "Fungoo", "Goblin", "Goblin", "Imp"],
		"leader": "Goblin",
		"difficulty": 5,
		"biome": "MOUNTAIN",
		"description": "The ultimate guardian of the Earth Realm awaits - Victory brings great rewards!",
		"connections": []
	}
}

# Card database references
var card_paths = {
	"Dirt": "res://Cards/Monster Cards/Dirt.tres",
	"Fungoo": "res://Cards/Monster Cards/Fungoo.tres",
	"Goblin": "res://Cards/Monster Cards/Goblin.tres",
	"Imp": "res://Cards/Monster Cards/Imp.tres",
	"Falcreep": "res://Cards/Monster Cards/Falcreep.tres"
}

func _run():

	print("🗺️  EARTH REALM MAP GENERATOR")


	# Get the currently edited scene
	var edited_scene = get_editor_interface().get_edited_scene_root()

	if edited_scene == null:
		print("❌ ERROR: No scene is currently open!")
		print("   Please open earth_map_screen.tscn first")
		return

	if edited_scene.name != "EarthMapScene":
		print("❌ ERROR: Wrong scene open!")
		print("   Current scene: ", edited_scene.name)
		print("   Expected: EarthMapScene")
		print("   Please open earth_map_screen.tscn")
		return

	# Find NodeLayer
	var node_layer = edited_scene.get_node_or_null("MapRoot/NodeLayer")

	if node_layer == null:
		print("❌ ERROR: Could not find MapRoot/NodeLayer")
		print("   Make sure earth_map_screen.tscn has the correct structure")
		return

	print("✅ Found scene: ", edited_scene.name)
	print("✅ Found NodeLayer: ", node_layer.get_path())
	print()

	# Clear old nodes
	clear_old_nodes(node_layer)
	print()

	# Generate new map
	generate_map(node_layer, edited_scene)


	print("🎉 MAP GENERATION COMPLETE!")
	print("\n📋 Next Steps:")
	print("  1. 💾 Save the scene (Ctrl+S)")
	print("  2. 🔄 Close and reopen the scene")
	print("  3. ▶️  Run the game to see all nodes")
	print("\n💡 Why you only see PortalHub in editor:")
	print("  - The map_screen.gd script runs at RUNTIME, not in editor")
	print("  - It sets node visibility based on reachability")
	print("  - All ", node_config.size(), " nodes ARE created - they're just invisible in editor")
	print("  - When you RUN the game, they'll all appear properly!")
	print()

func clear_old_nodes(node_layer: Node2D):
	var children_to_remove = []

	for child in node_layer.get_children():
		if child.name != "PortalHub" and child.name != "Player":
			children_to_remove.append(child)

	if children_to_remove.is_empty():
		print("✅ No old nodes to clear")
		return

	print("🧹 Clearing ", children_to_remove.size(), " old nodes...")

	for child in children_to_remove:
		print("  - Removing: ", child.name)
		node_layer.remove_child(child)
		child.queue_free()

	print("✅ Cleared ", children_to_remove.size(), " old nodes")

func generate_map(node_layer: Node2D, scene_root: Node):
	var created_nodes = {}

	print("📋 Generating ", node_config.size(), " nodes...\n")

	# First pass: Create all nodes
	for node_name in node_config:
		var config = node_config[node_name]

		# Update PortalHub if it exists
		if node_name == "PortalHub":
			var existing = node_layer.get_node_or_null("PortalHub")
			if existing:
				# Reset anchors to 0,0,0,0 for absolute positioning
				existing.anchor_left = 0.0
				existing.anchor_top = 0.0
				existing.anchor_right = 0.0
				existing.anchor_bottom = 0.0

				# Set position using offsets (same method as other nodes)
				var node_width = 50
				var node_height = 50
				existing.offset_left = config.pos.x
				existing.offset_top = config.pos.y
				existing.offset_right = config.pos.x + node_width
				existing.offset_bottom = config.pos.y + node_height

				# Set hub properties
				existing.encounter_type = "hub"
				existing.battle_completed = true
				existing.is_completed = true

				created_nodes[node_name] = existing
				print("  ✓ Updated PortalHub at ", config.pos)
			else:
				print("  ⚠️  PortalHub not found - will create new one")
			continue

		# Instantiate new node
		var node_instance = MapNode.instantiate()
		if node_instance == null:
			print("  ❌ Failed to create: ", node_name)
			continue

		node_instance.name = node_name

		# Add to scene FIRST (important - Control nodes need parent to calculate layout)
		node_layer.add_child(node_instance, true)
		node_instance.owner = scene_root

		# NOW set anchors to 0,0,0,0 for absolute positioning
		node_instance.anchor_left = 0.0
		node_instance.anchor_top = 0.0
		node_instance.anchor_right = 0.0
		node_instance.anchor_bottom = 0.0

		# Set position and size using the RECT method (works after being in scene tree)
		var node_width = 50
		var node_height = 50
		var target_rect = Rect2(config.pos, Vector2(node_width, node_height))

		# This is the most reliable way to set Control node position/size
		node_instance.offset_left = target_rect.position.x
		node_instance.offset_top = target_rect.position.y
		node_instance.offset_right = target_rect.position.x + target_rect.size.x
		node_instance.offset_bottom = target_rect.position.y + target_rect.size.y

		# Set properties
		node_instance.encounter_type = config.type
		node_instance.enemy_name = config.enemy
		node_instance.description = config.description

		if config.has("difficulty"):
			node_instance.difficulty = config.difficulty

		if config.has("biome"):
			node_instance.biome = config.biome

		# Load enemy deck
		if config.has("deck"):
			var deck_array: Array[CardData] = []
			for card_name in config.deck:
				if card_paths.has(card_name):
					var card_resource = load(card_paths[card_name])
					if card_resource:
						deck_array.append(card_resource)
			node_instance.enemy_deck = deck_array

		# Load enemy leader
		if config.has("leader"):
			var leader_name = config.leader
			if card_paths.has(leader_name):
				var leader_resource = load(card_paths[leader_name])
				if leader_resource:
					node_instance.enemy_leader = leader_resource
					print("    - Leader: ", leader_name)

		# Node already added to scene earlier (needed for layout calculation)
		created_nodes[node_name] = node_instance
		print("  ✓ Created: ", node_name, " (", config.type, ") at ", config.pos)

	# Second pass: Set up connections
	print("\n🔗 Setting up connections...\n")
	for node_name in node_config:
		var config = node_config[node_name]
		var node = created_nodes.get(node_name)

		if node and config.has("connections"):
			var paths: Array[NodePath] = []
			for conn_name in config.connections:
				paths.append(NodePath("../" + conn_name))

			node.connected_nodes = paths
			print("  ✓ ", node_name, " → ", config.connections)

	print("\n✅ Created ", created_nodes.size(), " nodes")

	# Third pass: Refresh map_screen connections and signals
	print("\n🔄 Setting up node signals and connections...")

	# Connect all nodes to the map screen's click handler
	var all_nodes_array: Array[MapNode] = []
	for child in node_layer.get_children():
		if child is MapNode:
			all_nodes_array.append(child)
			# Store in scene_root for later access
			if scene_root.has_method("_on_node_clicked"):
				# Disconnect first if already connected to avoid duplicates
				if child.is_connected("clicked", Callable(scene_root, "_on_node_clicked")):
					child.clicked.disconnect(Callable(scene_root, "_on_node_clicked"))
				child.clicked.connect(scene_root._on_node_clicked)

	print("✅ Connected ", all_nodes_array.size(), " node signals")
	print("\n⚠️  IMPORTANT: Save the scene, then RELOAD it (close and reopen)")
	print("   This ensures the map_screen script properly initializes all nodes")
