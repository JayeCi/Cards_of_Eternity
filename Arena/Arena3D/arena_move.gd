# =====================================================================
# 📘 FUNCTION INDEX — ArenaMove.gd
# =====================================================================

# ⚙️ INITIALIZATION
# ---------------------------------------------------------------------
# init(core_ref, ui_ref, board_ref, battle_ref)     → Injects dependencies & sets references

# 🟩 UNIT PLACEMENT
# ---------------------------------------------------------------------
# place_unit(card, pos, owner, mode, is_player=false)
#    → Places a card/unit on the board. Handles spells, summons, visuals, models, and abilities.

# 🟦 MOVEMENT & INPUT
# ---------------------------------------------------------------------
# on_board_click(screen_pos)
#    → Main click handler for player board interactions (move, attack, place, or flip)
# _move_or_battle(from, to, bypass_control_check=false)
#    → Executes either a movement or a battle depending on tile occupancy and state
# _is_within_move_range(from_pos, to_pos, unit)
#    → Returns whether a move/attack target is within allowed movement range
# _show_move_targets(from)
#    → Highlights reachable tiles for selected unit based on terrain, mode, and facing

# 🌀 FLIP / FACEUP CONFIRMATION
# ---------------------------------------------------------------------
# confirm_faceup(unit)
#    → Confirms that a unit has been flipped face-up, activates pending abilities
# _flip_faceup(tile, new_texture)
#    → Plays visual flip animation for a card and reveals its 3D model

# 🧭 TILE & UNIT HELPERS
# ---------------------------------------------------------------------
# _get_unit_tile(unit)
#    → Returns the tile Node3D currently holding the given UnitData
# clear_highlights()
#    → Clears all movement / attack highlights from every tile

# 🎵 AUDIO / FEEDBACK
# ---------------------------------------------------------------------
# _play_card_sound(sound, position=Vector3.ZERO)
#    → Plays a positional 3D sound effect (for movement, attack, or summon actions)
# =====================================================================



extends Node
class_name ArenaMove

#var core: ArenaCore
#var board: Node3D
#var ui: ArenaUI
#var battle: ArenaBattle

@onready var ui: ArenaUI = $"../UISystem"
@onready var battle: ArenaBattle = $"../BattleSystem"
@onready var board: Board3D = $"../BoardGenerator"
@onready var core: ArenaCore = $".."
@onready var cam: ArenaCamera = $"../CameraSystem"



var current_from: Vector2i = Vector2i(-1, -1)
var move_targets: Dictionary = {} # { Vector2i : { "kind": "move"|"attack" } }

func _ready():
	if $MoveHighlight:
		var mh = $MoveHighlight
		if mh.material:
			mh.material = mh.material.duplicate()

func init(core_ref: ArenaCore, ui_ref: ArenaUI, board_ref: Node3D, battle_ref: ArenaBattle) -> void:
	core = core_ref
	ui = ui_ref
	board = board_ref
	battle = battle_ref


# ===============================
# 🟩 Placement
# ===============================

