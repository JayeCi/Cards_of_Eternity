extends Node
class_name ArenaAI

var core: ArenaCore
var battle: ArenaBattle
var ui: ArenaUI
var move: Node3D

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
	# Silent configuration - no spam

# ---------------------------------------------------------
# MAIN TURN ENTRY
# ---------------------------------------------------------
func run_enemy_turn() -> void:
	_unit_has_moved.clear()
	battle.apply_all_passives()
	await get_tree().create_timer(0.5).timeout
	_draw_up_to_limit()


	# Smart flip before planning moves
	await _smart_flip_faceup()

	await get_tree().create_timer(1).timeout

	# 1️⃣ Handle leader logic first (survival priority)
	if _leader_in_danger():
		await _leader_behavior()
		await get_tree().create_timer(0.4).timeout

	# 2️⃣ Check for fusion/upgrade opportunities (strategic value)
	await _smart_fusion_upgrade()
	await get_tree().create_timer(0.3).timeout

	# 3️⃣ Try summoning or moving
	var can_summon := _has_summon_space() and core.enemy_essence > 0
	if can_summon and randf() < aggression:
		await _smart_summon()
	else:
		await _smart_move_and_attack()
	# 4️⃣ If no attacks or summons happened → do proactive movement
	if not _any_action_taken():
		await _proactive_reposition()

	await get_tree().create_timer(0.4).timeout


# ---------------------------------------------------------
# LEADER BEHAVIOR (Improved: retreat + call ally for help)
# ---------------------------------------------------------
func _leader_behavior() -> void:
	var lpos = battle.get_leader_pos(core.ENEMY)
	if lpos == Vector2i(-1, -1):
		return

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

	core._log("⚠️ Leader in danger — retreating...", Color(1, 0.8, 0.5))

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
				await move._move_or_battle(lpos, alt, true)
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
					await move._move_or_battle(best_ally, path.front(), true)
				await _find_and_attack_target(best_ally)
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
	# ✅ Check all 8 surrounding tiles (including diagonals)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			  Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
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

	var facedown = randf() < face_down_chance
	var mode = UnitData.Mode.FACEDOWN if facedown else UnitData.Mode.ATTACK
	move.place_unit(card, best, core.ENEMY, mode, true)
	core.enemy_essence -= int(card.cost)
	core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)
	_did_action_this_turn = true

	# 🎬 Brief pause after summon
	await get_tree().create_timer(0.5).timeout

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
		if not core.units.has(a) or not core.units.has(b):
			return false
		return core.units[b].current_atk > core.units[a].current_atk
	)

	for from in movable:
		if not core.units.has(from):
			continue
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

		# 2️⃣ Try to move closer to enemy leader (but avoid dangerous positions)
		var best_move = _find_best_move_toward(from, player_leader)

		# 2.5️⃣ Check for flying moves (jump over allies)
		var flying_moves = _find_flying_moves(from, unit, player_leader)
		if not flying_moves.is_empty():
			# Sort by score and pick best
			flying_moves.sort_custom(func(a, b): return a.score > b.score)
			var best_fly = flying_moves[0]

			# Compare flying move vs normal move
			var fly_dist = best_fly.pos.distance_to(player_leader)
			var normal_dist = best_move.distance_to(player_leader) if best_move != from else INF

			# Prefer flying if it gets us closer
			if fly_dist < normal_dist:
				best_move = best_fly.pos

		if best_move != from:
			# 🧠 Check if moving there would put us in danger
			var is_safe = _is_position_safe(best_move, unit)

			if not is_safe and randf() < (caution + core.difficulty * 0.05):
				# AI recognizes danger and avoids the move
				continue

			var target_tile = core.board.get_tile(best_move.x, best_move.y)

			if target_tile and target_tile.occupant and target_tile.occupant.owner == core.PLAYER:
				# Move *onto* enemy → attack normally (camera will focus on battle in _move_or_battle)
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
					_did_action_this_turn = true
					await get_tree().create_timer(0.3).timeout
		else:
			# If face-up but idle — nudge forward too
			var best_move = _find_best_move_toward(pos, player_leader)
			if best_move != pos:
				await move._move_or_battle(pos, best_move, true)
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
			await battle.reveal_card(pos)
			_did_action_this_turn = true

			# Mark it permanently face-up this turn
			unit.is_facedown = false
			unit.set_meta("is_facedown", false)
			unit.set_meta("flipped_permanent", true)

			# Visually refresh
			core.refresh_tile_art_safe(pos)

			await get_tree().create_timer(0.2).timeout

