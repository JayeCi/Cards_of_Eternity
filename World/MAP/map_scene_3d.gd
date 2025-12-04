extends Node3D
class_name MapScene3D

signal node_clicked(node: MapNode3D)
signal player_arrived(node: MapNode3D)

@export var grid_cell_size: float = 2.0  # Size of each grid cell
@export var enable_fog_of_war: bool = true
@export var show_path_lines: bool = true

# Scene references (set in the scene tree)
@onready var camera: MapCamera3D = $MapCamera3D
@onready var player: MapPlayer3D = $MapPlayer3D
@onready var node_container: Node3D = $NodeContainer
@onready var path_lines: Node3D = $PathLines
@onready var map_audio: MapAudio3D = $MapAudio3D
@onready var map_generator: MapGenerator3D = $MapGenerator3D
@onready var ui_overlay: MapUIOverlay3D = $MapUIOverlay3D

# Map data
var all_nodes: Array[MapNode3D] = []
var current_level_data: Dictionary = {}

func _ready():
	# Initialize the map
	setup_scene()

	# Connect signals
	connect_signals()

	# Set up UI overlay
	if ui_overlay:
		ui_overlay.set_map_scene(self)
		ui_overlay.set_realm_name("Earth")
		ui_overlay.return_to_hub_pressed.connect(_on_return_to_hub)

	# Nodes are now pre-generated in the editor, just set them up
	await get_tree().create_timer(0.1).timeout  # Wait for scene to fully load

	print("🗺️ Setting up pre-existing nodes...")
	setup_existing_nodes()
	print("✅ 3D Map scene ready!")
	print("📊 Found ", all_nodes.size(), " nodes")
	print("📷 Camera position: ", camera.global_position)
	print("🎮 Player position: ", player.global_position if player else "no player")

func setup_scene():
	"""Initialize the 3D map scene"""
	print("🗺️ Setting up 3D Map Scene...")

	# Ensure required nodes exist
	if not camera:
		camera = MapCamera3D.new()
		camera.name = "MapCamera3D"
		add_child(camera)

	if not player:
		player = MapPlayer3D.new()
		player.name = "MapPlayer3D"
		add_child(player)

	if not node_container:
		node_container = Node3D.new()
		node_container.name = "NodeContainer"
		add_child(node_container)

	if not path_lines:
		path_lines = Node3D.new()
		path_lines.name = "PathLines"
		add_child(path_lines)

	# Set camera to default position
	if camera:
		camera.setup_default_position()

func connect_signals():
	"""Connect all necessary signals"""
	if player:
		player.movement_started.connect(_on_player_movement_started)
		player.movement_completed.connect(_on_player_movement_completed)
		player.arrived_at_node.connect(_on_player_arrived_at_node)

func setup_existing_nodes():
	"""Set up nodes that already exist in the scene (from editor)"""
	print("🔍 Finding existing nodes in NodeContainer...")

	# Get all MapNode3D nodes from NodeContainer
	all_nodes.clear()

	if node_container:
		for child in node_container.get_children():
			if child is MapNode3D:
				all_nodes.append(child)

				# Connect signals
				child.clicked.connect(_on_node_clicked)
				child.hovered.connect(_on_node_hovered)
				child.unhovered.connect(_on_node_unhovered)

				print("  ✓ Found: ", child.name, " (", child.encounter_type, ")")

	# Draw path lines
	if show_path_lines:
		draw_all_path_lines()

	# Find and set the starting node (Portal Hub)
	var portal_hub = get_node_by_name("PortalHub")
	if portal_hub:
		print("🎮 Setting player at Portal Hub")
		player.set_current_node(portal_hub)

		# Debug: Show which nodes are reachable
		print("📍 Reachable nodes from Portal Hub:")
		for node in all_nodes:
			if node.is_reachable:
				print("  ✓ ", node.name, " (revealed: ", node.is_revealed, ")")
	else:
		print("❌ Portal Hub not found!")

