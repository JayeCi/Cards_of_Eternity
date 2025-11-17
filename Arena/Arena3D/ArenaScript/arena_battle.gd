# File: arena_battle.gd


# =====================================================================
# 📘 FUNCTION INDEX — arena_battle.gd
# =====================================================================
# 🧩 CORE SETUP & PROCESS
# ---------------------------------------------------------------------
# init_battle(core_ref)                 → Initialize core references (core, board, ui, camera, mover)
# _process(_dt)                         → Update hover & ghost each frame

# 🖱️ INPUT HANDLING
# ---------------------------------------------------------------------
# _unhandled_input(event)               → Handle global keybinds (cancel, toggle face)
# _on_cancel_card_drag()                → Cancel card placement & reset visuals

# 🧭 FACE / FLIP CONTROL
# ---------------------------------------------------------------------
# _try_toggle_face()                    → Toggle preview flip (face-down/up) for selected unit
# confirm_flip(unit := null)            → Confirm preview flip and trigger ability if needed
# _clear_toggle_session_flag()          → Clear flip session flag (safety reset)
# reveal_card(pos)                      → Forcefully reveal a facedown unit (used by scripts/tutorial)

# 🟩 MOVEMENT / RANGE / SUMMON HIGHLIGHTS
# ---------------------------------------------------------------------
# _is_within_move_range(from, to, unit) → Check if move is valid (range, terrain bonus, no diagonal)
# show_valid_summon_tiles()             → Highlight valid summon tiles around player leader
# clear_summon_highlights()             → Remove summon highlight indicators

# 🐭 HOVER & GHOST UI
# ---------------------------------------------------------------------
# _update_hover()                       → Handle hover state & highlight hovered tiles
# _reset_hover_state()                  → Reset all hover / drag flags
# show_hover_for_tile(tile)             → Display hover info (unit stats or terrain)
# _update_ghost_position()              → Update position of dragged “ghost card” in 3D

# 🟨 UNIT PLACEMENT HELPERS
# ---------------------------------------------------------------------
# normalize_model(model, target_height) → Uniformly scale 3D model to target height

# ⚔️ BATTLE RESOLUTION
# ---------------------------------------------------------------------
# resolve_battle(att, defn, silent)     → Simulate damage + return result dictionary
# _play_2d_battle(att, defn)            → Run full battle animation + update units & UI
# _focus_camera_on_battle(att_tile, def_tile, zoom_in) 
#                                      → Zoom camera in/out to focus on active battle

# 🌿 PASSIVES / STATE HELPERS
# ---------------------------------------------------------------------
# apply_all_passives()                  → Apply terrain/passive effects to all active units
# _enforce_visual_face_state()          → Force visual consistency of facedown/faceup models
# clear_exhausted_tiles()               → Reset exhausted indicators on all tiles
# set_exhausted_for_unit(u, exhausted)  → Set exhausted visual state for one unit
# get_leader_pos(owner)                 → Return current position of owner’s leader

# ✨ ABILITIES & UNIT DEATH
# ---------------------------------------------------------------------
# _apply_attack_bonus(unit)             → Apply stored temporary ATK bonus (BoostAttack)
# apply_passive_effect(unit, ability)   → Execute passive ability and mark active
# _trigger_ability(unit, trigger)       → Execute ability matching trigger event
# remove_passive_effect(unit, ability)  → Remove passive effects (on kill or removal)
# _kill_unit(u, silent)                 → Destroy unit, play animation/sound, clear tile

# 🎨 VISUAL FX HELPERS
# ---------------------------------------------------------------------
# _float_text(pos, text, color)         → Spawn 3D floating damage text
# _camera_shake(intensity, duration)    → Shake camera for impact feedback
# _add_card_highlight(sprite, color)    → Add glowing highlight mesh under a sprite
# _card_explode(sprite, color)          → Particle explosion for destroyed card
# _card_pulse(target, color)            → Flash/pulse color or light on a node
# _fade(to_alpha, dur)                  → Fade UI overlay to given opacity

# 🧰 MISC UTILS
# ---------------------------------------------------------------------
# _colorize_name(unit)                  → Return formatted color-coded name string for logs
# =====================================================================




extends Node
class_name ArenaBattle

# =====================================================
# 📦 CORE FIELDS
# =====================================================

var core: ArenaCore
var board: Node3D
var ui: ArenaUI
var cam: ArenaCamera
var mover: ArenaMove
var hovered_tile: Node3D = null

var _is_battle_in_progress: bool = false
var _camera_locked: bool = false
var _battle_cam_default_pos: Vector3
var _battle_cam_default_fov: float
var _last_click_time: float = 0.0

@onready var hand: GridContainer = $"../UISystem/BottomContainer/Hand"
@export var is_tutorial_match: bool = false


# =====================================================
# 🔧 INIT & PROCESS
# =====================================================

func init_battle(core_ref: ArenaCore) -> void:
	core = core_ref
	board = core.board
	ui = core.get_node("UISystem")
	cam = core.get_node("CameraSystem")
	mover= core.get_node("MoveSystem")

func _process(_dt: float) -> void:
	if not core or not cam:
		return
	_update_hover()
	_update_ghost_position()


# =====================================================
# 🎮 INPUT HANDLING
# =====================================================

