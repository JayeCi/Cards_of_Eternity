# File: arena_battle.gd
extends Node
class_name ArenaBattle

#const CARD_MODEL_SCALE := Vector3(0.25, 0.25, 0.25)

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

func _try_toggle_face() -> void:
	# --- Resolve which tile we are acting on ---
	var tile: Node3D = null
	if core.selected_pos != Vector2i(-1, -1):
		tile = board.get_tile(core.selected_pos.x, core.selected_pos.y)
	elif core.hovered_tile:
		tile = core.hovered_tile
	else:
		return
	if not tile or not tile.occupant:
		return

	var unit = tile.occupant

	# 🚫 Player-only, not enemy turn
	if unit.owner != core.PLAYER:
		return
	if core.phase == core.Phase.ENEMY_TURN:
		return

	# 🔒 Lock flags
	var is_locked = unit.has_meta("flipped_permanent") and unit.get_meta("flipped_permanent")
	var allow_session_toggle = unit.has_meta("allow_face_toggle_session") and unit.get_meta("allow_face_toggle_session")

	# Current face state
	var is_down = unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown"))

	if is_down:
		# ✅ Facedown → Face-up
		unit.is_facedown = false
		unit.set_meta("is_facedown", false)
		unit.mode = UnitData.Mode.ATTACK
		tile.set_art(unit.card.art, unit.owner == core.ENEMY)
		tile.set_badge_text("A")
		core._log("⚡ %s flipped face-up!" % unit.card.name, Color(1.0, 1.0, 0.6))

		if unit.has_meta("model_instance"):
			var m = unit.get_meta("model_instance")
			if is_instance_valid(m):
				m.visible = true

		core.refresh_tile_art_safe(core.board.get_unit_position(unit))
		
		# ✅ If card has an "on_summon" or "on_flip" ability → defer until confirmed
		if unit.card and unit.card.ability:
			var ab = unit.card.ability
			if ab.trigger in ["on_summon", "on_flip"]:
				# Defer activation until confirmation (store ability for later)
				unit.set_meta("pending_on_flip_ability", ab)
				core._log("💡 %s ability will activate once face-up is confirmed." % ab.display_name, Color(0.8, 0.9, 1.0))

			else:
				# Non-flip abilities can still be marked pending normally
				unit.set_meta("pending_ability", ab)
				core._log("💡 %s ability ready — click to activate." % ab.display_name, Color(0.8, 0.8, 1.0))

	else:
		# 🔁 Face-up → Facedown (only if allowed)
		if allow_session_toggle and not is_locked:
			unit.is_facedown = true
			unit.set_meta("is_facedown", true)
			unit.mode = UnitData.Mode.FACEDOWN
			tile.set_art(core.CARD_BACK)
			tile.set_badge_text("?")
			core._log("🃏 %s was set facedown." % unit.card.name, Color(0.8, 0.8, 1.0))

			if unit.has_meta("model_instance"):
				var m2 = unit.get_meta("model_instance")
				if is_instance_valid(m2):
					m2.visible = false

			core.refresh_tile_art_safe(core.board.get_unit_position(unit))
		else:
			core._log("⛔ Face-up cards cannot be set facedown now.", Color(1, 0.6, 0.6))

func _clear_toggle_session_flag():
	if core and core.selected_pos != Vector2i(-1, -1):
		var t = board.get_tile(core.selected_pos.x, core.selected_pos.y)
		if t and t.occupant:
			t.occupant.set_meta("allow_face_toggle_session", false)

func _unhandled_input(event):
	if event.is_action_pressed("cancel_action"):
		_on_cancel_card_drag()

	# 🔹 Allow R toggle for both placement and facedown cards on board
	if event.is_action_pressed("toggle_face"):
		if core.phase in [core.Phase.SUMMON_OR_MOVE, core.Phase.SELECT_SUMMON_TILE, core.Phase.SELECT_MOVE_TARGET]:
			_try_toggle_face()


