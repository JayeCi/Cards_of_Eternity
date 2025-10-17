extends CardAbility
class_name Vampirism

func _init():
	display_name = "Vampirism"
	description = "Steal 5 DEF after every attack."
	value = 5
	range = 0
	trigger = "on_attack"

func execute(arena: Node, unit: UnitData) -> void:
	if not unit or not unit.card:
		return
	if unit.is_leader or unit.current_def <= 0:
		return

	# 🧩 Get canonical instance from core.units
	if arena and "units" in arena and arena.units is Dictionary:
		for pos in arena.units.keys():
			if arena.units[pos] == unit:
				unit = arena.units[pos]
				break

	# --- Heal ---
	var heal_amount := int(value)
	var old_def := unit.current_def
	unit.current_def = min(unit.current_def + heal_amount, unit.max_def)

	# --- Log ---
	if arena and arena.has_method("_log"):
		arena._log("🩸 %s drains life and restores %d DEF! (%d → %d)" %
			[unit.card.name, heal_amount, old_def, unit.current_def],
			Color(0.6, 1.0, 0.6))

	# --- Refresh visuals ---
	if arena and arena.has_node("UISystem"):
		var ui_system = arena.get_node("UISystem")

		# ✅ Refresh card details using the correct UnitData
		if ui_system.has_node("ArenaCardDetails"):
			var details = ui_system.get_node("ArenaCardDetails")
			if details.visible and details.has_method("show_unit"):
				details.show_unit(unit)  # force refresh (not just refresh_if_showing)


	# ✅ Notify ArenaUI globally
	if arena.has_signal("unit_stats_changed"):
		arena.emit_signal("unit_stats_changed", unit)