func generate_map_from_config(config: Dictionary):
	"""Generate the 3D map from a configuration dictionary (like the 2D map_generator)"""
	print("🗺️ Generating 3D map from config...")

	current_level_data = config
	clear_existing_nodes()

	# Create all nodes
	for node_name in config:
		var node_config = config[node_name]
		create_map_node(node_name, node_config)

	# Set up connections after all nodes are created
	setup_node_connections()

	# Draw path lines
	if show_path_lines:
		draw_all_path_lines()

	# Find and set the starting node (Portal Hub)
	var portal_hub = get_node_by_name("PortalHub")
	if portal_hub:
		print("🎮 Setting player at Portal Hub")
		player.set_current_node(portal_hub)

		# Don't focus camera on portal hub, keep it at default overview
		# camera.focus_on_node(portal_hub, true)

		# Debug: Show which nodes are reachable
		print("📍 Reachable nodes from Portal Hub:")
		for node in all_nodes:
			if node.is_reachable:
				print("  ✓ ", node.name, " (revealed: ", node.is_revealed, ")")
	else:
		print("❌ Portal Hub not found!")

	print("✅ 3D Map generation complete! Created ", all_nodes.size(), " nodes")

func create_map_node(node_name: String, config: Dictionary) -> MapNode3D:
	"""Create a single map node from configuration"""

	var node = MapNode3D.new()
	node.name = node_name

	# Set properties from config
	node.encounter_type = config.get("type", "unknown")
	node.enemy_name = config.get("enemy", "Unknown")
	node.description = config.get("description", "")
	node.difficulty = config.get("difficulty", 1)
	node.is_completed = config.get("completed", false)

	# Convert 2D position to 3D grid position
	var pos_2d = config.get("pos", Vector2.ZERO)
	var grid_pos = convert_2d_to_grid_position(pos_2d)
	node.grid_position = Vector2i(int(grid_pos.x), int(grid_pos.z))

	# Handle fog of war
	if enable_fog_of_war:
		if node.encounter_type == "hub" or node.is_completed:
			node.is_revealed = true
		else:
			node.is_revealed = false

	# Load enemy deck if specified
	if config.has("deck"):
		# TODO: Load actual card resources
		pass

	# Add to scene FIRST (required before setting global_position)
	node_container.add_child(node)
	all_nodes.append(node)

	# Set 3D position AFTER adding to tree
	node.global_position = grid_pos

	print("  ✓ Created: ", node_name, " at ", grid_pos, " (revealed: ", node.is_revealed, ")")

	# Connect node signals
	node.clicked.connect(_on_node_clicked)
	node.hovered.connect(_on_node_hovered)
	node.unhovered.connect(_on_node_unhovered)

	return node

func convert_2d_to_grid_position(pos_2d: Vector2) -> Vector3:
	"""Convert a 2D map position to a 3D grid position"""

	# Map the 2D coordinates to a 3D grid
	# Center the map properly based on actual node positions
	# Node X range: 200-520, center at 360
	# Node Y range: 472-1150, center at 811
	var center_x = 360.0
	var center_y = 811.0

	var x = (pos_2d.x - center_x) / 100.0 * grid_cell_size
	var z = (pos_2d.y - center_y) / 100.0 * grid_cell_size
	var y = 0.5  # Slightly above ground

	return Vector3(x, y, z)

func setup_node_connections():
	"""Set up all node connections based on configuration"""

	for node in all_nodes:
		var node_name = node.name
		if not current_level_data.has(node_name):
			continue

		var config = current_level_data[node_name]
		if not config.has("connections"):
			continue

		var connection_names = config["connections"]
		node.connected_nodes.clear()

		for conn_name in connection_names:
			var target_node = get_node_by_name(conn_name)
			if target_node:
				var path = node.get_path_to(target_node)
				node.connected_nodes.append(path)

