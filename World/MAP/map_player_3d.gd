extends Node3D
class_name MapPlayer3D

signal movement_started(from_node: MapNode3D, to_node: MapNode3D)
signal movement_completed(node: MapNode3D)
signal arrived_at_node(node: MapNode3D)

@export var movement_speed: float = 5.0
@export var rotation_speed: float = 10.0
@export var hover_height: float = 0.5  # How high above the ground
@export var bounce_amplitude: float = 0.1  # Idle bounce effect
@export var bounce_speed: float = 2.0

var current_node: MapNode3D = null
var target_node: MapNode3D = null
var is_moving: bool = false
var movement_progress: float = 0.0
var start_position: Vector3
var end_position: Vector3
var idle_time: float = 0.0

# Visual components
var model_holder: Node3D
var player_model: Node3D

func _ready():
	# Create a holder for the player model
	model_holder = Node3D.new()
	add_child(model_holder)

	# We'll set the actual model from the scene or load a default one
	setup_player_model()

func _process(delta: float):
	if is_moving:
		process_movement(delta)
	else:
		process_idle_animation(delta)

func setup_player_model():
	"""Set up the visual representation of the player"""

	# For now, create a simple capsule to represent the player
	# Later this can be replaced with the actual leader model
	var mesh_instance = MeshInstance3D.new()
	var capsule = CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.0
	mesh_instance.mesh = capsule

	# Create a material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.6, 1.0, 1.0)  # Blue color for player
	material.emission_enabled = true
	material.emission = Color(0.1, 0.3, 0.5)
	material.metallic = 0.3
	material.roughness = 0.7
	mesh_instance.set_surface_override_material(0, material)

	model_holder.add_child(mesh_instance)
	player_model = mesh_instance

	# Add a glow effect
	var light = OmniLight3D.new()
	light.light_color = Color(0.2, 0.6, 1.0)
	light.light_energy = 1.0
	light.omni_range = 2.0
	model_holder.add_child(light)

func set_current_node(node: MapNode3D):
	"""Set the current node the player is on"""
	print("🎮 Player setting current node to: ", node.name if node else "null")

	if current_node:
		current_node.set_current(false)

	current_node = node

	if current_node:
		current_node.set_current(true)
		current_node.reveal()  # Reveal the node when player arrives

		# Position player at the node
		global_position = current_node.global_position
		global_position.y += hover_height

		print("  📍 Player position: ", global_position)

		# Reveal connected nodes
		reveal_connected_nodes()

		emit_signal("arrived_at_node", current_node)

func reveal_connected_nodes():
	"""Reveal nodes connected to the current node"""
	if not current_node:
		print("  ⚠️ No current node to reveal connections from")
		return

	print("  🔍 Revealing connected nodes from: ", current_node.name)
	print("  📋 Connections: ", current_node.connected_nodes)

	# First, mark ALL nodes as unreachable
	var all_nodes = get_tree().get_nodes_in_group("map_nodes")
	if all_nodes.is_empty():
		# Fallback: get nodes from parent
		var map_scene = get_parent()
		if map_scene and map_scene.has_method("get_all_nodes"):
			all_nodes = map_scene.all_nodes

	for node in all_nodes:
		if node != current_node and node is MapNode3D:
			node.set_reachable(false)

	# Then reveal and mark connected nodes as reachable
	for node_path in current_node.connected_nodes:
		var node = current_node.get_node(node_path) as MapNode3D
		if node:
			print("    ✓ Revealing and enabling: ", node.name)
			node.reveal()
			node.set_reachable(true)
		else:
			print("    ❌ Could not find node at path: ", node_path)

func move_to_node(node: MapNode3D):
	"""Start movement to a target node"""
	if is_moving:
		return

	if not node:
		return

	if not node.is_reachable:
		print("Cannot move to unreachable node: ", node.name)
		return

	# Check if the node is connected to current node
	if current_node and not current_node.is_connected_to(node):
		print("Node is not connected to current node")
		return

	is_moving = true
	target_node = node
	movement_progress = 0.0
	start_position = global_position
	end_position = node.global_position
	end_position.y += hover_height

	emit_signal("movement_started", current_node, target_node)

func process_movement(delta: float):
	"""Process movement animation to target node"""
	movement_progress += delta * movement_speed

	if movement_progress >= 1.0:
		# Movement complete
		movement_progress = 1.0
		is_moving = false

		# Set unreachable on old connections
		if current_node:
			for node_path in current_node.connected_nodes:
				var node = current_node.get_node(node_path) as MapNode3D
				if node:
					node.set_reachable(false)

		set_current_node(target_node)
		emit_signal("movement_completed", current_node)

	# Smooth interpolation with arc
	var t = movement_progress
	var smooth_t = ease(t, -0.5)  # Ease in-out

	# Calculate position with arc
	var base_pos = start_position.lerp(end_position, smooth_t)
	var arc_height = sin(t * PI) * 1.0  # Arc height during movement
	base_pos.y += arc_height

	global_position = base_pos

	# Rotate to face movement direction
	var direction = (end_position - start_position).normalized()
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, delta * rotation_speed)

func process_idle_animation(delta: float):
	"""Add a subtle bounce when idle"""
	idle_time += delta * bounce_speed

	# Apply bounce to model holder, not the player position
	if model_holder:
		var bounce_offset = sin(idle_time) * bounce_amplitude
		model_holder.position.y = bounce_offset

func can_move_to(node: MapNode3D) -> bool:
	"""Check if the player can move to a node"""
	if is_moving:
		return false

	if not node:
		return false

	if not node.is_reachable:
		return false

	if current_node and not current_node.is_connected_to(node):
		return false

	return true

func set_leader_model(leader_card: CardData):
	"""Set the player model based on the leader card"""
	# TODO: Load the 3D model from the leader card
	# For now, we'll keep the default capsule
	pass
