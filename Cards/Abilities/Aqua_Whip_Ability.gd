extends CardAbility
class_name Aqua_Whip_Ability

func _init():
	display_name = "Aqua Whip"
	description = "When fused with a WATER monster, permanently increases its ATK by 6."
	trigger = "on_fusion"
	value = 6

# Called automatically when fusion completes.
# 'arena' is the ArenaCore, 'base_unit' is the result of the fusion
func execute(arena: Node, base_unit: UnitData) -> void:
	if not base_unit or not base_unit.card:
		return

	# Only apply if the fused card's element is WATER
	if str(base_unit.card.element).to_lower() != "water":
		return

	var bonus := int(value)
	var old_atk := base_unit.current_atk
	base_unit.current_atk += bonus

	# Store permanent buff in metadata so terrain changes preserve it
	if not base_unit.has_meta("perm_attack_bonus"):
		base_unit.set_meta("perm_attack_bonus", 0)
	base_unit.set_meta("perm_attack_bonus", base_unit.get_meta("perm_attack_bonus") + bonus)

	# Log and visual feedback
	if arena and arena.has_method("_log"):
		arena._log("💧 Aqua Whip empowers %s! +%d ATK (%d → %d)" %
			[base_unit.card.name, bonus, old_atk, base_unit.current_atk],
			Color(0.3, 0.7, 1.0))

	# Optional floating combat text
	if arena and arena.ui_sys and arena.ui_sys.has_method("_float_text"):
		var tile = arena.board.get_tile_position_for_unit(base_unit)
		if tile:
			var pos3d = tile.global_position + Vector3(0, 1.2, 0)
			arena.ui_sys._float_text(pos3d, "+%d ATK 💧" % bonus, Color(0.4, 0.8, 1.0))