func _unhandled_input(event) -> void:
	if event.is_action_pressed("cancel_action"):
		_on_cancel_card_drag()

	# 🔹 Allow R toggle while selecting move target
	if event.is_action_pressed("toggle_face"):
		if core.phase in [core.Phase.SELECT_MOVE_TARGET]:
			_try_toggle_face()



func _on_cancel_card_drag():
	if core.dragging_card:
		if ui and ui.ghost_card:
			ui.ghost_card.visible = false

		if ui and core.dragging_card:
			ui.return_card_to_hand(core.dragging_card)

		core.dragging_card = null

		mover.clear_highlights()
		hovered_tile = null
		ui.hide_hover()

		core._log("🌀 Card placement canceled.", Color(0.8, 0.8, 1))


# =====================================================
# 🧭 FACE / FLIP CONTROL
# =====================================================

func _try_toggle_face() -> void:
	var tile: Node3D = null
	if core.selected_pos != Vector2i(-1, -1):
		tile = board.get_tile(core.selected_pos.x, core.selected_pos.y)
	else:
		core._log("⚠️ You must select a card before flipping.", Color(1, 0.6, 0.6))
		return
	if not tile or not tile.occupant:
		return

	var unit = tile.occupant

	# 🚫 Player-only + no enemy turn/cutscene
	if unit.owner != core.PLAYER:
		return
	if core.phase == core.Phase.ENEMY_TURN or core.is_cutscene_active:
		return

	# ✅ Require visible move highlights (must be selected)
	if not board.has_method("are_move_highlights_visible") \
	or not board.are_move_highlights_visible(core.selected_pos):
		core._log("⚠️ You can only flip while a card is selected for action.", Color(1, 0.7, 0.4))
		return

	# 🔒 Permanent lock respected
	var is_locked = unit.has_meta("flipped_permanent") and unit.get_meta("flipped_permanent")
	if is_locked and not (unit.has_meta("is_previewing_flip") and unit.get_meta("is_previewing_flip")):
		core._log("⛔ This card’s state is locked.", Color(1, 0.6, 0.6))
		return

	# --- Sync face state
	if unit.has_meta("is_facedown"):
		unit.is_facedown = unit.get_meta("is_facedown")
	else:
		unit.set_meta("is_facedown", unit.is_facedown)

	var is_down = unit.is_facedown
	var is_preview = unit.has_meta("is_previewing_flip") and unit.get_meta("is_previewing_flip")

	core._log(
		"🧩 Flip check for %s — facedown=%s, preview=%s"
		% [unit.card.name, str(is_down), str(is_preview)],
		Color(0.8, 0.8, 1.0)
	)

	# =====================================================
	# ✅ Flip Logic
	# =====================================================

	# ❄️ Check if unit is frozen - block flip if frozen and facedown
	if FrozenStatusEffect.is_frozen(unit) and is_down:
		core._log("❄️ %s is frozen and cannot be flipped face-up!" % unit.card.name, Color(0.5, 0.7, 1.0))
		return

	# 🚫 If face-up and NOT previewing → fully revealed, block flip down
	if not is_down and not is_preview:
		core._log("⛔ %s is revealed — cannot flip facedown again." % unit.card.name, Color(1, 0.6, 0.6))
		return

	# 🔁 Otherwise toggle preview state
	unit.is_facedown = not unit.is_facedown
	unit.set_meta("is_facedown", unit.is_facedown)
	unit.set_meta("is_previewing_flip", true)

	if unit.is_facedown:
		# 🔻 Flip to facedown (preview)
		tile.set_art(core.CARD_BACK)
		if tile.has_node("CardModel"):
			var m = tile.get_node("CardModel")
			if is_instance_valid(m):
				m.visible = false
		tile.set_badge_text("?")
		core._log("🔄 %s flipped face-down (preview)." % unit.card.name, Color(0.7, 0.7, 1.0))
	else:
		# 🔺 Flip to face-up (preview)
		tile.set_art(unit.card.art, unit.owner == core.ENEMY)
		if tile.has_node("CardModel"):
			var mm = tile.get_node("CardModel")
			if is_instance_valid(mm):
				mm.visible = true
		tile.set_badge_text("A")
		core._log("⚡ %s flipped face-up (preview)." % unit.card.name, Color(1.0, 1.0, 0.6))

		# 🌿 Preferred terrain preview
		var terrain = tile.terrain_type
		if terrain == unit.card.preferred_terrain and board.has_method("_show_move_targets"):
			core._log(
				"🌿 %s senses power on preferred terrain — showing extended movement!"
				% unit.card.name,
				Color(0.6, 1.0, 0.6)
			)
			board._show_move_targets(core.board.get_unit_position(unit))

		# 💡 Ability previews
		if unit.card and unit.card.ability:
			var ab = unit.card.ability
			if "on_summon" in ab.trigger:
				unit.set_meta("pending_on_flip_ability", ab)
				core._log(
					"💡 %s ability will activate once confirmed."
					% ab.display_name,
					Color(0.8, 0.9, 1.0)
				)

	core.refresh_tile_art_safe(core.board.get_unit_position(unit))