# ---------------------------------------------------------
# ATTACK DECISION (Human-like reaction to faceup/facedown)
# ---------------------------------------------------------
func _find_and_attack_target(from: Vector2i) -> bool:
	var attacker = core.units.get(from)
	if not attacker:
		return false

	# Don't allow attacking if already moved this turn
	if _unit_has_moved.has(attacker) and _unit_has_moved[attacker]:
		return false

	var best_target: Vector2i = Vector2i(-1, -1)
	var best_score := -INF
	var should_retreat := false

	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var target = from + dir
		if not core.board.is_in_bounds(target):
			continue

		var t = core.board.get_tile(target.x, target.y)
		if not t or not t.occupant or t.occupant.owner != core.PLAYER:
			continue

		var defender = t.occupant
		var score = 0.0

		# ============================================
		# 🎭 HUMAN-LIKE REACTION SYSTEM
		# ============================================

		if defender.is_facedown:
			# 🔒 FACEDOWN CARD - Treat as unknown threat
			# AI assumes it could be: Monster, Spell, or Event
			# Base aggression: be more aggressive toward facedown (eliminate unknowns)
			score = 15.0  # Base "attack the unknown" bonus

			# 🎲 Difficulty scaling for facedown aggression
			# Lower difficulty = more cautious with facedowns
			# Higher difficulty = more aggressive
			var facedown_aggression = aggression * (0.5 + (core.difficulty * 0.1))
			score += facedown_aggression * 10.0

			# 🧠 Smart assumptions based on AI's knowledge
			# If defender is adjacent to their leader, assume it's a protector (Monster)
			var player_leader_pos = battle.get_leader_pos(core.PLAYER)
			if player_leader_pos != Vector2i(-1, -1) and target.distance_to(player_leader_pos) <= 1:
				score += 8.0  # Prioritize attacking protectors

		else:
			# 👁️ FACEUP CARD - Full information available
			# AI can now make informed decisions

			# Calculate battle outcome
			var attacker_survives = attacker.current_atk >= defender.current_def
			var defender_survives = defender.current_atk >= attacker.current_def

			# 💪 Evaluate if AI would WIN this fight
			if attacker_survives and not defender_survives:
				# 🎯 AI WINS - Attack with confidence!
				score = 25.0
				score += (defender.current_atk + defender.current_def) * 0.5

				if defender.is_leader:
					score += 50.0  # MASSIVE priority for winning against leader

			elif not attacker_survives:
				# 💀 AI LOSES - Try to save the card!
				score = -100.0
				should_retreat = true
				core._log("🛡️ %s retreats to avoid defeat" % attacker.card.name, Color(1, 0.8, 0.5))

			else:
				# 🤝 MUTUAL DESTRUCTION or defender survives
				var attacker_value = attacker.current_atk + attacker.current_def
				var defender_value = defender.current_atk + defender.current_def

				if defender_value > attacker_value * 1.3:
					# Good trade - eliminate higher-value target
					score = 20.0
					score += (defender_value - attacker_value) * 0.3
				elif defender.is_leader:
					# Always worth it to damage/kill leader
					score = 40.0
				else:
					# Unfavorable trade - might retreat instead
					score = -20.0
					should_retreat = randf() < (caution * (1.0 + core.difficulty * 0.1))

		# 🎯 Leader targeting bonus (always attractive)
		if defender.is_leader:
			score += 30.0

		if score > best_score:
			best_score = score
			best_target = target

	# ============================================
	# 🏃 RETREAT LOGIC - Save valuable units
	# ============================================
	if should_retreat and best_score < 0:
		await _tactical_retreat(from)
		_unit_has_moved[attacker] = true
		return false

	# ============================================
	# ⚔️ EXECUTE ATTACK
	# ============================================
	if best_target != Vector2i(-1, -1) and best_score > 0:
		# Verify target still exists before attacking
		if not core.units.has(best_target):
			return false
		var defender_name = "a facedown card" if core.units[best_target].is_facedown else core.units[best_target].card.name
		core._log("⚔️ %s attacks %s" % [attacker.card.name, defender_name], Color(1, 0.85, 0.7))
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
	if not src_tile or not core.units.has(from):
		return from
	var unit = core.units[from]
	if not unit:
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
	if not core.units.has(from):
		return
	var unit: UnitData = core.units[from]
	if not unit:
		return

	# Get movement range (respecting terrain bonuses)
	var src_tile = core.board.get_tile(from.x, from.y)
	if not src_tile:
		return

	var range = core.BASE_MOVE_RANGE
	if src_tile.terrain_type == unit.card.preferred_terrain and not unit.is_facedown:
		range *= 2

	# Determine which directions this unit can move
	var dirs: Array[Vector2i] = []

	# All units can move orthogonally (4 directions)
	dirs.append_array([Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)])

	# Some units (Flying, etc.) can also move diagonally
	if _can_move_diagonally(unit):
		dirs.append_array([Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)])

	var best := from
	var best_score := -INF

	# Check each direction for retreat options
	for dir in dirs:
		for step in range(1, range + 1):
			var pos = from + dir * step

			# Stop if out of bounds
			if not core.board.is_in_bounds(pos):
				break

			var t = core.board.get_tile(pos.x, pos.y)
			if not t:
				break

			# Stop if blocked by any unit (ally or enemy)
			if t.occupant != null:
				break

			# Evaluate this empty tile as a retreat option
			var dist_score = pos.distance_to(leader_pos)
			var terrain_bonus := 0.0
			if not unit.is_facedown and t.terrain_type == unit.card.preferred_terrain:
				terrain_bonus = 2.0

			var score = dist_score + terrain_bonus
			if score > best_score:
				best = pos
				best_score = score

	if best != from:
		await move._move_or_battle(from, best, true)
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
						await get_tree().create_timer(0.3).timeout
						break

	for dir in dirs:
		var escape = leader_pos + dir
		if core.board.is_in_bounds(escape):
			var tile = core.board.get_tile(escape.x, escape.y)
			if tile and tile.occupant == null:
				await battle._move_or_battle(leader_pos, escape, true)
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
	# ✅ Check all 8 surrounding tiles (including diagonals)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
			  Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var p = l + d
		if core.board.is_in_bounds(p):
			var t = core.board.get_tile(p.x, p.y)
			if t and t.occupant == null:
				return true
	return false

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

