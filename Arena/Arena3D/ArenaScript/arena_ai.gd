# File: arena_ai.gd
extends Node
class_name ArenaAI

var core: ArenaCore
var battle: ArenaBattle
var ui: ArenaUI

# Personality tuning
const AGGRESSION := 0.65       # higher = pushes toward player
const CAUTION := 0.35          # higher = retreats when weak
const FACE_DOWN_CHANCE := 0.75 # 75% summon secrecy
const TERRAIN_SYNERGY_BONUS := 4.0
const PROTECT_LEADER_RADIUS := 3
const ATTACK_RADIUS := 2

# ---------------------------------------------------------
# INIT
# ---------------------------------------------------------
func init_ai(core_ref: ArenaCore) -> void:
	core = core_ref
	battle = core.get_node("BattleSystem")
	ui = core.get_node("UISystem")

# ---------------------------------------------------------
# MAIN TURN ENTRY
# ---------------------------------------------------------
func run_enemy_turn() -> void:
	battle.apply_all_passives()
	await get_tree().create_timer(0.6).timeout
	_draw_up_to_limit()

	core._log("🤖 Enemy analyzing field...", Color(0.8, 0.8, 1.0))
	await get_tree().create_timer(0.8).timeout

	# 1️⃣ Evaluate danger first
	if _leader_in_danger():
		await _leader_behavior()
		await get_tree().create_timer(0.4).timeout

	# 2️⃣ Evaluate summon vs movement
	var can_summon := _has_summon_space() and core.enemy_essence > 0
	if can_summon and (randi() % 100 < int(AGGRESSION * 100)):
		await _smart_summon()
	else:
		await _smart_move_and_attack()

	core._log("🤖 Enemy turn complete.", Color(0.7, 0.9, 1))
	await get_tree().create_timer(0.5).timeout


# ---------------------------------------------------------
# LEADER BEHAVIOR
# ---------------------------------------------------------
func _leader_behavior() -> void:
	var lpos = battle.get_leader_pos(core.ENEMY)
	if lpos == Vector2i(-1, -1):
		return

	core._log("⚠️ Enemy leader assessing risk...", Color(1, 0.8, 0.6))

	# If surrounded, retreat if possible
	if _leader_in_danger():
		var safe_tile = _find_safe_tile(lpos)
		if safe_tile and safe_tile != lpos:
			await battle._move_or_battle(lpos, safe_tile, true)
			core._log("🏃 Enemy leader retreats to safety!", Color(1, 0.7, 0.5))
	else:
		# 20% chance to advance aggressively if terrain matches
		var player_leader_pos = battle.get_leader_pos(core.PLAYER)
		if randi() % 100 < 20 and lpos.distance_to(player_leader_pos) > 2:
			var path = _find_path_toward(lpos, player_leader_pos)
			if not path.is_empty():
				await battle._move_or_battle(lpos, path.front(), true)
				core._log("🔥 Enemy leader advances forward!", Color(1, 0.6, 0.4))