func _process(_dt: float) -> void:
	# Wait until core and camera are ready
	if not core or not cam:
		return
	_update_hover()
	_update_ghost_position()
	
# 🔹 Reapply any accumulated ATK boosts (e.g., BoostAttack)
func _apply_attack_bonus(unit: UnitData) -> void:
	if unit and unit.has_meta("boost_attack_bonus"):
		var bonus = unit.get_meta("boost_attack_bonus")
		unit.current_atk = unit.card.atk + bonus

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
	
func _reset_hover_state() -> void:
	_is_battle_in_progress = false
	if core:
		core.is_cutscene_active = false
	if ui:
		ui._is_hovering_hand_card = false
		ui.is_dragging_card = false
		ui.hide_hover()

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
	if not result:
		return

	var node = result.collider
	while node and (not node.has_meta("tile_marker")):
		node = node.get_parent()
	if not node:
		return

	var tile: Node3D = node

	# ✅ Allow clicking empty tile ONLY if moving a selected unit
	var is_moving := (core.phase == core.Phase.SELECT_MOVE_TARGET and core.selected_pos != Vector2i(-1, -1))
	var is_placing := (core.dragging_card != null)

	if tile.occupant == null and not is_moving and not is_placing:
		core._log("💡 Click ignored — empty tile.", Color(0.7, 0.7, 0.7))
		return

	# ✅ Handle pending ability trigger on clicked occupied tile
	var pending_unit: UnitData = null
	var pending_ability: CardAbility = null
	if tile.occupant and tile.occupant.has_meta("pending_ability"):
		pending_unit = tile.occupant
		pending_ability = pending_unit.get_meta("pending_ability")

	if pending_unit and pending_ability:
		core._execute_card_ability(pending_unit, pending_ability)
		pending_unit.set_meta("pending_ability", null)
		core._log("✨ %s ability activated!" % pending_ability.display_name, Color(1.0, 1.0, 0.6))
		return

	# 🚫 If player is dragging a card, handle placement only
	if is_placing:
		core.try_place_dragged_card(tile)
		return

	# ✅ Moving existing unit to empty or enemy tile
	if is_moving:
		if tile.highlighted:
			await _move_or_battle(core.selected_pos, Vector2i(tile.x, tile.y))
			clear_highlights()
			core.selected_pos = Vector2i(-1, -1)
			core._set_phase(core.Phase.SUMMON_OR_MOVE)
			core._update_phase_ui()
		return

	# ✅ Only allow phase change if clicking a tile that HAS a unit
	if tile.occupant == null:
		core._log("💡 No unit to select here.", Color(0.7, 0.7, 0.7))
		return

	match core.phase:
		core.Phase.SUMMON_OR_MOVE:
			# Select unit on board to move
			core.selected_pos = Vector2i(tile.x, tile.y)
			if tile.occupant and (tile.occupant.is_facedown or (tile.occupant.has_meta("is_facedown") and tile.occupant.get_meta("is_facedown"))):
				tile.occupant.set_meta("allow_face_toggle_session", true)
			else:
				tile.occupant.set_meta("allow_face_toggle_session", false)

			_show_move_targets(core.selected_pos)
			core._set_phase(core.Phase.SELECT_MOVE_TARGET)
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
#func spawn_card_model(card_data: CardData) -> Node3D:
	#if not card_data or card_data.model_path == "":
		#print("No model path assigned for card:", card_data.name)
		#return null
#
	#var model_scene: PackedScene = load(card_data.model_path)
	#if not model_scene:
		#push_warning("⚠️ Could not load model scene at: %s" % card_data.model_path)
		#return null
#
	#var model_instance: Node3D = model_scene.instantiate()
	#model_instance.name = "CardModel"
	#model_instance.position = Vector3(0, 0.5, 0)
#
	## 🟢 Use model's own scale from its scene — do not override here
	## (optional: if you want to apply a small global tweak, multiply)
	## model_instance.scale *= Vector3(1, 1, 1)  # fine-tune globally if ever needed
