extends CardAbility
class_name GroundSlamAbility

@export var knockback_distance := 1  # how far each enemy is pushed

# Sound effect
const ROCK_SMASH_SOUND = preload("res://Audio/RockSmash.mp3")

func _init():
	trigger = "on_summon|on_attacked"  # Triggers on reveal OR when attacked
	display_name = "Ground Slam"
	description = "When revealed face-up OR attacked: Slam the ground, creating stone debris and knocking back all enemies (or the attacker) 1 tile backward."

func _get_forward_positions(core: Node, unit: UnitData) -> Array[Vector2i]:
	"""Get the 3 tiles in front of this unit (center + left + right)"""
	var board = core.board
	var positions: Array[Vector2i] = []
	var unit_pos = board.get_unit_position(unit)
	if unit_pos == Vector2i(-1, -1):
		return positions

	# Determine facing direction (forward row)
	var dir := Vector2i(0, 1) if unit.owner == core.PLAYER else Vector2i(0, -1)

	# Find the row directly in front
	var forward_row_y = unit_pos.y + dir.y

	# Collect 3 adjacent tiles in that row (left, center, right)
	for offset_x in [-1, 0, 1]:
		var pos := Vector2i(unit_pos.x + offset_x, forward_row_y)
		if board.is_in_bounds(pos):
			positions.append(pos)

	return positions


func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit:
		return

	var core = arena
	var board = core.board
	var camera = core.get_node_or_null("CameraSystem")

	# 🎵 Play rock smash sound effect
	_play_sound(ROCK_SMASH_SOUND, arena)

	# Check if this is a defensive trigger (being attacked)
	var is_defensive = unit.has_meta("slam_attacker_pos")
	var attacker_pos = unit.get_meta("slam_attacker_pos", Vector2i(-1, -1)) if is_defensive else Vector2i(-1, -1)

	if is_defensive:
		core._log("💥 %s retaliates with a defensive Ground Slam!" % unit.card.name, Color(1.0, 0.8, 0.4))
	else:
		core._log("💥 %s slams the ground with tremendous force!" % unit.card.name, Color(1.0, 0.8, 0.4))

	# Camera shake for dramatic effect
	if camera and camera.has_method("shake"):
		camera.shake(0.3, 0.5)

	# 🛡️ DEFENSIVE MODE: Only target the attacker
	if is_defensive and attacker_pos != Vector2i(-1, -1):
		# Create particle effect on attacker's tile
		var attacker_tile = board.get_tile(attacker_pos.x, attacker_pos.y)
		if attacker_tile:
			_create_slam_particles(attacker_tile, arena)

			# Flash the attacker's tile
			if board.has_method("flash_tiles"):
				board.flash_tiles([attacker_pos], Color(0.8, 0.6, 0.4), 0.15)

			await arena.get_tree().create_timer(0.2).timeout

			# Knockback the attacker
			if attacker_tile.occupant:
				await _knockback_unit(core, board, attacker_tile.occupant, attacker_pos, unit.owner)

		# Clear the meta property
		unit.set_meta("slam_attacker_pos", null)
		return

	# ⚔️ OFFENSIVE MODE: Hit all tiles in front
	# Get current position (always use real-time position, not cached)
	var tiles_in_front := _get_forward_positions(core, unit)

	# Flash tiles before impact
	if board.has_method("flash_tiles"):
		board.flash_tiles(tiles_in_front, Color(0.8, 0.6, 0.4), 0.15)

	await arena.get_tree().create_timer(0.2).timeout

	# Process each tile sequentially for visual impact
	for pos in tiles_in_front:
		if not board.tiles.has(pos):
			continue

		var tile = board.get_tile(pos.x, pos.y)
		if not tile:
			continue

		# Create stone/smoke particle effect on this tile
		_create_slam_particles(tile, arena)

		# Check if tile has an occupant (enemy unit or leader)
		if tile.occupant:
			var target = tile.occupant

			# Only affect enemies
			if target.owner != unit.owner:
				await _knockback_unit(core, board, target, pos, unit.owner)

		# Small delay between each tile impact
		await arena.get_tree().create_timer(0.1).timeout


