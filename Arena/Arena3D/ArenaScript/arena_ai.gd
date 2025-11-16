extends Node
class_name ArenaAI

var core: ArenaCore
var battle: ArenaBattle
var ui: ArenaUI
var move: ArenaMove

var aggression := 0.65
var caution := 0.35
var face_down_chance := 0.75
var terrain_synergy_bonus := 4.0
var protect_leader_radius := 3
var attack_radius := 1
var think_delay := 0.5
var _did_action_this_turn := false
var _unit_has_moved := {}


# ---------------------------------------------------------
# INIT
# ---------------------------------------------------------
func init_ai(core_ref: ArenaCore) -> void:
	core = core_ref
	battle = core.get_node("BattleSystem")
	ui = core.get_node("UISystem")
	move = core.get_node("MoveSystem")
	
func configure_style(ai_style: String, difficulty: int) -> void:
	# --- Difficulty Scaling ---
	var diff_scale = clamp(float(difficulty), 1.0, 10.0)
	aggression += (diff_scale - 1.0) * 0.03
	caution = max(0.1, 0.5 - (diff_scale - 1.0) * 0.02)
	think_delay = clamp(0.7 - (diff_scale * 0.05), 0.15, 0.7)
	terrain_synergy_bonus = 4.0 + (diff_scale * 0.4)
	protect_leader_radius = 2 + int(diff_scale / 3)

	# --- Personality Profiles ---
	match ai_style:
		"balanced":
			aggression = 0.65 + (diff_scale * 0.02)
			caution = 0.35 - (diff_scale * 0.01)
			face_down_chance = 0.75
		"aggressive":
			aggression = 0.9
			caution = 0.2
			face_down_chance = 0.4
			attack_radius += 1
		"defensive":
			aggression = 0.45
			caution = 0.6
			face_down_chance = 0.9
			protect_leader_radius += 1
		"tactical":
			aggression = 0.7
			caution = 0.55
			face_down_chance = 0.5
			terrain_synergy_bonus += 3.0
		"reckless":
			aggression = 1.0
			caution = 0.15
			face_down_chance = 0.2
		"passive":
			aggression = 0.4
			caution = 0.8
			face_down_chance = 0.9
		"random":
			aggression = randf_range(0.4, 1.0)
			caution = 1.0 - aggression
			face_down_chance = randf_range(0.3, 0.8)
	print("AI configured → Style:", ai_style, " | Difficulty:", difficulty)

	#core._log("🧠 AI configured: style=%s, diff=%d" % 
		#[ai_style, difficulty, aggression, caution, face_down_chance], Color(0.7, 0.9, 1.0))

# ---------------------------------------------------------
# MAIN TURN ENTRY
# ---------------------------------------------------------
func run_enemy_turn() -> void:
	_unit_has_moved.clear()
	battle.apply_all_passives()
	await get_tree().create_timer(0.5).timeout
	_draw_up_to_limit()


	# 🔹 NEW: Smart flip before planning moves
	await _smart_flip_faceup()

	core._log("🤖 Enemy analyzing field...", Color(0.8, 0.8, 1.0))
	await get_tree().create_timer(1).timeout

	# 1️⃣ Handle leader logic first (survival priority)
	if _leader_in_danger():
		await _leader_behavior()
		await get_tree().create_timer(0.4).timeout

	# 2️⃣ Try summoning or moving
	var can_summon := _has_summon_space() and core.enemy_essence > 0
	if can_summon and randf() < aggression:
		await _smart_summon()
	else:
		await _smart_move_and_attack()
	# 3️⃣ If no attacks or summons happened → do proactive movement
	if not _any_action_taken():
		await _proactive_reposition()

	core._log("🤖 Enemy turn complete.", Color(0.7, 0.9, 1))
	await get_tree().create_timer(0.4).timeout


