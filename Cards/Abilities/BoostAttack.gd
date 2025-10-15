extends CardAbility
class_name BoostAttack

func _init():
	display_name = "Boost Attack"
	description = "Increases this unit's attack power for the rest of this battle."
	value = 2
	range = 0
	trigger = "on_attack"
	
func execute(arena: Node, unit: UnitData) -> void:
	unit.current_atk += value
	unit.atk += value # Optional: keeps base stat updated for UI consistency
	arena._log("💥 %s gains +%d ATK!" % [unit.card.name, value], Color(1, 0.9, 0.6))

	# ✅ Refresh card details UI if this unit is currently displayed
	if arena.card_details_ui:
		arena.card_details_ui.call("refresh_if_showing", unit)
