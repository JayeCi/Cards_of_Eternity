extends CardAbility
class_name Vampirism

func _init():
	display_name = "Vampirism"
	description = "Steal 3 DEF after every attack."
	value = 3
	range = 0
	trigger = "on_attack"

func execute(arena: Node, unit: UnitData) -> void:
	if not unit or not unit.card:
		return
	if unit.is_leader or unit.current_def <= 0:
		return

	# 🔎 Find canonical UnitData in core.units (defensive)
	if arena and "units" in arena and arena.units is Dictionary:
		for pos in arena.units.keys():
			if arena.units[pos] == unit:
				unit = arena.units[pos]
				break

	# ➕ Compute terrain-capped max DEF (same approach as regen)
	var board = arena.board if "board" in arena else null
	var tile = null
	if board and board.has_method("get_tile_position_for_unit"):
		tile = board.get_tile_position_for_unit(unit)
	if tile == null:
		# Fallback: scan grid (rare)
		for pos in arena.units.keys():
			if arena.units[pos] == unit:
				tile = arena.board.get_tile(pos.x, pos.y)
				break

	var terrain = tile.terrain_type if tile else ""
	var mult = arena.get_terrain_multiplier(unit, terrain) if "get_terrain_multiplier" in arena else 1.0

	var base_def: float = float(unit.get_meta("base_def")) if unit.has_meta("base_def") else float(unit.card.def)
	var max_def_for_tile := int(round(base_def * mult))

	# 🩸 Heal after attack
	var heal_amount := int(value)
	var old_def := unit.current_def
	unit.current_def = min(unit.current_def + heal_amount, max_def_for_tile)

	# 📝 Log
	if arena and arena.has_method("_log"):
		arena._log("🩸 %s drains life and restores %d DEF! (%d → %d)" %
			[unit.card.name, unit.current_def - old_def, old_def, unit.current_def],
			Color(0.6, 1.0, 0.6))

	# 🔄 Refresh visuals (card details + tile labels)
	if arena and "card_details_ui" in arena and arena.card_details_ui and arena.card_details_ui.visible:
		arena.card_details_ui.call("refresh_if_showing", unit)

	if tile and tile.has_method("update_stat_labels"):
		tile.update_stat_labels(unit.current_atk, unit.current_def)

	# 📣 Notify UI subscribers
	if arena.has_signal("unit_stats_changed"):
		arena.emit_signal("unit_stats_changed", unit)