# ---------------------------------------------------------
# LEADER BEHAVIOR (Improved: retreat + call ally for help)
# ---------------------------------------------------------
func _leader_behavior() -> void:
	var lpos = battle.get_leader_pos(core.ENEMY)
	if lpos == Vector2i(-1, -1):
		return
	core._log("⚠️ Enemy leader assessing threats...", Color(1, 0.8, 0.6))

	var leader_tile = core.board.get_tile(lpos.x, lpos.y)
	if not leader_tile or not leader_tile.occupant:
		return

	# Detect adjacent player threats
	var adjacent_threats: Array[Vector2i] = []
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var adj = lpos + dir
		if not core.board.is_in_bounds(adj):
			continue
		var t = core.board.get_tile(adj.x, adj.y)
		if t and t.occupant and t.occupant.owner == core.PLAYER:
			adjacent_threats.append(adj)

	# ✅ If no immediate danger, no need to act
	if adjacent_threats.is_empty():
		return

	core._log("🚨 Leader is under threat! Evaluating escape routes...", Color(1, 0.7, 0.6))

	# ---------------------------------------------------------
	# 1️⃣ Check for any empty escape tiles (away from player)
	# ---------------------------------------------------------
	var escape_tiles: Array[Vector2i] = []
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var pos = lpos + dir
		if not core.board.is_in_bounds(pos):
			continue
		var t = core.board.get_tile(pos.x, pos.y)
		if t and t.occupant == null:
			escape_tiles.append(pos)

	# Sort escape tiles by distance away from nearest threat
	var best_escape: Vector2i = lpos
	var best_score := -INF
	for tile in escape_tiles:
		var min_threat_dist = INF
		for threat in adjacent_threats:
			min_threat_dist = min(min_threat_dist, tile.distance_to(threat))
		if min_threat_dist > best_score:
			best_score = min_threat_dist
			best_escape = tile

	# If a safe open tile exists → MOVE THERE immediately
	if best_escape != lpos:
		_did_action_this_turn = true
		await move._move_or_battle(lpos, best_escape, true)
		core._log("🏃 Leader retreats to %s to avoid damage!" % str(best_escape), Color(1, 0.7, 0.5))
		lpos = best_escape
		await get_tree().create_timer(0.3).timeout

	# ---------------------------------------------------------
	# 2️⃣ If still adjacent, try ordering allies to block path
	# ---------------------------------------------------------
	var still_threatened := false
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var adj = lpos + dir
		if core.board.is_in_bounds(adj):
			var t = core.board.get_tile(adj.x, adj.y)
			if t and t.occupant and t.occupant.owner == core.PLAYER:
				still_threatened = true
				break

	if still_threatened:
		core._log("🛡 Calling allies to block enemies near leader!", Color(0.8, 0.9, 1.0))
		await _assist_leader_defense(lpos, adjacent_threats)

	# ---------------------------------------------------------
	# 3️⃣ As last resort, swap with ally tile (body block)
	# ---------------------------------------------------------
	still_threatened = false
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var adj = lpos + dir
		if core.board.is_in_bounds(adj):
			var t = core.board.get_tile(adj.x, adj.y)
			if t and t.occupant and t.occupant.owner == core.PLAYER:
				still_threatened = true
				break

	if still_threatened:
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var alt = lpos + dir
			if not core.board.is_in_bounds(alt):
				continue
			var t = core.board.get_tile(alt.x, alt.y)
			if t and t.occupant and t.occupant.owner == core.ENEMY and not t.occupant.is_leader:
				_did_action_this_turn = true
				await battle._move_or_battle(lpos, alt, true)
				core._log("↩️ Leader swaps with ally to protect itself!", Color(1, 0.8, 0.6))
				return

	# ---------------------------------------------------------
	# 4️⃣ Try emergency summon (last chance)
	# ---------------------------------------------------------
	if _has_summon_space() and core.enemy_essence > 0 and not core.enemy_hand.is_empty():
		var card: CardData = core.enemy_hand.front()
		var threat = adjacent_threats.front()
		var summon_tile = lpos + (lpos - threat)
		if core.board.is_in_bounds(summon_tile):
			var t = core.board.get_tile(summon_tile.x, summon_tile.y)
			if t and t.occupant == null:
				_did_action_this_turn = true
				move.place_unit(card, summon_tile, core.ENEMY, UnitData.Mode.ATTACK, true)
				core.enemy_hand.pop_front()
				core.enemy_essence -= int(card.cost)
				core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)
				core._log("🧱 Leader summons %s to create a blocker!" % card.name, Color(0.6, 0.9, 1))
				await get_tree().create_timer(0.3).timeout