func place_unit(card: CardData, pos: Vector2i, owner: int, mode: int, is_player: bool = false) -> void:
	var is_real_summon := true   # this is a *real summon*, not a movement

	var tile = board.get_tile(pos.x, pos.y)
	if not tile:
		core._log("⚠️ Tried to place unit on invalid tile: %s" % str(pos))
		return

	if tile.occupant != null:
		core._log("⚠️ Tile already occupied at %s" % str(pos))
		return

	var unit := UnitData.new().init_from_card(card, owner)

	# 🪤 EVENT cards (Trap cards): ALWAYS placed facedown, trigger when attacked
	if card.card_type == CardData.CardType.EVENT:
		unit.mode = UnitData.Mode.FACEDOWN
		core.units[pos] = unit
		tile.set_occupant(unit)
		tile.set_art(core.CARD_BACK)
		unit.set_meta("is_facedown", true)
		unit.is_facedown = true
		unit.set_meta("is_previewing_flip", false)

		# Store cast position for when it's revealed
		unit.set_meta("spell_cast_position", pos)

		core._log("🪤 EVENT card placed facedown as trap.", Color(1.0, 0.8, 0.6))
		core._play_card_place_sound()
		return

	# 🧙‍♂️ SPELL cards: cast immediately if face-up, or place facedown
	if card.card_type == CardData.CardType.SPELL:
		var is_facedown := (mode == UnitData.Mode.FACEDOWN)

		# If placed facedown, treat like a normal facedown card
		if is_facedown:
			unit.mode = mode
			core.units[pos] = unit
			tile.set_occupant(unit)
			tile.set_art(core.CARD_BACK)
			unit.set_meta("is_facedown", true)
			unit.is_facedown = true
			unit.set_meta("is_previewing_flip", false)

			# Store cast position for when it's revealed
			unit.set_meta("spell_cast_position", pos)

			core._log("🎴 Spell card placed facedown.", Color(0.7, 0.7, 0.8))
			core._play_card_place_sound()
			return

		# ⚔️ UPGRADE SPELL: Stay on board until moved onto monster
		if card.is_upgrade_spell:
			core._log("⚔️ %s placed on board (waiting for monster)." % card.name, Color(1.0, 0.9, 0.6))

			# Place spell on tile and keep it there
			core.units[pos] = unit
			tile.set_occupant(unit)
			tile.set_art(card.art)
			tile.set_badge_text("U")  # U for Upgrade
			unit.set_meta("spell_cast_position", pos)
			core._play_card_place_sound()
			return

		# Otherwise, cast immediately and vanish
		core._log("✨ Casting spell: %s" % card.name, Color(0.9, 0.8, 1.0))

		# ✅ Temporarily place spell on tile for visual feedback
		core.units[pos] = unit
		tile.set_occupant(unit)
		tile.set_art(card.art)
		tile.set_badge_text("S")  # S for Spell

		# Store cast position for abilities that need it
		unit.set_meta("spell_cast_position", pos)

		# Wait a moment for visual
		await get_tree().create_timer(0.3).timeout

		if card.ability and "on_summon" in card.ability.trigger:
			await core._execute_card_ability(unit, card.ability)

		# Remove spell from board
		await get_tree().create_timer(0.5).timeout
		core._play_card_place_sound()
		core._log("💨 %s vanishes after casting." % card.name, Color(0.7, 0.7, 1.0))

		# Clean up
		core.units.erase(pos)
		tile.set_occupant(null)
		tile.set_art(null)
		tile.set_badge_text("")
		return

	unit.mode = mode
	core.units[pos] = unit
	tile.set_occupant(unit)

	var is_facedown := (mode == UnitData.Mode.FACEDOWN)

	if is_facedown:
		tile.set_art(core.CARD_BACK)
		unit.set_meta("is_facedown", true)
		unit.is_facedown = true
		unit.set_meta("is_previewing_flip", false)
		unit.set_meta("flipped_permanent", false)
	else:
		tile.set_art(card.art)
		unit.set_meta("is_facedown", false)
		unit.is_facedown = false
		unit.set_meta("is_previewing_flip", false)
		unit.set_meta("flipped_permanent", true)

	# 3D model
	if card.model_path != "":
		var model_scene: PackedScene = load(card.model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "CardModel"

			if card.model_position != Vector3(0, 0, 0):
				model_instance.position = card.model_position

			if card.model_scale != Vector3(.5, .5, .5):
				model_instance.scale = card.model_scale

			tile.add_child(model_instance)
			unit.set_meta("model_instance", model_instance)

			if owner == core.ENEMY:
				model_instance.rotate_y(deg_to_rad(180))

			if is_facedown:
				model_instance.visible = false
			else:
				model_instance.visible = true

	match mode:
		UnitData.Mode.ATTACK:
			tile.set_badge_text("A")
		UnitData.Mode.DEFENSE:
			tile.set_badge_text("D")
		UnitData.Mode.FACEDOWN:
			tile.set_badge_text("?")

	var terrain = tile.terrain_type
	core._apply_terrain_bonus(unit, terrain)

	await get_tree().process_frame

	if is_real_summon and not is_facedown and card.ability and "on_summon" in card.ability.trigger:
		await core._execute_card_ability(unit, card.ability)


	core._play_card_place_sound()


	# Keep only tile/unit setup, visuals, and ability triggers
	pass


# ===============================
# 🟦 Movement
# ===============================

func on_board_click(screen_pos: Vector2) -> void:
	# Ignore during battle / cutscene
	if battle._is_battle_in_progress or (core and core.is_cutscene_active):
		return

	var result = cam.ray_pick(screen_pos)
	if not result:
		return

	var tile = board.get_tile_from_collider(result.collider)
	if tile == null:
		return

	var pos := Vector2i(tile.x, tile.y)
	core.hovered_tile = tile

	var is_placing := (core.dragging_card != null)

	# 1️⃣ If we're in summon placement flow, let core handle it
	if is_placing:
		core.try_place_dragged_card(tile)
		return

	# 2️⃣ SELECT UNIT PHASE: choose a unit to move
	if core.phase == core.Phase.SUMMON_OR_MOVE:
		if tile.occupant and tile.occupant.owner == core.PLAYER:
			if not core.can_unit_act(tile.occupant):
				core._log("⏳ %s has already acted." % tile.occupant.card.name, Color(0.7, 0.7, 0.7))
				return

			_reset_selection()
			current_from = pos
			core.selected_pos = pos
			core._log("🎯 Selected %s. Choose a highlighted tile to move or attack." % tile.occupant.card.name, Color(0.8, 1.0, 0.8))
			_show_move_targets(pos)
			core._set_phase(core.Phase.SELECT_MOVE_TARGET)
			core._update_phase_ui()
		else:
			core._log("💡 Click one of your units to move.", Color(0.7, 0.7, 0.7))

		return

	# 3️⃣ MOVE TARGET PHASE: we already have a source; click decides action
	if core.phase == core.Phase.SELECT_MOVE_TARGET:
		# Self-click = flip/ability/exhaust logic via _move_or_battle(from, from)
		if pos == current_from:
			await _move_or_battle(current_from, current_from)
			_reset_selection()
			if core.phase != core.Phase.ENEMY_TURN:
				core._set_phase(core.Phase.SUMMON_OR_MOVE)
				core._update_phase_ui()
			return

		# If clicked a highlighted tile → guaranteed valid
		if move_targets.has(pos):
			await _move_or_battle(current_from, pos)
			_reset_selection()
			# Phase might change inside _move_or_battle (e.g. battle → enemy turn),
			# only reset if still player's action phase.
			if core.phase != core.Phase.ENEMY_TURN:
				core._set_phase(core.Phase.SUMMON_OR_MOVE)
				core._update_phase_ui()
			return

		# If clicked another friendly unit → switch selection
		if tile.occupant and tile.occupant.owner == core.PLAYER and core.can_unit_act(tile.occupant):
			_reset_selection()
			current_from = pos
			core.selected_pos = pos
			_show_move_targets(pos)
			core._set_phase(core.Phase.SELECT_MOVE_TARGET)
			core._update_phase_ui()
			return

		core._log("🚫 Not a valid move target.", Color(1, 0.5, 0.5))
		return


func _move_or_battle(from: Vector2i, to: Vector2i, bypass_control_check := false) -> void:
	if battle._is_battle_in_progress:
		return
	battle._is_battle_in_progress = true

	# ✅ Only allow moves/attacks to known highlighted targets (unless bypassed or self-click)
	if from != to and not bypass_control_check and not move_targets.has(to):
		core._log("🚫 That tile is not a valid target.", Color(1, 0.5, 0.5))
		battle._is_battle_in_progress = false
		return

	var src = board.get_tile(from.x, from.y)
	var dst = board.get_tile(to.x, to.y)
	if not src or not dst:
		battle._is_battle_in_progress = false
		return

	var attacker: UnitData = src.occupant
	if not attacker:
		battle._is_battle_in_progress = false
		return
	
	# ✅ Check universal frozen status
	if FrozenStatusEffect.is_frozen(attacker):
		core._log("❄️ %s is frozen and cannot act!" % attacker.card.name, Color(0.5, 0.5, 0.9))
		battle._is_battle_in_progress = false
		return
		
	# 🟢 If this command is a move/attack to ANOTHER tile, confirm flip now.
	if from != to and attacker.has_meta("is_previewing_flip") and attacker.get_meta("is_previewing_flip"):
		core._log("✅ Confirming %s's flip before movement/attack." % attacker.card.name, Color(0.8, 1.0, 0.8))
		battle.confirm_flip()

	# 🚫 Prevent controlling enemy (unless AI)
	if not bypass_control_check and attacker.owner != core.PLAYER:
		core._log("🚫 You can't control enemy cards!", Color(1, 0.5, 0.5))
		battle._is_battle_in_progress = false
		return

	# 🟢 Self-click = ability / exhaust / confirm flip
	if from == to:
		var tile = board.get_tile(from.x, from.y)
		if not tile or not tile.occupant:
			battle._is_battle_in_progress = false
			return

		var unit = tile.occupant
		if not core.can_unit_act(unit):
			core._log("⏳ %s has already acted this turn." % unit.card.name)
			battle._is_battle_in_progress = false
			return

		# ✅ Confirm flip if previewing
		if unit.has_meta("is_previewing_flip") and unit.get_meta("is_previewing_flip"):
			core._log("✅ Confirming flip for %s..." % unit.card.name, Color(0.8, 1.0, 0.8))
			await battle.confirm_flip()
			core.mark_unit_acted(unit)
			if tile.has_method("set_exhausted"):
				tile.set_exhausted(true)
			clear_highlights()
			core.selected_pos = Vector2i(-1, -1)
			core._set_phase(core.Phase.SUMMON_OR_MOVE)
			core._update_phase_ui()
			battle._is_battle_in_progress = false
			return

		var is_down = unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown"))
		if is_down:
			core._log("🃏 %s is facedown — no ability triggered." % unit.card.name, Color(0.7, 0.7, 0.7))
			core.mark_unit_acted(unit)
			if tile.has_method("set_exhausted"):
				tile.set_exhausted(true)
			clear_highlights()
			core.selected_pos = Vector2i(-1, -1)
			core._set_phase(core.Phase.SUMMON_OR_MOVE)
			core._update_phase_ui()
			battle._is_battle_in_progress = false
			return

		# 🔸 Normal self-click ability flow
		if unit.has_meta("pending_on_flip_ability"):
			var ab = unit.get_meta("pending_on_flip_ability")
			unit.set_meta("pending_on_flip_ability", null)
			if ab:
				core._log("✨ %s activates %s!" % [unit.card.name, ab.display_name], Color(1.0, 0.9, 0.6))
				core._execute_card_ability(unit, ab)
		else:
			core._log("🌀 %s steadies their position." % unit.card.name, Color(0.8, 0.8, 1.0))

		core._apply_terrain_bonus(unit, tile.terrain_type)
		core.mark_unit_acted(unit)
		if tile.has_method("set_exhausted"):
			tile.set_exhausted(true)

		clear_highlights()
		if ui and not ui._is_hovering_hand_card:
			ui.hide_hover()

		core.selected_pos = Vector2i(-1, -1)
		core._set_phase(core.Phase.SUMMON_OR_MOVE)
		core._update_phase_ui()
		battle._is_battle_in_progress = false
		return

	# -------------------------
	# MOVE (no defender) OR UPGRADE SPELL INTERACTION
	# -------------------------
	if dst.occupant == null:
		clear_highlights()
		if ui and not ui._is_hovering_hand_card:
			ui.hide_hover()

		var model: Node3D = null
		var model_path := NodePath("CardModel")
		if src.has_node(model_path):
			model = src.get_node(model_path)

		dst.set_occupant_no_summon(attacker)
		# Don't refresh art yet - wait for model animation

		_play_card_sound(core.CARD_MOVE_SOUND, dst.global_position)
		dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")
		core._apply_terrain_bonus(attacker, dst.terrain_type)

		# --- 🔹 Visual Sync for AI or Player movement ---
		if model and is_instance_valid(model):
			var offset = Vector3(0, 0.1, 0)
			if attacker.card and attacker.card.model_position != Vector3.ZERO:
				offset = attacker.card.model_position
			var world_target = dst.global_position + offset

			# smooth tween movement
			var tw = create_tween()
			tw.tween_property(model, "global_position", world_target, 0.25)
			await tw.finished

			# Reparent model safely (for AI or player)
			if is_instance_valid(src) and model.get_parent() == src:
				src.remove_child(model)
			if is_instance_valid(dst) and not model.is_queued_for_deletion():
				dst.add_child(model)
				model.position = offset

		# NOW set the art after model has moved
		dst.set_art(
			attacker.card.art if attacker.mode != UnitData.Mode.FACEDOWN else core.CARD_BACK,
			attacker.owner == core.ENEMY
		)
		dst.refresh_card_art()

		# --- Sync data and cleanup ---
		src.clear()
		core.units.erase(from)
		core.units[to] = attacker
		core.mark_unit_acted(attacker)

		battle._is_battle_in_progress = false
		return

	# ⚔️ CHECK FOR UPGRADE SPELL INTERACTIONS (before battle)
	# Case 1: Monster moves onto upgrade spell
	if dst.occupant and attacker.card.card_type == CardData.CardType.MONSTER and dst.occupant.card and dst.occupant.card.is_upgrade_spell:
		clear_highlights()

		# Store spell unit reference before we change occupancy
		var spell_unit = dst.occupant

		# STEP 1: Move monster's 3D model to the spell's tile
		var model: Node3D = null
		var model_path := NodePath("CardModel")
		if src.has_node(model_path):
			model = src.get_node(model_path)

		_play_card_sound(core.CARD_MOVE_SOUND, dst.global_position)

		if model and is_instance_valid(model):
			var offset = Vector3(0, 0.1, 0)
			if attacker.card and attacker.card.model_position != Vector3.ZERO:
				offset = attacker.card.model_position
			var world_target = dst.global_position + offset

			var tw = create_tween()
			tw.tween_property(model, "global_position", world_target, 0.25)
			await tw.finished

			if is_instance_valid(src) and model.get_parent() == src:
				src.remove_child(model)
			if is_instance_valid(dst) and not model.is_queued_for_deletion():
				dst.add_child(model)
				model.position = offset

		# STEP 2: Update tile occupancy and art
		dst.set_occupant_no_summon(attacker)
		dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")
		dst.set_art(
			attacker.card.art if attacker.mode != UnitData.Mode.FACEDOWN else core.CARD_BACK,
			attacker.owner == core.ENEMY
		)
		dst.refresh_card_art()

		# STEP 3: Clear previous tile
		src.clear()
		core.units.erase(from)
		core.units[to] = attacker

		# STEP 4: NOW play the upgrade animation (pass spell art since tile occupant is now monster)
		await _try_upgrade_monster(spell_unit, attacker, dst, dst, spell_unit.card.art)

		# Final cleanup
		core.mark_unit_acted(attacker)
		battle._is_battle_in_progress = false
		return

	# Case 2: Upgrade spell moves onto monster
	if dst.occupant and attacker.card.is_upgrade_spell and dst.occupant.card.card_type == CardData.CardType.MONSTER:
		clear_highlights()
		await _try_upgrade_monster(attacker, dst.occupant, src, dst)

		# Spell was removed, monster stays
		src.clear()
		core.units.erase(from)
		core.mark_unit_acted(attacker)
		battle._is_battle_in_progress = false
		return

	# Case 3: Upgrade spell moves onto another spell or event - destroy the upgrade spell
	if dst.occupant and attacker.card.is_upgrade_spell and dst.occupant.card and (dst.occupant.card.card_type == CardData.CardType.SPELL or dst.occupant.card.card_type == CardData.CardType.EVENT):
		core._log("💥 %s cannot be used here and is destroyed!" % attacker.card.name, Color(1.0, 0.6, 0.4))
		clear_highlights()

		# Remove the upgrade spell
		src.clear()
		core.units.erase(from)
		core.mark_unit_acted(attacker)
		battle._is_battle_in_progress = false
		return
		
	# 🚫 Leaders cannot attack enemy units — but they CAN move
	if attacker.is_leader and dst.occupant != null:
		core._log("🚫 Leaders cannot attack enemy units.", Color(1, 0.6, 0.4))
		battle._is_battle_in_progress = false
		return

	# 🚫 EVENT cards cannot attack enemy units — but they CAN move
	if attacker.card and attacker.card.card_type == CardData.CardType.EVENT and dst.occupant != null:
		core._log("🚫 EVENT cards cannot attack enemy units.", Color(1, 0.6, 0.4))
		battle._is_battle_in_progress = false
		return

	# -------------------------
	# BATTLE
	# -------------------------
	var defender: UnitData = dst.occupant

	if attacker.mode == UnitData.Mode.FACEDOWN:
		attacker.mode = UnitData.Mode.ATTACK
		await _flip_faceup(src, attacker.card.art)
		await confirm_faceup(attacker)
		battle.confirm_flip()

		core._log("📢 confirm_faceup() manually invoked for %s" % attacker.card.name, Color(0.9, 1.0, 0.7))

		attacker.current_atk = attacker.card.atk
		attacker.current_def = attacker.card.def
		core._apply_terrain_bonus(attacker, src.terrain_type)
		core._log("🔄 %s was revealed in Attack Mode!" % attacker.card.name, Color(1, 1, 0.6))

		attacker.is_facedown = false
		attacker.set_meta("is_facedown", false)

		if attacker.card and attacker.card.ability:
			var ab_a = attacker.card.ability
			if ab_a.trigger in ["on_summon", "passive"]:
				core._log(
					"✨ %s's %s ability activates on reveal!"
					% [attacker.card.name, ab_a.display_name],
					Color(1.0, 0.9, 0.6)
				)
				core._execute_card_ability(attacker, ab_a)

		var attacker_tile = board.get_tile(from.x, from.y)
		if attacker_tile:
			core.refresh_tile_art_safe(from)
			if attacker_tile.has_node("CardModel"):
				var m_a = attacker_tile.get_node("CardModel")
				if is_instance_valid(m_a):
					m_a.visible = true

	# 🪤 TRAP CARD: Check if defender is a facedown EVENT card
	core._log("🔍 TRAP CHECK: defender.mode=%s, card_type=%s, card_name=%s" % [defender.mode, defender.card.card_type if defender.card else "NO CARD", defender.card.name if defender.card else "NO CARD"], Color(1.0, 1.0, 0.0))

	if defender.mode == UnitData.Mode.FACEDOWN and defender.card and defender.card.card_type == CardData.CardType.EVENT:
		core._log("🪤 %s was a trap! It activates on the attacker!" % defender.card.name, Color(1.0, 0.6, 1.0))

		# 🎥 Move camera to trap location
		var trap_tile = board.get_tile(to.x, to.y)
		if trap_tile and cam:
			var trap_pos = trap_tile.global_position
			cam.focus_on_battle(trap_pos, trap_pos, true)
			await get_tree().create_timer(0.4).timeout

		# Reveal the EVENT card visually
		await _flip_faceup(dst, defender.card.art)
		dst.set_badge_text("E")
		await get_tree().create_timer(0.3).timeout

		# Store the TRAP's position as the event cast position (freezes adjacent to trap, not attacker)
		defender.set_meta("spell_cast_position", to)  # to = trap/defender position

		# Execute the event ability
		if defender.card.ability and defender.card.ability.trigger in ["on_summon"]:
			await core._execute_card_ability(defender, defender.card.ability)

		# Remove the EVENT card from the board
		await get_tree().create_timer(0.5).timeout
		core._log("💨 %s vanishes after activation." % defender.card.name, Color(0.7, 0.7, 1.0))
		core.units.erase(to)
		dst.set_occupant(null)
		dst.set_art(null)
		dst.set_badge_text("")

		# 🎥 Return camera to normal position
		if cam:
			cam.focus_on_battle(Vector3.ZERO, Vector3.ZERO, false)
			await get_tree().create_timer(0.3).timeout

		# Cancel the battle
		battle._is_battle_in_progress = false
		clear_highlights()
		return
	else:
		core._log("🔍 NOT A TRAP - continuing to normal battle", Color(1.0, 1.0, 0.0))

	# 🛡️ DEFENSIVE ABILITY: Check if defender has "on_attacked" trigger (like Ground Slam)
	if defender.card and defender.card.ability:
		var ab = defender.card.ability
		if "on_attacked" in ab.trigger:
			core._log("🛡️ %s activates a defensive ability!" % defender.card.name, Color(1.0, 0.8, 0.4))

			# Store attacker position for the ability to use
			defender.set_meta("slam_attacker_pos", from)

			# Reveal defender if facedown
			if defender.mode == UnitData.Mode.FACEDOWN:
				defender.mode = UnitData.Mode.ATTACK
				await _flip_faceup(dst, defender.card.art)
				defender.current_atk = defender.card.atk
				defender.current_def = defender.card.def
				core._apply_terrain_bonus(defender, dst.terrain_type)
				defender.is_facedown = false
				defender.set_meta("is_facedown", false)
				core._log("⚡ %s was revealed defensively!" % defender.card.name, Color(1, 1, 0.6))

				# Make model visible
				if dst and dst.has_node("CardModel"):
					var m_d = dst.get_node("CardModel")
					if is_instance_valid(m_d):
						m_d.visible = true

			# Execute the defensive ability
			await core._execute_card_ability(defender, ab)

			# Clean up meta
			defender.set_meta("slam_attacker_pos", null)

			# Check if attacker was pushed back
			var attacker_new_pos = core.board.get_unit_position(attacker)
			if attacker_new_pos != from:
				# Attacker was successfully knocked back - cancel battle
				core._log("💨 The attacker was repelled! Battle canceled.", Color(0.7, 1.0, 0.7))
				battle._is_battle_in_progress = false
				clear_highlights()
				core.mark_unit_acted(attacker)
				return
			else:
				# Attacker wasn't pushed (blocked or edge) - battle continues
				core._log("⚔️ The attacker holds their ground! Battle proceeds.", Color(1.0, 0.9, 0.6))

	# 🛡️ ATTACKER DEFENSIVE ABILITY: Check if attacker has "on_attacked" trigger (like Ground Slam)
	# This triggers when the attacker initiates combat
	if attacker.card and attacker.card.ability:
		var ab_attacker = attacker.card.ability
		if "on_attacked" in ab_attacker.trigger:
			core._log("🛡️ %s activates a defensive ability while attacking!" % attacker.card.name, Color(1.0, 0.8, 0.4))

			# Store defender position for the ability to use
			attacker.set_meta("slam_attacker_pos", to)

			# Execute the attacker's defensive ability
			await core._execute_card_ability(attacker, ab_attacker)

			# Clean up meta
			attacker.set_meta("slam_attacker_pos", null)

			# Check if defender was pushed back
			var defender_new_pos = core.board.get_unit_position(defender)
			if defender_new_pos != to:
				# Defender was successfully knocked back - cancel battle
				core._log("💨 The defender was repelled! Battle canceled.", Color(0.7, 1.0, 0.7))
				battle._is_battle_in_progress = false
				clear_highlights()
				core.mark_unit_acted(attacker)
				return
			else:
				# Defender wasn't pushed (blocked or edge) - battle continues
				core._log("⚔️ The defender holds their ground! Battle proceeds.", Color(1.0, 0.9, 0.6))

	if defender.mode == UnitData.Mode.FACEDOWN:
		defender.mode = UnitData.Mode.ATTACK
		await _flip_faceup(dst, defender.card.art)
		await confirm_faceup(defender)
		battle.confirm_flip()

		defender.current_atk = defender.card.atk
		defender.current_def = defender.card.def
		core._apply_terrain_bonus(defender, dst.terrain_type)

		core._log("⚡ %s was revealed in Attack Mode!" % defender.card.name, Color(1, 1, 0.6))

		defender.is_facedown = false
		defender.set_meta("is_facedown", false)

		if defender.card and defender.card.ability:
			var ab_d = defender.card.ability
			if ab_d.trigger in ["on_summon", "passive"]:
				core._log(
					"✨ %s's %s ability activates on reveal!"
					% [defender.card.name, ab_d.display_name],
					Color(1.0, 0.9, 0.6)
				)
				await core._execute_card_ability(defender, ab_d)

	var def_tile = board.get_tile(to.x, to.y)
	if def_tile:
		core.refresh_tile_art_safe(to)
		if def_tile.has_node("CardModel"):
			var m_d = def_tile.get_node("CardModel")
			if is_instance_valid(m_d):
				m_d.visible = true

	clear_highlights()
	if ui and not ui._is_hovering_hand_card:
		ui.hide_hover()

	var prev_cutscene_state := core.is_cutscene_active if core and "is_cutscene_active" in core else false
	if core and "is_cutscene_active" in core:
		core.is_cutscene_active = true

	if def_tile and def_tile.has_method("pulse_move_highlight"):
		def_tile.pulse_move_highlight()

	var result_data = await battle._play_2d_battle(attacker, defender)

	core.mark_unit_acted(attacker)

	if core and "is_cutscene_active" in core:
		core.is_cutscene_active = prev_cutscene_state

	var result: String = result_data["result"]

	# 🧩 Auto-advance AI attacker
	if attacker.owner == core.ENEMY and result == "attacker_wins":
		if not dst.occupant and attacker.current_def > 0:
			dst.set_occupant_no_summon(attacker)
			# Don't refresh art yet - wait for model animation

			dst.set_badge_text("E")

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

			# NOW set the art after model has moved
			dst.set_art(attacker.card.art, true)
			dst.refresh_card_art()

			src.clear()
			core.units.erase(from)
			core.units[to] = attacker
			core._log(
				"🤖 Enemy advances into conquered tile (%s → %s)" %
				[str(from), str(to)],
				Color(0.8, 0.9, 1.0)
			)

	match result:
		"attacker_wins":
			if attacker.current_def > 0:
				dst.set_occupant_no_summon(attacker)
				# Don't refresh art yet - wait for model animation

				dst.set_badge_text("P" if attacker.owner == core.PLAYER else "E")

				if src.has_node("CardModel"):
					var m1 = src.get_node("CardModel")
					if is_instance_valid(m1):
						var offset1 = Vector3(0, 0.1, 0)
						if attacker.card and attacker.card.model_position != Vector3.ZERO:
							offset1 = attacker.card.model_position
						var world_target1 = dst.global_position + offset1

						var tw1 = create_tween()
						tw1.tween_property(m1, "global_position", world_target1, 0.25)
						await tw1.finished
						if m1.get_parent() == src:
							src.remove_child(m1)
						if is_instance_valid(dst):
							dst.add_child(m1)
							m1.position = Vector3(0, 0.5, 0)

				# NOW set the art after model has moved
				dst.set_art(attacker.card.art, attacker.owner == core.ENEMY)
				dst.refresh_card_art()

				src.clear()
				core.units.erase(from)
				core.units[to] = attacker
			core.mark_unit_acted(attacker)

		"defender_wins":
			core.mark_unit_acted(attacker)

		"both_destroyed":
			pass

		"both_survive":
			core.mark_unit_acted(attacker)
			var att_tile = _get_unit_tile(attacker)
			if att_tile:
				att_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)
			if def_tile and def_tile.occupant:
				def_tile.set_art(def_tile.occupant.card.art, def_tile.occupant.owner == core.ENEMY)

			var moved_distance = abs(to.x - from.x) + abs(to.y - from.y)
			if moved_distance >= 2:
				var mid_x := int((from.x + to.x) / 2)
				var mid_y := int((from.y + to.y) / 2)
				var mid_pos := Vector2i(mid_x, mid_y)

				if core.board.is_in_bounds(mid_pos):
					var mid_tile = board.get_tile(mid_pos.x, mid_pos.y)
					if mid_tile and mid_tile.occupant == null:
						core._log(
							"↩️ %s retreats to midpoint after stalemate."
							% attacker.card.name,
							Color(0.8, 0.9, 1.0)
						)

						if def_tile.has_node("CardModel"):
							var m2 = def_tile.get_node("CardModel")
							if is_instance_valid(m2):
								var offset2 = Vector3(0, 0.1, 0)
								if attacker.card and attacker.card.model_position != Vector3.ZERO:
									offset2 = attacker.card.model_position
								var world_target2 = mid_tile.global_position + offset2
								var tw2 = create_tween()
								tw2.tween_property(m2, "global_position", world_target2, 0.25)
								await tw2.finished
								if m2.get_parent() == def_tile:
									def_tile.remove_child(m2)
								if is_instance_valid(mid_tile):
									mid_tile.add_child(m2)
									m2.position = Vector3(0, 0.1, 0)

						def_tile.clear()
						core.units.erase(to)
						core.units[mid_pos] = attacker
						mid_tile.set_occupant(attacker)
						mid_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)
						mid_tile.set_badge_text("P" if attacker.owner == core.PLAYER else "E")
						core._apply_terrain_bonus(attacker, mid_tile.terrain_type)

		"leader_damaged":
			core.mark_unit_acted(attacker)
			var l_tile = _get_unit_tile(attacker)
			if l_tile:
				l_tile.set_art(attacker.card.art, attacker.owner == core.ENEMY)

	battle._is_battle_in_progress = false

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



