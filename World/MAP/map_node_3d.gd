@tool
extends Area3D
class_name MapNode3D

signal clicked(node: MapNode3D)
signal hovered(node: MapNode3D)
signal unhovered(node: MapNode3D)

@export_enum("hub", "fight", "elite", "boss", "shop", "fireevent", "waterevent", "windevent", "earthevent", "rest", "explore", "unknown")
var encounter_type := "fight"

@export var enemy_name: String = "Tutorial Enemy"
@export var enemy_deck: Array[CardData] = []
@export var enemy_leader: CardData = null
@export var enemy_art_override: Texture2D = null  # Optional: Override enemy leader art in UI
@export var difficulty: int = 1
@export var ai_style: String = "balanced"
@export var rewards: Array[CardData] = []
@export var arena_modifier: String = "none"
@export_enum("OCEAN", "VOLCANO", "FOREST", "MEADOW", "MOUNTAIN", "TUNDRA") var biome: String = "FOREST"
@export var connected_nodes: Array[NodePath] = []
@export var randomize_event: bool = true
@export var battle_completed := false
@export var is_completed := false  # Has player visited this node?
@export var grid_position: Vector2i = Vector2i.ZERO  # Position on the grid
@export_multiline var defeat_message: String
@export_multiline var description: String = "A mysterious encounter awaits..."

var is_reachable := false
var is_current := false
var is_revealed := false  # For fog of war
var battle_started := false

# Visual components
var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var particle_effect: GPUParticles3D
var glow_effect: OmniLight3D
var node_model: Node3D  # Can hold custom 3D models
var fog_particles: GPUParticles3D  # Fog effect for unrevealed nodes
var fog_mesh: MeshInstance3D  # Visual fog cover
var shadow_decal: MeshInstance3D  # Shadow underneath node

# Colors for different node types
var node_colors := {
	"fight": Color(0.8, 0.3, 0.3, 1),
	"elite": Color(0.6, 0.3, 0.8, 1),
	"boss": Color(0.9, 0.2, 0.2, 1),
	"shop": Color(0.9, 0.8, 0.3, 1),
	"fireevent": Color(1.0, 0.4, 0.1, 1),
	"waterevent": Color(0.2, 0.5, 0.9, 1),
	"windevent": Color(0.8, 0.95, 0.9, 1),
	"earthevent": Color(0.5, 0.4, 0.2, 1),
	"rest": Color(0.3, 0.7, 0.4, 1),
	"explore": Color(0.5, 0.5, 0.6, 1),
	"hub": Color(0.4, 0.2, 0.6, 1),
	"unknown": Color(0.3, 0.3, 0.3, 1)
}

func _ready():
	# Only print in game mode, not in editor
	if not Engine.is_editor_hint():
		print("🔧 MapNode3D ready: ", name, " at ", global_position)

	# Add to map_nodes group for easy access
	add_to_group("map_nodes")

	# Set up collision
	setup_collision()

	# Set up visual representation
	setup_visuals()

	# Set up mouse interaction (only in game mode)
	if not Engine.is_editor_hint():
		input_ray_pickable = true
		input_event.connect(_on_input_event)
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
	else:
		# In editor, still make it pickable for selection
		input_ray_pickable = true

	# Set default description if empty
	if description == "":
		set_default_description()

	if not Engine.is_editor_hint():
		print("  ✅ Node setup complete: mesh=", mesh_instance != null, " glow=", glow_effect != null, " pickable=", input_ray_pickable)

func setup_collision():
	"""Create a collision shape for mouse picking"""
	# Check if collision shape already exists (added manually in editor)
	for child in get_children():
		if child is CollisionShape3D:
			collision_shape = child
			if not Engine.is_editor_hint():
				print("  🎯 Using existing collision shape from editor")
			break

	# Only create collision if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape3D.new()
		var shape = SphereShape3D.new()
		shape.radius = 0.6  # Slightly larger for easier clicking
		collision_shape.shape = shape
		add_child(collision_shape)

		if not Engine.is_editor_hint():
			print("  🎯 Created default collision shape")

	# Ensure collision layers are set for mouse picking
	collision_layer = 1
	collision_mask = 1

	# CRITICAL: Enable monitoring for Area3D
	monitorable = true
	monitoring = true