# ---------------------------------------------------------
# ALLY SUPPORT — Attack cards threatening the leader
# ---------------------------------------------------------
func _assist_leader_defense(leader_pos: Vector2i, threats: Array[Vector2i]) -> void:
	var allies: Array[Vector2i] = []
	for pos in core.units:

		var u = core.units[pos]
		if u.owner == core.ENEMY and not u.is_leader and core.can_unit_act(u):
			allies.append(pos)

	if allies.is_empty():
		return

	for threat in threats:
		var best_ally := Vector2i(-1, -1)
		var best_dist := INF
		for ally in allies:
			var dist = ally.distance_to(threat)
			if dist < best_dist:
				best_dist = dist
				best_ally = ally

		if best_ally != Vector2i(-1, -1):
			var ally_unit = core.units[best_ally]
			if ally_unit and not ally_unit.is_facedown:
				var path = _find_path_toward(best_ally, threat)
				if not path.is_empty():
					await battle._move_or_battle(best_ally, path.front(), true)
				await _find_and_attack_target(best_ally)
				core._log("💥 %s attacks to protect the leader!" % ally_unit.card.name, Color(1, 0.8, 0.8))
				await get_tree().create_timer(0.3).timeout

# ---------------------------------------------------------
# SUMMONING (Respects terrain bonuses)
# ---------------------------------------------------------
func _smart_summon() -> void:
	if core.enemy_hand.is_empty() and not core.enemy_deck.is_empty():
		core.enemy_hand.append(core.enemy_deck.pop_back())
	if core.enemy_hand.is_empty():
		return

	var leader_pos = battle.get_leader_pos(core.ENEMY)
	var player_leader_pos = battle.get_leader_pos(core.PLAYER)

	var spaces: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p = leader_pos + d
		if core.board.is_in_bounds(p):
			var t = core.board.get_tile(p.x, p.y)
			if t and t.occupant == null:
				spaces.append(p)
	if spaces.is_empty():
		return

	core.enemy_hand.sort_custom(func(a, b):
		return _evaluate_card(a, leader_pos) > _evaluate_card(b, leader_pos)
	)
	var card: CardData = core.enemy_hand.pop_front()
	var best = spaces.front()
	var best_score := -INF
	for s in spaces:
		var t = core.board.get_tile(s.x, s.y)
		var score = -s.distance_to(player_leader_pos)
		if t and t.terrain_type == card.preferred_terrain:
			score += terrain_synergy_bonus
		if score > best_score:
			best = s
			best_score = score

	_focus_camera_on(core.board.get_tile(best.x, best.y).global_position, 0.8, 0.5)
	await get_tree().create_timer(0.3).timeout

	var facedown = randf() < face_down_chance
	var mode = UnitData.Mode.FACEDOWN if facedown else UnitData.Mode.ATTACK
	move.place_unit(card, best, core.ENEMY, mode, true)
	core.enemy_essence -= int(card.cost)
	core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)
	_did_action_this_turn = true

	#core._log("🤖 Summoned %s (%s) at %s" % 
		#[card.name, ("Facedown" if facedown else "Faceup"), str(best)], Color(0.8, 0.8, 1))

func _evaluate_card(card, pos: Vector2i) -> float:
	var base := 10.0
	var cost := 0.0
	var atk := 0.0
	var def := 0.0
	var terrain_pref := ""

	# Get the exported fields safely
	if card:
		var props = card.get_property_list()
		var names = []
		for p in props:
			names.append(p.name)

		if "cost" in names: cost = float(card.get("cost"))
		if "atk" in names: atk = float(card.get("atk"))
		if "def" in names: def = float(card.get("def"))
		if "preferred_terrain" in names: terrain_pref = str(card.get("preferred_terrain"))

	base -= cost
	var tile = core.board.get_tile(pos.x, pos.y)
	if tile and terrain_pref == tile.terrain_type:
		base += terrain_synergy_bonus
	base += atk * 0.1 + def * 0.05
	return base

# ---------------------------------------------------------
# MOVEMENT + ATTACK (Fully respects player rules)
# ---------------------------------------------------------
func _smart_move_and_attack() -> void:
	var player_leader = battle.get_leader_pos(core.PLAYER)
	var movable: Array[Vector2i] = []

	for pos in core.units:
		var u = core.units[pos]
		if u.owner == core.ENEMY and not u.is_leader and core.can_unit_act(u):
			# ✅ Skip frozen units (universal system)
			if FrozenStatusEffect.is_frozen(u):
				continue
			movable.append(pos)

	if movable.is_empty():
		return

	movable.sort_custom(func(a, b):
		return core.units[b].current_atk > core.units[a].current_atk
	)

	for from in movable:
		var unit: UnitData = core.units[from]
		if not unit:
			continue

		# Skip if already moved this turn
		if _unit_has_moved.has(unit) and _unit_has_moved[unit]:
			continue

		# 🚫 Skip facedown units
		if unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown")):
			continue

		# 1️⃣ Try to attack if adjacent
		if await _find_and_attack_target(from):
			_unit_has_moved[unit] = true
			continue

		# 2️⃣ Try to move closer to enemy leader
		var best_move = _find_best_move_toward(from, player_leader)
		if best_move != from:
			var target_tile = core.board.get_tile(best_move.x, best_move.y)
			if target_tile and target_tile.occupant and target_tile.occupant.owner == core.PLAYER:
				# Move *onto* enemy → attack normally
				await move._move_or_battle(from, best_move, true)
				_did_action_this_turn = true
			else:
				# Move only — no follow-up attack allowed this turn
				await move._move_or_battle(from, best_move, true)
				_unit_has_moved[unit] = true
				_did_action_this_turn = true
			continue

		# 3️⃣ Weak units retreat (same as player)
		if unit.current_def < unit.max_def * caution:
			await _tactical_retreat(from)
			_unit_has_moved[unit] = true
			continue