# ---------------------------------------------------------
# MOVEMENT CAPABILITY - Check if unit can move diagonally
# ---------------------------------------------------------
func _can_move_diagonally(unit: UnitData) -> bool:
	"""Check if this unit has diagonal movement capability"""
	if not unit or not unit.card:
		return false

	# Only diagonal movement flag grants diagonal movement
	# Flying is a separate mechanic (jump over allies)
	return unit.card.can_move_diagonally

func _can_fly(unit: UnitData) -> bool:
	"""Check if this unit can fly over allies"""
	if not unit or not unit.card:
		return false

	return unit.card.can_fly or unit.card.has_type("Flying")

func _find_flying_moves(from: Vector2i, unit: UnitData, goal: Vector2i) -> Array[Dictionary]:
	"""Find all valid flying moves (jumping over allies). Returns array of {pos: Vector2i, score: float}"""
	var flying_moves: Array[Dictionary] = []

	if not _can_fly(unit):
		return flying_moves

	var src_tile = core.board.get_tile(from.x, from.y)
	if not src_tile:
		return flying_moves

	var range = core.BASE_MOVE_RANGE
	if src_tile.terrain_type == unit.card.preferred_terrain and not unit.is_facedown:
		range *= 2

	# Only check orthogonal directions for flying
	var fly_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

	for dir in fly_dirs:
		for step in range(1, range + 1):
			var ally_pos = from + dir * step
			if not core.board.is_in_bounds(ally_pos):
				break

			var ally_tile = core.board.get_tile(ally_pos.x, ally_pos.y)
			if not ally_tile:
				break

			# Found an ally - can we fly over it?
			if ally_tile.occupant and ally_tile.occupant.owner == core.ENEMY:
				# Check the tile AFTER the ally (one tile beyond)
				var land_pos = ally_pos + dir
				if not core.board.is_in_bounds(land_pos):
					break

				var land_tile = core.board.get_tile(land_pos.x, land_pos.y)
				if not land_tile:
					break

				# Flying allows landing one tile beyond normal range
				# Ally must be within range, landing is always +1 from ally
				# No additional range check needed - if ally is reachable, we can fly over

				# Can land here! Score based on distance to goal
				if land_tile.occupant == null:
					# Empty tile
					var score = -land_pos.distance_to(goal)
					flying_moves.append({"pos": land_pos, "score": score})
				elif land_tile.occupant.owner == core.PLAYER:
					# Enemy tile - good for attacking!
					var score = -land_pos.distance_to(goal) + 5.0  # Bonus for attacking
					flying_moves.append({"pos": land_pos, "score": score})

				break  # Stop after finding first ally in this direction
			elif ally_tile.occupant:
				# Player unit in the way - can't fly through
				break

	return flying_moves

