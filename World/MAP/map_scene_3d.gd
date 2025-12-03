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
@onready var ui_overlay: MapUIOverlay3D = $UI/MapUIOverlay3D

# Map data
var all_nodes: Array[MapNode3D] = []
var current_level_data: Dictionary = {}

func _ready():
	# Register this map instance with GameSession
	GameSession.map_instance = self

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

	# Check if returning from a battle
	check_battle_result()

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

	# Find the Portal Hub
	var portal_hub = get_node_by_name("PortalHub")
	if portal_hub:
		# Only set player at Portal Hub if we're NOT returning from a battle
		# If there's a battle result, preserve player position
		if GameSession.last_battle_result == "":
			print("🎮 Setting player at Portal Hub (new game)")
			player.set_current_node(portal_hub)
		else:
			print("🎮 Returning from battle, preserving player position")
			# Player position will be restored after battle result is processed

		# Initialize node locking - only 1a, 1b, 1c, and portal hub are unlocked
		initialize_node_locking()

		# Debug: Show which nodes are reachable
		print("📍 Reachable nodes:")
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

	if not path_lines:
		print("❌ PathLines container is NULL!")
		return

	# Clear existing lines
	for child in path_lines.get_children():
		child.queue_free()

	if not player or not player.current_node:
		return

	var lines_drawn = 0
	var current = player.current_node

	# Draw lines from current node to reachable nodes (available paths)
	for node_path in current.connected_nodes:
		var target = current.get_node(node_path) as MapNode3D
		if target and target.is_revealed and target.is_reachable:
			draw_path_line(current, target, Color(0.6, 0.75, 1.0, 0.8))  # Bright blue for available
			lines_drawn += 1

	# Draw traveled paths (from visited nodes)
	for node in all_nodes:
		if node.is_completed:
			for node_path in node.connected_nodes:
				var target = node.get_node(node_path) as MapNode3D
				if target and target.is_completed:
					draw_path_line(node, target, Color(0.4, 0.4, 0.5, 0.5))  # Subtle gray for traveled
					lines_drawn += 1

	if lines_drawn > 0:
		print("✨ Drew ", lines_drawn, " path lines")