func _show_move_targets(from: Vector2i) -> void:
	if battle._is_battle_in_progress or (core and core.is_cutscene_active):
		return

	clear_highlights()

	var src = board.get_tile(from.x, from.y)
	if not src or not src.occupant:
		return

	var unit: UnitData = src.occupant
	if not core.can_unit_act(unit):
		return

	current_from = from
	core.selected_pos = from

	var range := core.BASE_MOVE_RANGE

	# Preferred terrain bonus
	var is_down = unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown"))
	var previewed_up = unit.has_meta("is_previewing_flip") and unit.get_meta("is_previewing_flip")
	if (not is_down or previewed_up) and src.terrain_type == unit.card.preferred_terrain:
		range *= 2
		if src.has_method("pulse_move_highlight"):
			src.pulse_move_highlight()

	var dirs = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	# Check if this is an EVENT card (cannot attack)
	var is_event_card = unit.card and unit.card.card_type == CardData.CardType.EVENT
	var is_upgrade_spell = unit.card and unit.card.is_upgrade_spell

	for dir in dirs:
		for step in range(1, range + 1):
			var p = from + dir * step
			if not core.board.is_in_bounds(p):
				break

			var t = board.get_tile(p.x, p.y)
			if not t:
				break

			if t.occupant:
				# ⚔️ CHECK FOR UPGRADE SPELL INTERACTIONS
				var target_is_upgrade_spell = t.occupant.card and t.occupant.card.is_upgrade_spell
				var target_is_monster = t.occupant.card and t.occupant.card.card_type == CardData.CardType.MONSTER
				var target_is_spell = t.occupant.card and t.occupant.card.card_type == CardData.CardType.SPELL
				var target_is_event = t.occupant.card and t.occupant.card.card_type == CardData.CardType.EVENT
				var moving_is_monster = unit.card and unit.card.card_type == CardData.CardType.MONSTER

				# Case 1: Monster moving onto upgrade spell (YELLOW highlight)
				# Skip if monster is a leader
				if moving_is_monster and target_is_upgrade_spell and t.occupant.owner == core.PLAYER and not unit.is_leader:
					move_targets[p] = {"kind": "upgrade"}
					_highlight_move_tile(t, false, true)  # Yellow
					break

				# Case 2: Upgrade spell moving onto monster (YELLOW highlight)
				# Skip if target is a leader
				elif is_upgrade_spell and target_is_monster and t.occupant.owner == core.PLAYER and not t.occupant.is_leader:
					move_targets[p] = {"kind": "upgrade"}
					_highlight_move_tile(t, false, true)  # Yellow
					break

				# Case 3: Upgrade spell moving onto spell/event (YELLOW highlight - will be destroyed)
				elif is_upgrade_spell and (target_is_spell or target_is_event) and t.occupant.owner == core.PLAYER:
					move_targets[p] = {"kind": "upgrade"}
					_highlight_move_tile(t, false, true)  # Yellow
					break

				# EVENT cards cannot attack - just stop when encountering enemies
				elif is_event_card:
					break
				# Normal cards can attack enemies
				elif t.occupant.owner != core.PLAYER:
					move_targets[p] = {"kind": "attack"}
					_highlight_move_tile(t, true, false)  # Red
				break
			else:
				move_targets[p] = {"kind": "move"}
				_highlight_move_tile(t, false, false)  # Blue