func setup_visuals():
	"""Create the visual representation of the node"""

	# Check if visual components already exist (added manually in editor)
	for child in get_children():
		if child is MeshInstance3D and not mesh_instance:
			mesh_instance = child
			if not Engine.is_editor_hint():
				print("  🎨 Using existing mesh from editor: ", child.name)
		elif child is OmniLight3D and not glow_effect:
			glow_effect = child
			if not Engine.is_editor_hint():
				print("  💡 Using existing light from editor: ", child.name)

	# Only create default mesh if none exists
	if not mesh_instance:
		mesh_instance = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.5
		sphere_mesh.height = 1.0
		mesh_instance.mesh = sphere_mesh

		# Create material
		var material = StandardMaterial3D.new()

		if is_revealed:
			# Show actual color when revealed
			material.albedo_color = node_colors.get(encounter_type, Color.WHITE)
			material.emission_enabled = true
			material.emission = material.albedo_color * 0.3
		else:
			# Hidden/fog of war appearance - very dark silhouette
			material.albedo_color = Color(0.1, 0.1, 0.12, 0.3)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		mesh_instance.set_surface_override_material(0, material)
		add_child(mesh_instance)

		if not Engine.is_editor_hint():
			print("  🎨 Created default sphere mesh")

	# Only create default glow if none exists
	if not glow_effect:
		glow_effect = OmniLight3D.new()
		glow_effect.light_energy = 0.5
		glow_effect.light_color = node_colors.get(encounter_type, Color.WHITE)
		glow_effect.omni_range = 2.0
		glow_effect.visible = is_revealed
		add_child(glow_effect)

		if not Engine.is_editor_hint():
			print("  💡 Created default omni light")

	# Add particles based on encounter type
	if is_revealed and not particle_effect:
		setup_particles()

	# Add fog effects for unrevealed nodes (but not for hub/portal nodes or starting nodes)
	var starting_nodes = ["Node_1A", "Node_1B", "Node_1C", "Node1A", "Node1B", "Node1C", "1a", "1b", "1c", "PortalHub"]
	var is_starting_node = name in starting_nodes or encounter_type == "hub"

	if not is_revealed and not is_starting_node:
		setup_fog_effects()
	elif is_starting_node:
		# Starting nodes should be revealed from the beginning
		is_revealed = true
		is_reachable = true

func setup_particles():
	"""Create particle effects based on node type"""
	# Check if particles already exist
	if particle_effect:
		return  # Don't create duplicates

	particle_effect = GPUParticles3D.new()
	particle_effect.emitting = true
	particle_effect.amount = 20
	particle_effect.lifetime = 2.0
	particle_effect.one_shot = false
	particle_effect.explosiveness = 0.0
	particle_effect.randomness = 0.5

	# Create particle material
	var particle_mat = ParticleProcessMaterial.new()
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.3
	particle_mat.direction = Vector3.UP
	particle_mat.spread = 45.0
	particle_mat.initial_velocity_min = 0.5
	particle_mat.initial_velocity_max = 1.0
	particle_mat.gravity = Vector3(0, 0.5, 0)
	particle_mat.scale_min = 0.05
	particle_mat.scale_max = 0.1

	# Color based on node type
	var color = node_colors.get(encounter_type, Color.WHITE)
	particle_mat.color = color

	particle_effect.process_material = particle_mat

	# Create a simple mesh for particles
	var particle_mesh = SphereMesh.new()
	particle_mesh.radius = 0.05
	particle_effect.draw_pass_1 = particle_mesh

	add_child(particle_effect)