func _knockback_unit(core: Node, board: Node, target: UnitData, current_pos: Vector2i, attacker_owner: int) -> void:
	"""Knock back a unit (or leader) one tile backward"""
	# Calculate knockback direction (away from attacker)
	var dir := Vector2i(0, 1) if attacker_owner == core.PLAYER else Vector2i(0, -1)
	var new_pos := current_pos + dir

	# Check if knockback destination is valid
	if not board.is_in_bounds(new_pos):
		core._log("🚫 %s resisted knockback (edge of board)!" % target.card.name, Color(0.9, 0.7, 0.5))
		return

	var new_tile = board.get_tile(new_pos.x, new_pos.y)
	if not new_tile:
		return

	# Check if destination is occupied
	if new_tile.occupant:
		core._log("🚫 %s resisted knockback (blocked)!" % target.card.name, Color(0.9, 0.7, 0.5))
		return

	# Perform the knockback
	var old_tile = board.get_tile(current_pos.x, current_pos.y)

	# Update board state
	old_tile.set_occupant(null)
	new_tile.set_occupant(target)
	core.units.erase(current_pos)
	core.units[new_pos] = target

	core._log("⬅ %s was knocked back by the ground slam!" % target.card.name, Color(1.0, 0.6, 0.6))

	# Animate model movement
	if target.has_meta("model_instance"):
		var model: Node3D = target.get_meta("model_instance")
		if is_instance_valid(model):
			var tw := model.create_tween()
			var end_pos = new_tile.global_position + Vector3(0, 0.1, 0)
			tw.tween_property(model, "global_position", end_pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Show knockback effect
	core._float_text(new_tile.global_position + Vector3(0, 0.8, 0), "💨 KNOCKED BACK", Color(1, 0.9, 0.7))

	# Update stat labels if not a leader
	if not target.is_leader:
		if new_tile.has_method("update_stat_labels"):
			new_tile.update_stat_labels(target.current_atk, target.current_def)

	await core.get_tree().create_timer(0.1).timeout


func _create_slam_particles(tile: Node3D, arena: Node) -> void:
	"""Create stone/smoke debris particles on a tile"""
	if not tile or not is_instance_valid(tile):
		return

	var particles = GPUParticles3D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 25
	particles.lifetime = 1.2
	particles.explosiveness = 0.8
	particles.randomness = 0.3
	particles.fixed_fps = 30
	particles.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))
	particles.position = tile.global_position + Vector3(0, 0.1, 0)

	# Create particle material
	var particle_mat = ParticleProcessMaterial.new()

	# Emission from ground
	particle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_mat.emission_box_extents = Vector3(0.8, 0.05, 0.8)

	# Gravity and direction - burst upward then fall
	particle_mat.gravity = Vector3(0, -4.0, 0)
	particle_mat.direction = Vector3(0, 1, 0)
	particle_mat.spread = 45.0
	particle_mat.initial_velocity_min = 2.0
	particle_mat.initial_velocity_max = 4.5

	# Angular velocity for tumbling effect
	particle_mat.angular_velocity_min = -180.0
	particle_mat.angular_velocity_max = 180.0

	# Size variation (rocks and dust)
	particle_mat.scale_min = 0.15
	particle_mat.scale_max = 0.35

	# Damping to slow particles as they rise
	particle_mat.damping_min = 1.5
	particle_mat.damping_max = 2.5

	# Color gradient - brown/gray stone and dust
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.45, 0.35, 0.25, 1.0))  # Dark brown stone
	gradient.add_point(0.3, Color(0.6, 0.5, 0.4, 0.9))     # Lighter brown dust
	gradient.add_point(0.6, Color(0.5, 0.5, 0.5, 0.6))     # Gray smoke
	gradient.add_point(1.0, Color(0.4, 0.4, 0.4, 0.0))     # Fade to transparent
	particle_mat.color_ramp = gradient

	particles.process_material = particle_mat

	# Create visual mesh (cubic chunks for stone debris)
	var particle_mesh = BoxMesh.new()
	particle_mesh.size = Vector3(0.32, 0.32, 0.32)

	# Material for particles
	var particle_visual_mat = StandardMaterial3D.new()
	particle_visual_mat.albedo_color = Color(0.5, 0.4, 0.3, 1.0)
	particle_visual_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particle_visual_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_visual_mat.roughness = 0.8
	particle_mesh.material = particle_visual_mat

	particles.draw_pass_1 = particle_mesh

	# Add to tile
	tile.add_child(particles)

	# Auto-cleanup after lifetime
	await arena.get_tree().create_timer(particles.lifetime + 0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()


func _play_sound(sound: AudioStream, arena: Node) -> void:
	"""Play the rock smash sound effect"""
	if not sound or not arena:
		return
	var player := AudioStreamPlayer.new()
	arena.add_child(player)
	player.stream = sound
	player.volume_db = -5.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()
	player.connect("finished", Callable(player, "queue_free"))