func _highlight_move_tile(tile: Node3D, is_attack: bool, is_upgrade: bool = false) -> void:
	# Badge symbol
	if tile.has_method("set_highlight"):
		var symbol := "⚔" if is_attack else ("⚡" if is_upgrade else "•")
		tile.set_highlight(true, symbol)

	# Tint color
	var tint := Color(1.0, 1.0, 0.3) if is_upgrade else (Color(1.0, 0.3, 0.3) if is_attack else Color(0.3, 0.7, 1.0))

	# Animated highlight intro
	if tile.has_method("play_move_highlight_intro"):
		tile.play_move_highlight_intro(tint)
	elif tile.has_method("set_move_highlight_tint"):
		tile.set_move_highlight_tint(tint)
	else:
		# Absolute fallback
		if tile.has_node("MoveHighlight"):
			var mh = tile.get_node("MoveHighlight")
			mh.visible = true

	# Continue pulse animation
	if tile.has_method("pulse_move_highlight"):
		tile.pulse_move_highlight()

func confirm_faceup(unit: UnitData) -> void:
	if not unit:
		return

	core._log("📜 confirm_faceup() called for %s" % unit.card.name, Color(0.9, 0.9, 1.0))

	# 🧩 Clear preview flag
	if unit.has_meta("is_previewing_flip"):
		unit.set_meta("is_previewing_flip", false)
		core._log("🧩 Cleared preview flag for %s" % unit.card.name, Color(0.7, 0.9, 1.0))

	# 🛑 If remained facedown, cancel
	if unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown")):
		core._log("❎ %s remained facedown — ability canceled." % unit.card.name, Color(0.7, 0.7, 0.7))
		if unit.has_meta("pending_on_flip_ability"):
			unit.set_meta("pending_on_flip_ability", null)
		return

	# ✅ Confirmed face-up → mark as permanently revealed
	unit.set_meta("flipped_permanent", true)
	core._log(
		"🔒 %s marked permanently revealed (flipped_permanent=true)" % unit.card.name,
		Color(0.6, 1.0, 0.6)
	)

	if unit.has_meta("pending_on_flip_ability"):
		var ab: CardAbility = unit.get_meta("pending_on_flip_ability")
		unit.set_meta("pending_on_flip_ability", null)
		if ab:
			core._log(
				"✨ %s activates %s!" % [unit.card.name, ab.display_name],
				Color(1.0, 1.0, 0.6)
			)
			core._execute_card_ability(unit, ab)