func _proactive_reposition() -> void:
	core._log("🤖 AI is repositioning idle units...", Color(0.8, 0.8, 1.0))

	var player_leader = battle.get_leader_pos(core.PLAYER)
	if player_leader == Vector2i(-1, -1):
		return

	for pos in core.units.keys():
		var u = core.units[pos]
		if u.owner != core.ENEMY or u.is_leader:
			continue
		
		# ✅ Skip frozen units (universal system)
		if FrozenStatusEffect.is_frozen(u):
			continue
		
		if u.is_facedown:
			# Optionally skip spells or events
			if u.card and u.card.card_type in ["Spell", "Event"]:
				continue

			# If it's a monster facedown with no nearby threats, consider moving forward
			var has_nearby_enemy := false
			for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				var adj = pos + dir
				if core.board.is_in_bounds(adj):
					var t = core.board.get_tile(adj.x, adj.y)
					if t and t.occupant and t.occupant.owner == core.PLAYER:
						has_nearby_enemy = true
						break

			if not has_nearby_enemy:
				var best_move = _find_best_move_toward(pos, player_leader)
				if best_move != pos:
					await move._move_or_battle(pos, best_move, true)
					core._log("🤖 Moves facedown unit toward player!", Color(0.7, 0.9, 1.0))
					_did_action_this_turn = true
					await get_tree().create_timer(0.3).timeout
		else:
			# If face-up but idle — nudge forward too
			var best_move = _find_best_move_toward(pos, player_leader)
			if best_move != pos:
				await move._move_or_battle(pos, best_move, true)
				core._log("🤖 Advances idle %s toward enemy lines." % u.card.name, Color(0.7, 0.9, 1.0))
				_did_action_this_turn = true
				await get_tree().create_timer(0.3).timeout

# ---------------------------------------------------------
# SMART FLIPPING — AI decides when to reveal facedown cards
# ---------------------------------------------------------
func _smart_flip_faceup() -> void:
	for pos in core.units:

		var unit: UnitData = core.units[pos]
		if unit.owner != core.ENEMY:
			continue
		if not unit.is_facedown and not (unit.has_meta("is_facedown") and unit.get_meta("is_facedown")):
			continue

		var tile = core.board.get_tile(pos.x, pos.y)
		if not tile:
			continue

		# 🔹 Skip if currently blocked in or isolated
		var has_adjacent_enemy := false
		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var adj = pos + dir
			if not core.board.is_in_bounds(adj):
				continue
			var t = core.board.get_tile(adj.x, adj.y)
			if t and t.occupant and t.occupant.owner == core.PLAYER:
				has_adjacent_enemy = true
				break

		# 🧩 Auto-flip if enemy is near or has an on_flip/passive ability
		var should_flip := false
		if has_adjacent_enemy:
			should_flip = true
		elif unit.card and unit.card.ability and unit.card.ability.trigger in ["on_summon", "passive"]:
			should_flip = true
		elif randf() < aggression * 0.4:
			should_flip = true

		if should_flip:
			core._log("🤖 AI flips %s face-up!" % unit.card.name, Color(0.9, 0.9, 1.0))
			await battle.reveal_card(pos)
			_did_action_this_turn = true

			# ✅ NEW: mark it permanently face-up this turn
			unit.is_facedown = false
			unit.set_meta("is_facedown", false)
			unit.set_meta("flipped_permanent", true)

			# Optional: visually refresh so the sync routines agree
			core.refresh_tile_art_safe(pos)

			await get_tree().create_timer(0.2).timeout