# ---------------------------------------------------------
# DANGER ASSESSMENT - Check if position is safe for unit
# ---------------------------------------------------------
func _is_position_safe(pos: Vector2i, unit: UnitData) -> bool:
	"""Check if moving to this position would endanger the unit"""
	if not core.board.is_in_bounds(pos):
		return false

	# Check all adjacent tiles for threats
	for dir in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var adj = pos + dir
		if not core.board.is_in_bounds(adj):
			continue

		var t = core.board.get_tile(adj.x, adj.y)
		if not t or not t.occupant or t.occupant.owner != core.PLAYER:
			continue

		var threat = t.occupant

		# 🔒 Facedown threats - always somewhat risky
		if threat.is_facedown:
			# Assume facedown could be dangerous, but not certain
			# Higher difficulty = less afraid of unknowns
			if randf() > (aggression * 0.7):
				return false

		else:
			# 👁️ Faceup threat - calculate if we'd lose
			var would_lose = threat.current_atk >= unit.current_def

			if would_lose:
				# This position is DANGEROUS - threat can kill us
				return false

			# Even if we survive, check if it's a bad trade
			var threat_value = threat.current_atk + threat.current_def
			var our_value = unit.current_atk + unit.current_def

			if threat_value > our_value * 1.5:
				# They're much stronger - risky position
				if randf() < caution:
					return false

	# No immediate threats detected
	return true


# ---------------------------------------------------------
# FUSION / UPGRADE SPELL LOGIC
# ---------------------------------------------------------
## AI evaluates and executes fusion/upgrade opportunities
func _smart_fusion_upgrade() -> void:
	# Higher difficulty = more likely to use upgrades strategically
	var fusion_chance = 0.3 + (aggression * 0.5)  # 30-80% based on aggression

	if randf() > fusion_chance:
		return

	# ========================================
	# PRIORITY 1: Monster+Monster Fusions (Database)
	# ========================================
	# Check for fusion pairs on the board first (immediate value)
	if await _try_board_fusion():
		return

	# Check for fusion pairs in hand (strategic placement)
	if await _try_hand_fusion_placement():
		return

	# ========================================
	# PRIORITY 2: Upgrade Spell Fusions
	# ========================================
	# Strategy 1: Check if AI has upgrade spells in hand that can be used
	var upgrade_spells_in_hand: Array[CardData] = []
	for card in core.enemy_hand:
		if card and card.is_upgrade_spell:
			upgrade_spells_in_hand.append(card)

	# Strategy 2: Check for upgrade spells already on the board
	var upgrade_spells_on_board: Array[Dictionary] = []  # {pos: Vector2i, unit: UnitData}
	var monsters_on_board: Array[Dictionary] = []  # {pos: Vector2i, unit: UnitData}

	for pos in core.units:
		var u = core.units[pos]
		if u.owner == core.ENEMY:
			if u.card and u.card.is_upgrade_spell:
				upgrade_spells_on_board.append({"pos": pos, "unit": u})
			elif u.card and u.card.card_type == CardData.CardType.MONSTER:
				monsters_on_board.append({"pos": pos, "unit": u})

	# Try to move existing upgrade spells onto matching monsters
	if not upgrade_spells_on_board.is_empty() and not monsters_on_board.is_empty():
		if await _try_move_spell_to_monster(upgrade_spells_on_board, monsters_on_board):
			return

	# Try to place upgrade spell from hand near monster
	if not upgrade_spells_in_hand.is_empty() and not monsters_on_board.is_empty():
		if await _try_place_upgrade_spell(upgrade_spells_in_hand, monsters_on_board):
			return