func _flip_faceup(tile: Node3D, new_texture: Texture2D) -> void:
	var mesh = tile.get_node("CardMesh")
	var tw = create_tween()
	tw.tween_property(mesh, "rotation_degrees:y", 90, 0.15)
	await tw.finished

	tile.set_art(new_texture, tile.occupant.owner == core.ENEMY)

	var tw2 = create_tween()
	tw2.tween_property(mesh, "rotation_degrees:y", 0, 0.15)
	await tw2.finished

	if tile.has_node("CardModel"):
		var model = tile.get_node("CardModel")
		if is_instance_valid(model):
			model.visible = true

func _get_unit_tile(u: UnitData) -> Node3D:
	for pos in core.units.keys():
		if core.units[pos] == u:
			return board.get_tile(pos.x, pos.y)
	return null

func _reset_selection() -> void:
	current_from = Vector2i(-1, -1)
	core.selected_pos = Vector2i(-1, -1)
	move_targets.clear()
	clear_highlights()

func clear_highlights() -> void:
	move_targets.clear()
	for y in range(core.BOARD_H):
		for x in range(core.BOARD_W):
			var t = board.get_tile(x, y)
			if t:
				if t.has_method("set_highlight"):
					t.set_highlight(false)
				if t.has_node("MoveHighlight"):
					t.get_node("MoveHighlight").visible = false