func draw_all_path_lines():
	"""Draw lines for traveled paths and currently available paths"""

	# Clear existing lines
	for child in path_lines.get_children():
		child.queue_free()

	if not player or not player.current_node:
		return

	# Draw lines from current node to reachable nodes (available paths)
	var current = player.current_node
	for node_path in current.connected_nodes:
		var target = current.get_node(node_path) as MapNode3D
		if target and target.is_revealed and target.is_reachable:
			draw_path_line(current, target, Color(0.8, 0.8, 1.0, 0.6))  # Bright blue for available

	# Draw traveled paths (from visited nodes)
	for node in all_nodes:
		if node.is_completed:  # Only draw from completed nodes
			for node_path in node.connected_nodes:
				var target = node.get_node(node_path) as MapNode3D
				# Only draw to nodes we've been to
				if target and target.is_completed:
					draw_path_line(node, target, Color(0.5, 0.5, 0.5, 0.4))  # Gray for traveled

func draw_path_line(from_node: MapNode3D, to_node: MapNode3D, line_color: Color = Color(0.5, 0.5, 0.8, 0.3)):
	"""Draw a line between two nodes"""

	var line = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()

	# Create line material
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = line_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Draw the line
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	mesh.surface_add_vertex(from_node.global_position)
	mesh.surface_add_vertex(to_node.global_position)
	mesh.surface_end()

	line.mesh = mesh
	path_lines.add_child(line)

func clear_existing_nodes():
	"""Clear all existing map nodes"""
	for node in all_nodes:
		if node:
			node.queue_free()

	all_nodes.clear()

	# Clear path lines
	for child in path_lines.get_children():
		child.queue_free()

func get_node_by_name(node_name: String) -> MapNode3D:
	"""Get a map node by name"""
	for node in all_nodes:
		if node.name == node_name:
			return node
	return null

# Signal handlers

func _on_node_clicked(node: MapNode3D):
	"""Handle when a node is clicked"""
	print("Node clicked: ", node.name)

	# Play click sound
	if map_audio:
		map_audio.play_node_click()

	# Move player to the node if possible
	if player.can_move_to(node):
		player.move_to_node(node)
		# Focus camera on the target node
		if camera:
			camera.focus_on_node(node)
	else:
		print("  ❌ Cannot move to this node")

	emit_signal("node_clicked", node)

func _on_node_hovered(node: MapNode3D):
	"""Handle when mouse enters a node"""
	# Play hover sound
	if map_audio:
		map_audio.play_node_hover()

	# Show tooltip or info panel via UI overlay
	if ui_overlay:
		ui_overlay._on_node_hovered(node)

func _on_node_unhovered(node: MapNode3D):
	"""Handle when mouse exits a node"""
	# Hide tooltip or info panel via UI overlay
	if ui_overlay:
		ui_overlay._on_node_unhovered(node)

func _on_player_movement_started(from_node: MapNode3D, to_node: MapNode3D):
	"""Handle when player starts moving"""
	print("Player moving from ", from_node.name if from_node else "null", " to ", to_node.name)

	# Play movement sound
	if map_audio:
		map_audio.play_player_move()

	# Camera will already be focusing from the click handler
	# No need to focus again here

func _on_player_movement_completed(node: MapNode3D):
	"""Handle when player completes movement"""
	print("Player arrived at ", node.name)

	# Play arrival sound
	if map_audio:
		map_audio.play_player_arrive()

	# Update path lines if new nodes were revealed
	if show_path_lines:
		draw_all_path_lines()

func _on_player_arrived_at_node(node: MapNode3D):
	"""Handle when player arrives at a node"""
	emit_signal("player_arrived", node)

	# Trigger node event based on type
	handle_node_event(node)