# =====================================================
# ✅ CONFIRM FLIP — finalize preview & trigger abilities
# =====================================================
# =====================================================
# ✅ CONFIRM FLIP — finalize preview & trigger abilities
# =====================================================
func confirm_flip(unit: UnitData = null) -> void:
	if not core:
		return

	# If no unit passed, fall back to selected_pos (legacy use)
	if unit == null:
		if core.selected_pos == Vector2i(-1, -1):
			return
		var sel_tile = board.get_tile(core.selected_pos.x, core.selected_pos.y)
		if not sel_tile or not sel_tile.occupant:
			return
		unit = sel_tile.occupant

	if not unit:
		return

	# Must be in preview state
	if not unit.has_meta("is_previewing_flip") or not unit.get_meta("is_previewing_flip"):
		return

	# --- Clear preview flag
	unit.set_meta("is_previewing_flip", false)

	# Get position for spell handling
	var pos := core.board.get_unit_position(unit)

	# 🧙‍♂️ If this is a SPELL card, cast it and remove it
	if unit.card.card_type == CardData.CardType.SPELL:
		var tile = board.get_tile(pos.x, pos.y)

		# ✅ First, make the spell visually face-up
		unit.is_facedown = false
		unit.mode = UnitData.Mode.ATTACK
		if tile:
			tile.set_art(unit.card.art)
			tile.set_badge_text("S")

		# Store cast position
		unit.set_meta("spell_cast_position", pos)

		core._log("✨ %s spell revealed - casting now!" % unit.card.name, Color(1.0, 0.9, 0.6))

		# Wait for visual
		await get_tree().create_timer(0.3).timeout

		# Trigger ability
		if unit.has_meta("pending_on_flip_ability"):
			var ab: CardAbility = unit.get_meta("pending_on_flip_ability")
			unit.set_meta("pending_on_flip_ability", null)
			if ab:
				await core._execute_card_ability(unit, ab)
		elif unit.card.ability and "on_summon" in unit.card.ability.trigger:
			await core._execute_card_ability(unit, unit.card.ability)

		# Remove spell from board
		await get_tree().create_timer(0.5).timeout
		core._log("💨 %s vanishes after casting." % unit.card.name, Color(0.7, 0.7, 1.0))

		if pos != Vector2i(-1, -1):
			core.units.erase(pos)
			if tile:
				tile.set_occupant(null)
				tile.set_art(null)
				tile.set_badge_text("")

				# 🧹 Ensure CardMesh is hidden/cleared
				if tile.has_node("CardMesh"):
					var card_mesh = tile.get_node("CardMesh")
					if card_mesh:
						card_mesh.visible = false
		return

	# 🪤 If this is an EVENT card, trigger it and remove it
	if unit.card.card_type == CardData.CardType.EVENT:
		var tile = board.get_tile(pos.x, pos.y)

		# 🎥 Move camera to EVENT location
		if tile and cam:
			var event_pos = tile.global_position
			cam.focus_on_battle(event_pos, event_pos, true)
			await get_tree().create_timer(0.4).timeout

		# ✅ First, make the EVENT card visually face-up
		unit.is_facedown = false
		unit.mode = UnitData.Mode.ATTACK
		if tile:
			tile.set_art(unit.card.art)
			tile.set_badge_text("E")

		# Store cast position
		unit.set_meta("spell_cast_position", pos)

		core._log("🪤 %s EVENT revealed - activating now!" % unit.card.name, Color(1.0, 0.8, 0.6))

		# Wait for visual
		await get_tree().create_timer(0.3).timeout

		# Trigger ability
		if unit.has_meta("pending_on_flip_ability"):
			var ab: CardAbility = unit.get_meta("pending_on_flip_ability")
			unit.set_meta("pending_on_flip_ability", null)
			if ab:
				await core._execute_card_ability(unit, ab)
		elif unit.card.ability and "on_summon" in unit.card.ability.trigger:
			await core._execute_card_ability(unit, unit.card.ability)

		# Remove EVENT from board
		await get_tree().create_timer(0.5).timeout
		core._log("💨 %s vanishes after activation." % unit.card.name, Color(0.7, 0.7, 1.0))

		if pos != Vector2i(-1, -1):
			core.units.erase(pos)
			if tile:
				tile.set_occupant(null)
				tile.set_art(null)
				tile.set_badge_text("")

				# 🧹 Ensure CardMesh is hidden/cleared
				if tile.has_node("CardMesh"):
					var card_mesh = tile.get_node("CardMesh")
					if card_mesh:
						card_mesh.visible = false

		# 🎥 Return camera to normal position
		if cam:
			cam.focus_on_battle(Vector3.ZERO, Vector3.ZERO, false)
			await get_tree().create_timer(0.3).timeout

		return

	# --- Normal card flip handling ---
	# --- Trigger pending ability if stored
	if unit.has_meta("pending_on_flip_ability"):
		var ab: CardAbility = unit.get_meta("pending_on_flip_ability")
		unit.set_meta("pending_on_flip_ability", null)

		if ab:
			# We intentionally DO NOT re-check trigger; pending implies approval
			core._log(
				"✨ %s activates %s on confirmed flip!"
				% [unit.card.name, ab.display_name],
				Color(1.0, 0.9, 0.6)
			)
			await core._execute_card_ability(unit, ab)

	# --- Mark as permanently revealed (cannot flip back via R)
	unit.set_meta("flipped_permanent", true)
	unit.set_meta("is_facedown", unit.is_facedown)

	# --- Sync visuals using current unit position (in case it already moved)
	if pos != Vector2i(-1, -1):
		var t = board.get_tile(pos.x, pos.y)
		if t:
			core.refresh_tile_art_safe(pos)
			if t.has_node("CardModel"):
				var model = t.get_node("CardModel")
				if is_instance_valid(model):
					model.visible = not unit.is_facedown
			if t.has_method("update_stat_labels"):
				t.update_stat_labels(unit.current_atk, unit.current_def)

	core._log("✅ Flip confirmed for %s." % unit.card.name, Color(0.7, 1.0, 0.7))