#
	#return model_instance

# -----------------------------
# PLACE / MOVE / BATTLE
# -----------------------------

# -----------------------------------
# 🟨 UNIT PLACEMENT ON BOARD
# -----------------------------------
func place_unit(card: CardData, pos: Vector2i, owner: int, mode: int, is_player: bool = false) -> void:
	var tile = board.get_tile(pos.x, pos.y)
	if not tile:
		core._log("⚠️ Tried to place unit on invalid tile: %s" % str(pos))
		return

	if tile.occupant != null:
		core._log("⚠️ Tile already occupied at %s" % str(pos))
		return

	# --- Create the UnitData ---
	var unit := UnitData.new().init_from_card(card, owner)
	unit.mode = mode
	core.units[pos] = unit
	tile.set_occupant(unit)

	# --- Determine if facedown ---
	var is_facedown := (mode == UnitData.Mode.FACEDOWN)

	if is_facedown:
		tile.set_art(core.CARD_BACK)
		unit.is_facedown = true
		unit.set_meta("is_facedown", true)
	else:
		tile.set_art(card.art)
		unit.is_facedown = false
		unit.set_meta("is_facedown", false)

	# --- Spawn 3D model if available ---
	if card.model_path != "":
		var model_scene: PackedScene = load(card.model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "CardModel"
			if card.model_position != Vector3(0 , 0 , 0):
				model_instance.position = card.model_position
				
			if card.model_scale != Vector3(.5, .5, .5):
				model_instance.scale = card.model_scale

			tile.add_child(model_instance)
			unit.set_meta("model_instance", model_instance)
			if owner == core.ENEMY:
				model_instance.rotate_y(deg_to_rad(180))
						
			# ✅ Proper visibility logic for player/enemy placement
			if is_facedown:
				model_instance.visible = false
			else:
				# Only show player cards face-up immediately
				model_instance.visible 


	# --- Show badge for mode ---
	match mode:
		UnitData.Mode.ATTACK:
			tile.set_badge_text("A")
		UnitData.Mode.DEFENSE:
			tile.set_badge_text("D")
		UnitData.Mode.FACEDOWN:
			tile.set_badge_text("?")

	# --- Apply terrain bonuses ---
	var terrain = tile.terrain_type
	core._apply_terrain_bonus(unit, terrain)

# --- Trigger abilities only after placement completes and card is visible ---
	await get_tree().process_frame  # ensures model and tile visuals exist first
	if not is_facedown and card.ability and card.ability.trigger == "on_summon":
		core._execute_card_ability(unit, card.ability)


	# --- Play placement SFX ---
	core._play_card_place_sound()

	# --- Log ---
	var name_str = card.name if not is_facedown else "a facedown card"
	core._log("🎴 %s placed on (%d,%d)" % [name_str, pos.x, pos.y])

func normalize_model(model: Node3D, target_height := 1.0):
	var aabb = model.get_aabb()
	var current_height = aabb.size.y
	if current_height == 0:
		return
	var scale_factor = target_height / current_height
	model.scale = Vector3.ONE * scale_factor

func _move_or_battle(from: Vector2i, to: Vector2i, bypass_control_check := false) -> void:

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
	# 🚫 Prevent player from controlling enemy units unless bypassed (AI)
	if not bypass_control_check and attacker.owner != core.PLAYER:
		core._log("🚫 You can’t control enemy cards!", Color(1, 0.5, 0.5))
		_is_battle_in_progress = false
		return


	# 🟢 Self-click = stay in place but trigger ability & exhaust
	if from == to:
		var tile = board.get_tile(from.x, from.y)
		if not tile or not tile.occupant:
			_is_battle_in_progress = false
			return

		var unit = tile.occupant
		# ✅ Prevent double action
		if not core.can_unit_act(unit):
			core._log("⏳ %s has already acted this turn." % unit.card.name)
			_is_battle_in_progress = false
			return

		# ✅ Trigger pending flip or summon ability at current tile
		if unit.has_meta("pending_on_flip_ability"):
			var ab = unit.get_meta("pending_on_flip_ability")
			unit.set_meta("pending_on_flip_ability", null)
			if ab:
				core._log("✨ %s activates %s!" % [unit.card.name, ab.display_name], Color(1.0, 0.9, 0.6))
				if ab.has_method("execute_at"):
					ab.execute_at(core, unit, from)
				else:
					core._execute_card_ability(unit, ab)
		else:
			core._log("🌀 %s steadies their position." % unit.card.name, Color(0.8, 0.8, 1.0))

		# ✅ Apply terrain buff again (in case terrain changed)
		core._apply_terrain_bonus(unit, tile.terrain_type)

		# ✅ Mark as acted/exhausted
		core.mark_unit_acted(unit)
		if tile.has_method("set_exhausted"):
			tile.set_exhausted(true)

		clear_highlights()
		if ui and not ui._is_hovering_hand_card:
			ui.hide_hover()

		core.selected_pos = Vector2i(-1, -1)
		core._set_phase(core.Phase.SUMMON_OR_MOVE)
		core._update_phase_ui()
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
		core._apply_terrain_bonus(attacker, dst.terrain_type)

		if model and is_instance_valid(model) and not model.is_queued_for_deletion():
			var offset = Vector3(0, 0.1, 0)
			if attacker.card and attacker.card.model_position != Vector3.ZERO:
				offset = attacker.card.model_position
			var world_target = dst.global_position + offset

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
					model.position = Vector3(0, 0.1, 0)
					
		# ✅ Trigger pending flip/summon ability if it exists (on the new tile)
		if attacker.has_meta("pending_on_flip_ability"):
			var flip_ab = attacker.get_meta("pending_on_flip_ability")
			if flip_ab:
				core._log("🔥 %s activates %s on new tile!" % [attacker.card.name, flip_ab.display_name], Color(1.0, 0.9, 0.6))
				
				# Use new tile position for terrain-affecting effects
				if flip_ab.has_method("execute_at"):
					flip_ab.execute_at(core, attacker, to)
				else:
					core._execute_card_ability(attacker, flip_ab)
				
				attacker.set_meta("pending_on_flip_ability", null)

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

	if attacker.mode == UnitData.Mode.FACEDOWN:
		attacker.mode = UnitData.Mode.ATTACK
		await _flip_faceup(src, attacker.card.art)
		await confirm_faceup(attacker)

		# 🔹 Restore proper stats from card data
		attacker.current_atk = attacker.card.atk
		attacker.current_def = attacker.card.def
		core._apply_terrain_bonus(attacker, src.terrain_type)

		core._log("🔄 %s was revealed in Attack Mode!" % attacker.card.name, Color(1, 1, 0.6))

		# 🔓 Permanently mark attacker as face-up
		attacker.is_facedown = false
		attacker.set_meta("is_facedown", false)

		# ✅ NEW: trigger “on_summon” or “passive” abilities if any
		if attacker.card and attacker.card.ability:
			var ab = attacker.card.ability
			if ab.trigger in ["on_summon", "on_flip", "passive"]:
				core._log("✨ %s’s %s ability activates on reveal!" % [attacker.card.name, ab.display_name], Color(1.0, 0.9, 0.6))
				core._execute_card_ability(attacker, ab)

		var attacker_tile = board.get_tile(from.x, from.y)
		if attacker_tile:
			core.refresh_tile_art_safe(from)
			if attacker_tile.has_node("CardModel"):
				var m = attacker_tile.get_node("CardModel")
				if is_instance_valid(m):
					m.visible = true

				
	if defender.mode == UnitData.Mode.FACEDOWN:
		var reveal_mode = UnitData.Mode.ATTACK
		defender.mode = reveal_mode
		await _flip_faceup(dst, defender.card.art)
		await confirm_faceup(defender)

		defender.current_atk = defender.card.atk
		defender.current_def = defender.card.def
		core._apply_terrain_bonus(defender, dst.terrain_type)

		core._log("⚡ %s was revealed in Attack Mode!" % defender.card.name, Color(1, 1, 0.6))

		# 🔓 Mark defender as face-up
		defender.is_facedown = false
		defender.set_meta("is_facedown", false)

		# ✅ NEW: trigger “on_summon” or “passive” abilities if any
		if defender.card and defender.card.ability:
			var ab = defender.card.ability
			if ab.trigger in ["on_summon", "on_flip", "passive"]:
				core._log("✨ %s’s %s ability activates on reveal!" % [defender.card.name, ab.display_name], Color(1.0, 0.9, 0.6))
				core._execute_card_ability(defender, ab)

	var def_tile = board.get_tile(to.x, to.y)
	if def_tile:
		core.refresh_tile_art_safe(to)
		if def_tile.has_node("CardModel"):
			var m = def_tile.get_node("CardModel")
			if is_instance_valid(m):
				m.visible = true

	# 🧹 Hide all highlights + hover, and enter "cinematic" lock
	clear_highlights()
	if ui and not ui._is_hovering_hand_card:
		ui.hide_hover()
	var prev_cutscene_state := core.is_cutscene_active if core and "is_cutscene_active" in core else false
	if core and "is_cutscene_active" in core:
		core.is_cutscene_active = true
		
	if def_tile and def_tile.has_method("pulse_move_highlight"):
		def_tile.pulse_move_highlight()

	# Run cinematic battle
	var result_data = await _play_2d_battle(attacker, defender)
	
	# ✅ Immediately mark attacker as acted before any unlock
	core.mark_unit_acted(attacker)

	# ✅ Lock board actions until battle fully resolves
	core._set_phase(core.Phase.ENEMY_TURN)
	core._update_phase_ui()

	# 🔓 Leave cinematic lock
	if core and "is_cutscene_active" in core:
		core.is_cutscene_active = prev_cutscene_state

	var result: String = result_data["result"]
	var overflow_damage: int = result_data["overflow"]
	
	# ------------------------------------------------------------
	# 🧩 Auto-advance AI attacker into defeated player's tile
	# ------------------------------------------------------------
	if attacker.owner == core.ENEMY and result == "attacker_wins":
		if not dst.occupant and attacker.current_def > 0:
			dst.set_occupant(attacker)
			dst.set_art(attacker.card.art, attacker.owner == core.ENEMY)
			dst.set_badge_text("E")

			# Move 3D model visually
			if src.has_node("CardModel"):
				var model = src.get_node("CardModel")
				if is_instance_valid(model):
					var offset = Vector3(0, 0.1, 0)
					if attacker.card and attacker.card.model_position != Vector3.ZERO:
						offset = attacker.card.model_position
					var world_target = dst.global_position + offset

					var tw = create_tween()
					tw.tween_property(model, "global_position", world_target, 0.25)
					await tw.finished
					if model.get_parent() == src:
						src.remove_child(model)
					if is_instance_valid(dst):
						dst.add_child(model)
						model.position = Vector3(0, 0.1, 0)

			src.clear()
			core.units.erase(from)
			core.units[to] = attacker
			core._log("🤖 Enemy advances into conquered tile (%s → %s)" %
				[str(from), str(to)], Color(0.8, 0.9, 1.0))

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
						var offset = Vector3(0, 0.1, 0)
						if attacker.card and attacker.card.model_position != Vector3.ZERO:
							offset = attacker.card.model_position
						var world_target = dst.global_position + offset

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
			#dst.flash()
			core.mark_unit_acted(attacker)
			var att_tile = _get_unit_tile(attacker)
			if att_tile: att_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)
			if def_tile: def_tile.set_art(dst.occupant.card.art, dst.occupant.owner == core.ENEMY)

		"leader_damaged":
			#dst.flash()
			core.mark_unit_acted(attacker)
			var att_tile = _get_unit_tile(attacker)
			if att_tile: att_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)

	# ✅ Unlock and restore proper phase
	_is_battle_in_progress = false


	# If the attacker was the player, don’t reset turn — wait for End Turn button.
	# Only resume to SUMMON_OR_MOVE if player still has unacted units.
	if attacker.owner == core.PLAYER:
		var any_can_act := false
		for u in core.units.values():
			if u.owner == core.PLAYER and core.can_unit_act(u):
				any_can_act = true
				break

		if any_can_act:
			core._set_phase(core.Phase.SUMMON_OR_MOVE)
		else:
			core._set_phase(core.Phase.ENEMY_TURN)

		core._update_phase_ui()

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


