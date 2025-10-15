extends CardAbility
class_name FrozenAura

func _init():
	display_name = "Frozen Aura"
	description = "At the start of each turn, decreases DEF of adjacent enemy units permenantly by 1."
	value = 2
	range = 1
	trigger = "passive"
	print("✅ FrozenAura initialized.")
# Called once when the unit enters the field or at each turn tick

func execute(arena: Node, unit: UnitData) -> void:
	print("🧊 FrozenAura.execute() called for", unit.card.name)

	if not arena or not unit:
		return

	# Find the unit's current grid position (Vector2i)
	var pos: Vector2i = Vector2i(-1, -1)
	for coord in arena.units.keys():
		if arena.units[coord] == unit:
			pos = coord
			break

	if pos == Vector2i(-1, -1):
		return  # couldn't find this unit on board

	# Apply aura effect to adjacent enemies
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var p: Vector2i = pos + d
		if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
			continue
		if not arena.units.has(p):
			continue

		var target: UnitData = arena.units[p]
		if target.owner != unit.owner:
			target.current_def = max(0, target.current_def - value)
			arena._log("❄️ %s's Frozen Aura chills %s (-%d DEF)" % [
				unit.card.name, target.card.name, value
			], Color(0.6, 0.8, 1))
		if arena.card_details_ui:
			arena.card_details_ui.call("refresh_if_showing", target)
		if arena.board:
			for coord in arena.units.keys():
				var tile = arena.board.get_tile(coord.x, coord.y)
				if tile and tile.occupant == arena.units[coord]:
					tile.set_art(tile.occupant.card.art, tile.occupant.owner == arena.ENEMY)