# ---------------------------------------------------------
# SUMMONING
# ---------------------------------------------------------
func _smart_summon() -> void:
	if core.enemy_hand.is_empty() and not core.enemy_deck.is_empty():
		core.enemy_hand.append(core.enemy_deck.pop_back())
	if core.enemy_hand.is_empty():
		return

	var leader_pos = battle.get_leader_pos(core.ENEMY)
	var player_leader_pos = battle.get_leader_pos(core.PLAYER)

	# Find summon spaces
	var spaces: Array[Vector2i] = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var p = leader_pos + d
		if core.board.is_in_bounds(p):
			var t = core.board.get_tile(p.x, p.y)
			if t and t.occupant == null:
				spaces.append(p)
	if spaces.is_empty():
		return

	# Evaluate cards by cost, terrain, and type synergy
	core.enemy_hand.sort_custom(func(a, b):
		return _evaluate_card(a, leader_pos) > _evaluate_card(b, leader_pos)
	)
	var chosen_card: CardData = core.enemy_hand.pop_front()

	var best_tile = spaces.front()
	var best_score := -INF
	for p in spaces:
		var tile = core.board.get_tile(p.x, p.y)
		var score = -p.distance_to(player_leader_pos)
		if tile and tile.terrain_type == chosen_card.preferred_terrain:
			score += TERRAIN_SYNERGY_BONUS
		if score > best_score:
			best_score = score
			best_tile = p

	_focus_camera_on(core.board.get_tile(best_tile.x, best_tile.y).global_position, 0.8, 0.6)
	await get_tree().create_timer(0.3).timeout

	var facedown := (randi() % 100 < int(FACE_DOWN_CHANCE * 100))
	var mode := UnitData.Mode.FACEDOWN if facedown else UnitData.Mode.ATTACK
	battle.place_unit(chosen_card, best_tile, core.ENEMY, mode, true)
	core.enemy_essence -= int(chosen_card.cost)
	core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)

	core._log("🤖 Summoned %s (%s) at %s" %
		[chosen_card.name, ("Facedown" if facedown else "Faceup"), str(best_tile)], Color(0.8, 0.8, 1.0))

func _evaluate_card(card: CardData, pos: Vector2i) -> float:
	var base := 10.0 - int(card.cost)

	var tile := core.board.get_tile(pos.x, pos.y)
	var terrain = tile.terrain_type if tile else ""

	# Safely check preferred_terrain only if it exists
	if card.has_meta("preferred_terrain"):
		if card.get_meta("preferred_terrain") == terrain:
			base += TERRAIN_SYNERGY_BONUS
	elif "preferred_terrain" in card:
		if card.preferred_terrain == terrain:
			base += TERRAIN_SYNERGY_BONUS

	# ATK/DEF weighting
	if "atk" in card:
		base += float(card.atk) * 0.1
	if "def" in card:
		base += float(card.def) * 0.05

	return base


# ---------------------------------------------------------
# ADVANCE / ATTACK BEHAVIOR (Rewritten + "stuck fix")
# ---------------------------------------------------------
func _smart_move_and_attack() -> void:
	var player_leader_pos = battle.get_leader_pos(core.PLAYER)
	var movable: Array[Vector2i] = []

	# Gather all ready enemy units (excluding leader)
	for pos in core.units.keys():
		var u = core.units[pos]
		if u.owner == core.ENEMY and not u.is_leader and core.can_unit_act(u):
			movable.append(pos)
	if movable.is_empty():
		return

	# Sort strongest ATK first (aggression bias)
	movable.sort_custom(func(a, b):
		return core.units[b].current_atk > core.units[a].current_atk
	)

	# Loop through every movable enemy
	for from in movable:
		var unit: UnitData = core.units[from]
		if not unit:
			continue

		# 1️⃣ Try to attack something in range
		if await _find_and_attack_target(from):
			continue

		# 2️⃣ Try to move toward a reachable attack position
		var near_target := await _find_attack_position(from)
		if near_target != from:
			await battle._move_or_battle(from, near_target, true)
			# Try again to attack after moving
			await _find_and_attack_target(near_target)
			continue

		# 3️⃣ If weak → retreat slightly
		if unit.current_def < unit.max_def * CAUTION:
			await _tactical_retreat(from)
			continue

		# 4️⃣ Otherwise, advance toward the player leader
		var before := from
		await _advance_toward_player(from, player_leader_pos)
		
		# 🧩 Check if still stuck in same place after advance attempt
		var now := _find_unit_position(unit)
		if now == before:
			core._log("🧩 %s is trapped — evaluating sacrifice..." % unit.card.name, Color(1, 0.6, 0.6))
			await _sacrifice_weakest_adjacent(from)

	# ✅ After loop, small pause before ending turn
	await get_tree().create_timer(0.4).timeout


