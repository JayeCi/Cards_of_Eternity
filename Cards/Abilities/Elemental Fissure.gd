extends CardAbility
class_name ElementalFissure

func _init():
	display_name = "Elemental Fissure"
	description = "On Summon | Flip: Changes up to 3 tiles in front of this card to match this card’s element."
	trigger = "on_summon"
	value = 0
	range = 3  # number of tiles forward to affect


# ✅ Standard execution (for direct summons)
func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit or not unit.card:
		return
	var pos = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		return
	execute_at(arena, unit, pos)


# ✅ Directional execution (for summon or flip)
func execute_at(arena: Node, unit: UnitData, origin_pos: Vector2i) -> void:
	if not arena or not unit or not unit.card:
		return
	if origin_pos == Vector2i(-1, -1):
		return

	var board = arena.board
	var new_terrain := unit.card.preferred_terrain
	var changed_tiles: Array = []

	# --- Determine facing direction (down for player, up for enemy) ---
	var dir := Vector2i(0, 1) if unit.owner == arena.PLAYER else Vector2i(0, -1)

	# --- Loop through 1..range tiles straight ahead ---
	for i in range(1, range + 1):
		var p = origin_pos + dir * i
		if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
			break

		var tile = board.get_tile(p.x, p.y)
		if not tile:
			continue

		# Skip if already that terrain
		if tile.terrain_type == new_terrain:
			continue

		# Apply terrain change
		tile.terrain_type = new_terrain
		if tile.has_method("_apply_terrain_visual"):
			tile._apply_terrain_visual(new_terrain)
		changed_tiles.append(tile)

		# Re-apply buffs for any unit on this tile
		if tile.occupant:
			arena._apply_terrain_bonus(tile.occupant, new_terrain)
			arena._log("🌿 %s now resonates with %s terrain!" % [tile.occupant.card.name, new_terrain],
				Color(0.6, 1.0, 0.8))

		# Floating feedback
		if arena.has_method("_float_text"):
			arena._float_text(tile.global_position + Vector3(0, 1, 0), new_terrain, Color(0.5, 0.9, 1.0))

		await arena.get_tree().create_timer(0.1).timeout  # stagger visuals a bit

	# 🌎 Summary feedback
	if changed_tiles.size() > 0:
		arena._log("🌪 %s’s Elemental Fissure spread %d tiles of %s energy forward!" %
			[unit.card.name, changed_tiles.size(), new_terrain],
			Color(0.7, 1.0, 0.8))

		var center_tile = board.get_tile(origin_pos.x, origin_pos.y)
		if center_tile and center_tile.has_method("pulse_move_highlight"):
			center_tile.pulse_move_highlight()
	else:
		arena._log("💨 %s’s Elemental Fissure fizzled — no tiles changed." % unit.card.name,
			Color(0.8, 0.8, 0.8))