# =====================================================
# 🎵 AUDIO
# =====================================================

func _play_card_sound(sound: AudioStream, position := Vector3.ZERO) -> void:
	if not sound or not core:
		return
	var p := core._get_audio_player()
	p.stream = sound
	p.global_position = position
	p.unit_size = 5.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.volume_db = -10.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
	p.connect("finished", Callable(core, "_return_audio_player").bind(p), CONNECT_ONE_SHOT)


## ⚔️ UPGRADE SPELL: Check if spell can upgrade monster, animate, and apply
func _try_upgrade_monster(spell_unit: UnitData, monster_unit: UnitData, spell_tile: Node3D, monster_tile: Node3D, spell_art: Texture2D = null) -> bool:
	if not spell_unit or not monster_unit:
		return false
	if not spell_unit.card or not monster_unit.card:
		return false

	# Check if spell is actually an upgrade spell
	if not spell_unit.card.is_upgrade_spell:
		return false

	# Check if monster is actually a monster
	if monster_unit.card.card_type != CardData.CardType.MONSTER:
		return false

	# Leaders cannot be upgraded or fused
	if monster_unit.is_leader:
		core._log("❌ Leaders cannot be upgraded!", Color(1.0, 0.5, 0.5))
		return false

	# Check element matching for valid upgrade
	var spell_element = spell_unit.card.element
	var monster_element = monster_unit.card.element
	var is_valid_upgrade = (spell_element == monster_element)

	if is_valid_upgrade:
		core._log("⚔️ %s upgrades %s!" % [spell_unit.card.name, monster_unit.card.name], Color(1.0, 0.9, 0.3))

		# 🎬 ANIMATION: Hide if enemy is upgrading a facedown card
		# (Don't reveal enemy facedown upgrades to player)
		var is_facedown = monster_unit.is_facedown or (monster_unit.has_meta("is_facedown") and monster_unit.get_meta("is_facedown"))
		var is_enemy_card = monster_unit.owner == core.ENEMY

		# Hide animation if: enemy card AND facedown
		var should_hide_animation = is_enemy_card and is_facedown

		if not should_hide_animation:
			# Use passed spell_art if available, otherwise try to get from spell_unit
			var art_to_use = spell_art if spell_art else (spell_unit.card.art if spell_unit.card else null)
			await _animate_spell_upgrade(spell_tile, monster_tile, art_to_use)
		else:
			# Silent upgrade for facedown or enemy cards
			await get_tree().create_timer(0.3).timeout

		# 📊 Apply stat upgrades based on card ability
		if spell_unit.card.ability:
			# The ability should handle stat boosts (like +6 ATK or +8 DEF)
			await core._execute_card_ability(monster_unit, spell_unit.card.ability)

		# 🗑️ Remove upgrade spell from board
		# Find the spell's position in the units dictionary
		var spell_pos := Vector2i(-1, -1)
		for pos in core.units:
			if core.units[pos] == spell_unit:
				spell_pos = pos
				break

		if spell_pos != Vector2i(-1, -1):
			core.units.erase(spell_pos)
		spell_tile.set_occupant(null)
		spell_tile.set_art(null)
		spell_tile.set_badge_text("")

		core._log("✨ %s absorbed the power of %s!" % [monster_unit.card.name, spell_unit.card.name], Color(0.9, 1.0, 0.8))
		return true
	else:
		# Invalid upgrade - just destroy the spell
		core._log("❌ %s cannot be used on %s (element mismatch)!" % [spell_unit.card.name, monster_unit.card.name], Color(1.0, 0.5, 0.5))

		# 🗑️ Remove upgrade spell from board
		# Find the spell's position in the units dictionary
		var spell_pos := Vector2i(-1, -1)
		for pos in core.units:
			if core.units[pos] == spell_unit:
				spell_pos = pos
				break

		if spell_pos != Vector2i(-1, -1):
			core.units.erase(spell_pos)
		spell_tile.set_occupant(null)
		spell_tile.set_art(null)
		spell_tile.set_badge_text("")

		return false


