# FrozenStatusEffect.gd
# Universal frozen status system - can be used by ANY card/ability
# Save this as an Autoload singleton: Project Settings → Autoload → Add "FrozenStatusEffect"

extends Node

# Freeze sound effect
const FREEZE_SOUND = preload("res://Audio/Sound FX/ICE.mp3")

# ===================================================================
# APPLY FREEZE - Called by any ability that freezes units
# ===================================================================
static func apply_freeze(arena: Node, target: UnitData, pos: Vector2i, duration: int):
	"""
	Freeze a unit for a specified number of turns.
	Can be called by Shadow Candles, Frost Nova, Ice Trap, etc.
	"""
	target.set_meta("frozen", true)
	target.set_meta("frozen_turns_remaining", duration)

	var tile = arena.board.get_tile(pos.x, pos.y)
	if tile:
		_update_frozen_visuals(tile, target, true)

	# 🎵 Play freeze sound effect
	_play_freeze_sound(arena)

	arena._log("❄️ %s is frozen for %d turn(s)!" % [target.card.name, duration], Color(0.5, 0.5, 0.9))


# ===================================================================
# REMOVE FREEZE - Called when freeze expires
# ===================================================================
static func remove_freeze(arena: Node, unit: UnitData, pos: Vector2i):
	"""Remove frozen status and restore visuals"""
	unit.set_meta("frozen", false)
	unit.set_meta("frozen_turns_remaining", 0)
	
	var tile = arena.board.get_tile(pos.x, pos.y)
	if tile:
		_update_frozen_visuals(tile, unit, false)
	
	arena._log("🌟 %s thaws out and can act again!" % unit.card.name, Color(0.7, 0.9, 1.0))


# ===================================================================
# CHECK IF UNIT IS FROZEN
# ===================================================================
static func is_frozen(unit: UnitData) -> bool:
	"""Check if a unit is currently frozen"""
	return unit.has_meta("frozen") and unit.get_meta("frozen")


# ===================================================================
# PROCESS FROZEN UNITS (called at turn start)
# ===================================================================
static func process_frozen_units_turn_start(arena: Node, owner: int):
	"""Decrease freeze duration for all frozen units of the given owner"""
	for pos in arena.units.keys():
		var unit: UnitData = arena.units[pos]
		if not unit or unit.owner != owner:
			continue
		
		if is_frozen(unit):
			var turns_left: int = unit.get_meta("frozen_turns_remaining")
			turns_left -= 1
			
			if turns_left <= 0:
				remove_freeze(arena, unit, pos)
			else:
				unit.set_meta("frozen_turns_remaining", turns_left)
				arena._log("❄️ %s is frozen (%d turn(s) remaining)." % [unit.card.name, turns_left], Color(0.6, 0.6, 0.9))


# ===================================================================
# VISUAL EFFECTS
# ===================================================================
static func _update_frozen_visuals(tile: Node3D, unit: UnitData, frozen: bool):
	"""Update tile visuals to show frozen state"""
	if frozen:
		# Add frozen badge icon
		if tile.has_method("set_badge_text"):
			var badge := _get_base_badge(unit)
			tile.set_badge_text("❄️" + badge)

		# Apply dark blue tint to card mesh
		if tile.has_node("CardMesh"):
			var mesh := tile.get_node("CardMesh")
			if mesh is MeshInstance3D:
				var mat = mesh.get_active_material(0)
				if mat:
					mat = mat.duplicate()
					mat.albedo_color = Color(0.2, 0.3, 0.6, 1.0)  # Dark blue frozen tint
					mesh.set_surface_override_material(0, mat)

		# ✨ Create and attach frozen orb
		_create_frozen_orb(tile)
	else:
		# Restore normal badge
		if tile.has_method("set_badge_text"):
			var badge := _get_base_badge(unit)
			tile.set_badge_text(badge)

		# Restore normal color
		if tile.has_node("CardMesh"):
			var mesh := tile.get_node("CardMesh")
			if mesh is MeshInstance3D:
				var mat = mesh.get_active_material(0)
				if mat:
					mat = mat.duplicate()
					mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
					mesh.set_surface_override_material(0, mat)

		# ✨ Remove frozen orb
		_remove_frozen_orb(tile)


