# File: arena_battle.gd
extends Node
class_name ArenaBattle

const CARD_MODEL_SCALE := Vector3(0.5, 0.5, 0.5)

var core: ArenaCore
var board: Node3D
var ui: ArenaUI
var cam: ArenaCamera

var hovered_tile: Node3D = null

func init_battle(core_ref: ArenaCore) -> void:
	core = core_ref
	board = core.board
	ui = core.get_node("UISystem")
	cam = core.get_node("CameraSystem")
	
func _input(event):
	if event.is_action_pressed("cancel_action"):
		_on_cancel_card_drag()


func _process(_dt: float) -> void:
	# Wait until core and camera are ready
	if not core or not cam:
		return
	_update_hover()
	_update_ghost_position()

# -----------------------------
# HOVER & HIGHLIGHT
# -----------------------------
func _update_hover() -> void:
	if not core or not cam or not cam.has_method("ray_pick"):
		return

	var result = cam.ray_pick(get_viewport().get_mouse_position())
	var tile: Node3D = null
	if result:
		var node = result.collider
		if node is CollisionShape3D or node is StaticBody3D:
			node = node.get_parent()
		if node and node.has_method("set_highlight"): tile = node

	if hovered_tile and hovered_tile != tile:
		hovered_tile.set_highlight(false)
		hovered_tile = null
		if ui and not ui._is_hovering_hand_card:
			ui.hide_hover()


	if tile:
		tile.set_highlight(true, "★" if core.dragging_card != null else "")
		hovered_tile = tile
		if ui and ui.has_method("show_hover_for_tile"):
			ui.show_hover_for_tile(tile)
		if core.dragging_card:
			ui.move_ghost_over(tile)


	# also tell core about current tile
	core.hovered_tile = hovered_tile
	
func show_hover_for_tile(tile: Node3D) -> void:
	if not tile:
		return

	# Skip during cutscenes
	if core and core.is_cutscene_active:
		return

	# Show card if occupied
	if tile.occupant:
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.show_unit(tile.occupant)
		if has_node("ArenaTerrainDetails"):
			$ArenaTerrainDetails.visible = false
	else:
		# Otherwise show terrain
		if has_node("ArenaTerrainDetails"):
			$ArenaTerrainDetails.show_terrain(tile.terrain_type)
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.hide_card()

func _update_ghost_position() -> void:
	# ghost is moved in UI helper; here only default when no tile
	if not core.dragging_card or not ui.ghost_card.visible: return
	if not hovered_tile:
		var mpos = get_viewport().get_mouse_position()
		var from = core.camera.project_ray_origin(mpos)
		var dir = core.camera.project_ray_normal(mpos)
		var default_pos = from + dir * 5.0
		ui.ghost_card.position = default_pos

func clear_highlights() -> void:
	for y in core.BOARD_H:
		for x in core.BOARD_W:
			var t = board.get_tile(x, y)
			if t:
				t.set_highlight(false)
				# 🔹 Hide MoveHighlight mesh
				if t.has_node("MoveHighlight"):
					t.get_node("MoveHighlight").visible = false

func show_valid_summon_tiles():
	clear_highlights()
	
	var leader_pos = core.get_leader_pos(core.PLAYER)
	var tiles_to_highlight: Array = []

	for y in range(core.BOARD_H):
		for x in range(core.BOARD_W):
			var tile = core.board.get_tile(x, y)
			if not tile:
				continue

			var dist = Vector2i(x, y).distance_to(leader_pos)
			if dist == 1 and tile.occupant == null:
				tiles_to_highlight.append(tile)

	for tile in tiles_to_highlight:
		# --- Set summon flag and highlight ---
		tile.summon_highlight = true
		tile.set_highlight(true)
		tile.set_badge_text("⬆")  # optional symbol for clarity

		# --- NEW: Enable MoveHighlight visual ---
		if tile.has_node("MoveHighlight"):
			var mh = tile.get_node("MoveHighlight")
			mh.visible = true

			# Pulse for visibility
			if tile.has_method("pulse_move_highlight"):
				tile.pulse_move_highlight()

func clear_summon_highlights():
	for tile in core.board.tiles.values():
		if tile.summon_highlight:
			tile.summon_highlight = false
			tile.set_highlight(false)

			if tile.has_node("MoveHighlight"):
				var mh = tile.get_node("MoveHighlight")
				mh.visible = false