## 🎬 Animate spell card sliding onto monster with particle flash
func _animate_spell_upgrade(spell_tile: Node3D, monster_tile: Node3D, spell_art: Texture2D = null) -> void:
	if not spell_tile or not monster_tile:
		return

	# Create temporary visual effect overlay
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().root.add_child(canvas_layer)

	var container = Control.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(container)

	# Get spell card texture - use passed art parameter
	var spell_tex = TextureRect.new()
	spell_tex.texture = spell_art
	spell_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spell_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spell_tex.custom_minimum_size = Vector2(120, 168)
	spell_tex.pivot_offset = Vector2(60, 84)  # Set pivot to center for scaling
	container.add_child(spell_tex)

	# Position spell at its tile location
	var cam = get_viewport().get_camera_3d()
	if cam:
		var spell_screen_pos = cam.unproject_position(spell_tile.global_position)
		spell_tex.position = spell_screen_pos - Vector2(60, 84)

	# Get monster screen position
	var monster_screen_pos = Vector2.ZERO
	if cam:
		monster_screen_pos = cam.unproject_position(monster_tile.global_position)

	# 🎬 Animate spell sliding to monster position
	var slide_tween = create_tween()
	slide_tween.set_parallel(true)
	slide_tween.tween_property(spell_tex, "position", monster_screen_pos - Vector2(60, 84), 0.6).set_ease(Tween.EASE_IN_OUT)
	slide_tween.tween_property(spell_tex, "modulate:a", 0.0, 0.5).set_delay(0.3)
	slide_tween.tween_property(spell_tex, "scale", Vector2(0.5, 0.5), 0.6).set_ease(Tween.EASE_IN)

	# ✨ Create particle flash effect at monster position
	await get_tree().create_timer(0.5).timeout

	# Create glowing particles
	for i in range(15):
		var particle = ColorRect.new()
		particle.custom_minimum_size = Vector2(8, 8)
		particle.color = Color(1.0, 0.9, 0.3, 0.8)
		particle.position = monster_screen_pos
		container.add_child(particle)

		# Random burst direction
		var angle = randf() * TAU
		var distance = randf_range(30, 80)
		var target_pos = monster_screen_pos + Vector2(cos(angle), sin(angle)) * distance

		var particle_tween = create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "position", target_pos, 0.4)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.4)
		particle_tween.tween_property(particle, "custom_minimum_size", Vector2(2, 2), 0.4)

	# Wait for animations to complete
	await get_tree().create_timer(0.8).timeout

	# Clean up
	canvas_layer.queue_free()