func draw_path_line(from_node: MapNode3D, to_node: MapNode3D, line_color: Color = Color(0.5, 0.7, 1.0, 0.8)):
	"""Draw a curved line between two nodes with glow and animation"""

	var start_pos = from_node.global_position
	var end_pos = to_node.global_position
	var distance = start_pos.distance_to(end_pos)

	# Create control point for Bezier curve (arc upward)
	var midpoint = (start_pos + end_pos) / 2.0
	var arc_height = distance * 0.25  # Arc height is 25% of distance
	var control_point = midpoint + Vector3(0, arc_height, 0)

	# Create curved path using multiple segments
	var segments = 20  # Number of segments for smooth curve
	var prev_point = start_pos

	# Create material once for all segments
	var shader_material = ShaderMaterial.new()
	var shader = load("res://World/MAP/path_line.gdshader")
	var material_to_use: Material = null

	if shader:
		shader_material.shader = shader
		shader_material.set_shader_parameter("line_color", line_color)

		# Different colors for different path types
		if line_color.b > 0.7:  # Available path
			shader_material.set_shader_parameter("glow_color", Color(0.7, 0.85, 1.0, 1.0))
			shader_material.set_shader_parameter("glow_intensity", 2.5)
			shader_material.set_shader_parameter("flow_speed", 3.0)
			shader_material.set_shader_parameter("pulse_speed", 2.0)
		else:  # Traveled path
			shader_material.set_shader_parameter("glow_color", Color(0.5, 0.5, 0.6, 1.0))
			shader_material.set_shader_parameter("glow_intensity", 0.6)
			shader_material.set_shader_parameter("flow_speed", 0.8)
			shader_material.set_shader_parameter("pulse_speed", 0.3)

		material_to_use = shader_material
	else:
		# Fallback material
		var fallback_mat = StandardMaterial3D.new()
		fallback_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fallback_mat.albedo_color = line_color
		fallback_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fallback_mat.emission_enabled = true
		fallback_mat.emission = line_color.lightened(0.3)
		fallback_mat.emission_energy_multiplier = 2.0
		material_to_use = fallback_mat

	# Draw segments along the curve
	for i in range(1, segments + 1):
		var t = float(i) / float(segments)

		# Quadratic Bezier curve: B(t) = (1-t)²P0 + 2(1-t)tP1 + t²P2
		var point = (1 - t) * (1 - t) * start_pos + 2 * (1 - t) * t * control_point + t * t * end_pos

		# Create cylinder segment
		var segment = MeshInstance3D.new()
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.05
		cylinder.bottom_radius = 0.05
		cylinder.height = prev_point.distance_to(point)
		cylinder.radial_segments = 12
		cylinder.rings = 1

		segment.mesh = cylinder

		# Position and orient segment
		var segment_midpoint = (prev_point + point) / 2.0
		var segment_direction = (point - prev_point).normalized()

		var up_vector = Vector3.UP
		if abs(segment_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD

		var y_axis = segment_direction
		var x_axis = up_vector.cross(y_axis).normalized()
		var z_axis = y_axis.cross(x_axis).normalized()
		var basis = Basis(x_axis, y_axis, z_axis)

		segment.global_transform = Transform3D(basis, segment_midpoint)
		segment.material_override = material_to_use

		path_lines.add_child(segment)

		prev_point = point

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

func initialize_node_locking():
	"""Lock all nodes except starting nodes (Node_1A, Node_1B, Node_1C, PortalHub)"""
	print("🔒 Initializing node locking system...")

	# Define starting unlocked nodes (multiple variations to catch different naming)
	var starting_nodes = ["Node_1A", "Node_1B", "Node_1C", "Node1A", "Node1B", "Node1C", "1a", "1b", "1c", "PortalHub"]

	for node in all_nodes:
		if node.name in starting_nodes or node.encounter_type == "hub":
			# Unlock and reveal starting nodes
			node.is_reachable = true
			node.is_revealed = true

			# Remove fog effects from unlocked nodes
			if node.has_method("remove_fog_effects"):
				node.remove_fog_effects()

			# Make node fully visible
			if node.mesh_instance:
				var material = node.mesh_instance.get_surface_override_material(0) as StandardMaterial3D
				if material:
					material.albedo_color = node.node_colors.get(node.encounter_type, Color.WHITE)
					material.emission_enabled = true
					material.emission = material.albedo_color * 0.3
					material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

			# Show glow
			if node.glow_effect:
				node.glow_effect.visible = true
				node.glow_effect.light_color = node.node_colors.get(node.encounter_type, Color.WHITE)

			print("  ✅ Unlocked and revealed starting node: ", node.name)
		else:
			# Lock all other nodes
			node.is_reachable = false
			node.is_revealed = false
			print("  🔒 Locked node: ", node.name)

	# Update visuals
	update_node_visuals()

func update_node_reachability():
	"""Update which nodes are reachable based on progression"""
	print("🔄 Updating node reachability...")

	# Always keep PortalHub reachable
	for node in all_nodes:
		if node.name == "PortalHub" or node.encounter_type == "hub":
			node.is_reachable = true
			continue

	# Check progression: when a node is completed, unlock its connected nodes
	for node in all_nodes:
		if node.is_completed:
			print("  ✅ Node ", node.name, " completed, unlocking connected nodes...")

			# Unlock all connected nodes
			for node_path in node.connected_nodes:
				var connected_node = node.get_node(node_path) as MapNode3D
				if connected_node:
					if not connected_node.is_reachable:
						connected_node.is_reachable = true
						connected_node.is_revealed = true
						print("    🔓 Unlocked: ", connected_node.name)

	# Update visual appearance
	update_node_visuals()

	# Redraw path lines
	if show_path_lines:
		draw_all_path_lines()

func update_node_visuals():
	"""Update the visual appearance of all nodes based on their state"""
	for node in all_nodes:
		if not node.is_revealed:
			# Unrevealed nodes stay with fog
			continue

		if node.is_completed:
			# Completed nodes stay reachable (can revisit them)
			node.set_reachable(true)
		elif node.is_reachable:
			# Reachable nodes are highlighted
			node.set_reachable(true)
		else:
			# Revealed but unreachable nodes are dimmed
			node.set_reachable(false)

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
	"""Handle the event for the node type (called automatically when player arrives)"""

	match node.encounter_type:
		"fight", "elite", "boss":
			# Start battle
			print("Starting battle at ", node.name)
			# Note: Don't auto-start, wait for player to press DUEL button
			pass

		"shop":
			# Open shop
			print("Opening shop at ", node.name)
			# Note: Don't auto-open, wait for player to press ENTER SHOP button
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
			pass

func trigger_node_encounter(node: MapNode3D):
	"""Manually trigger the encounter for a node (called by action button)"""
	if not node:
		return

	print("🎯 Triggering encounter for: ", node.name, " (", node.encounter_type, ")")

	match node.encounter_type:
		"fight", "elite", "boss":
			_start_battle(node)

		"shop":
			_open_shop(node)

		"rest":
			_show_rest_site(node)

		"explore":
			_start_exploration(node)

		"fireevent", "waterevent", "windevent", "earthevent":
			_show_elemental_event(node)

		"hub":
			_return_to_hub(node)

func _prepare_arena_payload(node: MapNode3D):
	"""Prepare encounter data for the arena"""
	GameSession.encounter_data = {
		"enemy_name": node.enemy_name,
		"enemy_deck": node.enemy_deck,
		"enemy_leader": node.enemy_leader,
		"difficulty": node.difficulty,
		"ai_style": node.ai_style,
		"rewards": node.rewards,
		"completion": node.is_completed,
		"biome": node.biome
	}
	print("📦 Arena payload prepared for: ", node.enemy_name)

func _start_battle(node: MapNode3D):
	"""Start a battle encounter"""
	print("⚔️ Starting battle at ", node.name)
	_prepare_arena_payload(node)

	# Store battle node name so we can restore player position when returning
	GameSession.encounter_data["battle_node_name"] = node.name

	# Store current node for when player returns
	if player and player.current_node != node:
		# Move player to this node first
		player.set_current_node(node)

	# Don't mark as completed yet - wait for battle result
	# Will be marked complete when player returns victorious

	# Transition to arena
	GameSession.switch_to_arena()

func _open_shop(node: MapNode3D):
	"""Open the shop interface"""
	print("🛒 Opening shop at ", node.name)

	# Try to find and instantiate the shop panel
	var shop_panel_scene = load("res://World/MAP/shop_panel.tscn")
	if shop_panel_scene:
		var shop_panel = shop_panel_scene.instantiate()
		# Add to the scene
		add_child(shop_panel)

		# Connect shop closed signal
		if shop_panel.has_signal("shop_closed"):
			shop_panel.shop_closed.connect(_on_shop_closed.bind(node))

		# Open the shop
		if shop_panel.has_method("open_shop"):
			shop_panel.open_shop()

		# Hide UI overlay while shop is open
		if ui_overlay:
			ui_overlay.visible = false
	else:
		print("❌ Shop panel scene not found!")

func _on_shop_closed(node: MapNode3D):
	"""Handle shop closing"""
	print("🚪 Shop closed at ", node.name)

	# Move player to shop node if not already there
	if player and player.current_node != node:
		player.set_current_node(node)

	# Mark shop node as completed
	on_shop_completed(node)

	# Show UI overlay again
	if ui_overlay:
		ui_overlay.visible = true

func _show_rest_site(node: MapNode3D):
	"""Show rest site options"""
	print("💤 Rest site at ", node.name)
	# TODO: Implement rest site UI

func _start_exploration(node: MapNode3D):
	"""Start exploration event"""
	print("🔍 Exploration at ", node.name)
	# TODO: Implement exploration event

func _show_elemental_event(node: MapNode3D):
	"""Show elemental event"""
	print("🔮 Elemental event at ", node.name)
	# TODO: Implement elemental events

func _return_to_hub(node: MapNode3D):
	"""Return to the main hub"""
	print("🏠 Returning to hub...")
	await TransitionFade.fade_out()
	GameSession.switch_to_hub()

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
	"""Handle return to hub button press (old signal, now handled by trigger_node_encounter)"""
	print("Returning to hub...")
	await TransitionFade.fade_out()
	GameSession.switch_to_hub()

func on_battle_completed(node: MapNode3D):
	"""Called when a battle is completed successfully"""
	if not node:
		return

	print("✅ Battle completed at: ", node.name)
	print("  Connected nodes: ", node.connected_nodes)

	# Mark node as completed
	if not node.is_completed:
		node.complete_node()
		print("  ✓ Node marked as completed")

	# Update reachability to unlock new nodes
	update_node_reachability()

	# Reveal connected nodes from the completed node
	if player:
		print("  🔍 Calling reveal_connected_nodes() from player...")
		player.reveal_connected_nodes()

	# Debug: Show which nodes are now reachable
	print("📊 Reachable nodes after completion:")
	for n in all_nodes:
		if n.is_reachable:
			print("  ✓ ", n.name, " (revealed: ", n.is_revealed, ", completed: ", n.is_completed, ")")

	print("📊 Progression updated - new nodes may be available!")

func on_shop_completed(node: MapNode3D):
	"""Called when shopping is finished"""
	if not node:
		return

	print("🛒 Shop visit completed at: ", node.name)

	# Mark node as completed
	if not node.is_completed:
		node.complete_node()

	# Update reachability to unlock new nodes
	update_node_reachability()

	# Reveal connected nodes from the completed node
	if player:
		player.reveal_connected_nodes()

	print("📊 Progression updated - new nodes may be available!")

func check_battle_result():
	"""Check if we're returning from a battle and handle the result"""
	if GameSession.last_battle_result == "":
		return

	print("🏁 Checking battle result: ", GameSession.last_battle_result)

	# Get the battle node from stored data
	var battle_node_name = GameSession.encounter_data.get("battle_node_name", "")
	if battle_node_name == "":
		print("⚠️ No battle node name stored")
		GameSession.last_battle_result = ""
		return

	var battle_node = get_node_by_name(battle_node_name)
	if not battle_node:
		print("⚠️ Battle node not found: ", battle_node_name)
		GameSession.last_battle_result = ""
		return

	# Restore player to the battle node
	if player:
		print("📍 Restoring player to battle node: ", battle_node.name)
		player.set_current_node(battle_node)

	if GameSession.last_battle_result == "player_won":
		print("🎉 Player won! Completing node: ", battle_node.name)
		on_battle_completed(battle_node)

		# Show rewards if any
		if GameSession.pending_gold_reward > 0:
			GameSession.add_gold(GameSession.pending_gold_reward)
			# TODO: Show reward UI
			GameSession.pending_gold_reward = 0

	elif GameSession.last_battle_result == "player_lost":
		print("💀 Player lost at: ", battle_node.name)
		# Node stays incomplete, player can retry

	# Clear the result
	GameSession.last_battle_result = ""