## Check if two cards on the board can fuse via database and move them together
func _try_board_fusion() -> bool:
	# Get all enemy units on board
	var enemy_units: Array[Dictionary] = []
	for pos in core.units:
		var u = core.units[pos]
		if u.owner == core.ENEMY and u.card:
			enemy_units.append({"pos": pos, "unit": u})

	# Check all pairs for fusion potential
	for i in range(enemy_units.size()):
		var unit_a_data = enemy_units[i]
		var pos_a: Vector2i = unit_a_data.pos
		var unit_a: UnitData = unit_a_data.unit

		# Skip leaders - they cannot fuse
		if unit_a.is_leader:
			continue

		# Can this unit act?
		if not core.can_unit_act(unit_a):
			continue

		for j in range(i + 1, enemy_units.size()):
			var unit_b_data = enemy_units[j]
			var pos_b: Vector2i = unit_b_data.pos
			var unit_b: UnitData = unit_b_data.unit

			# Skip leaders - they cannot fuse
			if unit_b.is_leader:
				continue

			# Check if these can fuse
			var fusion_result = core._check_fusion_pair(unit_a.card, unit_b.card)
			if fusion_result:
				# Check if they're within movement range
				var distance = pos_a.distance_to(pos_b)
				if distance <= core.BASE_MOVE_RANGE:
					core._log("✨ Fusing %s + %s → %s" %
						[unit_a.card.name, unit_b.card.name, fusion_result.name], Color(1.0, 0.9, 0.5))

					# Move unit A onto unit B to trigger fusion
					await move._move_or_battle(pos_a, pos_b, true)
					_did_action_this_turn = true
					return true

	return false


## Check if AI has two cards in hand that can fuse and place them adjacent
func _try_hand_fusion_placement() -> bool:
	if core.enemy_hand.size() < 2:
		return false

	var leader_pos = battle.get_leader_pos(core.ENEMY)
	if leader_pos == Vector2i(-1, -1):
		return false

	# Check all pairs in hand for fusion potential
	for i in range(core.enemy_hand.size()):
		var card_a = core.enemy_hand[i]
		if not card_a:
			continue

		for j in range(i + 1, core.enemy_hand.size()):
			var card_b = core.enemy_hand[j]
			if not card_b:
				continue

			# Check if these can fuse
			var fusion_result = core._check_fusion_pair(card_a, card_b)
			if fusion_result:
				# Check if we can afford both
				var total_cost = card_a.cost + card_b.cost
				if core.enemy_essence < total_cost:
					continue

				# Find two adjacent empty tiles near leader
				var placed_first = false
				var first_pos: Vector2i
				var second_pos: Vector2i

				# Search for adjacent empty tiles
				for dir1 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var pos1 = leader_pos + dir1
					if not core.board.is_in_bounds(pos1):
						continue

					var tile1 = core.board.get_tile(pos1.x, pos1.y)
					if not tile1 or tile1.occupant != null:
						continue

					# Found first spot, now look for adjacent spot
					for dir2 in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var pos2 = pos1 + dir2
						if pos2 == leader_pos:  # Skip if it's the leader spot
							continue

						if not core.board.is_in_bounds(pos2):
							continue

						var tile2 = core.board.get_tile(pos2.x, pos2.y)
						if not tile2 or tile2.occupant != null:
							continue

						# Found two adjacent spots!
						first_pos = pos1
						second_pos = pos2
						placed_first = true
						break

					if placed_first:
						break

				if not placed_first:
					continue

				core._log("✨ Placing fusion pair: %s + %s" % [card_a.name, card_b.name], Color(0.9, 0.9, 1.0))

				# Remove from hand
				core.enemy_hand.erase(card_a)
				core.enemy_hand.erase(card_b)

				# Place first card
				move.place_unit(card_a, first_pos, core.ENEMY, UnitData.Mode.ATTACK, true)
				core.enemy_essence -= int(card_a.cost)

				await get_tree().create_timer(0.4).timeout

				# Place second card
				move.place_unit(card_b, second_pos, core.ENEMY, UnitData.Mode.ATTACK, true)
				core.enemy_essence -= int(card_b.cost)

				core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)
				_did_action_this_turn = true

				# AI will fuse them together next turn
				return true

	return false


