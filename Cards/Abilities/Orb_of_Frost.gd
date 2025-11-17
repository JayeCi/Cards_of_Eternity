# Shadow_Candles.gd
# Applies the universal "frozen" status to adjacent enemies
extends CardAbility

func _init():
	display_name = "Orb of Frost"
	description = "When revealed face-up: Freeze all adjacent enemies for 2 turns. They cannot move, attack, or counter-attack."
	value = 2
	range = 1
	trigger = "on_summon"

func execute(arena: Node, unit: UnitData):
	if not arena or not unit:
		return

	# Get current position from the board (always use actual position, not cached)
	var pos: Vector2i = arena.board.get_unit_position(unit)

	if pos == Vector2i(-1, -1):
		return

	# Check all 4 adjacent tiles
	var directions := [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]

	var frozen_count := 0

	for dir in directions:
		var target_pos = pos + dir

		if not arena.board.is_in_bounds(target_pos):
			continue

		if not arena.units.has(target_pos):
			continue

		var target_unit: UnitData = arena.units[target_pos]

		# Only freeze enemy units
		if target_unit.owner == unit.owner:
			continue

		# Skip leaders
		if target_unit.is_leader:
			arena._log("🛡️ %s resists the freeze!" % target_unit.card.name, Color(0.9, 0.7, 0.3))
			continue

		# ✅ Use the universal freeze system
		FrozenStatusEffect.apply_freeze(arena, target_unit, target_pos, value)
		frozen_count += 1

	if frozen_count > 0:
		arena._log("🕯️ Orb of Frost froze %d enemy unit(s)!" % frozen_count, Color(0.6, 0.8, 1.0))
	else:
		arena._log("🕯️ No enemies adjacent to freeze.", Color(0.7, 0.7, 0.7))