# -----------------------------
# BOARD INTERACTION
# -----------------------------
func on_board_click(screen_pos: Vector2) -> void:
	var result = cam.ray_pick(screen_pos)
	if not result: return
	var node = result.collider
	while node and (not node.has_meta("tile_marker")):
		node = node.get_parent()
	if not node: return

	var tile = node
	match core.phase:
		core.Phase.SUMMON_OR_MOVE:
			if tile.occupant and tile.occupant.owner == core.PLAYER:
				if not core.can_unit_act(tile.occupant):
					core._log("⏳ That unit already acted this turn."); return
				core.selected_pos = Vector2i(tile.x, tile.y)
				_show_move_targets(core.selected_pos)
				core._set_phase(core.Phase.SELECT_MOVE_TARGET)
				core._update_phase_ui()
		core.Phase.SELECT_MOVE_TARGET:
			if tile.highlighted:
				await _move_or_battle(core.selected_pos, Vector2i(tile.x, tile.y))
				clear_highlights()
				core.selected_pos = Vector2i(-1,-1)
				core._set_phase(core.Phase.SUMMON_OR_MOVE)
				core._update_phase_ui()

func _show_move_targets(from: Vector2i) -> void:
	clear_highlights()
	var src = board.get_tile(from.x, from.y)
	if not src or not src.occupant: return
	if not core.can_unit_act(src.occupant): return

	var range := core.BASE_MOVE_RANGE
	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			var dist = abs(dx) + abs(dy)
			if dist == 0 or dist > range: continue
			var p = from + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= core.BOARD_W or p.y >= core.BOARD_H: continue
			var t = board.get_tile(p.x, p.y)
			if t and (t.occupant == null or t.occupant.owner != core.PLAYER):
				t.set_highlight(true, "•" if t.occupant == null else "⚔")

				# 🔹 Color enemy tiles red, empty tiles blue
				var highlight_color := Color(0.3, 0.7, 1.0)  # blue for open
				if t.occupant and t.occupant.owner != core.PLAYER:
					highlight_color = Color(1.0, 0.3, 0.3)   # red for enemy

				if t.has_method("set_move_highlight_tint"):
					t.set_move_highlight_tint(highlight_color)
				elif t.has_node("MoveHighlight"):
					var mh = t.get_node("MoveHighlight")
					mh.visible = true

				# Optional: keep pulsing effect
				if t.has_method("pulse_move_highlight"):
					t.pulse_move_highlight()


func spawn_card_model(card_data: CardData) -> Node3D:
	if not card_data.model_scene:
		print("No model assigned for card:", card_data.name)
		return null

	var model_instance = card_data.model_scene.instantiate()
	model_instance.name = "CardModel"
	model_instance.position = Vector3(0, 0.5, 0) # centered above tile
	model_instance.scale = CARD_MODEL_SCALE  # ✅ match leader scale
	return model_instance

# -----------------------------
# PLACE / MOVE / BATTLE
# -----------------------------
func place_unit(card: CardData, pos: Vector2i, owner: int, mode: int, mark_acted := true) -> void:
	var u := UnitData.new().init_from_card(card, owner)
	u.mode = mode
	core.units[pos] = u
	var tile = board.get_tile(pos.x, pos.y)
	tile.set_occupant(u)

	match u.mode:
		UnitData.Mode.ATTACK:
			tile.set_art(card.art, owner == core.ENEMY)
			if card.ability and card.ability.trigger == "on_summon":
				core._execute_card_ability(u, card.ability)
		UnitData.Mode.DEFENSE:
			tile.set_art(card.art, owner == core.ENEMY)
			if tile.has_node("CardMesh"):
				var mesh = tile.get_node("CardMesh")
				mesh.rotation_degrees.y = 90
				mesh.position = Vector3(0, mesh.position.y, 0)
				mesh.position.x = -0.5
				mesh.position.z = 0.0
		UnitData.Mode.FACEDOWN:
			tile.set_art(core.CARD_BACK)
			if tile.has_node("CardMesh"):
				tile.get_node("CardMesh").rotation_degrees.y = 0

	# set badge for ownership
	tile.set_badge_text("P" if owner == core.PLAYER else "E")
	
	# ✅ Spawn the 3D model for this card (if one exists)
	if card.model_scene:
		var model_instance = spawn_card_model(card)
		if model_instance:
			tile.add_child(model_instance)

		# ✅ Make enemy cards face the player
		if owner == core.ENEMY:
			model_instance.rotate_y(deg_to_rad(180))
			
	# ✅ Once a card is placed, exit placement mode
	core.clear_card_placement_mode()

func normalize_model(model: Node3D, target_height := 1.0):
	var aabb = model.get_aabb()
	var current_height = aabb.size.y
	if current_height == 0:
		return
	var scale_factor = target_height / current_height
	model.scale = Vector3.ONE * scale_factor