func setup_fog_effects():
	"""Create fog and shadow effects for unrevealed nodes"""
	if not Engine.is_editor_hint():
		print("  🌫️ Setting up fog effects for unrevealed node: ", name)

	# Create fog volume mesh (MUCH larger sphere that envelops the node)
	if not fog_mesh:
		fog_mesh = MeshInstance3D.new()
		fog_mesh.name = "FogVolume"
		var fog_sphere = SphereMesh.new()
		fog_sphere.radius = 1.2  # Much larger than the node
		fog_sphere.height = 2.4
		fog_mesh.mesh = fog_sphere

		# Load or create fog shader material
		var fog_material = ShaderMaterial.new()
		var shader = load("res://World/MAP/fog_of_war.gdshader")
		if shader:
			fog_material.shader = shader
			# Set shader parameters for DRAMATIC fog effect
			fog_material.set_shader_parameter("fog_color", Color(0.05, 0.05, 0.08, 0.95))  # Very dark, very opaque
			fog_material.set_shader_parameter("edge_color", Color(0.3, 0.3, 0.4, 1.0))  # Brighter edges
			fog_material.set_shader_parameter("fog_density", 0.95)
			fog_material.set_shader_parameter("edge_glow", 1.2)
			fog_material.set_shader_parameter("animation_speed", 0.5)

			# Create a noise texture
			var noise = NoiseTexture2D.new()
			var fnoise = FastNoiseLite.new()
			fnoise.noise_type = FastNoiseLite.TYPE_PERLIN
			fnoise.frequency = 0.05
			noise.noise = fnoise
			noise.width = 512
			noise.height = 512
			fog_material.set_shader_parameter("noise_texture", noise)

			fog_mesh.material_override = fog_material
			if not Engine.is_editor_hint():
				print("    ✅ Fog shader applied successfully")
		else:
			# Fallback if shader doesn't load - make it VERY visible
			if not Engine.is_editor_hint():
				print("    ⚠️ Fog shader not found, using fallback material")
			var fallback_mat = StandardMaterial3D.new()
			fallback_mat.albedo_color = Color(0.05, 0.05, 0.1, 0.9)  # Very dark, very opaque
			fallback_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fallback_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			fallback_mat.emission_enabled = true
			fallback_mat.emission = Color(0.1, 0.1, 0.15)
			fog_mesh.material_override = fallback_mat

		add_child(fog_mesh)

	# Create fog particles (swirling mist effect) - MUCH more visible
	if not fog_particles:
		fog_particles = GPUParticles3D.new()
		fog_particles.name = "FogParticles"
		fog_particles.emitting = true
		fog_particles.amount = 50  # More particles
		fog_particles.lifetime = 4.0
		fog_particles.one_shot = false
		fog_particles.explosiveness = 0.0
		fog_particles.randomness = 0.8

		# Create fog particle material
		var fog_particle_mat = ParticleProcessMaterial.new()
		fog_particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		fog_particle_mat.emission_sphere_radius = 1.0  # Larger radius
		fog_particle_mat.direction = Vector3(0, 1, 0)
		fog_particle_mat.spread = 180.0
		fog_particle_mat.initial_velocity_min = 0.2
		fog_particle_mat.initial_velocity_max = 0.5
		fog_particle_mat.gravity = Vector3(0, 0.15, 0)
		fog_particle_mat.scale_min = 0.1  # Bigger particles
		fog_particle_mat.scale_max = 0.2
		fog_particle_mat.color = Color(0.1, 0.1, 0.15, 0.7)  # More opaque

		fog_particles.process_material = fog_particle_mat

		# Create fog particle mesh
		var fog_particle_mesh = SphereMesh.new()
		fog_particle_mesh.radius = 0.15  # Bigger
		fog_particles.draw_pass_1 = fog_particle_mesh

		# Create particle material for better visibility
		var particle_material = StandardMaterial3D.new()
		particle_material.albedo_color = Color(0.1, 0.1, 0.15, 0.8)
		particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fog_particles.draw_pass_1.material = particle_material

		add_child(fog_particles)
		if not Engine.is_editor_hint():
			print("    ✅ Fog particles created")

	# Create shadow decal underneath - MORE visible
	if not shadow_decal:
		shadow_decal = MeshInstance3D.new()
		shadow_decal.name = "Shadow"
		shadow_decal.position = Vector3(0, -0.45, 0)  # Place under the node

		# Create a flat disc for shadow
		var shadow_mesh = CylinderMesh.new()
		shadow_mesh.top_radius = 1.0  # Larger shadow
		shadow_mesh.bottom_radius = 1.0
		shadow_mesh.height = 0.02
		shadow_decal.mesh = shadow_mesh

		# Shadow material - darker and more visible
		var shadow_mat = StandardMaterial3D.new()
		shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.7)  # More opaque
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mat.disable_receive_shadows = true

		shadow_decal.material_override = shadow_mat
		add_child(shadow_decal)
		if not Engine.is_editor_hint():
			print("    ✅ Shadow decal created")

func remove_fog_effects():
	"""Remove fog effects when node is revealed"""
	if not Engine.is_editor_hint():
		print("  🌫️ Removing fog effects from: ", name)

	if fog_mesh:
		fog_mesh.queue_free()
		fog_mesh = null

	if fog_particles:
		fog_particles.queue_free()
		fog_particles = null

	if shadow_decal:
		shadow_decal.queue_free()
		shadow_decal = null

func reveal():
	"""Reveal this node (make it visible, but keep fog until visited)"""
	if is_revealed:
		return

	if not Engine.is_editor_hint():
		print("👁️ Revealing node: ", name)
	is_revealed = true

	# DON'T remove fog effects yet - only when completed
	# Fog effects stay until the node is actually visited

	# Update the base mesh to show node type through the fog
	if mesh_instance:
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			# Show a hint of the color through the fog
			var hint_color = node_colors.get(encounter_type, Color.WHITE) * 0.3
			material.albedo_color = hint_color
			material.emission_enabled = true
			material.emission = hint_color * 0.5
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Keep glow hidden until visited
	if glow_effect:
		glow_effect.visible = false

	# Don't add particles until visited

func complete_node():
	"""Mark node as completed and remove fog effects with animation"""
	if is_completed:
		return

	if not Engine.is_editor_hint():
		print("✅ Completing node: ", name)

	is_completed = true

	# Animate fog removal instead of instant
	animate_fog_removal()

	# Update visuals to full brightness
	if mesh_instance:
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = node_colors.get(encounter_type, Color.WHITE)
			material.emission_enabled = true
			material.emission = material.albedo_color * 0.3
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	# Show glow
	if glow_effect:
		glow_effect.visible = true

	# Add particles
	setup_particles()

