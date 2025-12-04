@tool
extends EditorScript

# Run this script from Script Editor -> File -> Run
# It will generate all map nodes and add them to the scene

func _run():
	print("🗺️ GENERATING MAP NODES IN EDITOR...")

	var editor_interface = get_editor_interface()
	var edited_scene = editor_interface.get_edited_scene_root()

	if not edited_scene:
		print("❌ No scene is open! Open 3DMAPSCENE.tscn first")
		return

	if edited_scene.name != "MapScene3D":
		print("❌ Wrong scene! Open 3DMAPSCENE.tscn (current: ", edited_scene.name, ")")
		return

	var node_container = edited_scene.get_node_or_null("NodeContainer")
	if not node_container:
		print("❌ NodeContainer not found in scene!")
		return

	# Clear existing nodes (except any you want to keep)
	for child in node_container.get_children():
		print("  🗑️ Removing old node: ", child.name)
		child.queue_free()

	# Node configuration (same as map_generator_3d.gd)
	var node_config = {
		# Layer 0: Portal Hub
		"PortalHub": {
			"type": "hub",
			"pos": Vector2(343, 472),
			"enemy": "Portal Hub",
			"description": "Return to the central hub",
			"connections": ["Node_1A", "Node_1B", "Node_1C"],
			"completed": true
		},

		# Layer 1: First Encounters
		"Node_1A": {
			"type": "fight",
			"pos": Vector2(240, 550),
			"enemy": "Forest Guardian",
			"difficulty": 1,
			"description": "A small forest guardian blocks your path.",
			"connections": ["Node_2A", "Node_2B"]
		},
		"Node_1B": {
			"type": "fight",
			"pos": Vector2(350, 550),
			"enemy": "Wandering Imp",
			"difficulty": 1,
			"description": "A mischievous imp challenges you!",
			"connections": ["Node_2B", "Node_2C"]
		},
		"Node_1C": {
			"type": "fight",
			"pos": Vector2(460, 550),
			"enemy": "Rocky Golem",
			"difficulty": 1,
			"description": "An animated rock formation stands in your way.",
			"connections": ["Node_2C", "Node_2D"]
		},

		# Layer 2: Diverging Paths
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
			"difficulty": 1,
			"description": "Pure earth energy coalesces into a guardian.",
			"connections": ["Node_3C"]
		},

		# Layer 3: Mid-Game Choices
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

		# Layer 4: Escalating Challenge
		"Node_4A": {
			"type": "fight",
			"pos": Vector2(310, 850),
			"enemy": "Beast Tamer",
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
			"difficulty": 2,
			"description": "Swift as the wind, deadly as a blade.",
			"connections": ["Node_5B"]
		},

		# Layer 5: Elite Encounters
		"Node_5A": {
			"type": "elite",
			"pos": Vector2(300, 950),
			"enemy": "Earth Warden",
			"difficulty": 3,
			"description": "Elite Guardian of the Earth Realm - Prepare yourself!",
			"connections": ["Node_6A", "Node_6B"]
		},
		"Node_5B": {
			"type": "elite",
			"pos": Vector2(440, 950),
			"enemy": "Flame Champion",
			"difficulty": 3,
			"description": "Elite Fire Warrior - A formidable challenge!",
			"connections": ["Node_6B", "Node_6C"]
		},

		# Layer 6: Final Preparation
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
			"difficulty": 5,
			"description": "The ultimate guardian of the Earth Realm awaits - Victory brings great rewards!",
			"connections": []
		}
	}

	var created_nodes = {}
	var grid_cell_size = 2.0

	# Create all nodes
	for node_name in node_config:
		var config = node_config[node_name]

		# Calculate position FIRST
		var pos_2d = config.get("pos", Vector2.ZERO)
		var grid_pos = convert_2d_to_grid_position(pos_2d, grid_cell_size)

		# Create node with position set BEFORE adding to tree
		var node = create_node(node_name, config, grid_cell_size)

		# Now add to tree FIRST
		node_container.add_child(node)
		node.owner = edited_scene  # CRITICAL: Set owner so it saves with scene

		# Set position AFTER adding to tree AND after _ready() has run
		# This ensures Area3D is properly initialized
		node.position = grid_pos
		node.transform.origin = grid_pos

		# For Area3D nodes, we need to explicitly set the transform in editor
		node.set_meta("editor_position", grid_pos)

		# Also set owner for all children created in _ready() so they save properly
		for child in node.get_children():
			child.owner = edited_scene

		created_nodes[node_name] = node
		print("  ✓ Created: ", node_name, " at position: ", grid_pos, " (saved to scene)")

	# Set up connections (second pass)
	print("\n🔗 Setting up connections...")
	for node_name in node_config:
		var config = node_config[node_name]
		var node = created_nodes[node_name]

		if config.has("connections"):
			for conn_name in config.connections:
				if created_nodes.has(conn_name):
					node.connected_nodes.append(NodePath("../" + conn_name))
			print("  ✓ ", node_name, " → ", config.connections)

	# Force editor to update and mark scene as modified
	editor_interface.get_selection().clear()

	# Mark the scene as modified so editor knows to update
	edited_scene.set_display_folded(false)

	# Request editor to rebuild scene tree display
	editor_interface.get_resource_filesystem().scan()

	# Select the NodeContainer to force viewport refresh
	editor_interface.get_selection().add_node(node_container)
	# Can't use get_tree() in editor script context, so skip the delay
	editor_interface.get_selection().clear()

	print("\n✅ DONE! Created ", created_nodes.size(), " nodes")
	print("💾 Now SAVE THE SCENE (Ctrl+S) to persist the nodes!")
	print("🔄 If nodes aren't visible, close and reopen the scene")
	print("📍 Try selecting a node in the Scene tree to see it highlighted in 3D viewport")

func create_node(node_name: String, config: Dictionary, grid_cell_size: float) -> MapNode3D:
	"""Create a single map node"""
	var node = MapNode3D.new()
	node.name = node_name

	# Set properties
	node.encounter_type = config.get("type", "fight")
	node.enemy_name = config.get("enemy", "Unknown")
	node.description = config.get("description", "")
	node.difficulty = config.get("difficulty", 1)
	node.is_completed = config.get("completed", false)

	# Store grid position (actual 3D position will be set after adding to tree)
	var pos_2d = config.get("pos", Vector2.ZERO)
	var grid_pos = convert_2d_to_grid_position(pos_2d, grid_cell_size)
	node.grid_position = Vector2i(int(grid_pos.x), int(grid_pos.z))
	# Don't set position here - will be set after adding to tree

	# Set fog of war and completion
	if node.encounter_type == "hub":
		node.is_revealed = true
		node.is_completed = true  # Portal hub starts as visited
	elif node.is_completed:
		node.is_revealed = true
	else:
		node.is_revealed = false

	return node

func convert_2d_to_grid_position(pos_2d: Vector2, grid_cell_size: float) -> Vector3:
	"""Convert 2D map position to 3D grid position"""
	var center_x = 360.0
	var center_y = 811.0

	var x = (pos_2d.x - center_x) / 100.0 * grid_cell_size
	var z = (pos_2d.y - center_y) / 100.0 * grid_cell_size
	var y = 0.5

	return Vector3(x, y, z)
