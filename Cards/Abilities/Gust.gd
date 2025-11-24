extends CardAbility
class_name Gust

func _init():
	display_name = "Gust"
	description = "Grants +1 movement to friendly units within 2 tiles (including diagonals) while faceup."
	value = 1  # movement bonus
	range = 2  # tile radius
	trigger = "passive"


func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit:
		return

	# Find Gale Spirit's position
	var gale_pos: Vector2i = Vector2i(-1, -1)
	for coord in arena.units.keys():
		if arena.units[coord] == unit:
			gale_pos = coord
			break

	if gale_pos == Vector2i(-1, -1):
		return

	# Clear old bonuses from ALL units first (prevents stacking from multiple Gale Spirits)
	for coord in arena.units.keys():
		var u = arena.units[coord]
		if u.has_meta("movement_bonus_from_gust"):
			u.set_meta("movement_bonus_from_gust", 0)

	var affected_count := 0

	# Apply new bonuses to units within range (including diagonals)
	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var p := gale_pos + Vector2i(dx, dy)

			# Bounds check
			if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
				continue

			# Skip if no unit there
			if not arena.units.has(p):
				continue

			var target: UnitData = arena.units[p]

			# Only affect friendly units (same owner as Gale Spirit)
			if target.owner == unit.owner:
				target.set_meta("movement_bonus_from_gust", value)
				affected_count += 1

	# Log feedback (optional - only if units were affected)
	if affected_count > 0:
		arena._log("🌬 Gale Spirit's Gust empowers %d friendly unit%s with increased mobility!" %
			[affected_count, "s" if affected_count != 1 else ""],
			Color(0.7, 1.0, 0.9))
