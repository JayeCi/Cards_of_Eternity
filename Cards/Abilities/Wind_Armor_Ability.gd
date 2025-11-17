extends CardAbility
class_name Wind_Armor_Ability

func _init():
	display_name = "Wind Armor"
	description = "When fused with a WIND monster, permanently increases its DEF by 8."
	trigger = "on_fusion"
	value = 8

# Called automatically when fusion completes.
# 'arena' is the ArenaCore, 'base_unit' is the result of the fusion
func execute(arena: Node, base_unit: UnitData) -> void:
	if not base_unit or not base_unit.card:
		return

	# Only apply if the fused card's element is WIND
	if str(base_unit.card.element).to_lower() != "wind":
		return

	var bonus := int(value)
	var old_def := base_unit.current_def
	base_unit.current_def += bonus

	# Store permanent buff in metadata so terrain changes preserve it
	if not base_unit.has_meta("perm_defense_bonus"):
		base_unit.set_meta("perm_defense_bonus", 0)
	base_unit.set_meta("perm_defense_bonus", base_unit.get_meta("perm_defense_bonus") + bonus)

	# Log and visual feedback
	if arena and arena.has_method("_log"):
		arena._log("🌪️ Wind Armor fortifies %s! +%d DEF (%d → %d)" %
			[base_unit.card.name, bonus, old_def, base_unit.current_def],
			Color(0.6, 1.0, 0.8))

	# Optional floating combat text
	if arena and arena.ui_sys and arena.ui_sys.has_method("_float_text"):
		var tile = arena.board.get_tile_position_for_unit(base_unit)
		if tile:
			var pos3d = tile.global_position + Vector3(0, 1.2, 0)
			arena.ui_sys._float_text(pos3d, "+%d DEF 🌪️" % bonus, Color(0.5, 1.0, 0.7))
