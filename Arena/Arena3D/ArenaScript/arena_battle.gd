# File: arena_battle.gd
extends Node
class_name ArenaBattle

const CARD_MODEL_SCALE := Vector3(0.5, 0.5, 0.5)

var core: ArenaCore
var board: Node3D
var ui: ArenaUI
var cam: ArenaCamera
var _is_battle_in_progress := false
var _camera_locked: bool = false
var _battle_cam_default_pos: Vector3
var _battle_cam_default_fov: float
@onready var hand: GridContainer = $"../UISystem/BottomContainer/Hand"

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

	# 🚫 Block hover/updates during cinematic/battle
	if _is_battle_in_progress or (core and core.is_cutscene_active):
		if hovered_tile:
			hovered_tile.set_highlight(false)
			hovered_tile = null
		if ui and not ui._is_hovering_hand_card:
			ui.hide_hover()
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

	# Skip during cutscenes/battle
	if (core and core.is_cutscene_active) or _is_battle_in_progress:
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
	# 🚫 Ignore clicks during cinematic/battle
	if _is_battle_in_progress or (core and core.is_cutscene_active):
		return

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
	# 🚫 Don't draw targets during battle/cinematic
	if _is_battle_in_progress or (core and core.is_cutscene_active):
		return

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

# -----------------------------------
# 🟩 CARD SPAWNING (uses model_path)
# -----------------------------------
func spawn_card_model(card_data: CardData) -> Node3D:
	if not card_data or card_data.model_path == "":
		print("No model path assigned for card:", card_data.name)
		return null

	var model_scene: PackedScene = load(card_data.model_path)
	if not model_scene:
		push_warning("⚠️ Could not load model scene at: %s" % card_data.model_path)
		return null

	var model_instance: Node3D = model_scene.instantiate()
	model_instance.name = "CardModel"
	model_instance.position = Vector3(0, 0.5, 0)
	model_instance.scale = CARD_MODEL_SCALE
	return model_instance

# -----------------------------
# PLACE / MOVE / BATTLE
# -----------------------------

# -----------------------------------
# 🟨 UNIT PLACEMENT ON BOARD
# -----------------------------------
func place_unit(card: CardData, pos: Vector2i, owner: int, mode: int, mark_acted := true) -> void:
	var u := UnitData.new().init_from_card(card, owner)
	u.mode = mode
	core.units[pos] = u

	var tile = board.get_tile(pos.x, pos.y)
	if not tile:
		push_error("⚠️ Tried to place a unit at invalid tile position: %s" % str(pos))
		return

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
				mesh.position.x = -0.5
				mesh.position.z = 0.0
		UnitData.Mode.FACEDOWN:
			tile.set_art(core.CARD_BACK)
			if tile.has_node("CardMesh"):
				tile.get_node("CardMesh").rotation_degrees.y = 0

	# 🟢 Set ownership badge
	tile.set_badge_text("P" if owner == core.PLAYER else "E")

	# ✅ Spawn 3D model from model_path (lazy load)
	if card.model_path != "":
		var model_instance := spawn_card_model(card)
		if model_instance:
			tile.add_child(model_instance)

			# 🔄 Flip enemy model to face the player
			if owner == core.ENEMY:
				model_instance.rotate_y(deg_to_rad(180))

	# 🎵 Play per-card placement sound if available
	if "place_sound" in card and card.place_sound:
		_play_card_sound(card.place_sound, tile.global_position)
	else:
		# fallback move/placement sound (optional)
		if core.CARD_MOVE_SOUND:
			_play_card_sound(core.CARD_MOVE_SOUND, tile.global_position)

	# ✅ Exit placement mode safely
	core.clear_card_placement_mode()

	# Optional log
	core._log("📥 %s summoned at %s" % [card.name, str(pos)], Color(0.7, 1, 0.7))

func normalize_model(model: Node3D, target_height := 1.0):
	var aabb = model.get_aabb()
	var current_height = aabb.size.y
	if current_height == 0:
		return
	var scale_factor = target_height / current_height
	model.scale = Vector3.ONE * scale_factor