# COMBAT RESOLUTION (returns both overflows)
# -----------------------------
func resolve_battle(att: UnitData, defn: UnitData, silent = false) -> Dictionary:
	var a_atk = att.current_atk
	var a_def = att.current_def
	var d_atk = defn.current_atk
	var d_def = defn.current_def

	var result := "both_survive"
	var overflow_to_def_leader := 0  # from attacker hitting defender
	var overflow_to_att_leader := 0  # from defender's counter hitting attacker

	var damage_to_def := 0
	var damage_to_att := 0
	
	# 🟫 Apply tile-based modifiers based on defender’s location
	var def_tile := core.board.get_tile(core.board.get_unit_position(defn).x, core.board.get_unit_position(defn).y)
	if def_tile:
		core._apply_terrain_bonus(att, def_tile.terrain_type)
		core._apply_terrain_bonus(defn, def_tile.terrain_type)

	if not silent:
		core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
		core._log("⚔️  BATTLE PREVIEW", Color(1,1,0.7))
		core._log("%s (ATK %d / DEF %d) ➤ %s (ATK %d / DEF %d, Mode: %s)" %
			[_colorize_name(att), a_atk, a_def, _colorize_name(defn), d_atk, d_def, str(defn.mode)],
			Color(1,0.9,0.6))

	# Leader target: no counter, no overflow concept (direct HP dmg)
	if defn.is_leader:
		damage_to_def = a_atk
		result = "leader_damaged"
		if not silent:
			core._log("Leader attack: %d damage (no counter)." % damage_to_def, Color(1,0.8,0.8))
		return {
			"result": result,
			"overflow": 0,
			"overflow_to_def_leader": 0,
			"overflow_to_att_leader": 0,
			"damage_to_def": damage_to_def,
			"damage_to_att": 0
		}

	# Defender in DEFENSE: no counter, only attacker overflow
	if defn.mode == UnitData.Mode.DEFENSE:
		damage_to_def = min(a_atk, d_def)
		var d_def_after = d_def - damage_to_def
		if d_def_after <= 0:
			result = "attacker_wins"
			overflow_to_def_leader = max(a_atk - d_def, 0)
		else:
			result = "both_survive"
		return {
			"result": result,
			"overflow": overflow_to_def_leader,
			"overflow_to_def_leader": overflow_to_def_leader,
			"overflow_to_att_leader": 0,
			"damage_to_def": damage_to_def,
			"damage_to_att": 0
		}

	# Both in ATTACK: mutual damage, both sides can overflow
	if defn.mode == UnitData.Mode.ATTACK:
		damage_to_def = min(a_atk, d_def)
		damage_to_att = min(d_atk, a_def)

		var d_def_after = d_def - damage_to_def
		var a_def_after = a_def - damage_to_att

		if d_def_after <= 0:
			overflow_to_def_leader = max(a_atk - d_def, 0)
		if a_def_after <= 0:
			overflow_to_att_leader = max(d_atk - a_def, 0)

		if a_def_after <= 0 and d_def_after <= 0:
			result = "both_destroyed"
		elif d_def_after <= 0:
			result = "attacker_wins"
		elif a_def_after <= 0:
			result = "defender_wins"
		else:
			result = "both_survive"

		return {
			"result": result,
			"overflow": overflow_to_def_leader,              # keep legacy key
			"overflow_to_def_leader": overflow_to_def_leader, # attacker→def leader
			"overflow_to_att_leader": overflow_to_att_leader, # defender→att leader (counter overflow)
			"damage_to_def": damage_to_def,
			"damage_to_att": damage_to_att
		}

	if not silent:
		core._log("⚠️ Unexpected mode in battle preview.", Color(1,0.7,0.4))
	return {
		"result": "both_survive",
		"overflow": 0,
		"overflow_to_def_leader": 0,
		"overflow_to_att_leader": 0,
		"damage_to_def": 0,
		"damage_to_att": 0
	}

