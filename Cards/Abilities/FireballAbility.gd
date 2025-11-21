extends CardAbility
class_name FireballAbility

@export var damage: int = 5

func _init():
	trigger = "on_summon"
	display_name = "Fireball"
	description = "Inflicts damage to the enemy leader when summoned face up."
	value = damage
	range = 0  # direct attack

func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not arena.has_method("damage_leader"):
		push_warning("ArenaCore missing 'damage_leader' method.")
		return

	# 🎥 Focus camera on enemy leader
	var cam = null
	if arena.has_node("CameraSystem"):
		cam = arena.get_node("CameraSystem")

	if cam:
		# Find enemy leader position by searching through units
		var enemy_leader_pos = Vector3.ZERO
		for pos in arena.units.keys():
			var u = arena.units[pos]
			if u and u.is_leader and u.owner == arena.ENEMY:
				var tile = arena.board.get_tile(pos.x, pos.y)
				if tile:
					enemy_leader_pos = tile.global_position
				break

		# Zoom in on enemy leader
		if enemy_leader_pos != Vector3.ZERO:
			cam.focus_on_battle(enemy_leader_pos, enemy_leader_pos, true)
			await arena.get_tree().create_timer(0.4).timeout

	# Log and effect
	arena._log("🔥 Fireball scorches the enemy leader for %d damage!" % damage, Color(1, 0.4, 0.4))
	# Apply the damage
	arena.damage_leader(arena.ENEMY, damage)

	# Optional: add visual flash or particles if you have a UI system
	if arena.ui_sys and arena.ui_sys.has_method("show_battle_message"):
		arena.ui_sys.show_battle_message("🔥 %d Damage to Enemy Leader!" % damage, 1.5)

	await arena.get_tree().create_timer(0.5).timeout

	# 🎥 Return camera to normal position
	if cam:
		cam.focus_on_battle(Vector3.ZERO, Vector3.ZERO, false)
		await arena.get_tree().create_timer(0.3).timeout

	if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
		arena._log("💨 Fireball spell dissipates.", Color(1, 0.6, 0.3))
		arena.battle_sys._kill_unit(unit)