func _move_or_battle(from: Vector2i, to: Vector2i) -> void:
	# 🚫 Prevent re-entry if already battling or moving
	if _is_battle_in_progress:
		return
	_is_battle_in_progress = true

	var src = board.get_tile(from.x, from.y)
	var dst = board.get_tile(to.x, to.y)
	if not src or not dst:
		_is_battle_in_progress = false
		return

	var attacker: UnitData = src.occupant
	if not attacker:
		_is_battle_in_progress = false
		return

	# 🚫 Prevent self-targeting
	if from == to:
		core._log("⚠️ You can’t attack your own tile!", Color(1, 0.6, 0.4))
		_is_battle_in_progress = false
		return

	# 🚫 Ensure attacker can act
	if not core.can_unit_act(attacker):
		core._log("⏳ That unit already acted this turn.")
		_is_battle_in_progress = false
		return

	# 🚫 Check move distance
	var dist = abs(to.x - from.x) + abs(to.y - from.y)
	if dist > core.BASE_MOVE_RANGE:
		core._log("⚠️ You can only move 1 tile per turn!", Color(1, 0.6, 0.4))
		_is_battle_in_progress = false
		return
	# ------------------------------------------------------------
	# 🟦 MOVE (no defender)
	# ------------------------------------------------------------
	if dst.occupant == null:
		# Hide any highlights/hover before moving
		clear_highlights()
		if ui and not ui._is_hovering_hand_card:
			ui.hide_hover()

		var model: Node3D = null
		var model_path := NodePath("CardModel")
		if src.has_node(model_path):
			model = src.get_node(model_path)

		dst.set_occupant(attacker)
		_play_card_sound(core.CARD_MOVE_SOUND, dst.global_position)
		dst.set_art(
			attacker.card.art if attacker.mode != UnitData.Mode.FACEDOWN else core.CARD_BACK,
			attacker.owner == core.ENEMY
		)
		dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")

		if model and is_instance_valid(model) and not model.is_queued_for_deletion():
			var world_target = dst.global_position + Vector3(0, 0.5, 0)
			var tw = create_tween()
			tw.tween_property(model, "global_position", world_target, 0.25)
			await tw.finished

		# ✅ Only move if still valid and attached
		if is_instance_valid(model):
			if is_instance_valid(src) and model.get_parent() == src:
				src.remove_child(model)
			if is_instance_valid(dst):
				# Double-check it's not freed before re-adding
				if not model.is_queued_for_deletion():
					dst.add_child(model)
					model.position = Vector3(0, 0.5, 0)


		src.clear()
		core.units.erase(from)
		core.units[to] = attacker
		core.mark_unit_acted(attacker)
		_is_battle_in_progress = false
		return

	# 🚫 Leaders cannot attack
	if attacker.is_leader:
		core._log("🚫 Leaders cannot attack.", Color(1, 0.6, 0.4))
		_is_battle_in_progress = false
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

	# 🧹 Hide all highlights + hover, and enter "cinematic" lock
	clear_highlights()
	if ui and not ui._is_hovering_hand_card:
		ui.hide_hover()
	var prev_cutscene_state := core.is_cutscene_active if core and "is_cutscene_active" in core else false
	if core and "is_cutscene_active" in core:
		core.is_cutscene_active = true

	# Run cinematic battle
	var result_data = await _play_2d_battle(attacker, defender)

	# 🔓 Leave cinematic lock
	if core and "is_cutscene_active" in core:
		core.is_cutscene_active = prev_cutscene_state

	var result: String = result_data["result"]
	var overflow_damage: int = result_data["overflow"]

	# 🧩 Apply result as before
	match result:
		"attacker_wins":
			# Defender was already killed in _play_2d_battle()
			# Move attacker into dst if attacker is still alive
			if attacker.current_def > 0:
				dst.set_occupant(attacker)
				dst.set_art(attacker.card.art, attacker.owner == core.ENEMY)
				dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")

				# move 3D model if it exists
				if src.has_node("CardModel"):
					var model = src.get_node("CardModel")
					if is_instance_valid(model):
						var world_target = dst.global_position + Vector3(0, 0.5, 0)
						var tw = create_tween()
						tw.tween_property(model, "global_position", world_target, 0.25)
						await tw.finished
						if model.get_parent() == src:
							src.remove_child(model)
						if is_instance_valid(dst):
							dst.add_child(model)
							model.position = Vector3(0, 0.5, 0)

				src.clear()
				core.units.erase(from)
				core.units[to] = attacker
			core.mark_unit_acted(attacker)

		"defender_wins":
			# Attacker was already killed
			core.mark_unit_acted(attacker)

		"both_destroyed":
			# Already handled
			pass

		"both_survive":
			dst.flash()
			core.mark_unit_acted(attacker)
			var att_tile = _get_unit_tile(attacker)
			if att_tile: att_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)
			var def_tile = _get_unit_tile(dst.occupant)
			if def_tile: def_tile.set_art(dst.occupant.card.art, dst.occupant.owner == core.ENEMY)

		"leader_damaged":
			dst.flash()
			core.mark_unit_acted(attacker)
			var att_tile = _get_unit_tile(attacker)
			if att_tile: att_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)

	# ✅ Unlock after everything completes
	_is_battle_in_progress = false

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
	
