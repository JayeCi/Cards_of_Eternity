extends CardAbility
class_name ChangeTerrainAbility

@export_enum("Grass", "Lava", "Forest", "Water", "Ice", "Stone", "Shadow") var new_terrain := "Grass"

func _init():
	display_name = "Change Terrain"
	description = "When activated, changes its tile and surrounding tiles to the chosen terrain."
	trigger = "on_summon"  # fires when placed face-up
	value = 0
	range = 1               # radius of effect (1 = surrounding 8 tiles)

func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not arena.has_method("_log"):
		return

	var board = arena.board
	if not board:
		return

	# Find this unit’s tile
	var tile_pos := Vector2i(-1, -1)
	for pos in arena.units.keys():
		if arena.units[pos] == unit:
			tile_pos = pos
			break
	if tile_pos == Vector2i(-1, -1):
		return

	# Collect all nearby tiles (including center)
	var affected := []
	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var p := tile_pos + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
				continue
			var t = board.get_tile(p.x, p.y)
			if t:
				affected.append(t)

	# Apply terrain change to each
	for t in affected:
		t.terrain_type = new_terrain
		if t.has_method("_apply_terrain_visual"):
			t.terrain_type = new_terrain
			t._apply_terrain_visual()

			# Optional glow or pulse
			var tw = t.create_tween()
			tw.tween_property(t, "scale", t.scale * 1.1, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(t, "scale", t.scale, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


		# Reapply terrain bonuses to any occupant
		if t.occupant:
			arena._log("🌎 %s is now on %s terrain!" % [t.occupant.card.name, new_terrain], Color(0.6, 1, 0.8))
			arena._apply_terrain_bonus(t.occupant, new_terrain)

	# Visual feedback
	if arena.has_method("_float_text"):
		arena._float_text(board.get_tile(tile_pos.x, tile_pos.y).global_position, "🌿 Terrain Changed!", Color(0.7, 1, 0.7))

	arena._log("🌿 Terrain shifted around %s’s position to %s." % [unit.card.name, new_terrain], Color(0.7, 1, 0.7))

	# ✨ Optional effect message
	if arena.has_method("_float_text"):
		arena._float_text(board.get_tile(tile_pos.x, tile_pos.y).global_position, "✨ Spell Resolved", Color(1, 0.9, 0.6))

	# 🧹 Remove spell after short delay
	await arena.get_tree().create_timer(0.3).timeout

	if arena.has_method("_kill_unit"):
		arena._kill_unit(unit)

	# ✅ Also remove the card’s visual from the board (for spells)
	var tile = arena.board.get_tile(tile_pos.x, tile_pos.y)
	if tile:
		# Fade out the model or mesh if exists
		if tile.has_node("CardModel"):
			var model = tile.get_node("CardModel")
			if is_instance_valid(model):
				var tw = tile.create_tween()
				tw.tween_property(model, "modulate:a", 0.0, 0.3)
				tw.tween_property(model, "scale", model.scale * 0.5, 0.3)
				await tw.finished
				model.queue_free()
		if tile.has_node("CardMesh"):
			var mesh = tile.get_node("CardMesh")
			if is_instance_valid(mesh):
				var tw2 = tile.create_tween()
				tw2.tween_property(mesh, "modulate:a", 0.0, 0.3)
				tw2.tween_property(mesh, "scale", mesh.scale * 0.5, 0.3)
				await tw2.finished
				mesh.queue_free()
		
		# Clear the tile’s occupant + art
		tile.clear()