func _move_or_battle(from: Vector2i, to: Vector2i) -> void:
	var src = board.get_tile(from.x, from.y)
	var dst = board.get_tile(to.x, to.y)
	if not src or not dst: return

	var attacker: UnitData = src.occupant
	if not attacker: return


	# 🚫 Prevent self-targeting
	if from == to:
		core._log("⚠️ You can’t attack your own tile!", Color(1, 0.6, 0.4))
		return

	# 🚫 Ensure attacker can act
	if not core.can_unit_act(attacker):
		core._log("⏳ That unit already acted this turn.")
		return

	# 🚫 Check move distance
	var dist = abs(to.x - from.x) + abs(to.y - from.y)
	if dist > core.BASE_MOVE_RANGE:
		core._log("⚠️ You can only move 1 tile per turn!", Color(1, 0.6, 0.4))
		return

	# ------------------------------------------------------------
	# 🟦 MOVE (no defender)
	# ------------------------------------------------------------
	if dst.occupant == null:
		# Capture reference to model (before clearing src)
		var model: Node3D = null
		if src.has_node("CardModel"):
			model = src.get_node("CardModel")

		dst.set_occupant(attacker)
		_play_card_sound(core.CARD_MOVE_SOUND, dst.global_position)
		dst.set_art(
			attacker.card.art if attacker.mode != UnitData.Mode.FACEDOWN else core.CARD_BACK,
			attacker.owner == core.ENEMY
		)
		dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")

		# Reparent model if found
		if model:
			var world_target = dst.global_position + Vector3(0, 0.5, 0)
			var tw = create_tween()
			tw.tween_property(model, "global_position", world_target, 0.25)
			await tw.finished

			src.remove_child(model)
			dst.add_child(model)
			model.position = Vector3(0, 0.5, 0)

		src.clear()
		core.units.erase(from)
		core.units[to] = attacker
		core.mark_unit_acted(attacker)
		return
	if attacker.is_leader:
		core._log("🚫 Leaders cannot attack.", Color(1, 0.6, 0.4))
		return
	# ------------------------------------------------------------
	# 🟥 BATTLE
	# ------------------------------------------------------------
	var defender: UnitData = dst.occupant

	# Flip facedowns before battle
	if attacker.mode == UnitData.Mode.FACEDOWN:
		attacker.mode = UnitData.Mode.ATTACK
		await _flip_faceup(src, attacker.card.art)
		core._log("🔄 %s was revealed in Attack Mode!" % attacker.card.name, Color(1, 1, 0.6))

	if defender.mode == UnitData.Mode.FACEDOWN:
		defender.mode = UnitData.Mode.DEFENSE
		await _flip_faceup(dst, defender.card.art)
		core._log("❗ %s was revealed!" % defender.card.name, Color(1, 0.9, 0.7))

	# Run cinematic battle and get result
	var result_data = await _play_2d_battle(attacker, defender)
	var result: String = result_data["result"]
	var overflow_damage: int = result_data["overflow"]


	# ------------------------------------------------------------
	# 🎯 Apply result
	# ------------------------------------------------------------
	match result:
		"attacker_wins":
			await _kill_unit(defender)  # ✅ wait for death animation to finish

			# --- Move the unit data ---
			dst.set_occupant(attacker)
			dst.set_art(attacker.card.art, attacker.owner == core.ENEMY)
			dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")

			# --- Move the 3D model (if exists) ---
			if src.has_node("CardModel"):
				var model = src.get_node("CardModel")
				var world_target = dst.global_position + Vector3(0, 0.5, 0)
				var tw = create_tween()
				tw.tween_property(model, "global_position", world_target, 0.25)
				await tw.finished

				src.remove_child(model)
				dst.add_child(model)
				model.position = Vector3(0, 0.5, 0)

			# --- Cleanup ---
			src.clear()
			core.units.erase(from)
			core.units[to] = attacker
			core.mark_unit_acted(attacker)


		"defender_wins":
			_kill_unit(attacker)
			core.mark_unit_acted(attacker)

		"both_destroyed":
			await _kill_unit(defender)
			await _kill_unit(attacker)


		"both_survive":
			dst.flash()
			core.mark_unit_acted(attacker)

			# ✅ Refresh survivors visually
			var att_tile = _get_unit_tile(attacker)
			if att_tile: att_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)

			var def_tile = _get_unit_tile(defender)
			if def_tile: def_tile.set_art(defender.card.art, defender.owner == core.ENEMY)

		"leader_damaged":
			dst.flash()
			core.mark_unit_acted(attacker)

			# ✅ Refresh attacker visuals in case they fade
			var att_tile = _get_unit_tile(attacker)
			if att_tile: att_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)