func _clear_toggle_session_flag() -> void:
	if core and core.selected_pos != Vector2i(-1, -1):
		var t = board.get_tile(core.selected_pos.x, core.selected_pos.y)
		if t and t.occupant:
			t.occupant.set_meta("allow_face_toggle_session", false)


func reveal_card(pos: Vector2i) -> void:
	if not core.units.has(pos):
		return
	var unit: UnitData = core.units[pos]
	if not unit or unit.mode != UnitData.Mode.FACEDOWN:
		return

	# ❄️ Frozen units cannot be revealed
	if FrozenStatusEffect.is_frozen(unit):
		core._log("❄️ %s is frozen and cannot be revealed!" % unit.card.name, Color(0.5, 0.7, 1.0))
		return

	var tile = board.get_tile(pos.x, pos.y)

	# 🧙‍♂️ Handle SPELL cards differently
	if unit.card.card_type == CardData.CardType.SPELL:
		core._log("⚡ %s spell revealed - casting now!" % unit.card.name, Color(1, 1, 0.7))

		if tile:
			tile.set_art(unit.card.art)
			tile.set_badge_text("S")

		# Store cast position for abilities that need it
		unit.set_meta("spell_cast_position", pos)

		# Wait a moment for visual
		await get_tree().create_timer(0.3).timeout

		if unit.card.ability and "on_summon" in unit.card.ability.trigger:
			await core._execute_card_ability(unit, unit.card.ability)

		# Remove spell from board
		await get_tree().create_timer(0.5).timeout
		core._log("💨 %s vanishes after casting." % unit.card.name, Color(0.7, 0.7, 1.0))

		core.units.erase(pos)
		if tile:
			tile.set_occupant(null)
			tile.set_art(null)
			tile.set_badge_text("")

			# 🧹 Ensure CardMesh is hidden/cleared
			if tile.has_node("CardMesh"):
				var card_mesh = tile.get_node("CardMesh")
				if card_mesh:
					card_mesh.visible = false
		return

	# 🪤 Handle EVENT cards differently
	if unit.card.card_type == CardData.CardType.EVENT:
		core._log("⚡ %s EVENT revealed - activating now!" % unit.card.name, Color(1.0, 0.8, 0.6))

		# 🎥 Move camera to EVENT location
		if tile and cam:
			var event_pos = tile.global_position
			cam.focus_on_battle(event_pos, event_pos, true)
			await get_tree().create_timer(0.4).timeout

		if tile:
			tile.set_art(unit.card.art)
			tile.set_badge_text("E")

		# Store cast position for abilities that need it
		unit.set_meta("spell_cast_position", pos)

		# Wait a moment for visual
		await get_tree().create_timer(0.3).timeout

		if unit.card.ability and "on_summon" in unit.card.ability.trigger:
			await core._execute_card_ability(unit, unit.card.ability)

		# Remove EVENT from board
		await get_tree().create_timer(0.5).timeout
		core._log("💨 %s vanishes after activation." % unit.card.name, Color(0.7, 0.7, 1.0))

		core.units.erase(pos)
		if tile:
			tile.set_occupant(null)
			tile.set_art(null)
			tile.set_badge_text("")

			# 🧹 Ensure CardMesh is hidden/cleared
			if tile.has_node("CardMesh"):
				var card_mesh = tile.get_node("CardMesh")
				if card_mesh:
					card_mesh.visible = false

		# 🎥 Return camera to normal position
		if cam:
			cam.focus_on_battle(Vector3.ZERO, Vector3.ZERO, false)
			await get_tree().create_timer(0.3).timeout

		return

	# Normal card reveal
	unit.mode = UnitData.Mode.ATTACK
	if tile:
		tile.set_art(unit.card.art)
		tile.set_badge_text("A")

		if unit.has_meta("model_instance"):
			var model_instance = unit.get_meta("model_instance")
			if is_instance_valid(model_instance):
				model_instance.visible = true

	core._log("⚡ %s was flipped face-up!" % unit.card.name, Color(1, 1, 0.7))

	if unit.card.ability and "on_summon" in unit.card.ability.trigger:
		await core._execute_card_ability(unit, unit.card.ability)



# =====================================================
# 🧮 MOVEMENT & RANGE + HIGHLIGHTS
# =====================================================

