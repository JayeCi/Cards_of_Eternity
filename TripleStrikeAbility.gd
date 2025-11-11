extends CardAbility
class_name TripleStrikeAbility

@export var delay_between_hits := 0.5   # seconds between each attack visual


func execute(arena: Node, unit: UnitData):
	if not arena or not unit:
		return

	# ✅ Ensure this only runs during an attack phase
	if trigger != "on_attack":
		return

	var battle := arena if arena is ArenaBattle else arena.get_node_or_null("BattleSystem")
	if not battle:
		push_error("TripleStrikeAbility: ArenaBattle not found.")
		return

	var core = battle.core
	if not core or not core.board:
		return

	# ✅ Attacker tile
	var attacker_pos = core.board.get_unit_position(unit)
	var attacker_tile = core.board.get_tile(attacker_pos.x, attacker_pos.y)

	# ✅ Defender tile detection
	var defender_tile: Node3D = null

	# Preferred: check if ArenaBattle stored last attack target
	if core.has_meta("last_attack_target"):
		var last_target = core.get_meta("last_attack_target")
		if last_target is Vector2i:
			defender_tile = core.board.get_tile(last_target.x, last_target.y)

	# Fallback: try to use internal combat cache if any
	if not defender_tile and battle.has_method("get_last_target_tile"):
		defender_tile = battle.get_last_target_tile()

	# Fallback 2: pick any opposing adjacent tile if found
	if not defender_tile:
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var check = attacker_pos + dir
			var t = core.board.get_tile(check.x, check.y)
			if t and t.occupant and t.occupant.owner != unit.owner:
				defender_tile = t
				break

	# ✅ Validate target
	if not defender_tile or not defender_tile.occupant:
		core._log("⚠️ Triple Strike: No valid defender found.", Color(1, 0.6, 0.6))
		return

	var defender = defender_tile.occupant
	core._log("🔥 %s unleashes Triple Strike!" % unit.card.name, Color(1, 0.8, 0.3))

	# 🔁 Perform 3 rapid hits visually + logically
	for i in range(3):
		core._log("💥 Hit %d!" % (i + 1), Color(1, 0.8, 0.5))

		# Visual feedback
		await battle._camera_shake(0.2, 0.15)
		battle._float_text(defender_tile.global_position, "Hit %d" % (i + 1), Color(1, 0.4, 0.2))

		# Apply partial damage each hit (1/3 of normal ATK per hit)
		var damage := int(ceil(unit.current_atk / 3.0))
		defender.current_def = max(defender.current_def - damage, 0)

		if defender_tile.has_method("update_stat_labels"):
			defender_tile.update_stat_labels(defender.current_atk, defender.current_def)

		# Optional attack animation or sound
		if unit.has_meta("attack_sound"):
			battle.mover._play_card_sound(unit.get_meta("attack_sound"), defender_tile.global_position)

		# ✅ Wait for the next hit using arena tree
		await arena.get_tree().create_timer(delay_between_hits).timeout

		# Stop combo if defender dies mid-sequence
		if defender.current_def <= 0:
			battle._float_text(defender_tile.global_position, "☠️ KO!", Color(1, 0.2, 0.2))
			await battle._kill_unit(defender)
			break

	core._log("✅ %s finishes the Triple Strike." % unit.card.name, Color(0.7, 1.0, 0.7))