func _on_cancel_card_drag():
	if core.dragging_card:
		# Hide the ghost
		if ui and ui.ghost_card:
			ui.ghost_card.visible = false

		# Return the card to the player hand (depends on your UI system)
		if ui and core.dragging_card:
			ui.return_card_to_hand(core.dragging_card)

		# Clear drag reference
		core.dragging_card = null

		# Reset highlights and hover
		clear_highlights()
		hovered_tile = null
		ui.hide_hover()

		core._log("🌀 Card placement canceled.", Color(0.8, 0.8, 1))

func _fizzle_out(sprite: Sprite3D) -> void:
	if not sprite: return
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector3.ZERO, 0.3)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3)
	await tw.finished

# -----------------------------
# COMBAT RESOLUTION (no negatives)
# -----------------------------
# -----------------------------
# COMBAT RESOLUTION (color-coded)
# -----------------------------
func resolve_battle(att: UnitData, defn: UnitData, silent := false) -> Dictionary:
	var a := att.current_atk
	var d := defn.current_def
	var result := "both_survive"
	var overflow := 0
	var damage_to_def := 0
	var damage_to_att := 0

	if not silent:
		core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
		core._log("⚔️  BATTLE COMMENCES!", Color(1, 1, 0.7))
		core._log("%s (ATK %d / DEF %d) ➤ %s (ATK %d / DEF %d, Mode: %s)" %
			[_colorize_name(att), a, att.current_def, _colorize_name(defn),
			defn.current_atk, defn.current_def, str(defn.mode)],
			Color(1, 0.9, 0.6))

	# --- Direct leader hit ---
	if defn.is_leader:
		if not silent:
			core._log("📊  Damage Calc: %d (ATK) - 0 (Leader DEF) = %d Leader damage" % [a, a],
				Color(0.9, 0.9, 0.9))
		defn.hp = max(defn.hp - a, 0)
		damage_to_def = a
		result = "leader_damaged"

		if not silent:
			core._log("💥 %s strikes directly at the LEADER for %d damage!" %
				[_colorize_name(att), a], Color(1, 0.6, 0.6))
			core._log("🏁 Leader HP: %d → %d" % [defn.hp + a, defn.hp], Color(1, 0.8, 0.8))
		core.on_leader_damaged(defn.owner, defn.hp)
		if defn.hp <= 0:
			if not silent:
				core._log("💀 The Leader has been defeated!", Color(1, 0.4, 0.4))
			core.on_leader_defeated(defn.owner)
		if not silent:
			core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
		return {"result": result, "overflow": overflow, "damage_to_def": damage_to_def, "damage_to_att": 0}

	# --- Defense Mode ---
	if defn.mode == UnitData.Mode.DEFENSE:
		if not silent:
			core._log("🛡 %s defends against the attack!" % [_colorize_name(defn)], Color(0.7, 0.9, 1.0))
			core._log("📊  Damage Calc: %d (ATK) - %d (DEF) = %d" %
				[a, defn.current_def, a - defn.current_def], Color(0.9, 0.9, 0.9))

		var old_def := defn.current_def
		defn.current_def = max(defn.current_def - a, 0)
		damage_to_def = min(a, old_def)

		if a > old_def or defn.current_def <= 0:
			result = "attacker_wins"
			overflow = max(a - old_def, 0)
			if not silent:
				core._log("💥 Defense broken! %s takes %d damage." %
					[_colorize_name(defn), damage_to_def], Color(1, 0.8, 0.5))

			if overflow > 0:
				var target_owner := defn.owner
				if not silent:
					core._log("📊  Overflow: %d (ATK) - %d (DEF) = %d → Leader damage" %
						[a, old_def, overflow], Color(0.9, 0.9, 0.9))
				core.damage_leader(target_owner, overflow)
				if not silent:
					core._log("💔 %s Leader takes %d overflow damage!" %
						["[color=#FF6666]Enemy[/color]" if target_owner == core.ENEMY else "[color=#55CCFF]Player[/color]",
						overflow], Color(1, 0.7, 0.7))

				if (target_owner == core.PLAYER and core.player_leader.hp <= 0) \
				or (target_owner == core.ENEMY and core.enemy_leader.hp <= 0):
					if not silent:
						core._log("💀 The Leader has been defeated!", Color(1, 0.4, 0.4))
					core.on_leader_defeated(target_owner)
		else:
			result = "both_survive"
			if not silent:
				core._log("🪨 %s withstands the attack! Remaining DEF: %d" %
					[_colorize_name(defn), defn.current_def], Color(0.6, 1.0, 0.6))
		return {"result": result, "overflow": overflow, "damage_to_def": damage_to_def, "damage_to_att": 0}

	# --- Attack vs Attack ---
	if defn.mode == UnitData.Mode.ATTACK:
		if not silent:
			core._log("⚔️  Both units attack simultaneously!", Color(1, 0.9, 0.6))
			core._log("📊  Attack Step: %d (ATK) - %d (DEF) = %d damage to defender" %
				[a, defn.current_def, max(a - defn.current_def, 0)], Color(0.9, 0.9, 0.9))

		var old_def_defn := defn.current_def
		var old_def_att := att.current_def

		defn.current_def = max(defn.current_def - a, 0)
		damage_to_def = min(a, old_def_defn)

		if not defn.is_leader:
			if not silent:
				core._log("📊  Counter Step: %d (ATK) - %d (DEF) = %d damage to attacker" %
					[defn.current_atk, att.current_def, max(defn.current_atk - att.current_def, 0)],
					Color(0.9, 0.9, 0.9))
			damage_to_att = min(defn.current_atk, att.current_def)
			att.current_def = max(att.current_def - defn.current_atk, 0)

		if not silent:
			core._log("💢 %s inflicts %d damage on %s (%d → %d DEF)" %
				[_colorize_name(att), damage_to_def, _colorize_name(defn),
				old_def_defn, defn.current_def], Color(1, 0.8, 0.5))
		_trigger_ability(att, "on_attack")

		if not defn.is_leader and not silent:
			core._log("💢 %s counterattacks for %d damage on %s (%d → %d DEF)" %
				[_colorize_name(defn), damage_to_att, _colorize_name(att),
				old_def_att, att.current_def], Color(1, 0.8, 0.5))

		core.card_details_ui.call("refresh_if_showing", defn)
		core.card_details_ui.call("refresh_if_showing", att)

		var attacker_dead := att.current_def <= 0
		var defender_dead := defn.current_def <= 0

		# 🩸 Overflow check happens BEFORE deciding final outcome
		if defender_dead:
			overflow = max(a - old_def_defn, 0)
			if overflow > 0:
				var target_owner := defn.owner
				if not silent:
					core._log("📊  Overflow: %d (ATK) - %d (DEF) = %d → Leader damage" %
						[a, old_def_defn, overflow], Color(0.9, 0.9, 0.9))
				core.damage_leader(target_owner, overflow)
				if not silent:
					core._log("💔 %s Leader takes %d overflow damage!" %
						["[color=#FF6666]Enemy[/color]" if target_owner == core.ENEMY else "[color=#55CCFF]Player[/color]",
						overflow], Color(1, 0.7, 0.7))

				if (target_owner == core.PLAYER and core.player_leader.hp <= 0) \
				or (target_owner == core.ENEMY and core.enemy_leader.hp <= 0):
					if not silent:
						core._log("💀 The Leader has been defeated!", Color(1, 0.4, 0.4))
					core.on_leader_defeated(target_owner)

		# 🎯 Decide battle outcome
		if attacker_dead and defender_dead:
			result = "both_destroyed"
			if not silent:
				core._log("☠️  Both units are destroyed!", Color(1, 0.5, 0.5))
		elif defender_dead:
			result = "attacker_wins"
			if not silent:
				core._log("🏆 %s defeats %s!" %
					[_colorize_name(att), _colorize_name(defn)], Color(0.7, 1.0, 0.7))
		elif attacker_dead:
			if not silent:
				core._log(("❌ %s falls in battle." % [_colorize_name(att)]), Color(1, 0.4, 0.4))
		else:
			result = "both_survive"
			if not silent:
				core._log("🤜 Both fighters remain standing!", Color(0.8, 0.8, 1.0))

		if not silent:
			core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
		return {"result": result, "overflow": overflow, "damage_to_def": damage_to_def, "damage_to_att": damage_to_att}

	if not silent:
		core._log("⚠️  Unexpected mode in battle between %s and %s" %
			[_colorize_name(att), _colorize_name(defn)], Color(1, 0.7, 0.4))
		core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
	return {"result": "both_survive", "overflow": 0, "damage_to_def": 0, "damage_to_att": 0}