func _is_within_move_range(from_pos: Vector2i, to_pos: Vector2i, unit: UnitData) -> bool:
	# Block diagonal moves entirely
	var dx := to_pos.x - from_pos.x
	var dy := to_pos.y - from_pos.y
	if abs(dx) > 0 and abs(dy) > 0:
		return false

	var allowed_range := core.BASE_MOVE_RANGE
	var from_tile = board.get_tile(from_pos.x, from_pos.y)

	# Preferred terrain doubles range if face-up
	if from_tile and from_tile.occupant == unit and not unit.is_facedown:
		if from_tile.terrain_type == unit.card.preferred_terrain:
			allowed_range *= 2

	var dist = abs(dx) + abs(dy)
	return dist <= allowed_range


func show_valid_summon_tiles() -> void:
	mover.clear_highlights()

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

	# Animate summon highlights with staggered intro
	for i in range(tiles_to_highlight.size()):
		var tile = tiles_to_highlight[i]
		tile.summon_highlight = true

		# Set badge symbol
		if tile.has_method("set_highlight"):
			tile.set_highlight(true, "⬆")
		else:
			tile.set_highlight(true)
			tile.set_badge_text("⬆")

		# Summon highlight tint (green/yellow for friendly summon)
		var tint := Color(0.3, 1.0, 0.5)

		# Play animated intro
		if tile.has_method("play_move_highlight_intro"):
			tile.play_move_highlight_intro(tint)
		elif tile.has_method("set_move_highlight_tint"):
			tile.set_move_highlight_tint(tint)

		# Add pulse animation
		if tile.has_method("pulse_move_highlight"):
			tile.pulse_move_highlight()

		if tile.has_node("MoveHighlight"):
			var mh = tile.get_node("MoveHighlight")
			mh.visible = true
			if tile.has_method("pulse_move_highlight"):
				tile.pulse_move_highlight()


func clear_summon_highlights() -> void:
	for tile in core.board.tiles.values():
		if tile.summon_highlight:
			tile.summon_highlight = false
			tile.set_highlight(false)

			if tile.has_node("MoveHighlight"):
				var mh = tile.get_node("MoveHighlight")
				mh.visible = false


# =====================================================
# 🐭 HOVER & GHOST
# =====================================================

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
		if node and node.has_method("set_highlight"):
			tile = node

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

	if (core and core.is_cutscene_active) or _is_battle_in_progress:
		return

	if tile.occupant:
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.show_unit(tile.occupant)
		if has_node("ArenaTerrainDetails"):
			$ArenaTerrainDetails.visible = false
	else:
		if has_node("ArenaTerrainDetails"):
			$ArenaTerrainDetails.show_terrain(tile.terrain_type)
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.hide_card()


func _update_ghost_position() -> void:
	if not core.dragging_card or not ui.ghost_card.visible:
		return
	if not hovered_tile:
		var mpos = get_viewport().get_mouse_position()
		var from = core.camera.project_ray_origin(mpos)
		var dir = core.camera.project_ray_normal(mpos)
		var default_pos = from + dir * 5.0
		ui.ghost_card.position = default_pos


# =====================================================
# 🟨 UNIT PLACEMENT
# =====================================================

func normalize_model(model: Node3D, target_height := 1.0) -> void:
	var aabb = model.get_aabb()
	var current_height = aabb.size.y
	if current_height == 0:
		return
	var scale_factor = target_height / current_height
	model.scale = Vector3.ONE * scale_factor


func resolve_battle(att: UnitData, defn: UnitData, silent := false) -> Dictionary:
	var a_atk = att.current_atk
	var a_def = att.current_def
	var d_atk = defn.current_atk
	var d_def = defn.current_def

	var result := "both_survive"
	var overflow_to_def_leader := 0
	var overflow_to_att_leader := 0

	var damage_to_def := 0
	var damage_to_att := 0

	var def_tile := core.board.get_tile(
		core.board.get_unit_position(defn).x,
		core.board.get_unit_position(defn).y
	)
	if def_tile:
		core._apply_terrain_bonus(att, def_tile.terrain_type)
		core._apply_terrain_bonus(defn, def_tile.terrain_type)

	if not silent:
		core._log("────────────────────────────────────", Color(0.6, 0.6, 0.6))
		core._log("⚔️  BATTLE PREVIEW", Color(1, 1, 0.7))
		core._log(
			"%s (ATK %d / DEF %d) ➤ %s (ATK %d / DEF %d, Mode: %s)" %
			[
				_colorize_name(att), a_atk, a_def,
				_colorize_name(defn), d_atk, d_def, str(defn.mode)
			],
			Color(1, 0.9, 0.6)
		)

	# Leader target
	if defn.is_leader:
		damage_to_def = a_atk
		result = "leader_damaged"
		if not silent:
			core._log("Leader attack: %d damage (no counter)." % damage_to_def, Color(1, 0.8, 0.8))
		return {
			"result": result,
			"overflow": 0,
			"overflow_to_def_leader": 0,
			"overflow_to_att_leader": 0,
			"damage_to_def": damage_to_def,
			"damage_to_att": 0
		}

	# Defender in DEFENSE
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

	# Both in ATTACK
	if defn.mode == UnitData.Mode.ATTACK:
		damage_to_def = min(a_atk, d_def)
		damage_to_att = min(d_atk, a_def)

		var d_def_after2 = d_def - damage_to_def
		var a_def_after2 = a_def - damage_to_att

		if d_def_after2 <= 0:
			overflow_to_def_leader = max(a_atk - d_def, 0)
		if a_def_after2 <= 0:
			overflow_to_att_leader = max(d_atk - a_def, 0)

		if a_def_after2 <= 0 and d_def_after2 <= 0:
			result = "both_destroyed"
		elif d_def_after2 <= 0:
			result = "attacker_wins"
		elif a_def_after2 <= 0:
			result = "defender_wins"
		else:
			result = "both_survive"

		return {
			"result": result,
			"overflow": overflow_to_def_leader,
			"overflow_to_def_leader": overflow_to_def_leader,
			"overflow_to_att_leader": overflow_to_att_leader,
			"damage_to_def": damage_to_def,
			"damage_to_att": damage_to_att
		}

	if not silent:
		core._log("⚠️ Unexpected mode in battle preview.", Color(1, 0.7, 0.4))

	return {
		"result": "both_survive",
		"overflow": 0,
		"overflow_to_def_leader": 0,
		"overflow_to_att_leader": 0,
		"damage_to_def": 0,
		"damage_to_att": 0
	}


