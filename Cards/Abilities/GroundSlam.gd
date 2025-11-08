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
	var camera := core.get_node_or_null("CameraSystem")

	core._log("💥 %s slams the ground, shaking the battlefield!" % unit.card.name, Color(1.0, 0.8, 0.4))
	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.4)

	var tiles_in_front := _get_forward_positions(core, unit)
	for pos in tiles_in_front:
		if not board.tiles.has(pos):
			continue

		var tile = board.tiles[pos]
		if tile.occupant:
			var target = tile.occupant
			core._log("⬅ %s is knocked back by the slam!" % target.card.name, Color(1.0, 0.6, 0.6))

			# Deal flat DEF damage
			if slam_damage > 0:
				target.current_def = max(target.current_def - slam_damage, 0)
				core._float_text(tile.global_position + Vector3(0, 1, 0), "-%d DEF" % slam_damage, Color(1, 0.4, 0.4))
				var tile3d = board.get_tile(pos.x, pos.y)
				if tile3d and tile3d.has_method("update_stat_labels"):
					tile3d.update_stat_labels(target.current_atk, target.current_def)

			# Calculate knockback direction
			var dir := Vector2i(0, 1) if unit.owner == core.PLAYER else Vector2i(0, -1)
			var new_pos := pos + dir

			if board.is_in_bounds(new_pos):
				var new_tile := board.get_tile(new_pos.x, new_pos.y)
				if new_tile and not new_tile.occupant:
					# Move the unit in data
					board.get_tile(pos.x, pos.y).set_occupant(null)
					new_tile.set_occupant(target)
					core.units.erase(pos)
					core.units[new_pos] = target

					# Animate model movement
					if target.has_meta("model_instance"):
						var model: Node3D = target.get_meta("model_instance")
						if is_instance_valid(model):
							var tw := model.create_tween()
							var start_pos = model.global_position
							var end_pos = new_tile.global_position + Vector3(0, 0.1, 0)
							tw.tween_property(model, "global_position", end_pos, 0.3).set_trans(Tween.TRANS_SINE)

					core._float_text(new_tile.global_position + Vector3(0, 0.5, 0), "💨", Color(1, 1, 1))
					core._log("%s was pushed to %s!" % [target.card.name, str(new_pos)], Color(0.8, 0.9, 1.0))
					if core.camera.has_method("shake"):
						core.camera.shake(0.15, 0.25)
					board.flash_tiles(tiles_in_front, Color(1.0, 0.8, 0.5), 0.2)