# ===================================================================
# FROZEN ORB 3D VISUAL
# ===================================================================
static func _create_frozen_orb(tile: Node3D):
	"""Create a 3D blue orb above the frozen unit"""
	if not tile:
		return

	# Don't create duplicate orbs
	if tile.has_node("FrozenOrb"):
		return

	# Create orb container
	var orb_container = Node3D.new()
	orb_container.name = "FrozenOrb"
	tile.add_child(orb_container)

	# Position above the card/model
	orb_container.position = Vector3(0, 1.0, 0)

	# Create sphere mesh
	var mesh_instance = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.3
	mesh_instance.mesh = sphere

	# Create glowing blue material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.5, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.7, 1.0)
	mat.emission_energy_multiplier = 2.0
	mat.metallic = 0.3
	mat.roughness = 0.2
	mesh_instance.material_override = mat

	orb_container.add_child(mesh_instance)

	# ❄️ Create freezing dripping particle effect
	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = false
	particles.amount = 30
	particles.lifetime = 1.5
	particles.preprocess = 0.0  # No preprocess to avoid freeze
	particles.speed_scale = 0.5
	particles.explosiveness = 0.0
	particles.randomness = 0.4
	particles.fixed_fps = 30
	particles.visibility_aabb = AABB(Vector3(-1, -2, -1), Vector3(2, 3, 2))

	# Create particle material for freezing drips
	var particle_mat = ParticleProcessMaterial.new()

	# Emission shape - sphere around the orb
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_mat.emission_sphere_radius = 0.2

	# Gravity and direction - drip downward
	particle_mat.gravity = Vector3(0, -1.5, 0)
	particle_mat.direction = Vector3(0, -1, 0)
	particle_mat.spread = 30.0
	particle_mat.initial_velocity_min = 0.2
	particle_mat.initial_velocity_max = 0.6

	# Size - make particles more visible
	particle_mat.scale_min = 0.08
	particle_mat.scale_max = 0.15

	# Color - icy blue gradient with full opacity at start
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.95, 1.0, 1.0))  # Bright icy blue
	gradient.add_point(0.7, Color(0.5, 0.8, 1.0, 0.6))   # Mid blue, fading
	gradient.add_point(1.0, Color(0.3, 0.6, 0.9, 0.0))   # Fade to transparent
	particle_mat.color_ramp = gradient

	particles.process_material = particle_mat

	# Create visual mesh for particles (simple quad for better performance)
	var particle_mesh = QuadMesh.new()
	particle_mesh.size = Vector2(0.1, 0.1)

	# Create simple billboard material for particles
	var particle_visual_mat = StandardMaterial3D.new()
	particle_visual_mat.albedo_color = Color(0.8, 0.95, 1.0, 0.9)
	particle_visual_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_visual_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_visual_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	particle_visual_mat.emission_enabled = true
	particle_visual_mat.emission = Color(0.6, 0.9, 1.0)
	particle_visual_mat.emission_energy_multiplier = 2.0
	particle_mesh.material = particle_visual_mat

	particles.draw_pass_1 = particle_mesh
	orb_container.add_child(particles)

	# Add floating animation
	var tween = tile.create_tween()
	tween.set_loops(0)
	tween.tween_property(orb_container, "position:y", 2.3, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(orb_container, "position:y", 2.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Add rotation animation
	var rotate_tween = tile.create_tween()
	rotate_tween.set_loops(0)
	rotate_tween.tween_property(mesh_instance, "rotation:y", TAU, 3.0).set_trans(Tween.TRANS_LINEAR)


static func _remove_frozen_orb(tile: Node3D):
	"""Remove the frozen orb from the tile"""
	if not tile:
		return

	if tile.has_node("FrozenOrb"):
		var orb = tile.get_node("FrozenOrb")
		orb.queue_free()


static func _get_base_badge(unit: UnitData) -> String:
	"""Get the base badge text for a unit based on its state"""
	if unit.owner == 0:  # PLAYER
		return "P"
	else:  # ENEMY
		return "E"


static func _play_freeze_sound(arena: Node) -> void:
	"""Play the freeze sound effect"""
	if not FREEZE_SOUND:
		return

	var player := AudioStreamPlayer.new()
	arena.add_child(player)
	player.stream = FREEZE_SOUND
	player.volume_db = -5.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()
	player.connect("finished", Callable(player, "queue_free"))