func animate_fog_removal():
	"""Animate the fog dissipating"""
	if not Engine.is_editor_hint():
		print("  🌫️ Animating fog removal from: ", name)

	# Animate fog mesh fading out and expanding
	if fog_mesh:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(fog_mesh, "scale", Vector3(1.5, 1.5, 1.5), 0.6)
		tween.tween_property(fog_mesh, "modulate", Color(1, 1, 1, 0), 0.6)

		# Wait then remove
		await tween.finished
		if fog_mesh:
			fog_mesh.queue_free()
			fog_mesh = null

	# Stop and fade out fog particles
	if fog_particles:
		fog_particles.emitting = false
		var tween2 = create_tween()
		tween2.tween_property(fog_particles, "modulate", Color(1, 1, 1, 0), 0.5)
		await tween2.finished
		if fog_particles:
			fog_particles.queue_free()
			fog_particles = null

	# Fade out shadow
	if shadow_decal:
		var tween3 = create_tween()
		tween3.tween_property(shadow_decal, "modulate", Color(1, 1, 1, 0), 0.4)
		await tween3.finished
		if shadow_decal:
			shadow_decal.queue_free()
			shadow_decal = null

func set_default_description():
	"""Set default descriptions based on encounter type"""
	match encounter_type:
		"hub":
			description = "Portal Hub - Return to the central hub"
		"fight":
			description = "Face off against an enemy in a tactical card duel."
		"elite":
			description = "A dangerous elite opponent awaits — tougher rewards too."
		"boss":
			description = "The ultimate test of this realm's strength."
		"shop":
			description = "Trade cards and items for gold."
		"fireevent":
			description = "An elemental event tied to fire energy unfolds here."
		"waterevent":
			description = "An elemental event tied to water energy overflows here."
		"windevent":
			description = "An elemental event tied to wind energy blows here."
		"earthevent":
			description = "An elemental event tied to earth energy resonates here."
		"rest":
			description = "A place of respite and healing."
		"explore":
			description = "Explore, see what you find."

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	"""Handle mouse clicks on the node"""
	if Engine.is_editor_hint():
		return  # Don't handle clicks in editor

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🖱️ Node clicked: ", name, " (reachable: ", is_reachable, ", revealed: ", is_revealed, ")")
		if is_reachable:
			print("  ✅ Moving player to this node")
			emit_signal("clicked", self)
		else:
			print("  ❌ Node not reachable")

func _on_mouse_entered():
	"""Handle mouse hover start"""
	if Engine.is_editor_hint():
		return  # Don't handle hover in editor

	print("🖱️ Mouse entered node: ", name)
	if is_revealed:
		# Increase glow on hover
		if glow_effect:
			glow_effect.light_energy = 1.0

		# Scale up slightly
		if mesh_instance:
			mesh_instance.scale = Vector3(1.2, 1.2, 1.2)

		emit_signal("hovered", self)

func _on_mouse_exited():
	"""Handle mouse hover end"""
	if Engine.is_editor_hint():
		return  # Don't handle hover in editor

	if is_revealed:
		# Reset glow
		if glow_effect:
			glow_effect.light_energy = 0.5

		# Reset scale
		if mesh_instance:
			mesh_instance.scale = Vector3(1.0, 1.0, 1.0)

		emit_signal("unhovered", self)

func set_reachable(reachable: bool):
	"""Mark this node as reachable or not"""
	is_reachable = reachable
	if not Engine.is_editor_hint():
		print("🔄 Node ", name, " reachable set to: ", reachable)

	if is_revealed and mesh_instance:
		var material = mesh_instance.get_surface_override_material(0) as StandardMaterial3D
		if material:
			if reachable:
				# Brighten reachable nodes - make them pulse/stand out
				material.emission_energy_multiplier = 2.0
				# Make them slightly bigger
				mesh_instance.scale = Vector3(1.1, 1.1, 1.1)
			else:
				# Dim unreachable nodes
				material.emission_energy_multiplier = 0.3
				mesh_instance.scale = Vector3(1.0, 1.0, 1.0)

func set_current(current: bool):
	"""Mark this node as the current player position"""
	is_current = current

	if current and glow_effect:
		# Make current node glow brighter
		glow_effect.light_energy = 2.0
		glow_effect.light_color = Color.WHITE

func get_world_position() -> Vector3:
	"""Get the world position of this node"""
	return global_position

func is_connected_to(other_node: MapNode3D) -> bool:
	"""Check if this node is connected to another node"""
	return connected_nodes.has(get_path_to(other_node))
