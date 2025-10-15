# File: arena_ai.gd
extends Node
class_name ArenaAI

var core: ArenaCore
var battle: ArenaBattle
var ui: ArenaUI

func init_ai(core_ref: ArenaCore) -> void:
	core = core_ref
	battle = core.get_node("BattleSystem")
	ui = core.get_node("UISystem")

func run_enemy_turn() -> void:
	battle.apply_all_passives()
	await get_tree().create_timer(1.0).timeout
	_draw_up_to_limit()


	var has_units := false
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		if u.owner == core.ENEMY and not u.is_leader:
			has_units = true; break

	var action: int
	if not has_units and not core.enemy_deck.is_empty():
		action = 0
	else:
		action = (randi() % 100 < 40) if _has_summon_space() else 1

	if action == 0:
		await _try_summon()
		core.enemy_essence += core.essence_gain_per_turn
		core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)
	else:
		await _try_move_or_attack()

	await get_tree().create_timer(0.8).timeout

func _draw_up_to_limit() -> void:
	while core.enemy_hand.size() < core.MAX_ENEMY_HAND_SIZE and not core.enemy_deck.is_empty():
		var c = core.enemy_deck.pop_back()
		core.enemy_hand.append(c)

func _has_summon_space() -> bool:
	var l = battle.get_leader_pos(core.ENEMY)
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var p = l + d
		if p.x>=0 and p.y>=0 and p.x<core.BOARD_W and p.y<core.BOARD_H:
			var t = core.board.get_tile(p.x,p.y)
			if t and t.occupant == null: return true
	return false

func _try_summon() -> void:
	if core.enemy_essence <= 0: return
	if core.enemy_hand.is_empty() and core.enemy_deck.is_empty(): return

	var leader_pos := battle.get_leader_pos(core.ENEMY)
	var valid: Array = []
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var p = leader_pos + d
		if p.x<0 or p.y<0 or p.x>=core.BOARD_W or p.y>=core.BOARD_H: continue
		var t = core.board.get_tile(p.x,p.y)
		if t and t.occupant == null: valid.append(p)
	if valid.is_empty(): return

	var player_leader_pos := battle.get_leader_pos(core.PLAYER)
	valid.sort_custom(func(a, b):
		return a.distance_to(player_leader_pos) < b.distance_to(player_leader_pos)
	)

	if core.enemy_hand.is_empty():
		var c = core.enemy_deck.pop_back() if not core.enemy_deck.is_empty() else null
		if c: core.enemy_hand.append(c)
	if core.enemy_hand.is_empty(): return

	var card: CardData = core.enemy_hand.pop_back()
	var cost = int(card.cost) if "cost" in card else 1

	if core.enemy_essence < cost: return
	var prev = core.enemy_essence
	core.enemy_essence -= cost
	core.emit_signal("essence_changed", core.player_essence, core.enemy_essence)

	var pos: Vector2i = valid.front()
	var tile = core.board.get_tile(pos.x, pos.y)
	_focus_camera_on(tile.global_position, 0.8, 0.6)
	await get_tree().create_timer(0.4).timeout

	battle.place_unit(card, pos, core.ENEMY, UnitData.Mode.ATTACK, true)
	core._log("🤖 Enemy summoned %s at %s" % [card.name, str(pos)], Color(0.8,0.8,1))

func _try_move_or_attack() -> void:
	var player_pos := battle.get_leader_pos(core.PLAYER)
	var movables: Array = []
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		if u.owner == core.ENEMY and not u.is_leader:
			movables.append(pos)
	if movables.is_empty(): return

	movables.sort_custom(func(a, b):
		return a.distance_to(player_pos) < b.distance_to(player_pos)
	)

	for from in movables:
		var src = core.board.get_tile(from.x, from.y)
		if not src or not src.occupant: continue
		if not core.can_unit_act(src.occupant): continue

		var range := core.BASE_MOVE_RANGE
		# try attack first
		for dx in range(-range, range + 1):
			for dy in range(-range, range + 1):
				var dist = abs(dx)+abs(dy)
				if dist == 0 or dist > range: continue
				var target = from + Vector2i(dx, dy)
				if target.x<0 or target.y<0 or target.x>=core.BOARD_W or target.y>=core.BOARD_H: continue
				var tile = core.board.get_tile(target.x, target.y)
				if tile and tile.occupant and tile.occupant.owner == core.PLAYER:
					_focus_camera_on(tile.global_position, 0.6, 0.5)
					await get_tree().create_timer(0.3).timeout
					core._log("⚔ Enemy attacks player’s unit at %s!" % str(target), Color(1,0.7,0.7))
					await battle._move_or_battle(from, target)
					await get_tree().create_timer(0.4).timeout
					return

		# else move closer
		var best = from
		var best_dist = from.distance_to(player_pos)
		for dx in range(-range, range + 1):
			for dy in range(-range, range + 1):
				var dist = abs(dx)+abs(dy)
				if dist == 0 or dist > range: continue
				var target = from + Vector2i(dx,dy)
				if target.x<0 or target.y<0 or target.x>=core.BOARD_W or target.y>=core.BOARD_H: continue
				var t = core.board.get_tile(target.x, target.y)
				if t and t.occupant == null:
					var d = target.distance_to(player_pos)
					if d < best_dist: best = target; best_dist = d

		if best != from:
			var move_tile = core.board.get_tile(best.x, best.y)
			if move_tile:
				_focus_camera_on(move_tile.global_position, 0.75, 0.6)
				await get_tree().create_timer(0.25).timeout
			await battle._move_or_battle(from, best)
			await get_tree().create_timer(0.4).timeout
			return

func _focus_camera_on(pos: Vector3, zoom_mult: float, duration: float) -> void:
	core.emit_signal("focus_camera", pos, zoom_mult, duration)