func handle_node_event(node: MapNode3D):
	"""Handle the event for the node type"""

	match node.encounter_type:
		"fight", "elite", "boss":
			# Start battle
			print("Starting battle at ", node.name)
			# TODO: Transition to battle scene
			pass

		"shop":
			# Open shop
			print("Opening shop at ", node.name)
			# TODO: Open shop UI
			pass

		"rest":
			# Rest site
			print("Resting at ", node.name)
			# TODO: Show rest options
			pass

		"explore":
			# Exploration event
			print("Exploring at ", node.name)
			# TODO: Show exploration event
			pass

		"fireevent", "waterevent", "windevent", "earthevent":
			# Elemental event
			print("Elemental event at ", node.name)
			# TODO: Show elemental event
			pass

		"hub":
			# Portal hub - allow returning to main hub
			print("At portal hub")
			# TODO: Show portal hub options
			pass

func navigate_to_node_in_direction(direction: Vector2):
	"""Navigate to the nearest reachable node in the given direction"""
	if not player or not player.current_node:
		return

	if player.is_moving:
		return  # Don't allow navigation while moving

	var current_pos = player.current_node.global_position
	var best_node: MapNode3D = null
	var best_score: float = -999999.0

	# Find all reachable nodes
	for node in all_nodes:
		if not node.is_reachable or node == player.current_node:
			continue

		# Calculate direction to this node
		var to_node = node.global_position - current_pos
		var node_direction = Vector2(to_node.x, to_node.z).normalized()

		# Calculate how well this node matches the requested direction
		# Dot product gives us alignment (-1 to 1, where 1 is perfect match)
		var alignment = node_direction.dot(direction)

		# Only consider nodes that are somewhat in the right direction (> 0.5)
		if alignment > 0.5:
			# Prefer closer nodes with better alignment
			var distance = Vector2(to_node.x, to_node.z).length()
			var score = alignment * 100.0 - distance  # Prioritize alignment over distance

			if score > best_score:
				best_score = score
				best_node = node

	# Move to the best matching node
	if best_node:
		print("⌨️ Navigating ", direction, " to: ", best_node.name)
		_on_node_clicked(best_node)
	else:
		print("⌨️ No reachable node in direction ", direction)

func _input(event: InputEvent):
	"""Handle input for camera controls and node navigation"""

	# Handle left click on nodes
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🖱️ Left click at: ", event.position)
		handle_node_click(event.position)

	# WASD node navigation
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_W:
			navigate_to_node_in_direction(Vector2(0, -1))  # Up/North
		elif event.keycode == KEY_S:
			navigate_to_node_in_direction(Vector2(0, 1))   # Down/South
		elif event.keycode == KEY_A:
			navigate_to_node_in_direction(Vector2(-1, 0))  # Left/West
		elif event.keycode == KEY_D:
			navigate_to_node_in_direction(Vector2(1, 0))   # Right/East
		elif event.keycode == KEY_SHIFT:
			# Toggle to overview mode (zoomed out view of current node)
			if camera:
				camera.toggle_to_overview()

	# Zoom disabled - camera stays at fixed height
	# if event is InputEventMouseButton:
	# 	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
	# 		camera.zoom_in(1.0)
	# 	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
	# 		camera.zoom_out(1.0)

	# Return camera to default view
	if event.is_action_pressed("ui_cancel"):
		camera.return_to_default()

func handle_node_click(mouse_pos: Vector2):
	"""Manually raycast to detect node clicks"""
	if not camera:
		print("❌ No camera for raycasting")
		return

	# Perform raycast
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result = space_state.intersect_ray(query)

	if result and result.collider:
		var hit_node = result.collider
		print("  🎯 Hit: ", hit_node.name)

		# Check if it's a MapNode3D
		if hit_node is MapNode3D:
			print("  ✅ Is a MapNode3D!")
			_on_node_clicked(hit_node)
		else:
			print("  ⚠️ Not a MapNode3D, type: ", hit_node.get_class())
	else:
		print("  ❌ Raycast didn't hit anything")

func _on_return_to_hub():
	"""Handle return to hub button press"""
	print("Returning to hub...")
	# TODO: Transition back to EarthPortalScene
	# await TransitionFade.fade_out()
	# get_tree().change_scene_to_file("res://EarthPortalScene.tscn")
