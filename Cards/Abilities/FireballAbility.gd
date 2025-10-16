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

	# Log and effect
	arena._log("🔥 Fireball scorches the enemy leader for %d damage!" % damage, Color(1, 0.4, 0.4))
	# Apply the damage
	arena.damage_leader(arena.ENEMY, damage)

	# Optional: add visual flash or particles if you have a UI system
	if arena.ui_sys and arena.ui_sys.has_method("show_battle_message"):
		arena.ui_sys.show_battle_message("🔥 %d Damage to Enemy Leader!" % damage, 1.5)
		
	if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
		await arena.get_tree().create_timer(0.4).timeout
		arena._log("💨 Fireball spell dissipates.", Color(1, 0.6, 0.3))
		arena.battle_sys._kill_unit(unit)