func _play_2d_battle(att: UnitData, defn: UnitData) -> Dictionary:
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

	var defender_pos := core.board.get_unit_position(defn)
	var attacker_pos := core.board.get_unit_position(att)
	var defender_tile := core.board.get_tile(defender_pos.x, defender_pos.y)
	var attacker_tile := core.board.get_tile(attacker_pos.x, attacker_pos.y)

	if defender_tile:
		core._apply_terrain_bonus(att, defender_tile.terrain_type)
		core._apply_terrain_bonus(defn, defender_tile.terrain_type)
		if core.has_method("_apply_adjacency_effects"):
			core._apply_adjacency_effects(defn, defender_pos)

	if core.is_tutorial_match and TutorialManager.once("attack_explained"):
		DialogueManager.start_convo([
			DialogueManager._dl("Guide", "When you attack, you deal damage to DEF."),
			DialogueManager._dl("Guide", "If DEF reaches 0, the card is destroyed."),
		])

	battle_ui.refresh_stats(att, defn)
	_apply_attack_bonus(att)
	_apply_attack_bonus(defn)

	# 🔥 Check for multi-hit abilities (like Tri-Strike)
	var hit_count = 1
	var multi_hit_name = ""
	if att.has_meta("multi_hit_count"):
		hit_count = att.get_meta("multi_hit_count")
		multi_hit_name = att.get_meta("multi_hit_ability_name", "Multi-Strike")
		core._log("⚡ %s activates %s!" % [att.card.name, multi_hit_name], Color(1.0, 0.8, 0.3))

	# 🔁 Execute multiple hits
	for hit_num in range(hit_count):
		# Show which hit this is (for multi-hit attacks)
		if hit_count > 1:
			core._log("💥 Hit %d of %d!" % [hit_num + 1, hit_count], Color(1.0, 0.9, 0.6))

		await battle_ui.play_attack_phase(att, defn, damage_to_def, hit_num + 1, hit_count)

		if defn.is_leader:
			core.damage_leader(defn.owner, damage_to_def)
		else:
			defn.current_def = max(defn.current_def - damage_to_def, 0)

		battle_ui.refresh_stats(att, defn)

		# Check if defender died during this hit
		if defn.current_def <= 0:
			core._log("💀 %s was defeated!" % defn.card.name, Color(1.0, 0.4, 0.4))
			break

		# Small delay between hits for multi-hit attacks
		if hit_count > 1 and hit_num < hit_count - 1:
			await get_tree().create_timer(0.3).timeout

	var ability_done = _trigger_ability(att, "on_attack")
	if ability_done:
		await ability_done


	battle_ui.refresh_stats(att, defn)

	# ✅ Check universal frozen status and if defender is still alive
	var is_defender_frozen := FrozenStatusEffect.is_frozen(defn)
	var do_counter := (damage_to_att > 0) and not is_defender_frozen and defn.current_def > 0

	if do_counter:
		battle_ui.refresh_stats(att, defn)
		await battle_ui.play_counter_phase(defn, att, damage_to_att)

		if core.is_tutorial_match and TutorialManager.once("counter_explained"):
			DialogueManager.start_convo([
				DialogueManager._dl("Guide", "When attacking a face-up unit in ATTACK mode, it can counterattack."),
				DialogueManager._dl("Guide", "This damages your card as well."),
			])

		att.current_def = max(att.current_def - damage_to_att, 0)
		battle_ui.refresh_stats(att, defn)

		if att.current_def > 0:
			var counter_ability_done = _trigger_ability(defn, "on_attack")
			if counter_ability_done:
				await counter_ability_done

			battle_ui.refresh_stats(att, defn)

	elif is_defender_frozen and damage_to_att > 0:
		core._log("❄️ %s is frozen and cannot counter-attack!" % defn.card.name, Color(0.5, 0.5, 0.9))
	elif defn.current_def <= 0 and damage_to_att > 0:
		core._log("💀 %s was destroyed before it could counter-attack!" % defn.card.name, Color(1.0, 0.4, 0.4))

	await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame

	var result = result_data["result"]
	var of_def = result_data.get("overflow_to_def_leader", result_data.get("overflow", 0))
	var of_att = result_data.get("overflow_to_att_leader", 0)

	if core.is_tutorial_match and TutorialManager.once("overflow_explained") and (of_def > 0 or of_att > 0):
		DialogueManager.start_convo([
			DialogueManager._dl("Guide", "More ATK than DEF? The extra damage hits the leader directly!"),
		])

	if ui:
		ui._lock_hp_updates = false

	if of_def > 0 and not defn.is_leader and defn.current_def <= 0:
		core._log("💥 Overflow to defender leader: %d" % of_def, Color(1, 0.6, 0.3))
		core.damage_leader(defn.owner, of_def)

	if of_att > 0 and not att.is_leader and att.current_def <= 0:
		core._log("💥 Counter overflow to Attacker's Leader: %d" % of_att, Color(1, 0.6, 0.3))
		core.damage_leader(att.owner, of_att)

	if ui:
		ui._lock_hp_updates = true

	var attacker_dead := (not att.is_leader and att.current_def <= 0)
	var defender_dead := (not defn.is_leader and defn.current_def <= 0)

	if defender_dead:
		await _kill_unit(defn)
	if attacker_dead:
		await _kill_unit(att)

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