# -----------------------------
# PASSIVES / KILL / HELPERS
# -----------------------------
func apply_all_passives() -> void:
	print("🧊 apply_all_passives: units=", core.units.size())
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		var ab = u.card.ability
		var trig = ab.trigger if (ab and ab is CardAbility and "trigger" in ab) else "nil"
		print(" -", u.card.name, " ability:", ab, "type:", typeof(ab), "trigger:", trig)

		if ab and ab is CardAbility and trig == "passive":
			ab.execute(core, u)
			print("executed passive ability")

	# ✅ Refresh DEF labels for all tiles after passives
	for pos in core.units.keys():
		var tile = core.board.get_tile(pos.x, pos.y)
		var unit: UnitData = core.units[pos]
		if tile and tile.occupant == unit:
			tile.set_art(unit.card.art, unit.owner == core.ENEMY)
			# 🔹 Optional: if tiles display DEF stat text, update it here
			if tile.has_method("update_stat_labels"):
				tile.update_stat_labels(unit.current_atk, unit.current_def)


	# ✅ Also refresh the card details panel if visible
	if core.card_details_ui and core.card_details_ui.visible:
		core.card_details_ui.call("refresh_if_showing", core.card_details_ui.current_unit)
		
func _colorize_name(unit: UnitData) -> String:
	if not unit or not unit.card:
		return ""
	var color = "#55CCFF" if unit.owner == core.PLAYER else "#FF6666"
	return "[color=%s]%s[/color]" % [color, unit.card.name]

