extends CardAbility
class_name BoostAttack

func _init():
	display_name = "Boost Attack"
	description = "Increases this unit's attack power for the rest of this battle."
	value = 2
	range = 0
	trigger = "on_attack"
	
func execute(arena: Node, unit: UnitData) -> void:
	unit.atk += value
	arena.log_message("💥 %s gains +%d ATK!" % [unit.card.name, value], Color(1, 0.9, 0.6))