func _focus_camera_on_battle(att_tile: Node3D, def_tile: Node3D, zoom_in := true) -> void:
	if not cam or not att_tile or not def_tile:
		return

	if zoom_in:
		_camera_locked = true
		_battle_cam_default_pos = cam.position
		_battle_cam_default_fov = cam.fov

		var midpoint := (att_tile.global_position + def_tile.global_position) / 2.0
		var target_pos := midpoint + Vector3(0, 3, 6)

		var tw = create_tween()
		tw.tween_property(cam, "position", target_pos, 0.6)
		tw.parallel().tween_property(cam, "fov", _battle_cam_default_fov * 0.7, 0.6)
		await tw.finished
	else:
		var tw2 = create_tween()
		tw2.tween_property(cam, "position", _battle_cam_default_pos, 0.6)
		tw2.parallel().tween_property(cam, "fov", _battle_cam_default_fov, 0.6)
		await tw2.finished
		_camera_locked = false


# =====================================================
# 🌿 PASSIVES / STATE HELPERS
# =====================================================

func apply_all_passives() -> void:
	print("🧊 apply_all_passives: units=", core.units.size())

	for pos in core.units.keys():
		var tile = core.board.get_tile(pos.x, pos.y)
		var unit: UnitData = core.units[pos]
		if not tile or tile.occupant != unit:
			continue
		if not unit or unit.current_def <= 0 or not is_instance_valid(unit):
			continue

		var facedown = unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown"))

		core._apply_terrain_bonus(unit, tile.terrain_type)

		if not facedown and unit.card and unit.card.ability and unit.card.ability.trigger == "passive":
			unit.card.ability.execute(core, unit)

		if facedown:
			tile.set_art(core.CARD_BACK)
			if tile.has_node("CardModel"):
				var model0 := tile.get_node("CardModel")
				if is_instance_valid(model0):
					model0.visible = false
		else:
			core.refresh_tile_art_safe(pos)
			if tile.has_node("CardModel"):
				var model1 := tile.get_node("CardModel")
				if is_instance_valid(model1):
					model1.visible = true

		if tile.has_method("update_stat_labels"):
			tile.update_stat_labels(unit.current_atk, unit.current_def)

	if core.card_details_ui and core.card_details_ui.visible:
		core.card_details_ui.call("refresh_if_showing", core.card_details_ui.current_unit)


func _enforce_visual_face_state() -> void:
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		var tile = core.board.get_tile(pos.x, pos.y)
		if not tile or not u:
			continue

		var is_down = u.is_facedown or (u.has_meta("is_facedown") and u.get_meta("is_facedown"))
		if is_down:
			tile.set_art(core.CARD_BACK)
			if tile.has_node("CardModel"):
				var m = tile.get_node("CardModel")
				if is_instance_valid(m):
					m.visible = false
		else:
			tile.set_art(u.card.art)
			if tile.has_node("CardModel"):
				var mm = tile.get_node("CardModel")
				if is_instance_valid(mm):
					mm.visible = true


func clear_exhausted_tiles() -> void:
	for pos in core.units.keys():
		var t = board.get_tile(pos.x, pos.y)
		if t:
			t.set_exhausted(false)


func set_exhausted_for_unit(u: UnitData, exhausted: bool) -> void:
	for pos in core.units.keys():
		if core.units[pos] == u:
			var t = board.get_tile(pos.x, pos.y)
			if t:
				t.set_exhausted(exhausted)
			return


func get_leader_pos(owner: int) -> Vector2i:
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		if u.is_leader and u.owner == owner:
			return pos
	return Vector2i(-1, -1)


# =====================================================
# ✨ ABILITIES & KILLS
# =====================================================

func _apply_attack_bonus(unit: UnitData) -> void:
	if unit and unit.has_meta("boost_attack_bonus"):
		var bonus = unit.get_meta("boost_attack_bonus")
		unit.current_atk = unit.card.atk + bonus


func apply_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	ability.execute(core, unit)
	unit.set_meta("passive_active", true)