func apply_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	ability.execute(core, unit)
	unit.set_meta("passive_active", true)

func _trigger_ability(unit: UnitData, trigger: String) -> void:
	if not unit or not unit.card or not unit.card.ability:
		return

	var ab = unit.card.ability
	if ab.trigger == trigger:
		ab.execute(core, unit)

		# ✅ Always refresh UI after ability triggers
		if core and core.card_details_ui and core.card_details_ui.visible:
			core.card_details_ui.call("refresh_if_showing", unit)


func remove_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	if ability.has_method("remove"): ability.remove(core, unit)

func _kill_unit(u: UnitData, silent := false) -> void:
	if u == null: return
	if u.current_def > 0 and not u.is_leader:
		return

	# Remove passive effects if active
	if u.card and u.card.ability and u.card.ability.trigger == "passive":
		remove_passive_effect(u, u.card.ability)

	# Find tile
	var found_pos := Vector2i(-1, -1)
	for pos in core.units.keys():
		if core.units[pos] == u:
			found_pos = pos
			break

	if found_pos == Vector2i(-1, -1):
		return

	var tile = core.board.get_tile(found_pos.x, found_pos.y)
	if not tile:
		return

	# --- Fade out & clear mesh ---
	if tile.has_node("CardMesh"):
		var mesh = tile.get_node("CardMesh")
		var tw = create_tween()
		tw.tween_property(mesh, "modulate:a", 0.0, 0.3)
		tw.tween_property(mesh, "scale", mesh.scale * 0.5, 0.3)
		await tw.finished

	# --- Fade out & remove 3D model if exists ---
	if tile.has_node("CardModel"):
		var model = tile.get_node("CardModel")
		var tw2 = create_tween()
		tw2.tween_property(model, "scale", model.scale * 0.3, 0.3)
		tw2.parallel().tween_property(model, "modulate:a", 0.0, 0.3)
		await tw2.finished
		model.queue_free()

	tile.clear()
	core.units.erase(found_pos)
	core.card_details_ui.call("hide_card")
	if not silent:
		core._log("💀 %s was destroyed." % u.card.name, Color(1, 0.4, 0.4))
func clear_exhausted_tiles() -> void:
	for pos in core.units.keys():
		var t = board.get_tile(pos.x, pos.y)
		if t: t.set_exhausted(false)

func set_exhausted_for_unit(u: UnitData, exhausted: bool) -> void:
	for pos in core.units.keys():
		if core.units[pos] == u:
			var t = board.get_tile(pos.x, pos.y)
			if t: t.set_exhausted(exhausted)
			return

func get_leader_pos(owner: int) -> Vector2i:
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		if u.is_leader and u.owner == owner: return pos
	return Vector2i(-1, -1)

func _get_unit_tile(u: UnitData) -> Node3D:
	for pos in core.units.keys():
		if core.units[pos] == u:
			return board.get_tile(pos.x, pos.y)
	return null

# -----------------------------
# CINEMATIC BATTLE (wraps fade + scene)
# -----------------------------
func _play_2d_battle(att: UnitData, defn: UnitData) -> Dictionary:
	# Temporarily disable HP bar updates during battle
	if ui:
		ui._lock_hp_updates = true

	var att_def_before := att.current_def
	var def_def_before := defn.current_def
	var def_leader_hp_before := defn.hp
	var att_leader_hp_before := att.hp

	# --- Compute result silently (no logs yet) ---
	var result_data = resolve_battle(att, defn, true)
	var result: String = result_data["result"]
	var damage_to_def: int = result_data["damage_to_def"]
	var damage_to_att: int = result_data["damage_to_att"]
	var overflow_damage: int = result_data["overflow"]
