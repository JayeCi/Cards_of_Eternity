extends CardAbility
class_name GroundSlamAbility

@export var knockback_distance := 1  # how far each enemy is pushed
@export var knockback_range := 3     # how many tiles forward are affected
@export var slam_damage := 2         # optional flat damage

func _get_forward_positions(core: ArenaCore, unit: UnitData) -> Array[Vector2i]:
	var board := core.board
	var positions: Array[Vector2i] = []
	var unit_pos := board.get_unit_position(unit)
	if unit_pos == Vector2i(-1, -1):
		return positions

	# Determine facing direction (forward row)
	var dir := Vector2i(0, 1) if unit.owner == core.PLAYER else Vector2i(0, -1)

	# Find the row directly in front
	var forward_row_y := unit_pos.y + dir.y

	# Collect 3 adjacent tiles in that row (center, left, right)
	for offset_x in [-1, 0, 1]:
		var pos := Vector2i(unit_pos.x + offset_x, forward_row_y)
		if board.is_in_bounds(pos):
			positions.append(pos)

	return positions


func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit:
		return

	var core: ArenaCore = arena
	var board := core.board
	var camera := core.camera_sys if core.has_node("CameraSystem") else null

	
	core._log("💥 %s slams the ground, shaking the battlefield!" % unit.card.name, Color(1.0, 0.8, 0.4))
	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.4)

	# Get all tiles in front of unit
	var tiles_in_front := _get_forward_positions(core, unit)
	for pos in tiles_in_front:
		if not board.tiles.has(pos):
			continue
		var tile = board.tiles[pos]
		if tile.occupant:
			var target = tile.occupant
			core._log("⬅ %s is knocked back by the slam!" % target.card.name, Color(1.0, 0.6, 0.6))

			# Optional: small damage
			if slam_damage > 0:
				target.current_def = max(target.current_def - slam_damage, 0)
				core._float_text(tile.global_position + Vector3(0, 1, 0), "-%d DEF" % slam_damage, Color(1, 0.4, 0.4))
				var tile3d = board.get_tile_position_for_unit(target)
				if tile3d and tile3d.has_method("update_stat_labels"):
					tile3d.update_stat_labels(target.current_atk, target.current_def)
			
			# Try to push them back 1 tile
			var dir := Vector2i(0, 1) if unit.owner == core.PLAYER else Vector2i(0, -1)
			var new_pos := pos + dir
			if board.is_in_bounds(new_pos) and not board.get_tile(new_pos.x, new_pos.y).occupant:
				# Move the unit
				var prev_tile := board.get_tile(pos.x, pos.y)
				prev_tile.set_occupant(null)
				var new_tile := board.get_tile(new_pos.x, new_pos.y)
				new_tile.set_occupant(target)
				core.units.erase(pos)
				core.units[new_pos] = target
				# Animate
				if new_tile and new_tile.has_node("CardModel"):
					var model = new_tile.get_node("CardModel")
					var tween = new_tile.create_tween()
					tween.tween_property(model, "position:y", 0.3, 0.1).set_trans(Tween.TRANS_SINE)
					tween.tween_property(model, "position:y", 0.0, 0.1).set_trans(Tween.TRANS_SINE)
	#
	#var tile3d := board.get_tile_position_for_unit(unit)
	#if tile3d:
		#var dust: GPUParticles3D = GPUParticles3D.new()
		#dust.amount = 60
		#dust.lifetime = 0.6
		#dust.one_shot = true
		#dust.emitting = true
		#dust.scale = Vector3(0.6, 0.6, 0.6)
#
		## Optional: small upward offset so it’s visible
		#dust.position = Vector3(0, 0.05, 0)
#
		## Optionally use a built-in material for quick dirt burst
		#var mat := StandardMaterial3D.new()
		#mat.albedo_color = Color(0.5, 0.4, 0.3)
		#dust.draw_pass_1 = QuadMesh.new()
		#dust.material_override = mat
#
		#tile3d.add_child(dust)
