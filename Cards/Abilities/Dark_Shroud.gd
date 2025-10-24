extends CardAbility
class_name OrbOfDarkness

func _init():
	display_name = "Orb of Darkness"
	description = "Reduce all enemy units’ ATK/DEF by 2 per Shadow ally for 2 turns. If 3+ Shadows exist, destroy the weakest enemy."
	value = 2
	trigger = "on_summon"

func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit:
		return
	
	# 🩸 Count all Shadow-type allies
	var shadow_count := 0
	for pos in arena.units.keys():
		var ally = arena.units[pos]
		if ally.owner == arena.PLAYER and ally.card and ally.card.element == "Shadow":
			shadow_count += 1

	if shadow_count == 0:
		arena._log("⚫ The orb hums quietly... but finds no darkness to feed on.")
		await _fade_and_kill(arena, unit)
		return

	var debuff_amt := shadow_count * value
	var enemies: Array = []

	for pos in arena.units.keys():
		var enemy = arena.units[pos]
		if enemy.owner != arena.PLAYER and not enemy.is_leader:
			enemies.append(enemy)

	# 🔹 Apply debuff to all enemies
	for e in enemies:
		e.current_atk = max(0, e.current_atk - debuff_amt)
		e.current_def = max(0, e.current_def - debuff_amt)
		
		# 🕶 Hide name if facedown
		var target_name = "Enemy Facedown Card" if (e.is_facedown or (e.has_meta("is_facedown") and e.get_meta("is_facedown"))) else e.card.name
		
		arena._log("☠️ %s loses %d ATK and DEF!" % [target_name, debuff_amt], Color(0.5, 0.5, 1))
		e.set_meta("dark_shroud_turns", 2)

	# 🔹 Bonus effect: destroy weakest enemy
	if shadow_count >= 3 and enemies.size() > 0:
		enemies.sort_custom(Callable(self, "_sort_by_def"))
		var weakest = enemies[0]
		var name = "Enemy Facedown Card" if (weakest.is_facedown or (weakest.has_meta("is_facedown") and weakest.get_meta("is_facedown"))) else weakest.card.name
		arena._log("💀 The darkness devours %s!" % name, Color(0.3, 0.3, 1))
		arena.destroy_unit(weakest, false)

	# 🔹 Visuals + camera feedback
	if arena.has_node("UISystem"):
		arena.get_node("UISystem").show_battle_message("🌑 Orb of Darkness Activated!", 2.0)
	if arena.has_node("CameraSystem"):
		arena.get_node("CameraSystem").shake(0.15, 0.4)

	# 💨 Remove the spell after a short delay
	await _fade_and_kill(arena, unit)


# ---------------------------------------------------------
# HELPERS
# ---------------------------------------------------------
func _fade_and_kill(arena: Node, unit: UnitData) -> void:
	await arena.get_tree().create_timer(0.4).timeout
	arena._log("💨 Orb of Darkness dissipates into the void.", Color(0.7, 0.7, 1.0))

	if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
		arena.battle_sys._kill_unit(unit)
	elif arena.has_method("destroy_unit"):
		arena.destroy_unit(unit, true)
	elif "core" in arena and arena.core.has_method("destroy_unit"):
		arena.core.destroy_unit(unit, true)

func _sort_by_def(a, b) -> bool:
	return a.current_def < b.current_def