# --- Add math summary for clarity ---

	# --- Restore for visuals ---
	att.current_def = att_def_before
	defn.current_def = def_def_before
	if defn.is_leader:
		defn.hp = def_leader_hp_before

	await _fade(1.0, 0.2)

	# --- Announce battle ---
	core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
	core._log("⚔️  BATTLE COMMENCES!", Color(1, 1, 0.7))
	core._log("%s engages %s!" % [_colorize_name(att), _colorize_name(defn)], Color(1, 0.9, 0.6))
	await get_tree().create_timer(0.5).timeout

	# Find tile visuals
	var att_tile := _get_unit_tile(att)
	var def_tile := _get_unit_tile(defn)
	var att_mesh := att_tile.get_node("CardMesh") if att_tile and att_tile.has_node("CardMesh") else null
	var def_mesh := def_tile.get_node("CardMesh") if def_tile and def_tile.has_node("CardMesh") else null



	# 1️⃣ Attacker strikes
	core._log("💢 %s attacks for %d!" % [_colorize_name(att), damage_to_def], Color(1, 0.8, 0.5))
	if ui and ui.has_method("play_attack_step"):
		await ui.play_attack_step(att, defn, damage_to_def)

	if def_mesh:
		await _card_pulse(def_mesh, Color(1, 0.5, 0.5))
		_float_text(def_mesh.global_position, "-%d" % damage_to_def)
		_camera_shake(0.07, 0.2)
		_play_card_sound(core.CARD_MOVE_SOUND, def_mesh.global_position)

	await get_tree().create_timer(0.4).timeout

	# 2️⃣ Counterattack (if any)
	if damage_to_att > 0:
		core._log("🛡 %s counterattacks for %d!" % [_colorize_name(defn), damage_to_att], Color(1, 0.8, 0.5))
		if ui and ui.has_method("play_attack_step"):
			await ui.play_attack_step(defn, att, damage_to_att)
		if att_mesh:
			await _card_pulse(att_mesh, Color(0.6, 0.8, 1))
			_float_text(att_mesh.global_position, "-%d" % damage_to_att, Color(0.6,0.8,1))
			_camera_shake(0.06, 0.15)
			_play_card_sound(core.CARD_MOVE_SOUND, att_mesh.global_position)
		await get_tree().create_timer(0.3).timeout

	# 3️⃣ Overflow damage
# 3️⃣ Overflow damage (visual only — already applied in resolve_battle)
	if overflow_damage > 0:
		await _float_text(def_mesh.global_position, "-%d" % overflow_damage, Color(1,0.7,0.7))
		_camera_shake(0.1, 0.25)
		await get_tree().create_timer(0.3).timeout

	# 4️⃣ Result & aftermath
	match result:
		"attacker_wins":
			core._log("🏆 %s defeats %s!" % [_colorize_name(att), _colorize_name(defn)], Color(0.7, 1.0, 0.7))
		"defender_wins":
			core._log("❌ %s falls in battle." % _colorize_name(att), Color(1, 0.4, 0.4))
		"both_destroyed":
			core._log("☠️  Both units are destroyed!", Color(1, 0.5, 0.5))
		"both_survive":
			core._log("🤜 Both fighters remain standing!", Color(0.8, 0.8, 1.0))
		"leader_damaged":
			core._log("💥 %s directly hits the leader!" % _colorize_name(att), Color(1, 0.6, 0.6))
	
	core._log("📊  Battle Math Summary:", Color(0.9, 0.9, 0.9))
	core._log("• %s ATK: %d  |  %s DEF: %d" %
		[_colorize_name(att), att.current_atk, _colorize_name(defn), defn.current_def],
		Color(0.9, 0.9, 0.9))
	core._log("• Damage to Defender: %d  |  Damage to Attacker: %d  |  Overflow: %d" %
		[damage_to_def, damage_to_att, overflow_damage],
		Color(0.9, 0.9, 0.9))

	core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
	await get_tree().create_timer(0.6).timeout

	# Apply final results visually
	if not defn.is_leader:
		defn.current_def = max(def_def_before - damage_to_def, 0)
	else:
		defn.hp = max(def_leader_hp_before - damage_to_def, 0)
		core.on_leader_damaged(defn.owner, defn.hp)

	if damage_to_att > 0:
		att.current_def = max(att_def_before - damage_to_att, 0)

	#if overflow_damage > 0:
		#var target_owner := defn.owner
		#core.damage_leader(target_owner, overflow_damage)

	# Refresh visuals
	if att_tile: att_tile.set_art(att.card.art, att.owner == core.ENEMY)
	if def_tile: def_tile.set_art(defn.card.art, defn.owner == core.ENEMY)

	# Kill animations if destroyed
	if att.current_def <= 0 and not att.is_leader:
		await _kill_unit(att, true)
	if defn.current_def <= 0 and not defn.is_leader:
		await _kill_unit(defn, true)

	await _fade(0.0, 0.2)
		# ✅ Now allow HP updates and sync bars to final HP
	if ui:
		ui._lock_hp_updates = false
		ui._update_hp_labels()
		ui._update_hp_bar()

	return result_data
	# Helper for floating text