# 🧩 NEW HELPER: sacrifice weakest adjacent ally to clear space
func _sacrifice_weakest_adjacent(from: Vector2i) -> void:
	var weakest = null
	var weakest_pos := Vector2i(-1, -1)
	var lowest_score := INF

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if abs(dx) + abs(dy) != 1:
				continue
			var pos := from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(pos):
				continue
			var tile = core.board.get_tile(pos.x, pos.y)
			if tile and tile.occupant and tile.occupant.owner == core.ENEMY and not tile.occupant.is_leader:
				var score = tile.occupant.current_def + tile.occupant.current_atk
				if score < lowest_score:
					lowest_score = score
					weakest = tile.occupant
					weakest_pos = pos

	if weakest and weakest_pos != Vector2i(-1, -1):
		core._log("💀 %s sacrifices %s to make room!" %
			[core.units[from].card.name, weakest.card.name], Color(1, 0.5, 0.5))
		await battle._kill_unit(weakest)
	else:
		core._log("⚠️ No valid ally to sacrifice near %s." %
			core.units[from].card.name, Color(1, 0.7, 0.4))


# 🧩 Tiny helper to find the latest position of a unit
func _find_unit_position(u: UnitData) -> Vector2i:
	for pos in core.units.keys():
		if core.units[pos] == u:
			return pos
	return Vector2i(-1, -1)

func _find_and_attack_target(from: Vector2i) -> bool:
	var range := ATTACK_RADIUS
	var attacker = core.units.get(from, null)
	if attacker == null:
		return false

	var best_target = null
	var best_score := -INF

	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var dist = abs(dx) + abs(dy)
			if dist == 0 or dist > range:
				continue

			var target := from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(target):
				continue

			var t := core.board.get_tile(target.x, target.y)
			if not t or not t.occupant:
				continue
			if t.occupant.owner != core.PLAYER:
				continue

			# --- Score: prefers low DEF enemies and closer distance ---
			var score = (10.0 - float(t.occupant.current_def)) - dist
			if t.occupant.is_leader:
				score += 8.0 # prioritize direct damage opportunity
			if score > best_score:
				best_score = score
				best_target = target

	if best_target:
		var name_att = attacker.card.name if attacker.card else "Unknown"
		var name_def = core.units[best_target].card.name if core.units.has(best_target) else "Unknown"
		core._log("⚔ %s attacks %s!" % [name_att, name_def], Color(1, 0.7, 0.7))
		await battle._move_or_battle(from, best_target, true)
		return true

	return false

func _find_attack_position(from: Vector2i) -> Vector2i:
	var attacker = core.units.get(from, null)
	if not attacker:
		return from

	var closest_enemy = null
	var closest_dist := INF

	for pos in core.units.keys():
		var u = core.units[pos]
		if u.owner == core.PLAYER:
			var d = from.distance_to(pos)
			if d < closest_dist:
				closest_dist = d
				closest_enemy = pos

	if not closest_enemy:
		return from

	# Move closer one tile toward enemy
	var best := from
	var best_dist := from.distance_to(closest_enemy)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if abs(dx) + abs(dy) != 1:
				continue
			var step := from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(step):
				continue
			var tile = core.board.get_tile(step.x, step.y)
			if tile and tile.occupant == null:
				var new_dist := step.distance_to(closest_enemy)
				if new_dist < best_dist:
					best = step
					best_dist = new_dist
	return best

func _advance_toward_player(from: Vector2i, goal: Vector2i) -> void:
	var range := core.BASE_MOVE_RANGE
	var best := from
	var best_dist := from.distance_to(goal)

	var unit: UnitData = core.units.get(from, null)
	if unit == null:
		return

	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var dist = abs(dx) + abs(dy)
			if dist == 0 or dist > range:
				continue

			var target = from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(target):
				continue

			var t = core.board.get_tile(target.x, target.y)
			if not t:
				continue

			# 🚫 Block if tile has *any* occupant (even ally)
			if t.occupant != null:
				continue

			if target.distance_to(goal) < best_dist:
				best = target
				best_dist = target.distance_to(goal)

	if best != from:
		await battle._move_or_battle(from, best, true)
		var name := unit.card.name if unit and unit.card else "Unknown"
		core._log("➡️ %s advances to %s" % [name, str(best)], Color(0.8, 0.9, 1.0))