func _focus_camera_on_battle(att_tile: Node3D, def_tile: Node3D, zoom_in := true) -> void:
	if not cam or not att_tile or not def_tile:
		return

	if zoom_in:
		_camera_locked = true
		_battle_cam_default_pos = cam.position
		_battle_cam_default_fov = cam.fov

		var midpoint := (att_tile.global_position + def_tile.global_position) / 2.0
		var target_pos := midpoint + Vector3(0, 3, 6)  # adjust for your board scale

		var tw = create_tween()
		tw.tween_property(cam, "position", target_pos, 0.6)
		tw.parallel().tween_property(cam, "fov", _battle_cam_default_fov * 0.7, 0.6)
		await tw.finished
	else:
		var tw = create_tween()
		tw.tween_property(cam, "position", _battle_cam_default_pos, 0.6)
		tw.parallel().tween_property(cam, "fov", _battle_cam_default_fov, 0.6)
		await tw.finished
		_camera_locked = false

# -----------------------------
# COMBAT RESOLUTION (color-coded)
# -----------------------------
func resolve_battle(att: UnitData, defn: UnitData, silent := false) -> Dictionary:
	# NEVER mutate units here. Compute only.
	var a_atk := att.current_atk
	var a_def := att.current_def
	var d_atk := defn.current_atk
	var d_def := defn.current_def

	var result := "both_survive"
	var overflow := 0
	var damage_to_def := 0     # defender takes from attacker
	var damage_to_att := 0     # attacker takes from defender (counter)

	# Log (optional)
	if not silent:
		core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
		core._log("⚔️  BATTLE PREVIEW", Color(1,1,0.7))
		core._log("%s (ATK %d / DEF %d) ➤ %s (ATK %d / DEF %d, Mode: %s)" %
			[_colorize_name(att), a_atk, a_def, _colorize_name(defn), d_atk, d_def, str(defn.mode)],
			Color(1,0.9,0.6))

	# --- Direct attack on Leader ---
	if defn.is_leader:
		damage_to_def = a_atk           # all goes to leader HP; no counter
		result = "leader_damaged"
		if not silent:
			core._log("Leader attack: %d damage (no counter)." % damage_to_def, Color(1,0.8,0.8))
		return {"result": result, "overflow": 0, "damage_to_def": damage_to_def, "damage_to_att": 0}

	# --- Defender in DEFENSE ---
	if defn.mode == UnitData.Mode.DEFENSE:
		damage_to_def = min(a_atk, d_def)
		var d_def_after := d_def - damage_to_def
		if d_def_after <= 0:
			result = "attacker_wins"
			overflow = max(a_atk - d_def, 0)
		else:
			result = "both_survive"
		return {"result": result, "overflow": overflow, "damage_to_def": damage_to_def, "damage_to_att": 0}

	# --- Defender in ATTACK (mutual damage) ---
	if defn.mode == UnitData.Mode.ATTACK:
		damage_to_def = min(a_atk, d_def)
		damage_to_att = min(d_atk, a_def)

		var d_def_after := d_def - damage_to_def
		var a_def_after := a_def - damage_to_att

		if d_def_after <= 0:
			overflow = max(a_atk - d_def, 0)

		if a_def_after <= 0 and d_def_after <= 0:
			result = "both_destroyed"
		elif d_def_after <= 0:
			result = "attacker_wins"
		elif a_def_after <= 0:
			result = "defender_wins"
		else:
			result = "both_survive"

		return {"result": result, "overflow": overflow, "damage_to_def": damage_to_def, "damage_to_att": damage_to_att}

	# Fallback (shouldn't happen)
	if not silent:
		core._log("⚠️ Unexpected mode in battle preview.", Color(1,0.7,0.4))
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
	# 🎵 Death sound (3D positional)
	if u.card and "death_sound" in u.card and u.card.death_sound:
		_play_card_sound(u.card.death_sound, tile.global_position)
	else:
		_play_card_sound(core.CARD_DEATH_SOUND, tile.global_position)

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

		if is_instance_valid(model):
			var tw2 = create_tween()
			tw2.tween_property(model, "scale", model.scale * 0.3, 0.3)
			tw2.parallel().tween_property(model, "modulate:a", 0.0, 0.3)
			await tw2.finished

			# ✅ Wait one frame so any tweens or visuals complete
			await get_tree().process_frame

			# ✅ Then safely free the model (only if still valid)
			if is_instance_valid(model):
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
	if ui:
		ui.force_hide_hand(true)   # 🔒 hard-lock the hand hidden

	if ui and ui.hand_grid:
		ui.hand_grid.visible = false
		ui.hand_grid.modulate.a = 0.0

	if is_instance_valid(hand):
		hand.visible = false
		await get_tree().process_frame

	if ui:
		ui._lock_hp_updates = true

	var result_data = resolve_battle(att, defn, true)
	var damage_to_def: int = result_data["damage_to_def"]
	var damage_to_att: int = result_data["damage_to_att"]

	var battle_ui: BattleUI = core.get_node_or_null("UISystem/BattleUI")
	if not battle_ui:
		push_error("❌ Could not find BattleUI in UISystem — add a node named 'BattleUI'.")
		if is_instance_valid(hand):
			hand.visible = true
		return result_data

	if is_instance_valid(hand):
		hand.visible = false

	# --- 1️⃣ ATTACK PHASE ---
	# Refresh before animation so the defender shows correct starting stats
	battle_ui.refresh_stats(att, defn)
	await battle_ui.play_attack_phase(att, defn, damage_to_def)

	# Apply defender’s damage immediately and refresh again (before flash)
	if defn.is_leader:
		defn.hp = max(defn.hp - damage_to_def, 0)
		core.on_leader_damaged(defn.owner, defn.hp)
	else:
		defn.current_def = max(defn.current_def - damage_to_def, 0)
	battle_ui.refresh_stats(att, defn)

	# --- 2️⃣ COUNTER PHASE ---
	var defender_was_alive_for_counter := (
		not defn.is_leader and defn.current_def > 0 and damage_to_att > 0
	)


	# Refresh before the counter animation
	battle_ui.refresh_stats(att, defn)
	await battle_ui.play_counter_phase(defn, att, damage_to_att)

	# Apply attacker’s damage immediately after counter starts
	att.current_def = max(att.current_def - damage_to_att, 0)
	battle_ui.refresh_stats(att, defn)

	await get_tree().create_timer(0.25).timeout  # small pause for pacing

	await get_tree().process_frame

	# --- 3️⃣ CLEANUP + OVERFLOW ---
	var overflow := 0
	if not defn.is_leader and defn.current_def <= 0:
		overflow = result_data["overflow"]
		if overflow > 0:
			core.damage_leader(defn.owner, overflow)

	var attacker_dead := (not att.is_leader and att.current_def <= 0)
	var defender_dead := (not defn.is_leader and defn.current_def <= 0)

	if defender_dead:
		await _kill_unit(defn)
	if attacker_dead:
		await _kill_unit(att)

	# --- 4️⃣ Refresh battlefield visuals ---
	var att_tile := _get_unit_tile(att)
	if att_tile and att.current_def > 0:
		att_tile.set_art(att.card.art, att.owner == core.ENEMY)

	var def_tile := _get_unit_tile(defn)
	if def_tile and defn.current_def > 0:
		def_tile.set_art(defn.card.art, defn.owner == core.ENEMY)

	# --- 5️⃣ Wrap up ---
	if ui:
		ui._lock_hp_updates = false
		ui._update_hp_labels()
		ui._update_hp_bar()

	if battle_ui:
		await battle_ui.fade_out_battle()
	if hand:
		hand.visible = true
	if ui:
		ui.force_hide_hand(false)  # 🔓 release lock; phase logic can show it again
		# Optionally re-apply phase-driven visibility right away:
		ui._show_hand_and_orbs(core.phase != core.Phase.ENEMY_TURN)

	return result_data

# Helper for floating text
func _float_text(pos: Vector3, text: String, color := Color(1, 0.3, 0.3)):
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.0045  # 🔹 Larger text size (was 0.0025)
	lbl.modulate = color
	lbl.outline_size = 4
	lbl.outline_modulate = Color(0, 0, 0, 0.8)  # 🔹 Adds dark outline for contrast
	lbl.font_size = 48  # 🔹 Ensures thick readable text (if using dynamic fonts)
	lbl.position = pos + Vector3(0, 0.8, 0)

	core.add_child(lbl)

	# 🔸 Spawn with a pop (scale + fade + rise)
	lbl.scale = Vector3(0.6, 0.6, 0.6)

	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y + 1.0, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
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