func _float_text(pos: Vector3, text: String, color := Color(1,0.3,0.3)):
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.0025
	lbl.modulate = color
	lbl.position = pos + Vector3(0, 0.5, 0)
	core.add_child(lbl)
	var tw = create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.8, 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	await tw.finished
	lbl.queue_free()

# Helper for shake
func _camera_shake(intensity := 0.1, duration := 0.2):
	if not cam: return
	var base_pos = cam.position
	var t := 0.0
	while t < duration:
		cam.position = base_pos + Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0)
		await get_tree().process_frame
		t += get_process_delta_time()
	cam.position = base_pos
func _add_card_highlight(sprite: Sprite3D, color: Color) -> Node3D:
	var glow := MeshInstance3D.new()
	glow.mesh = QuadMesh.new()
	glow.scale = Vector3(1.3, 1.3, 1.3) # slightly bigger than the card art
	glow.position = sprite.position - Vector3(0, 0, 0.01) # 👈 push it slightly behind the sprite

	var mat := StandardMaterial3D.new()
	mat.unshaded = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy = 3.0
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.alpha_scissor_threshold = 0.05
	mat.disable_receive_shadows = true
	mat.disable_ambient_light = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # ensures it's visible even when viewed edge-on
	glow.material_override = mat

	# Ensure it’s rendered behind the art
	glow.sorting_offset = -1

	sprite.get_parent().add_child(glow)
	glow.look_at(sprite.global_position, Vector3.UP)

	return glow

func _card_explode(sprite: Sprite3D, color: Color):
	if not sprite:
		return

	var p := GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 1.0
	p.one_shot = true
	p.position = sprite.position

	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3(0, -9.8, 0)
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 8.0
	mat.scale_min = 0.05
	mat.scale_max = 0.1
	mat.angle_min = -15.0
	mat.angle_max = 15.0
	mat.color = color

	# ✅ Set emission shape here (on the material, not the particles node)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2

	# ✅ Add fade-out gradient
	var grad := Gradient.new()
	grad.add_point(0.0, color)
	grad.add_point(1.0, Color(color.r, color.g, color.b, 0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	p.process_material = mat
	p.emitting = true

	sprite.get_parent().add_child(p)
	sprite.visible = false

	await get_tree().create_timer(1.0).timeout
	p.queue_free()

func _card_pulse(target: Node3D, color: Color) -> void:
	if not target:
		return

	# Try to access modulate safely
	var has_modulate := target.has_method("set_modulate")
	if not has_modulate and target.get("modulate") == null:
		# Not a visual node (like MeshInstance3D without modulate)
		# → create a temporary emission flash instead
		var flash := OmniLight3D.new()
		flash.light_color = color
		flash.light_energy = 2.0
		flash.omni_range = 2.0
		target.add_child(flash)
		var tw_flash = create_tween()
		tw_flash.tween_property(flash, "light_energy", 0.0, 0.3)
		await tw_flash.finished
		flash.queue_free()
		return

	# Pulse modulate for visible nodes (Sprite3D, MeshInstance3D, etc.)
	var original_mod = target.modulate if target.get("modulate") != null else Color(1, 1, 1)
	var tw = create_tween()
	tw.tween_property(target, "modulate", color, 0.15)
	tw.tween_property(target, "modulate", original_mod, 0.25)
	await tw.finished

# -----------------------------
# VISUAL HELPERS
# -----------------------------
func _flip_faceup(tile: Node3D, new_texture: Texture2D):
	var mesh = tile.get_node("CardMesh")
	var tw = create_tween()
	tw.tween_property(mesh, "rotation_degrees:y", 90, 0.15)
	await tw.finished
	tile.set_art(new_texture, tile.occupant.owner == core.ENEMY)

	tw = create_tween()
	tw.tween_property(mesh, "rotation_degrees:y", 0, 0.15)
	await tw.finished

func _fade(to_alpha: float, dur: float):
	var rect: ColorRect = core.get_node("UISystem/FadeRect")

	var tw = create_tween()
	tw.tween_property(rect, "modulate:a", to_alpha, dur)
	await tw.finished

func _play_card_sound(sound: AudioStream, position := Vector3.ZERO):
	if not sound: return
	var p := AudioStreamPlayer3D.new()
	core.add_child(p)
	p.stream = sound
	p.global_position = position
	p.unit_size = 5.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.volume_db = -10.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
	p.connect("finished", Callable(p, "queue_free"))