func _tactical_retreat(from: Vector2i) -> void:
	var enemy_leader_pos = battle.get_leader_pos(core.ENEMY)
	var range := core.BASE_MOVE_RANGE
	var best := from
	var best_score := -INF

	var unit: UnitData = core.units.get(from, null)
	if unit == null:
		return

	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var target = from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(target):
				continue

			var t = core.board.get_tile(target.x, target.y)
			if not t or t.occupant != null:
				continue  # 🚫 skip occupied tiles

			var dist_score = target.distance_to(enemy_leader_pos)
			var terrain_bonus = 0.0
			if unit.card and "preferred_terrain" in unit.card and t.terrain_type == unit.card.preferred_terrain:
				terrain_bonus = 2.0

			var score = dist_score + terrain_bonus
			if score > best_score:
				best_score = score
				best = target

	if best != from:
		await battle._move_or_battle(from, best, true)
		var name := unit.card.name if unit and unit.card else "Unknown"
		core._log("🛡 %s falls back to %s" % [name, str(best)], Color(0.6, 0.9, 1.0))

# ---------------------------------------------------------
# SUPPORT / DANGER EVAL
# ---------------------------------------------------------
func _leader_in_danger() -> bool:
	var lpos = battle.get_leader_pos(core.ENEMY)
	if lpos == Vector2i(-1, -1):
		return false
	for pos in core.units.keys():
		var u = core.units[pos]
		if u.owner == core.PLAYER and pos.distance_to(lpos) <= PROTECT_LEADER_RADIUS:
			if _has_clear_path(pos, lpos):
				return true
	return false


func _find_safe_tile(from: Vector2i) -> Vector2i:
	var best := from
	var best_score := -INF
	for dx in range(-core.BASE_MOVE_RANGE, core.BASE_MOVE_RANGE + 1):
		for dy in range(-core.BASE_MOVE_RANGE, core.BASE_MOVE_RANGE + 1):
			var target = from + Vector2i(dx, dy)
			if not core.board.is_in_bounds(target):
				continue
			var t = core.board.get_tile(target.x, target.y)
			if t and t.occupant == null:
				var score = target.distance_to(battle.get_leader_pos(core.PLAYER))
				if _has_friendly_block_between(target, battle.get_leader_pos(core.PLAYER)):
					score += 3.0
				if t.terrain_type == "Shadow" or t.terrain_type == "Stone":
					score += 2.0 # defensive
				if score > best_score:
					best_score = score
					best = target
	return best


func _find_path_toward(from: Vector2i, to: Vector2i) -> Array:
	var candidates := []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var step = from + Vector2i(dx, dy)
			if core.board.is_in_bounds(step):
				var tile = core.board.get_tile(step.x, step.y)
				if tile and tile.occupant == null:
					candidates.append(step)
	candidates.sort_custom(func(a, b):
		return a.distance_to(to) < b.distance_to(to))
	return candidates


func _has_clear_path(from: Vector2i, to: Vector2i) -> bool:
	var dx = sign(to.x - from.x)
	var dy = sign(to.y - from.y)
	var steps = max(abs(to.x - from.x), abs(to.y - from.y))
	for i in range(1, steps):
		var mid = Vector2i(from.x + dx * i, from.y + dy * i)
		if not core.board.is_in_bounds(mid):
			continue
		var tile = core.board.get_tile(mid.x, mid.y)
		if tile and tile.occupant != null:
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
		var tile = core.board.get_tile(mid.x, mid.y)
		if tile and tile.occupant and tile.occupant.owner == core.ENEMY:
			return true
	return false


# ---------------------------------------------------------
# UTILITIES
# ---------------------------------------------------------
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