# -----------------------------
# PASSIVES / KILL / HELPERS
# -----------------------------
func apply_all_passives() -> void:
	print("🧊 apply_all_passives: units=", core.units.size())

	for pos in core.units.keys():
		var tile = core.board.get_tile(pos.x, pos.y)
		var unit: UnitData = core.units[pos]
		if not tile or tile.occupant != unit:
			continue

		var facedown = unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown"))

		# 🧩 Keep facedown cards hidden
		if facedown:
			tile.set_art(core.CARD_BACK)
		else:
			core.refresh_tile_art_safe(pos)


			# Run passive ability only if face-up
			if unit.card and unit.card.ability and unit.card.ability.trigger == "passive":
				unit.card.ability.execute(core, unit)

		# Update stat labels quietly
		if tile.has_method("update_stat_labels"):
			tile.update_stat_labels(unit.current_atk, unit.current_def)

	# ✅ Refresh the details panel if visible
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
		ui._lock_hp_updates = true

	var result_data = resolve_battle(att, defn, true)
	var damage_to_def: int = result_data["damage_to_def"]
	var damage_to_att: int = result_data["damage_to_att"]

	var battle_ui: BattleUI = core.get_node_or_null("UISystem/BattleUI")
	if not battle_ui:
		push_error("❌ Could not find BattleUI in UISystem — add a node named 'BattleUI'.")
		if is_instance_valid(hand): hand.visible = true
		return result_data
		
	# --- Ensure defender's tile context applies ---
	var defender_pos := core.board.get_unit_position(defn)
	var attacker_pos := core.board.get_unit_position(att)
	var defender_tile := core.board.get_tile(defender_pos.x, defender_pos.y)
	var attacker_tile := core.board.get_tile(attacker_pos.x, attacker_pos.y)

	# ✅ Apply defender tile’s terrain bonus and adjacency effects
	if defender_tile:
		core._apply_terrain_bonus(att, defender_tile.terrain_type)
		core._apply_terrain_bonus(defn, defender_tile.terrain_type)
		
		# Optional: If adjacency abilities (like “gain +2 DEF if ally adjacent”) exist:
		if core.has_method("_apply_adjacency_effects"):
			core._apply_adjacency_effects(defn, defender_pos)

	# --- ATTACK PHASE ---
	battle_ui.refresh_stats(att, defn)
	_apply_attack_bonus(att)
	_apply_attack_bonus(defn)

	await battle_ui.play_attack_phase(att, defn, damage_to_def)

	# Apply attack damage
	if defn.is_leader:
		defn.hp = max(defn.hp - damage_to_def, 0)
		core.on_leader_damaged(defn.owner, defn.hp)
	else:
		defn.current_def = max(defn.current_def - damage_to_def, 0)

	battle_ui.refresh_stats(att, defn)

	# 🟢 NOW trigger on_attack (e.g., Vampirism) — “after every attack”
	_trigger_ability(att, "on_attack")
	battle_ui.refresh_stats(att, defn)

	# --- COUNTER PHASE ---
	battle_ui.refresh_stats(att, defn)
	await battle_ui.play_counter_phase(defn, att, damage_to_att)

	# Apply counter damage
	att.current_def = max(att.current_def - damage_to_att, 0)
	battle_ui.refresh_stats(att, defn)

	# 🟣 NEW: Trigger on_attack for defender during counterattacks
	if damage_to_att > 0 and defn.current_def > 0:
		_trigger_ability(defn, "on_attack")
		battle_ui.refresh_stats(att, defn)

	await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame

	# --- CLEANUP + BOTH OVERFLOWS ---
	var result  = result_data["result"]
	var of_def  = result_data.get("overflow_to_def_leader", result_data.get("overflow", 0))
	var of_att  = result_data.get("overflow_to_att_leader", 0)

	# Temporarily unlock so hp_changed updates bars mid-battle
	if ui:
		ui._lock_hp_updates = false

	# Attacker overflow → defender's leader (defender died or mutual)
	if of_def > 0 and not defn.is_leader:
		if defn.current_def <= 0:
			core._log("💥 Overflow to defender leader: %d" % of_def, Color(1, 0.6, 0.3))
			core.damage_leader(defn.owner, of_def)

	# Counter overflow → attacker’s leader (attacker died or mutual)
	if of_att > 0 and not att.is_leader:
		if att.current_def <= 0:
			core._log("💥 Counter overflow to attacker leader: %d" % of_att, Color(1, 0.6, 0.3))
			core.damage_leader(att.owner, of_att)

	# Re-lock for the remaining wrap-up animation
	if ui:
		ui._lock_hp_updates = true

	var attacker_dead := (not att.is_leader and att.current_def <= 0)
	var defender_dead := (not defn.is_leader and defn.current_def <= 0)

	if defender_dead:
		await _kill_unit(defn)
	if attacker_dead:
		await _kill_unit(att)

	# Battlefield visuals refresh …

	# --- Wrap up ---
	if ui:
		ui._lock_hp_updates = false
		ui._update_hp_labels()
		ui._update_hp_bar()

	if battle_ui:
		await battle_ui.fade_out_battle()
	if hand:
		hand.visible = true
	if ui:
		ui.force_hide_hand(false)
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

	# ✅ Ensure 3D model becomes visible when flipped face-up
	if tile.has_node("CardModel"):
		var model = tile.get_node("CardModel")
		if is_instance_valid(model):
			model.visible = true
			
