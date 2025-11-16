# Shadow_Candles.gd
# Applies the universal "frozen" status to adjacent enemies
extends CardAbility

func _init():
	display_name = "Shadow Candles"
	description = "When revealed face-up: Freeze all adjacent enemies for 2 turns. They cannot move, attack, or counter-attack."
	value = 2
	range = 1
	trigger = "on_summon"
	
func execute(arena: Node, unit: UnitData):
	if not arena or not unit:
		arena._log("⚠️ Shadow Candles: Invalid arena or unit", Color(1, 0.5, 0.5))
		return
	
	# Debug logging
	arena._log("🕯️ Shadow Candles execute() called!", Color(0.9, 0.6, 1.0))
	
	var pos = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		arena._log("⚠️ Shadow Candles: Could not find unit position", Color(1, 0.5, 0.5))
		return
	
	arena._log("🕯️ Shadow Candles activated at position %s! Freezing adjacent enemies..." % str(pos), Color(0.4, 0.2, 0.6))
	
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
		
		arena._log("  → Checking position %s..." % str(target_pos), Color(0.7, 0.7, 0.8))
		
		if not arena.board.is_in_bounds(target_pos):
			arena._log("    ✗ Out of bounds", Color(0.6, 0.6, 0.6))
			continue
		
		if not arena.units.has(target_pos):
			arena._log("    ✗ No unit here", Color(0.6, 0.6, 0.6))
			continue
		
		var target_unit: UnitData = arena.units[target_pos]
		
		# Only freeze enemy units
		if target_unit.owner == unit.owner:
			arena._log("    ✗ Friendly unit (%s)" % target_unit.card.name, Color(0.6, 0.6, 0.6))
			continue
		
		# Skip leaders (optional - you can change this)
		if target_unit.is_leader:
			arena._log("    🛡️ %s resists the freeze (Leaders cannot be frozen)." % target_unit.card.name, Color(0.9, 0.7, 0.3))
			continue
		
		arena._log("    ❄️ Attempting to freeze %s..." % target_unit.card.name, Color(0.4, 0.6, 1.0))
		
		# ✅ Use the universal freeze system
		FrozenStatusEffect.apply_freeze(arena, target_unit, target_pos, value)
		frozen_count += 1
		
		arena._log("    ✓ Successfully frozen %s!" % target_unit.card.name, Color(0.3, 0.8, 1.0))
	
	if frozen_count > 0:
		arena._log("❄️ %d enemy unit(s) frozen by Shadow Candles!" % frozen_count, Color(0.6, 0.4, 0.8))
		
		if arena.has_method("_float_text"):
			var tile = arena.board.get_tile(pos.x, pos.y)
			if tile:
				arena._float_text(tile.global_position + Vector3(0, 1.2, 0), "FROZEN!", Color(0.4, 0.2, 0.6))
	else:
		arena._log("🕯️ No enemies adjacent to freeze.", Color(0.7, 0.7, 0.7))
		
	if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
		await arena.get_tree().create_timer(0.4).timeout
		arena._log("💨 Shadow Candles spell dissipates.", Color(1, 0.6, 0.3))
		arena.battle_sys._kill_unit(unit)