## Try to move an upgrade spell on board onto a matching monster
func _try_move_spell_to_monster(spells: Array[Dictionary], monsters: Array[Dictionary]) -> bool:
	for spell_data in spells:
		var spell_pos: Vector2i = spell_data.pos
		var spell_unit: UnitData = spell_data.unit

		if not spell_unit or not spell_unit.card:
			continue

		# Can this unit still act?
		if not core.can_unit_act(spell_unit):
			continue

		var spell_element = spell_unit.card.element

		# Find monsters with matching element
		for monster_data in monsters:
			var monster_pos: Vector2i = monster_data.pos
			var monster_unit: UnitData = monster_data.unit

			if not monster_unit or not monster_unit.card:
				continue

			# Skip leaders - they cannot be upgraded
			if monster_unit.is_leader:
				continue

			var monster_element = monster_unit.card.element

			# Check element match
			if spell_element == monster_element:
				# Check if monster is within movement range
				var distance = spell_pos.distance_to(monster_pos)
				if distance <= core.BASE_MOVE_RANGE:
					core._log("⬆️ Upgrading %s with %s" % [monster_unit.card.name, spell_unit.card.name], Color(0.7, 1.0, 0.9))

					await move._move_or_battle(spell_pos, monster_pos, true)
					_did_action_this_turn = true
					return true

	return false


## Try to place an upgrade spell from hand next to a matching monster
func _try_place_upgrade_spell(spells: Array[CardData], monsters: Array[Dictionary]) -> bool:
	var leader_pos = battle.get_leader_pos(core.ENEMY)

	for spell_card in spells:
		if not spell_card:
			continue

		var spell_element = spell_card.element

		# Find best matching monster
		var best_monster: Dictionary = {}
		var best_score = -INF

		for monster_data in monsters:
			var monster_unit: UnitData = monster_data.unit
			if not monster_unit or not monster_unit.card:
				continue

			# Skip leaders - they cannot be upgraded
			if monster_unit.is_leader:
				continue

			# Check element match
			if monster_unit.card.element == spell_element:
				# Evaluate if this upgrade is worth it
				var score = monster_unit.current_atk + monster_unit.current_def

				# Prefer monsters that are face-up (more valuable to upgrade)
				if not monster_unit.is_facedown:
					score += 20

				if score > best_score:
					best_score = score
					best_monster = monster_data

		if best_monster.is_empty():
			continue

		var monster_pos: Vector2i = best_monster.pos

		# Find adjacent empty tile to place upgrade spell
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var place_pos = monster_pos + dir

			if not core.board.is_in_bounds(place_pos):
				continue

			var tile = core.board.get_tile(place_pos.x, place_pos.y)
			if tile and tile.occupant == null:
				# Check if we can afford it
				if core.enemy_essence < spell_card.cost:
					continue

				# Remove from hand
				core.enemy_hand.erase(spell_card)

				# Place face-up (upgrade spells don't benefit from being face-down)
				move.place_unit(spell_card, place_pos, core.ENEMY, UnitData.Mode.ATTACK, true)
				core.enemy_essence -= int(spell_card.cost)
				core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)
				_did_action_this_turn = true

				# Next turn, AI will move monster onto spell or spell onto monster
				return true

	return false