func confirm_faceup(unit: UnitData) -> void:
	# This runs once the player confirms the face-up flip.
	if not unit:
		return

	# 🧩 Safety — clear preview state if needed
	if unit.has_meta("is_previewing_flip"):
		unit.set_meta("is_previewing_flip", false)

	# ✅ If ability was stored for post-flip, execute it now
	if unit.has_meta("pending_on_flip_ability"):
		var ab: CardAbility = unit.get_meta("pending_on_flip_ability")
		unit.set_meta("pending_on_flip_ability", null)
		if ab:
			core._log("✨ %s activates %s!" % [unit.card.name, ab.display_name], Color(1.0, 1.0, 0.6))
			core._execute_card_ability(unit, ab)

func _fade(to_alpha: float, dur: float):
	var rect: ColorRect = core.get_node("UISystem/FadeRect")

	var tw = create_tween()
	tw.tween_property(rect, "modulate:a", to_alpha, dur)
	await tw.finished
	
func reveal_card(pos: Vector2i) -> void:
	if not core.units.has(pos):
		return
	var unit: UnitData = core.units[pos]
	if not unit or unit.mode != UnitData.Mode.FACEDOWN:
		return

	unit.mode = UnitData.Mode.ATTACK
	var tile = board.get_tile(pos.x, pos.y)
	if tile:
		tile.set_art(unit.card.art)
		tile.set_badge_text("A")

		if unit.has_meta("model_instance"):
			var model_instance = unit.get_meta("model_instance")
			if is_instance_valid(model_instance):
				model_instance.visible = true

	core._log("⚡ %s was flipped face-up!" % unit.card.name, Color(1, 1, 0.7))

	# --- 🔥 Trigger abilities that activate when flipped ---
	if unit.card.ability:
		var ab = unit.card.ability
		if ab.trigger in ["on_flip", "on_summon"]:
			core._execute_card_ability(unit, ab)

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
