extends CardAbility
class_name TripleStrikeAbility

# Passive ability that marks this unit as having multi-hit attacks
func execute(arena: Node, unit: UnitData):
	if not unit:
		return

	# Set meta property indicating this unit has tri-attack
	unit.set_meta("multi_hit_count", 3)
	unit.set_meta("multi_hit_ability_name", "Tri-Strike")