# ---------------------------------------------------------
# ATTACK DECISION (same ATTACK_RADIUS logic)
# ---------------------------------------------------------
func _find_and_attack_target(from: Vector2i) -> bool:
	var attacker = core.units.get(from)
	if not attacker:
		return false

	# Don’t allow attacking if already moved this turn
	if _unit_has_moved.has(attacker) and _unit_has_moved[attacker]:
		return false

	var best_target: Vector2i = Vector2i(-1, -1)
	var best_score := -INF

	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var target = from + dir
		if not core.board.is_in_bounds(target):
			continue

		var t = core.board.get_tile(target.x, target.y)
		if not t or not t.occupant or t.occupant.owner != core.PLAYER:
			continue

		var score = 10.0 - float(t.occupant.current_def)
		if t.occupant.is_leader:
			score += 10.0

		if score > best_score:
			best_score = score
			best_target = target

	if best_target != Vector2i(-1, -1):
		core._log("⚔ %s attacks %s!" %
			[attacker.card.name, core.units[best_target].card.name], Color(1, 0.7, 0.7))
		await move._move_or_battle(from, best_target, true)
		_did_action_this_turn = true
		_unit_has_moved[attacker] = true
		return true

	return false

# ---------------------------------------------------------
# MOVEMENT RESPECTING TERRAIN + BLOCKERS
# ---------------------------------------------------------
func _find_best_move_toward(from: Vector2i, goal: Vector2i) -> Vector2i:
	var src_tile = core.board.get_tile(from.x, from.y)
	var unit = core.units[from]
	if not src_tile or not unit:
		return from

	var range = core.BASE_MOVE_RANGE
	if src_tile.terrain_type == unit.card.preferred_terrain and not unit.is_facedown:
		range *= 2

	var best := from
	var best_dist := from.distance_to(goal)
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	for dir in dirs:
		for step in range(1, range + 1):
			var p = from + dir * step
			if not core.board.is_in_bounds(p):
				break
			var t = core.board.get_tile(p.x, p.y)
			if not t:
				break
			if t.occupant and t.occupant.owner == core.ENEMY:
				break # ally blocks path
			if not t.occupant and p.distance_to(goal) < best_dist:
				best = p
				best_dist = p.distance_to(goal)
	return best

# ---------------------------------------------------------
# RETREAT / ESCAPE
# ---------------------------------------------------------
func _tactical_retreat(from: Vector2i) -> void:
	var leader_pos = battle.get_leader_pos(core.ENEMY)
	var unit: UnitData = core.units[from]
	if not unit:
		return

	var range = core.BASE_MOVE_RANGE
	var best := from
	var best_score := -INF
	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var pos = from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(pos):
				continue
			var t = core.board.get_tile(pos.x, pos.y)
			if not t or t.occupant != null:
				continue

			var dist_score = pos.distance_to(leader_pos)
			var terrain_bonus := 0.0
			if not unit.is_facedown and t.terrain_type == unit.card.preferred_terrain:
				terrain_bonus = 2.0

			var score = dist_score + terrain_bonus
			if score > best_score:
				best = pos
				best_score = score

	if best != from:
		await battle._move_or_battle(from, best, true)
		core._log("🛡 %s retreats to %s" % [unit.card.name, str(best)], Color(0.6, 0.9, 1.0))
		_did_action_this_turn = true
# ---------------------------------------------------------
# LEADER ESCAPE (same rules)
# ---------------------------------------------------------
func _try_escape_corner(leader_pos: Vector2i) -> bool:
	if not core or not battle or not core.board:
		return false

	var leader_tile = core.board.get_tile(leader_pos.x, leader_pos.y)
	if not leader_tile or not leader_tile.occupant:
		return false
	var leader = leader_tile.occupant

	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	var blocked = false
	for dir in dirs:
		var adj = leader_pos + dir
		var t = core.board.get_tile(adj.x, adj.y)
		if t and t.occupant and t.occupant.owner == core.PLAYER:
			blocked = true
			break

	if not blocked:
		return false

	for dir in dirs:
		var adj = leader_pos + dir
		var ally_tile = core.board.get_tile(adj.x, adj.y)
		if ally_tile and ally_tile.occupant and ally_tile.occupant.owner == core.ENEMY and not ally_tile.occupant.is_leader:
			for move_dir in dirs:
				var target = adj + move_dir
				if core.board.is_in_bounds(target):
					var t2 = core.board.get_tile(target.x, target.y)
					if t2 and t2.occupant == null:
						await battle._move_or_battle(adj, target, true)
						core._log("🤖 Ally clears path for leader.", Color(0.8, 0.9, 1))
						await get_tree().create_timer(0.3).timeout
						break

	for dir in dirs:
		var escape = leader_pos + dir
		if core.board.is_in_bounds(escape):
			var tile = core.board.get_tile(escape.x, escape.y)
			if tile and tile.occupant == null:
				await battle._move_or_battle(leader_pos, escape, true)
				core._log("🏃 Leader escapes corner!", Color(1, 0.7, 0.5))
				return true
	return false

