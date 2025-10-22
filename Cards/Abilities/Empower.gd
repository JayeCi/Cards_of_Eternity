extends CardAbility
class_name Empower

@export var atk_bonus: int = 3
@export var def_bonus: int = 2

func _init():
	display_name = "Empower"
	description = "Gain +3 ATK and +2 DEF while standing on preferred terrain. Lose the bonus when leaving it. "
	trigger = "passive"
	value = 0
	range = 0

func execute(arena: Node, unit: UnitData) -> void:
	if not unit or not unit.card:
		return

	var pos: Vector2i = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		return

	var tile = arena.board.get_tile(pos.x, pos.y)
	if not tile:
		return

	var terrain = tile.terrain_type
	var element := unit.card.element

	# --- Determine if this terrain favors the element
	var mult := 1.0
	if arena.TERRAIN_BONUS.has(terrain) and arena.TERRAIN_BONUS[terrain].has(element):
		mult = arena.TERRAIN_BONUS[terrain][element]

	var on_preferred_terrain := mult >= 1.0

	# --- Has Empower already been applied?
	var empowered = unit.has_meta("empower_active") and unit.get_meta("empower_active")

	# --- CASE 1: Step onto preferred terrain, apply Empower once
	if on_preferred_terrain and not empowered:
		unit.current_atk += atk_bonus
		unit.current_def = min(unit.current_def + def_bonus, unit.max_def)
		unit.set_meta("empower_active", true)

		if arena.has_method("_log"):
			arena._log("💧 %s is empowered by the %s terrain! (+%d ATK / +%d DEF)" % [
				unit.card.name, terrain, atk_bonus, def_bonus
			], Color(0.6, 1.0, 0.9))

		if arena.has_method("_float_text"):
			var pos3d = tile.global_position + Vector3(0, 1.2, 0)
			arena._float_text(pos3d, "+%d/+%d" % [atk_bonus, def_bonus], Color(0.6, 1.0, 0.9))

	# --- CASE 2: Leave preferred terrain, remove Empower
	elif not on_preferred_terrain and empowered:
		unit.current_atk -= atk_bonus
		unit.current_def = max(unit.current_def - def_bonus, 1)
		unit.set_meta("empower_active", false)

		if arena.has_method("_log"):
			arena._log("💨 %s loses Empower leaving %s terrain. (-%d ATK / -%d DEF)" % [
				unit.card.name, terrain, atk_bonus, def_bonus
			], Color(0.8, 0.7, 0.7))

		if arena.has_method("_float_text"):
			var pos3d = tile.global_position + Vector3(0, 1.2, 0)
			arena._float_text(pos3d, "−%d/−%d" % [atk_bonus, def_bonus], Color(0.8, 0.6, 0.6))

	# --- Always update UI
	if tile.has_method("update_stat_labels"):
		tile.update_stat_labels(unit.current_atk, unit.current_def)
	if arena.card_details_ui and arena.card_details_ui.visible:
		arena.card_details_ui.call("refresh_if_showing", unit)
