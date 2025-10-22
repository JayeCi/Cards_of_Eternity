extends CardAbility
class_name BoostAttack

func _init():
	display_name = "Boost Attack"
	description = "Before attacking, increase this unit's attack power by 2 for the rest of this battle."
	value = 2
	range = 0
	trigger = "on_attack"
	
func execute(arena: Node, unit: UnitData) -> void:
	# Keep track of cumulative boosts
	if not unit.has_meta("boost_attack_bonus"):
		unit.set_meta("boost_attack_bonus", 0)

	var current_bonus = unit.get_meta("boost_attack_bonus") + value
	unit.set_meta("boost_attack_bonus", current_bonus)

	# Apply the new total bonus
	unit.current_atk = unit.card.atk + current_bonus

	# ✅ Keep UI in sync
	if arena.has_method("_float_text"):
		var tile_pos = arena.board.get_unit_position(unit)
		var tile = arena.board.get_tile(tile_pos.x, tile_pos.y)

		if tile:
			var pos = tile.global_position + Vector3(0, 1.0, 0)
			arena._float_text(pos, "+%d ATK" % value, Color(1, 0.8, 0.4))

	arena._log("💥 %s gains +%d ATK! (Total bonus: +%d)" %
		[unit.card.name, value, current_bonus], Color(1, 0.9, 0.6))

	# ✅ Refresh card details UI if this unit is currently displayed
	if arena.card_details_ui:
		arena.card_details_ui.call("refresh_if_showing", unit)