# ---------------------------------------------------------
# SUPPORT HELPERS
# ---------------------------------------------------------
func _leader_in_danger() -> bool:
	var lpos = battle.get_leader_pos(core.ENEMY)
	if lpos == Vector2i(-1, -1):
		return false
	for pos in core.units:

		var u = core.units[pos]
		if u.owner == core.PLAYER and pos.distance_to(lpos) <= protect_leader_radius:
			if _has_clear_path(pos, lpos):
				return true
	return false

func _find_safe_tile(from: Vector2i) -> Vector2i:
	var best := from
	var best_score := -INF
	for dx in range(-core.BASE_MOVE_RANGE, core.BASE_MOVE_RANGE + 1):
		for dy in range(-core.BASE_MOVE_RANGE, core.BASE_MOVE_RANGE + 1):
			var pos = from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(pos):
				continue
			var t = core.board.get_tile(pos.x, pos.y)
			if t and t.occupant == null:
				var score = pos.distance_to(battle.get_leader_pos(core.PLAYER))
				if _has_friendly_block_between(pos, battle.get_leader_pos(core.PLAYER)):
					score += 3.0
				if t.terrain_type in ["Shadow", "Stone"]:
					score += 2.0
				if score > best_score:
					best = pos
					best_score = score
	return best

func _has_clear_path(from: Vector2i, to: Vector2i) -> bool:
	var dx = sign(to.x - from.x)
	var dy = sign(to.y - from.y)
	var steps = max(abs(to.x - from.x), abs(to.y - from.y))
	for i in range(1, steps):
		var mid = Vector2i(from.x + dx * i, from.y + dy * i)
		if not core.board.is_in_bounds(mid):
			continue
		var t = core.board.get_tile(mid.x, mid.y)
		if t and t.occupant != null:
			return false
	return true

func _has_friendly_block_between(from: Vector2i, to: Vector2i) -> bool:
	var dx = sign(to.x - from.x)
	var dy = sign(to.y - from.y)
	var steps = max(abs(to.x - from.x), abs(to.y - from.y))
	for i in range(1, steps):
		var mid = Vector2i(from.x + dx * i, from.y + dy * i)
		if not core.board.is_in_bounds(mid):
			continue
		var t = core.board.get_tile(mid.x, mid.y)
		if t and t.occupant and t.occupant.owner == core.ENEMY:
			return true
	return false

func _draw_up_to_limit() -> void:
	while core.enemy_hand.size() < core.MAX_ENEMY_HAND_SIZE and not core.enemy_deck.is_empty():
		core.enemy_hand.append(core.enemy_deck.pop_back())

func _has_summon_space() -> bool:
	var l = battle.get_leader_pos(core.ENEMY)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p = l + d
		if core.board.is_in_bounds(p):
			var t = core.board.get_tile(p.x, p.y)
			if t and t.occupant == null:
				return true
	return false

func _focus_camera_on(pos: Vector3, zoom_mult: float, duration: float) -> void:
	core.emit_signal("focus_camera", pos, zoom_mult, duration)

func _find_path_toward(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if from == to:
		return []

	# 🧭 Simple BFS (Breadth-First Search) for shortest path
	var open := [from]
	var came_from := {}
	came_from[from] = null

	while not open.is_empty():
		var current = open.pop_front()

		if current == to:
			break

		for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var next = current + dir
			if not core.board.is_in_bounds(next):
				continue

			# 🚫 Skip occupied tiles (both ally and enemy)
			var tile = core.board.get_tile(next.x, next.y)
			if not tile or (tile.occupant != null and next != to):
				continue

			if not came_from.has(next):
				came_from[next] = current
				open.append(next)

	# 🧩 Reconstruct path
	if not came_from.has(to):
		return []

	var path: Array[Vector2i] = []
	var cur = to
	while cur != null:
		path.push_front(cur)
		cur = came_from[cur]

	# Remove starting tile
	if not path.is_empty() and path.front() == from:
		path.pop_front()

	return path

func _any_action_taken() -> bool:
	var result = _did_action_this_turn
	_did_action_this_turn = false
	return result
