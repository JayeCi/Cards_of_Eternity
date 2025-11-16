# FrozenStatusEffect.gd
# Universal frozen status system - can be used by ANY card/ability
# Save this as an Autoload singleton: Project Settings → Autoload → Add "FrozenStatusEffect"

extends Node

# ===================================================================
# APPLY FREEZE - Called by any ability that freezes units
# ===================================================================
static func apply_freeze(arena: ArenaCore, target: UnitData, pos: Vector2i, duration: int):
	"""
	Freeze a unit for a specified number of turns.
	Can be called by Shadow Candles, Frost Nova, Ice Trap, etc.
	"""
	target.set_meta("frozen", true)
	target.set_meta("frozen_turns_remaining", duration)
	
	var tile := arena.board.get_tile(pos.x, pos.y)
	if tile:
		_update_frozen_visuals(tile, target, true)
	
	arena._log("❄️ %s is frozen for %d turn(s)!" % [target.card.name, duration], Color(0.5, 0.5, 0.9))


# ===================================================================
# REMOVE FREEZE - Called when freeze expires
# ===================================================================
static func remove_freeze(arena: ArenaCore, unit: UnitData, pos: Vector2i):
	"""Remove frozen status and restore visuals"""
	unit.set_meta("frozen", false)
	unit.set_meta("frozen_turns_remaining", 0)
	
	var tile := arena.board.get_tile(pos.x, pos.y)
	if tile:
		_update_frozen_visuals(tile, unit, false)
	
	arena._log("🌟 %s thaws out and can act again!" % unit.card.name, Color(0.7, 0.9, 1.0))


# ===================================================================
# CHECK IF UNIT IS FROZEN
# ===================================================================
static func is_frozen(unit: UnitData) -> bool:
	"""Check if a unit is currently frozen"""
	return unit.has_meta("frozen") and unit.get_meta("frozen")


# ===================================================================
# PROCESS FROZEN UNITS (called at turn start)
# ===================================================================
static func process_frozen_units_turn_start(arena: ArenaCore, owner: int):
	"""Decrease freeze duration for all frozen units of the given owner"""
	for pos in arena.units.keys():
		var unit: UnitData = arena.units[pos]
		if not unit or unit.owner != owner:
			continue
		
		if is_frozen(unit):
			var turns_left: int = unit.get_meta("frozen_turns_remaining")
			turns_left -= 1
			
			if turns_left <= 0:
				remove_freeze(arena, unit, pos)
			else:
				unit.set_meta("frozen_turns_remaining", turns_left)
				arena._log("❄️ %s is frozen (%d turn(s) remaining)." % [unit.card.name, turns_left], Color(0.6, 0.6, 0.9))


# ===================================================================
# VISUAL EFFECTS
# ===================================================================
static func _update_frozen_visuals(tile: Node3D, unit: UnitData, frozen: bool):
	"""Update tile visuals to show frozen state"""
	if frozen:
		# Add frozen badge icon
		if tile.has_method("set_badge_text"):
			var badge := _get_base_badge(unit)
			tile.set_badge_text("❄️" + badge)
		
		# Apply blue tint to card mesh
		if tile.has_node("CardMesh"):
			var mesh := tile.get_node("CardMesh")
			if mesh is MeshInstance3D:
				var mat = mesh.get_active_material(0)
				if mat:
					mat = mat.duplicate()
					mat.albedo_color = Color(0.6, 0.6, 0.9, 1.0)  # Blue frozen tint
					mesh.set_surface_override_material(0, mat)
	else:
		# Restore normal badge
		if tile.has_method("set_badge_text"):
			var badge := _get_base_badge(unit)
			tile.set_badge_text(badge)
		
		# Restore normal color
		if tile.has_node("CardMesh"):
			var mesh := tile.get_node("CardMesh")
			if mesh is MeshInstance3D:
				var mat = mesh.get_active_material(0)
				if mat:
					mat = mat.duplicate()
					mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
					mesh.set_surface_override_material(0, mat)


static func _get_base_badge(unit: UnitData) -> String:
	"""Get the base badge text for a unit based on its state"""
	if unit.owner == 0:  # PLAYER
		return "P"
	else:  # ENEMY
		return "E"
