extends CardAbility
class_name ChangeTerrainAbility

@export_enum("Grass", "Lava", "Forest", "Water", "Ice", "Stone", "Shadow") var new_terrain := "Grass"

func _init():
	display_name = "Change Terrain"
	description = "When activated, changes its tile and surrounding tiles to the chosen terrain."
	trigger = "on_summon"
	value = 0
	range = 1

# ✅ Standard execute (kept for backwards compatibility)
func execute(arena: Node, unit: UnitData) -> void:
	execute_at(arena, unit, arena.board.get_unit_position(unit))

# ✅ New version: directly specify where to erupt
func execute_at(arena: Node, unit: UnitData, tile_pos: Vector2i) -> void:
	if not arena or not arena.has_method("_log"):
		return
	var board = arena.board
	if not board or tile_pos == Vector2i(-1, -1):
		return

	# Gather nearby tiles (center + surrounding)
	var affected := []
	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var p := tile_pos + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
				continue
			var t = board.get_tile(p.x, p.y)
			if t:
				affected.append(t)

	for t in affected:
		t.terrain_type = new_terrain
		if t.has_method("_apply_terrain_visual"):
			t._apply_terrain_visual()
		if t.occupant:
			arena._apply_terrain_bonus(t.occupant, new_terrain)
			arena._log("🌎 %s now stands on %s terrain!" % [t.occupant.card.name, new_terrain], Color(0.7, 1, 0.8))

	# 🌋 Feedback
	if arena.has_method("_float_text"):
		arena._float_text(board.get_tile(tile_pos.x, tile_pos.y).global_position, "🌋 Eruption!", Color(1, 0.5, 0.3))

	await arena.get_tree().create_timer(0.4).timeout

	# 🧹 Remove the spell card visually and logically
	if arena.has_method("_kill_unit"):
		arena._kill_unit(unit, true) # silent

	var tile = board.get_tile(tile_pos.x, tile_pos.y)
	if tile:
		if tile.has_node("CardModel"):
			var m = tile.get_node("CardModel")
			if is_instance_valid(m):
				var tw = tile.create_tween()
				tw.tween_property(m, "scale", m.scale * 0.3, 0.25)
				tw.parallel().tween_property(m, "modulate:a", 0.0, 0.25)
				await tw.finished
				m.queue_free()

		tile.clear()