# =====================================================
# ✨ ABILITIES — SAFE ASYNC WRAPPER (Godot 4.5.1)
# =====================================================
# =====================================================
# ✨ ABILITIES — Synchronous + Awaitable (No async)
# =====================================================
func _trigger_ability(unit: UnitData, trigger: String) -> Signal:
	var finished := Signal()  # custom completion signal

	if not unit or not unit.card or not unit.card.ability:
		finished.emit()
		return finished

	var ab = unit.card.ability
	if ab.trigger != trigger:
		finished.emit()
		return finished

	core._log("✨ Triggering ability: %s" % ab.display_name, Color(0.9, 0.9, 0.6))

	# Execute the ability and wait for it to finish if it has internal waits
	_run_ability(ab, finished, unit)
	return finished


func _run_ability(ab: CardAbility, finished: Signal, unit: UnitData) -> void:
	# Wrap the ability execution safely
	var exec = await ab.execute(core, unit)

	# If ability uses timers/yields inside, we rely on that to manage pacing
	# but if not, we emit manually when it’s done.
	if exec and exec.has_method("is_valid"):
		# If it's a yield-like state (has finished signal)
		if exec.has_signal("finished"):
			exec.finished.connect(func(): finished.emit())
		else:
			finished.emit()
	else:
		finished.emit()

func remove_passive_effect(unit: UnitData, ability: CardAbility) -> void:
	if ability.has_method("remove"):
		ability.remove(core, unit)


func _kill_unit(u: UnitData, silent := false) -> void:
	if u == null:
		return
	if not is_instance_valid(u):
		return
	if u.is_leader:
		return
	if u.current_def > 0:
		return

	var card_name := (u.card.name if u.card and u.card.name else "Unknown Card")

	if u.card and u.card.ability and u.card.ability.trigger == "passive":
		remove_passive_effect(u, u.card.ability)

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

	if u.card and "death_sound" in u.card and u.card.death_sound:
		mover._play_card_sound(u.card.death_sound, tile.global_position)
	else:
		mover._play_card_sound(core.CARD_DEATH_SOUND, tile.global_position)

	if tile.has_node("CardMesh"):
		var mesh = tile.get_node("CardMesh")
		if is_instance_valid(mesh):
			var tw = create_tween()
			tw.tween_property(mesh, "scale", mesh.scale * 0.5, 0.3)
			await tw.finished

	if tile.has_node("CardModel"):
		var model = tile.get_node("CardModel")
		if is_instance_valid(model):
			var tw2 = create_tween()
			tw2.tween_property(model, "scale", model.scale * 0.3, 0.3)
			await tw2.finished
			await get_tree().process_frame
			if is_instance_valid(model):
				model.queue_free()

	tile.clear()
	core.units.erase(found_pos)

	if core.card_details_ui:
		core.card_details_ui.call("hide_card")

	if not silent:
		core._log("💀 %s was destroyed." % card_name, Color(1, 0.4, 0.4))


# =====================================================
# 🎨 VISUAL HELPERS & FX
# =====================================================

func _float_text(pos: Vector3, text: String, color := Color(1, 0.3, 0.3)) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.pixel_size = 0.0045
	lbl.modulate = color
	lbl.outline_size = 4
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.font_size = 48
	lbl.position = pos + Vector3(0, 0.8, 0)

	core.add_child(lbl)

	lbl.scale = Vector3(0.6, 0.6, 0.6)

	var tw := create_tween()
	tw.tween_property(lbl, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y + 1.0, 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	await tw.finished

	lbl.queue_free()


func _camera_shake(intensity := 0.1, duration := 0.2) -> void:
	if not cam:
		return
	var base_pos = cam.position
	var t := 0.0
	while t < duration:
		cam.position = base_pos + Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			0
		)
		await get_tree().process_frame
		t += get_process_delta_time()
	cam.position = base_pos


func _add_card_highlight(sprite: Sprite3D, color: Color) -> Node3D:
	var glow := MeshInstance3D.new()
	glow.mesh = QuadMesh.new()
	glow.scale = Vector3(1.3, 1.3, 1.3)
	glow.position = sprite.position - Vector3(0, 0, 0.01)

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
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	glow.material_override = mat

	glow.sorting_offset = -1

	sprite.get_parent().add_child(glow)
	glow.look_at(sprite.global_position, Vector3.UP)

	return glow


func _card_explode(sprite: Sprite3D, color: Color) -> void:
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
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.2

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

	var has_modulate := target.has_method("set_modulate")
	if not has_modulate and target.get("modulate") == null:
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

	var original_mod = target.modulate if target.get("modulate") != null else Color(1, 1, 1)
	var tw = create_tween()
	tw.tween_property(target, "modulate", color, 0.15)
	tw.tween_property(target, "modulate", original_mod, 0.25)
	await tw.finished


func _fade(to_alpha: float, dur: float) -> void:
	var rect: ColorRect = core.get_node("UISystem/FadeRect")
	var tw = create_tween()
	tw.tween_property(rect, "modulate:a", to_alpha, dur)
	await tw.finished


# =====================================================
# 🧰 MISC UTILS
# =====================================================

func _colorize_name(unit: UnitData) -> String:
	if not unit or not unit.card:
		return ""
	var color = "#55CCFF" if unit.owner == core.PLAYER else "#FF6666"
	return "[color=%s]%s[/color]" % [color, unit.card.name]
