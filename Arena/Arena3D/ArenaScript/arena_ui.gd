# File: arena_ui.gd
extends Node
class_name ArenaUI

# Cached references
var core: ArenaCore
var board: Node3D
var camera: Camera3D
var is_dragging_card := false
var _hover_tween: Tween = null
var _current_hover_card: CardData = null
var _last_hand_snapshot: Array = []
var _selected_card_ui_map: Dictionary = {}

# 🎯 Performance: Preload CardUI scene once
const CARD_UI_SCENE := preload("res://UI/CardUI.tscn")

@onready var fusion_pending := $FusionPending
@onready var fusion_label := $FusionPending/CenterContainer/VBoxContainer/FusionLabel

# UI nodes
@onready var hand_grid: GridContainer = $BottomContainer/Hand
@onready var phase_label: Label = $PhaseLabel
@onready var player_hp_label: Label = $PlayerHP/TextureRect/HPLabel
@onready var enemy_hp_label: Label = $EnemyHP/TextureRect/HPLabel
@onready var fade_rect: ColorRect = $FadeRect
@onready var summon_mode_popup: PopupPanel = $SummonMode
@onready var battle_log: RichTextLabel = $VBoxContainer/BattleLogLabel

@onready var card_details_ui: ArenaCardDetails = $ArenaCardDetails
@onready var leader_details_ui: ArenaLeaderDetails = $ArenaLeaderDetails

@onready var orb_grid: Control = $BottomContainer/OrbGrid/OrbGrid
@onready var battle_sys: ArenaBattle = $"../BattleSystem"
@onready var hp_progress_bar: ProgressBar = $PlayerHP/TextureRect/HPProgressBar
@onready var enemy_hp_progress_bar: ProgressBar = $EnemyHP/TextureRect/HPProgressBar


var _lock_hp_updates := false
var hover_label: Label3D
var ghost_card: Sprite3D
var last_card_ui: Control = null
var _is_hovering_hand_card := false
var _hover_check_timer := 0.0
var hand_forced_hidden := false
var _hand_orb_tween: Tween = null
var _is_fusion_pending_active: bool = false

func _ready():
	$ArenaLeaderDetails.visible = false
	$ArenaCardDetails.visible = false
	$ArenaTerrainDetails.visible = false
	$BottomContainer/OrbGrid/OrbGrid.visible = false
	_setup_discard_pile_ui()  # 🪦 Initialize discard pile viewer 


func init_ui(core_ref: ArenaCore) -> void:
	core = core_ref
	board = core.board
	camera = core.camera
	hp_progress_bar.max_value = core.player_leader.hp  # 🟢 set max HP
	hp_progress_bar.value = core.player_leader.hp      # full at start
	hp_progress_bar.min_value = 0
	enemy_hp_progress_bar.max_value = core.enemy_leader.hp  # 🟢 set max HP
	enemy_hp_progress_bar.value = core.enemy_leader.hp      # full at start
	enemy_hp_progress_bar.min_value = 0
	

	# signals
	core.connect("log_line", Callable(self, "_on_log"))
	core.connect("essence_changed", Callable(self, "_on_essence_changed"))
	core.connect("hp_changed", Callable(self, "_on_hp_changed"))
	core.connect("phase_changed", Callable(self, "_on_phase_changed"))

	# 🟢 Add a periodic UI refresh for DEF/ATK changes
	core.connect("unit_stats_changed", Callable(self, "_on_unit_stats_changed"))

	# Hover label
	hover_label = Label3D.new()
	hover_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hover_label.no_depth_test = true
	hover_label.pixel_size = 0.0025
	hover_label.set("theme_override_font_sizes/font_size", 72)
	hover_label.visible = false
	core.add_child(hover_label)

	# Ghost card
	ghost_card = Sprite3D.new()
	ghost_card.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost_card.no_depth_test = true
	ghost_card.modulate = Color(1,1,1,0.8)
	ghost_card.pixel_size = 0.005
	ghost_card.scale = Vector3.ONE * 0.5
	ghost_card.visible = false
	core.add_child(ghost_card)

	_update_hp_labels()
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# 🟢 1. Cancel summon popup if open
		if summon_mode_popup and summon_mode_popup.visible:
			_cancel_summon_popup()
			get_viewport().set_input_as_handled()
			return

		# 🟢 2. Hide fusion pending overlay if active
		if core and core._is_fusion_pending_active:
			core._is_fusion_pending_active = false
			if fusion_pending and fusion_pending.visible:
				await hide_fusion_pending()
				core._log("❌ Fusion canceled.", Color(1, 0.6, 0.6))
			if core.fusion_selection and core.fusion_selection.size() > 0:
				core.fusion_selection.clear()
				refresh_hand(core.player_hand, core.player_essence, true)
			get_viewport().set_input_as_handled()
			return

		# 🟢 3. Clear move/summon highlights
		if core and core.move_sys and core.move_sys.has_method("clear_highlights"):
			core.move_sys.clear_highlights()

		# 🟢 4. Deselect all cards in hand
		for ui in hand_grid.get_children():
			if ui and _selected_card_ui_map.has(ui):
				_selected_card_ui_map.erase(ui)
				var t := create_tween()
				t.tween_property(ui, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				t.tween_property(ui, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				t.tween_property(ui, "modulate", Color(1, 1, 1, 1), 0.2)

		# 🟢 5. Clear fusion selections if any remain
		if core and core.fusion_selection and core.fusion_selection.size() > 0:
			core.fusion_selection.clear()
			core._log("🧬 Fusion selection canceled.", Color(0.8, 0.8, 1.0))
			refresh_hand(core.player_hand, core.player_essence, true)

		# 🟢 6. Reset phase & selection state
		if core:
			core.selected_pos = Vector2i(-1, -1)
			core.dragging_card = null
			core.selected_card = null
			core._set_phase(core.Phase.SUMMON_OR_MOVE)
			core._update_phase_ui()
			core._log("🔄 Action canceled — highlights and selections cleared.", Color(0.8, 0.8, 1.0))

		# 🟢 7. Hide hover & card details
		# ✅ CRITICAL: Clear hover flag to unblock board interaction
		_is_hovering_hand_card = false

		if has_method("hide_hover"):
			hide_hover()
		if card_details_ui:
			card_details_ui.hide_card()
			card_details_ui.visible = false

		get_viewport().set_input_as_handled()

func _cancel_summon_popup() -> void:
	summon_mode_popup.hide()

	if core:
		core._log("❌ Summon canceled.", Color(1, 0.6, 0.6))
		core.dragging_card = null
		core.selected_card = null
		core.selected_pos = Vector2i(-1, -1)
		core._set_phase(core.Phase.SUMMON_OR_MOVE)
		core._update_phase_ui()

	cancel_drag()
	show_battle_message("Summon canceled", 1.0)

func refresh_hand(player_hand: Array, player_essence: int, force_update := false, skip_fade := false) -> void:
	# --- 🧩 Avoid redundant rebuilds unless forced
	var skip_rebuild := false
	if not force_update:
		if _last_hand_snapshot.size() == player_hand.size():
			var identical := true
			for i in range(player_hand.size()):
				if _last_hand_snapshot[i].id != player_hand[i].id:
					identical = false
					break
			if identical:
				skip_rebuild = true

	_last_hand_snapshot = player_hand.duplicate()  # Save new snapshot

	# --- ✅ Always update playability, even if skipping rebuild
	if skip_rebuild:
		for card_ui in hand_grid.get_children():
			if card_ui.has_method("get_card_data") and card_ui.has_method("set_playable"):
				var c = card_ui.card_data
				if c:
					var cost := 1
					if c.has_meta("cost"): cost = int(c.get_meta("cost"))
					elif c.has_method("get_cost"): cost = c.get_cost()
					elif "cost" in c: cost = int(c.cost)
					card_ui.set_playable(cost <= player_essence)
		return  # 🧠 No need to rebuild cards

	# --- Otherwise, rebuild as usual
	for child in hand_grid.get_children():
		child.queue_free()
	last_card_ui = null

	for c: CardData in player_hand:
		var ui = CARD_UI_SCENE.instantiate()
		ui.card_data = c
		ui.refresh()
		ui.set_meta("base_y", ui.position.y)  # remember its original Y

		var cost := 1
		if c.has_meta("cost"): cost = int(c.get_meta("cost"))
		elif c.has_method("get_cost"): cost = c.get_cost()
		elif "cost" in c: cost = int(c.cost)

		var is_selected := core.fusion_selection.has(c)
		var is_affordable := cost <= player_essence

		# Position selected cards higher
		ui.position.y = -25.0 if is_selected else 0.0

		# Set playability
		ui.set_playable(is_affordable)

		# 🩵 Set colors: selected cards are always green, unselected cards are white or dimmed
		if is_selected:
			# Selected cards are always highlighted green, regardless of affordability
			ui.modulate = Color(0.8, 1.0, 0.8, 1)
			ui._base_modulate = Color(0.8, 1.0, 0.8, 1)
		elif is_affordable:
			# Affordable unselected cards are white
			ui.modulate = Color(1, 1, 1, 1)
			ui._base_modulate = Color(1, 1, 1, 1)
		else:
			# Unaffordable unselected cards are dimmed
			ui.modulate = Color(0.4, 0.4, 0.4, 0.5)
			ui._base_modulate = Color(0.4, 0.4, 0.4, 0.5)

		# Hover + click
		if not ui.is_connected("request_show_zoom", Callable(self, "_on_card_hovered_in_hand")):
			ui.request_show_zoom.connect(Callable(self, "_on_card_hovered_in_hand"))
			ui.mouse_entered.connect(func(): _animate_card_hover_enter(ui))
		if not ui.is_connected("request_hide_zoom", Callable(self, "_on_card_hovered_in_hand_exit")):
			ui.request_hide_zoom.connect(Callable(self, "_on_card_hovered_in_hand_exit"))
			ui.mouse_exited.connect(func(): _animate_card_hover_exit(ui))

		ui.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if cost > player_essence:
					_on_log("❌ Not enough Essence for %s (Cost %d, you have %d)" % [c.name, cost, player_essence], Color.WHITE)
					return
				core.on_hand_card_clicked(c)
				await get_tree().process_frame
				if is_instance_valid(ui):
					_animate_card_selection(ui, core.fusion_selection.has(c))
		)

		# ✅ Only auto-fade if not skipping (for initial draw animation)
		if not skip_fade:
			ui.modulate.a = 0.0
			var t := create_tween()
			t.tween_property(ui, "modulate:a", 1.0, 0.25)
		else:
			ui.modulate.a = 0.0  # Start invisible, _animate_card_draw will handle fade
			ui.visible = false  # Keep completely hidden until animation starts
			ui.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Disable clicks until animation done
		hand_grid.add_child(ui)

		# 🧬 Check for valid fusion partners and show pulsing icon
		var has_fusion_partner := false
		for other_card in player_hand:
			if other_card != c:
				var fusion_result = core._check_fusion_pair(c, other_card)
				if fusion_result != null:
					has_fusion_partner = true
					break

		# Show/hide fusion icon with pulse animation
		if ui.has_method("start_fusion_icon_pulse") and ui.has_method("stop_fusion_icon_pulse"):
			if has_fusion_partner:
				ui.start_fusion_icon_pulse()
			else:
				ui.stop_fusion_icon_pulse()

		last_card_ui = ui

	if orb_grid:
		orb_grid.visible = player_hand.size() > 0

func get_last_hand_card_ui() -> Control:
	return last_card_ui

# Smoothly animate card selection raise/lower + keep hover-like pose
func _animate_card_selection(ui: Control, is_selected: bool) -> void:
	if not ui:
		return

	# 🧩 Prevent pulse conflict if selected
	if is_selected:
		_selected_card_ui_map[ui] = true
		# Kill any running hover pulse
		if _hover_card_tween_map.has(ui):
			var old_tween = _hover_card_tween_map[ui]
			if old_tween and old_tween.is_running():
				old_tween.kill()
			_hover_card_tween_map.erase(ui)
	else:
		_selected_card_ui_map.erase(ui)

	var t := create_tween()
	if is_selected:
		t.tween_property(ui, "position:y", -25.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(ui, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(ui, "modulate", Color(1.0, 1.0, 0.8, 1.0), 0.2)
	else:
		t.tween_property(ui, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(ui, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(ui, "modulate", Color(1, 1, 1, 1), 0.2)
# ==========================================================
# 🎴 HAND CARD HOVER ANIMATION — Safe (No Drift, No Conflict)
# ==========================================================
var _hover_card_tween_map: Dictionary = {}

func _animate_card_hover_enter(card_ui: Control) -> void:
	if not is_instance_valid(card_ui):
		return
	# 🛑 Skip hover animation if this card is selected
	if _selected_card_ui_map.has(card_ui):
		return

	# Kill any old tween
	if _hover_card_tween_map.has(card_ui):
		var old_tween = _hover_card_tween_map[card_ui]
		if old_tween and old_tween.is_running():
			old_tween.kill()

	# Create new tween
	var t := create_tween()
	t.tween_property(card_ui, "position:y", -20.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(card_ui, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Continuous pulse effect while hovered
	var pulse_tween := create_tween()
	pulse_tween.set_loops(0)
	pulse_tween.tween_property(card_ui, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(card_ui, "scale", Vector2(1.08, 1.08), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_hover_card_tween_map[card_ui] = pulse_tween


func _animate_card_hover_exit(card_ui: Control) -> void:
	if not is_instance_valid(card_ui):
		return
	# 🛑 Do nothing if card is selected — keep it raised
	if _selected_card_ui_map.has(card_ui):
		return

	# Kill running pulse
	if _hover_card_tween_map.has(card_ui):
		var old_tween = _hover_card_tween_map[card_ui]
		if old_tween and old_tween.is_running():
			old_tween.kill()
		_hover_card_tween_map.erase(card_ui)

	# Smoothly return to original position & scale
	var t := create_tween()
	t.tween_property(card_ui, "position:y", 0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(card_ui, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func show_popup(card: CardData, callback = null) -> void:

	if not summon_mode_popup:
		push_warning("❌ No SummonMode node found!")
		return

	summon_mode_popup.visible = true
	summon_mode_popup.popup_centered()
	show_battle_message("Summon %s — choose mode." % card.name, 1.2)
	print("✅ SummonMode popup displayed — waiting for player input.")
	
func is_popup_open() -> bool:
	return summon_mode_popup != null and summon_mode_popup.visible

func hide_popup() -> void:
	if summon_mode_popup:
		summon_mode_popup.visible = false
		
func _on_popup_button_pressed(callback: Callable, mode: int, popup: PopupPanel) -> void:
	print("🟢 Popup button pressed — mode =", mode)
	if popup:
		popup.hide()
	if callback and callback.is_valid():
		callback.call(mode)
	else:
		push_warning("⚠️ Invalid or missing summon callback!")


func force_hide_hand(on: bool) -> void:
	hand_forced_hidden = on

	# kill any in-flight show/hide tween to prevent a late 'visible = true'
	if _hand_orb_tween and _hand_orb_tween.is_running():
		_hand_orb_tween.kill()
		_hand_orb_tween = null

	# apply immediately
	if hand_grid:
		hand_grid.modulate.a = 0.0
		hand_grid.visible = not on and hand_grid.visible and hand_grid.visible # no-op unless allowed
		if on:
			hand_grid.visible = false

	if orb_grid:
		orb_grid.modulate.a = 0.0
		if on:
			orb_grid.visible = false

func _animate_card_draw(card_ui: Control) -> void:
	if not card_ui: return

	# Keep the real card completely hidden until animation finishes
	card_ui.modulate.a = 0.0
	card_ui.visible = false
	card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Disable clicks during animation

	# Wait for layout to update so we get the correct final position
	await get_tree().process_frame

	# Create a duplicate for animation
	var anim_card: Control = card_ui.duplicate(0)  # Shallow copy
	anim_card.top_level = true
	add_child(anim_card)

	# Store final global position (where card should end up)
	var final_global_pos := card_ui.global_position

	# Start from off-screen (bottom-center of viewport)
	var viewport_size := get_viewport().get_visible_rect().size
	anim_card.global_position = Vector2(viewport_size.x * 0.5 - anim_card.size.x * 0.5, viewport_size.y + 100)
	anim_card.rotation = deg_to_rad(randf_range(-15, 15))
	anim_card.scale = Vector2(0.7, 0.7)
	anim_card.modulate.a = 1.0
	anim_card.visible = true

	# Animate flying into hand with smooth curve
	var t = create_tween()
	t.set_parallel(true)
	t.set_trans(Tween.TRANS_CUBIC)
	t.set_ease(Tween.EASE_OUT)

	t.tween_property(anim_card, "global_position", final_global_pos, 0.4)
	t.tween_property(anim_card, "rotation", 0.0, 0.4)
	t.tween_property(anim_card, "scale", Vector2(1.0, 1.0), 0.3)

	await t.finished

	# Remove animated duplicate and show real card
	anim_card.queue_free()
	if card_ui:
		card_ui.visible = true
		card_ui.modulate.a = 1.0
		card_ui.mouse_filter = Control.MOUSE_FILTER_STOP  # Re-enable clicks after animation

func update_phase_label(phase: int) -> void:
	match phase:
		core.Phase.SUMMON_OR_MOVE:
			phase_label.text = "Your Turn: Summon or Move"
			$"../UISystem/EndTurnButton".disabled = false
		core.Phase.SELECT_SUMMON_TILE:
			phase_label.text = "Choose a tile to Summon"
			$"../UISystem/EndTurnButton".disabled = true
		core.Phase.SELECT_MOVE_TARGET:
			phase_label.text = "Choose a tile to Move"
			$"../UISystem/EndTurnButton".disabled = true
		core.Phase.ENEMY_TURN:
			phase_label.text = "Enemy Turn"
			$"../UISystem/EndTurnButton".disabled = true

func open_summon_popup() -> void:
	summon_mode_popup.popup_centered()

# Ghost/drag UI
func on_drag_start(card: CardData) -> void:
	is_dragging_card = true  # 🟢 mark drag active
	
	$ArenaTerrainDetails.visible = false
	if ghost_card:
		ghost_card.visible = false
	if hand_grid:
		hand_grid.visible = false
	if orb_grid:
		orb_grid.visible = false

	if card_details_ui:
		card_details_ui.show_card(card)
		card_details_ui.visible = true


func cancel_drag() -> void:
	is_dragging_card = false  # 🔴 allow hover updates again
	$ArenaTerrainDetails.visible = true

	# 💡 Clear card details immediately and reset state
	if card_details_ui:
		card_details_ui.hide_card()
		card_details_ui.visible = false
		card_details_ui.current_unit = null  # 🧹 fully reset the last card reference

	# Make sure hover panels also clear
	hide_hover()

	fade_hand_in()
	set_process(false)


func fade_hand_in() -> void:
	if hand_forced_hidden:
		return
	hand_grid.visible = true
	hand_grid.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hand_grid, "modulate:a", 1.0, 0.25)

func fade_hand_out() -> void:
	if hand_forced_hidden:
		return
	hand_grid.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hand_grid, "modulate:a", 1.0, 0.25)

func return_card_to_hand(card_data: CardData):
	if not card_data:
		return
	if not hand_grid:
		return

	# Make sure hand is visible before adding card
	fade_hand_in()


func move_ghost_over(tile: Node3D) -> void:
	if ghost_card.visible:
		ghost_card.position = (tile.position + Vector3(0,0.03,0)) if tile else ghost_card.position


# ----------------------------------------
# HAND HOVER (smart update, no flicker)
# ----------------------------------------
var _hide_timer_task: SceneTreeTimer = null
# ----------------------------------------
# HAND HOVER (Pro system)
# ----------------------------------------
var _hide_task: SceneTreeTimer
var _hover_state := "idle"  # "idle", "showing", "visible", "hiding"

func _on_card_hovered_in_hand(card: CardData) -> void:
	if not card:
		return

	# 🧩 Prevent multiple refreshes on same card
	if _current_hover_card == card:
		return
	_current_hover_card = card
	_is_hovering_hand_card = true

	# 🩵 Update playability tint dynamically
	for card_ui in hand_grid.get_children():
		if card_ui.card_data == card and card_ui.has_method("set_playable"):
			var cost := 1
			if card.has_meta("cost"):
				cost = int(card.get_meta("cost"))
			elif card.has_method("get_cost"):
				cost = card.get_cost()
			elif "cost" in card:
				cost = int(card.cost)
			# Check against available essence (accounting for selected cards)
			var available_essence := core._get_available_essence() if core.has_method("_get_available_essence") else core.player_essence
			card_ui.set_playable(cost <= available_essence)
			break

	# 🟢 Show the card details
	if card_details_ui:
		card_details_ui.show_card(card)
		card_details_ui.visible = true

func _on_card_hovered_in_hand_exit() -> void:
	if core and core.fusion_selection.size() > 0:
		print("[ArenaUI] 🧬 Fusion selection active — hover exit ignored.")
		return

	if not _is_hovering_hand_card:
		return

	_is_hovering_hand_card = false

	if card_details_ui:
		card_details_ui.hide_card()
		card_details_ui.visible = false

	_current_hover_card = null
	_hover_state = "idle"

func show_hover_for_tile(tile: Node3D) -> void:
	# 🛑 Prevent hover if dragging or hovering hand card
	if _is_hovering_hand_card or is_dragging_card:
		return
	if not tile or (core and core.is_cutscene_active):
		return

	# --- TILE WITH UNIT ---
	if tile.occupant:
		var unit = tile.occupant
		var is_enemy = unit.owner != core.PLAYER
		var is_facedown = unit.has_meta("is_facedown") and unit.get_meta("is_facedown")

		# Hide terrain panel when hovering units
		if has_node("ArenaTerrainDetails"):
			if $ArenaTerrainDetails.has_method("hide_terrain"):
				$ArenaTerrainDetails.hide_terrain()
			else:
				$ArenaTerrainDetails.visible = false

		# 🟢 CASE 1: Enemy facedown card — show terrain only
		if is_enemy and is_facedown:
			if has_node("ArenaCardDetails"):
				$ArenaCardDetails.hide_card()
			if has_node("ArenaLeaderDetails"):
				$ArenaLeaderDetails.hide_card()
			if has_node("ArenaTerrainDetails"):
				$ArenaTerrainDetails.show_terrain(tile.terrain_type)
				$ArenaTerrainDetails.visible = true
			return

		# 🟢 CASE 2: Leader units — show ArenaLeaderDetails
		if unit.is_leader:
			if has_node("ArenaLeaderDetails"):
				$ArenaLeaderDetails.show_unit(unit)
				$ArenaLeaderDetails.visible = true
			if has_node("ArenaCardDetails"):
				$ArenaCardDetails.hide_card()
			return


		# 🟢 CASE 3: Normal units — show ArenaCardDetails
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.show_unit(unit)
			$ArenaCardDetails.visible = true
		if has_node("ArenaLeaderDetails"):
			$ArenaLeaderDetails.hide_card()
	else:
		# --- EMPTY TILE: show terrain details only ---
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.hide_card()
		if has_node("ArenaLeaderDetails"):
			$ArenaLeaderDetails.hide_card()
		if has_node("ArenaTerrainDetails"):
			$ArenaTerrainDetails.show_terrain(tile.terrain_type)
			$ArenaTerrainDetails.visible = true

func hide_hover() -> void:
	if _is_hovering_hand_card or is_dragging_card:
		return
	if core and core.is_cutscene_active:
		return

	# Hide all hover UIs
	if has_node("ArenaCardDetails"):
		$ArenaCardDetails.hide_card()
	if has_node("ArenaLeaderDetails"):
		$ArenaLeaderDetails.hide_card()
	if has_node("ArenaTerrainDetails"):
		if $ArenaTerrainDetails.has_method("hide_terrain"):
			$ArenaTerrainDetails.hide_terrain()
		else:
			$ArenaTerrainDetails.visible = false

	if hover_label:
		hover_label.visible = false
		hover_label.modulate.a = 1.0

# Labels / log
func _on_essence_changed(p: int, e: int) -> void:
	# Limit orb display to 8
	var display_count = min(p, 8)

	if orb_grid and orb_grid.has_method("set_essence"):
		orb_grid.set_essence(display_count)

	# Optional visual feedback if capped
	if p > 8:
		core._log("⚠️ Essence capped at 8 (current: %d)" % p, Color(0.8, 0.8, 1.0))
		
	# Re-evaluate card playability tint each time essence changes
	for card_ui in hand_grid.get_children():
		if card_ui.has_method("get_card_data") and card_ui.has_method("set_playable"):
			var c = card_ui.card_data
			if c:
				var cost := 1
				if c.has_meta("cost"): cost = int(c.get_meta("cost"))
				elif "cost" in c: cost = int(c.cost)
				card_ui.set_playable(cost <= p) # p = player essence



func _on_hp_changed(owner: int, hp: int) -> void:
	# 🛑 Skip HP updates during active battle animations
	if _lock_hp_updates:
		return

	if owner == core.PLAYER:
		player_hp_label.text = str(hp)
		_flash(player_hp_label)
	else:
		enemy_hp_label.text = str(hp)
		_flash(enemy_hp_label)

	_update_hp_bar()


func _flash(lbl: Label) -> void:
	var t = create_tween()
	t.tween_property(lbl, "modulate", Color(1,0.5,0.5), 0.1)
	t.tween_property(lbl, "modulate", Color(1,1,1), 0.3)

func _on_phase_changed(new_phase: int) -> void:
	update_phase_label(new_phase)

	match new_phase:
		core.Phase.SUMMON_OR_MOVE, core.Phase.SELECT_SUMMON_TILE, core.Phase.SELECT_MOVE_TARGET:
			# Player turn phases — show hand and orbs
			_show_hand_and_orbs(true)
		core.Phase.ENEMY_TURN:
			# Hide UI when enemy is acting
			_show_hand_and_orbs(false)

func _show_hand_and_orbs(visible: bool) -> void:
	# Don’t touch hand during drag, battle, or forced hide
	if (core and core.battle_sys and core.battle_sys._is_battle_in_progress) \
	or hand_forced_hidden \
	or is_dragging_card \
	or core.dragging_card != null:
		return

	# cancel previous tween so it can't finish later and flip visibility
	if _hand_orb_tween and _hand_orb_tween.is_running():
		_hand_orb_tween.kill()
		_hand_orb_tween = null

	var target_alpha := 1.0 if visible else 0.0
	_hand_orb_tween = create_tween()
	if hand_grid:
		_hand_orb_tween.tween_property(hand_grid, "modulate:a", target_alpha, 0.25)
	if orb_grid:
		_hand_orb_tween.tween_property(orb_grid, "modulate:a", target_alpha, 0.25)
	await _hand_orb_tween.finished
	hand_grid.visible = visible
	orb_grid.visible = visible

func play_attack_step(attacker: UnitData, defender: UnitData, damage: int) -> void:
	# 🔹 Optional: name labels
	if has_node("AttackerLabel"):
		$AttackerLabel.text = "%s attacks!" % attacker.card.name
	if has_node("DefenderLabel"):
		$DefenderLabel.text = "vs %s" % defender.card.name

	# 🔹 Optional: damage label
	if has_node("DamageLabel"):
		$DamageLabel.text = "-%d DEF" % damage
		$DamageLabel.modulate = Color(1, 0.3, 0.3)
		$DamageLabel.visible = true

	# 🔹 Safely locate the defender's tile through the battle system
	if defender:
		var tile = core.battle_sys._get_unit_tile(defender)
		if tile and tile.has_node("CardMesh"):
			var mesh = tile.get_node("CardMesh")
			if mesh:
				var tw = create_tween()
				tw.tween_property(mesh, "scale", mesh.scale * 1.2, 0.1)
				tw.tween_property(mesh, "scale", mesh.scale, 0.2)
				await tw.finished

	# 🔹 Add a brief pause for pacing
	await get_tree().create_timer(0.4).timeout

	# 🔹 Hide temporary UI after animation
	if has_node("DamageLabel"):
		$DamageLabel.visible = false

func _on_log(msg: String, color := Color.WHITE) -> void:
	if not battle_log: return
	battle_log.append_text("[color=%s]%s[/color]\n" % [color.to_html(false), msg])
	battle_log.scroll_to_line(battle_log.get_line_count() - 1)
# 🟢 Called whenever a unit's ATK/DEF changes (e.g., Vampirism heal)

func _on_unit_stats_changed(unit: UnitData) -> void:
	if not unit:
		return
	if card_details_ui and card_details_ui.visible:
		card_details_ui.call("refresh_if_showing", unit)

func show_battle_message(text: String, duration := 2.0) -> void:
	var label: Label = $"../UISystem/BattlePopup"
	if not label:
		return
	label.text = text
	label.show()

	# ✅ Correct node lookup
	var outline_color := Color(0.2, 0.4, 1.0) # default blue

	if core.phase == core.Phase.ENEMY_TURN:
		outline_color = Color(1.0, 0.2, 0.2) # red for enemy
	else:
		outline_color = Color(0.2, 0.4, 1.0)
	_set_label_outline(label, outline_color)

	label.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(duration).timeout
	var t2 = create_tween()
	t2.tween_property(label, "modulate:a", 0.0, 0.5)


# 🏆 Show prominent Victory message
func show_victory_message() -> void:
	# Create victory label dynamically
	var victory_label := Label.new()
	victory_label.text = "🏆 VICTORY! 🏆"
	victory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Style the label prominently
	victory_label.add_theme_font_size_override("font_size", 96)
	victory_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	victory_label.add_theme_color_override("font_outline_color", Color(0.8, 0.4, 0.0, 1))
	victory_label.add_theme_constant_override("outline_size", 12)

	# Position it prominently in the center
	victory_label.anchor_left = 0.0
	victory_label.anchor_top = 0.0
	victory_label.anchor_right = 1.0
	victory_label.anchor_bottom = 1.0
	victory_label.modulate.a = 0.0
	victory_label.scale = Vector2(0.5, 0.5)

	add_child(victory_label)

	# Animate the victory label
	var tw = create_tween()
	tw.tween_property(victory_label, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(victory_label, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.5)  # Stay visible
	tw.tween_property(victory_label, "modulate:a", 0.0, 0.5)
	await tw.finished

	victory_label.queue_free()

func _set_label_outline(label: Label, color: Color) -> void:
	if not label:
		return
	if not label.label_settings:
		label.label_settings = LabelSettings.new()

	# Force-update every time (even if reused)
	var settings := label.label_settings
	settings.outline_size = 5
	settings.outline_color = color
	label.label_settings = settings

func _update_hp_bar() -> void:
	var t = create_tween()
	t.tween_property(hp_progress_bar, "value", core.player_leader.hp, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(enemy_hp_progress_bar, "value", core.enemy_leader.hp, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_hp_labels() -> void:
	player_hp_label.text = str(core.player_leader.hp)
	enemy_hp_label.text = str(core.enemy_leader.hp)


# ============================================
# 🧩 SummonMode Button Callbacks
# ============================================

func on_attack_mode_pressed() -> void:
	_handle_summon_choice(UnitData.Mode.ATTACK)

func on_defense_mode_pressed() -> void:
	_handle_summon_choice(UnitData.Mode.DEFENSE)

func on_face_down_pressed() -> void:
	_handle_summon_choice(UnitData.Mode.FACEDOWN)

func _handle_summon_choice(mode: int) -> void:
	if summon_mode_popup:
		summon_mode_popup.hide()

	if not core:
		push_warning("❌ Core missing — cannot complete summon.")
		return

	# 🔍 Detect current summon context
	if core.fusion_selection.size() == 2:
		#core._log("🧬 Fusion confirmed via popup button.")
		core.confirm_summon_in_mode(mode)  # ✅ directly place the fused card
	elif core.fusion_selection.size() == 1:
		#core._log("🎴 Normal summon confirmed via popup button.")
		core.confirm_summon_in_mode(mode)


# ==========================================================
# 🧬 FUSION PENDING DISPLAY — FULLY TWEAKABLE
# ==========================================================
@export var fusion_fade_in_duration: float = 0.1
@export var fusion_rotate_amplitude: float = 6.0
@export var fusion_rotate_speed: float = 3.2
@export var fusion_glow_pulse: bool = true
@export var fusion_glow_min: float = 0.4
@export var fusion_glow_max: float = 0.85
@export var fusion_glow_speed: float = 1.8
@export var fusion_glow_color: Color = Color(1.0, 0.7, 0.3, 0.7)  # warm orange glow
@export var fusion_label_color_ready: Color = Color(0.6, 1.0, 0.8)
@export var fusion_label_color_result: Color = Color(1.0, 0.9, 0.6)
@export var fusion_enable_rotation: bool = true
var fusion_tweens: Array[Tween] = []


func show_fusion_pending(cards: Array, result_card: CardData = null) -> void:
	if cards.size() < 2:
		return
	if not fusion_pending:
		return
	core._is_fusion_pending_active = true

	var a: CardData = cards[0]
	var b: CardData = cards[1]

	# 🧩 Clear old card UIs and particles
	var card_container = fusion_pending.get_node("CenterContainer/VBoxContainer/CardContainer")
	var particles_container = fusion_pending.get_node("ParticlesContainer")
	var title_label = fusion_pending.get_node("CenterContainer/VBoxContainer/TitleLabel")

	for child in card_container.get_children():
		child.queue_free()
	for child in particles_container.get_children():
		child.queue_free()

	var card_ui_scene := preload("res://UI/CardUI.tscn")

	# 🎴 Create both card UIs with proper parenting
	var card_ui_a: Control = card_ui_scene.instantiate()
	card_ui_a.name = "FusionCardUI_A"
	card_ui_a.card_data = a
	card_ui_a.refresh()
	card_ui_a.custom_minimum_size = Vector2(150, 210)
	card_ui_a.scale = Vector2(1.0, 1.0)
	card_ui_a.modulate.a = 0.0

	var card_ui_b: Control = card_ui_scene.instantiate()
	card_ui_b.name = "FusionCardUI_B"
	card_ui_b.card_data = b
	card_ui_b.refresh()
	card_ui_b.custom_minimum_size = Vector2(150, 210)
	card_ui_b.scale = Vector2(1.0, 1.0)
	card_ui_b.modulate.a = 0.0

	card_container.add_child(card_ui_a)
	card_container.add_child(card_ui_b)

	# 🌟 Create glow backgrounds for cards
	for card_ui in [card_ui_a, card_ui_b]:
		var glow_bg = ColorRect.new()
		glow_bg.name = "GlowBG"
		glow_bg.color = Color(1.0, 0.8, 0.3, 0.0)
		glow_bg.z_index = -1
		glow_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_ui.add_child(glow_bg)
		glow_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow_bg.offset_left = -10
		glow_bg.offset_top = -10
		glow_bg.offset_right = 10
		glow_bg.offset_bottom = 10

	# ⚡ Create energy beam between cards
	var energy_beam = Line2D.new()
	energy_beam.name = "EnergyBeam"
	energy_beam.width = 0.0
	energy_beam.default_color = Color(1.0, 0.9, 0.3, 0.0)
	energy_beam.add_point(Vector2.ZERO)
	energy_beam.add_point(Vector2.ZERO)
	energy_beam.z_index = 99
	particles_container.add_child(energy_beam)

	# ✨ Create particle effects
	for i in range(20):
		var particle = ColorRect.new()
		particle.name = "Particle_%d" % i
		particle.custom_minimum_size = Vector2(4, 4)
		particle.color = Color(1.0, 0.9 + randf() * 0.1, 0.3 + randf() * 0.4, 0.0)
		particle.modulate.a = 0.0
		particles_container.add_child(particle)

	# 🧬 Update label text
	fusion_label.text = "⚡ %s ⚡" % result_card.name if result_card != null else "Ready to Fuse!"
	fusion_label.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.5))
	fusion_label.add_theme_constant_override("outline_size", 8)

	# Style title label
	title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	title_label.add_theme_color_override("font_outline_color", Color(0.6, 0.3, 0.0))
	title_label.add_theme_constant_override("outline_size", 6)

	# 🎬 ANIMATION SEQUENCE
	fusion_pending.visible = true
	fusion_pending.modulate.a = 0.0

	# Fade in background
	var fade_bg := create_tween()
	fade_bg.tween_property(fusion_pending, "modulate:a", 1.0, 0.3)

	# Animate title with scale punch
	title_label.scale = Vector2(0.5, 0.5)
	title_label.modulate.a = 0.0
	var title_tween := create_tween()
	title_tween.tween_property(title_label, "modulate:a", 1.0, 0.2).set_delay(0.1)
	title_tween.parallel().tween_property(title_label, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title_tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)

	# Staggered card entrance with bounce
	await get_tree().create_timer(0.2).timeout

	var card_a_tween := create_tween()
	card_a_tween.set_parallel(true)
	card_a_tween.tween_property(card_ui_a, "modulate:a", 1.0, 0.3)
	card_a_tween.tween_property(card_ui_a, "scale", Vector2(1.0, 1.0), 0.3).from(Vector2(0.3, 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card_a_tween.tween_property(card_ui_a, "rotation_degrees", 0.0, 0.3).from(-20.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.1).timeout

	var card_b_tween := create_tween()
	card_b_tween.set_parallel(true)
	card_b_tween.tween_property(card_ui_b, "modulate:a", 1.0, 0.3)
	card_b_tween.tween_property(card_ui_b, "scale", Vector2(1.0, 1.0), 0.3).from(Vector2(0.3, 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	card_b_tween.tween_property(card_ui_b, "rotation_degrees", 0.0, 0.3).from(20.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await card_b_tween.finished

	# 🌊 Continuous pulsing glow animation
	_start_fusion_pulse_animation(card_ui_a, card_ui_b)

	# ⚡ Animate energy beam
	_animate_fusion_energy_beam(energy_beam, card_ui_a, card_ui_b, particles_container)

	# ✨ Animate particles
	_animate_fusion_particles(particles_container, card_ui_a, card_ui_b)

# 🌊 Continuous pulsing glow and scale animation for cards
func _start_fusion_pulse_animation(card_a: Control, card_b: Control) -> void:
	if not is_instance_valid(card_a) or not is_instance_valid(card_b):
		return

	# Pulse scale
	var pulse_a := create_tween()
	pulse_a.set_loops(0)
	pulse_a.tween_property(card_a, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_a.tween_property(card_a, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var pulse_b := create_tween()
	pulse_b.set_loops(0)
	pulse_b.tween_property(card_b, "scale", Vector2(1.05, 1.05), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_b.tween_property(card_b, "scale", Vector2(1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Pulse glow backgrounds
	if card_a.has_node("GlowBG"):
		var glow_a = card_a.get_node("GlowBG")
		var glow_tween_a := create_tween()
		glow_tween_a.set_loops(0)
		glow_tween_a.tween_property(glow_a, "color:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow_tween_a.tween_property(glow_a, "color:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if card_b.has_node("GlowBG"):
		var glow_b = card_b.get_node("GlowBG")
		var glow_tween_b := create_tween()
		glow_tween_b.set_loops(0)
		glow_tween_b.tween_property(glow_b, "color:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow_tween_b.tween_property(glow_b, "color:a", 0.3, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	fusion_tweens.append(pulse_a)
	fusion_tweens.append(pulse_b)

# ⚡ Energy beam animation between cards
func _animate_fusion_energy_beam(beam: Line2D, card_a: Control, card_b: Control, container: Control) -> void:
	if not is_instance_valid(beam) or not is_instance_valid(card_a) or not is_instance_valid(card_b):
		return

	# Fade in beam width
	var width_tween := create_tween()
	width_tween.tween_property(beam, "width", 8.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	width_tween.tween_property(beam, "default_color:a", 0.8, 0.4)

	# Create continuous update for beam position
	var update_timer := Timer.new()
	update_timer.name = "BeamUpdateTimer"
	update_timer.wait_time = 0.016  # ~60 FPS
	update_timer.autostart = true
	container.add_child(update_timer)

	update_timer.timeout.connect(func():
		if not is_instance_valid(beam) or not is_instance_valid(card_a) or not is_instance_valid(card_b):
			if is_instance_valid(update_timer):
				update_timer.queue_free()
			return

		# Convert global positions to container's local space
		var pos_a_global = card_a.global_position + card_a.size * 0.5
		var pos_b_global = card_b.global_position + card_b.size * 0.5

		var pos_a_local = container.get_global_transform().affine_inverse() * pos_a_global
		var pos_b_local = container.get_global_transform().affine_inverse() * pos_b_global

		beam.set_point_position(0, pos_a_local)
		beam.set_point_position(1, pos_b_local)

		# Pulse beam color
		var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		beam.default_color.a = 0.4 + pulse * 0.4
	)

	fusion_tweens.append(width_tween)

# ✨ Particle animation around cards
func _animate_fusion_particles(container: Control, card_a: Control, card_b: Control) -> void:
	if not is_instance_valid(container):
		return

	var viewport_size = get_viewport().get_visible_rect().size
	var center = viewport_size * 0.5

	for child in container.get_children():
		# Check if child is valid before accessing properties
		if not is_instance_valid(child):
			continue
		if not child.name.begins_with("Particle_"):
			continue

		var particle = child as ColorRect
		if not particle:
			continue

			# Random starting angle and radius
			var angle = randf() * TAU
			var radius = 100.0 + randf() * 200.0
			var orbit_speed = 1.0 + randf() * 2.0
			var start_delay = randf() * 0.5

			# Fade in
			await get_tree().create_timer(start_delay).timeout
			if not is_instance_valid(particle):
				continue

			var fade_tween := create_tween()
			fade_tween.tween_property(particle, "modulate:a", 1.0, 0.3)

			# Create orbit animation
			var update_timer := Timer.new()
			update_timer.wait_time = 0.016
			update_timer.autostart = true
			particle.add_child(update_timer)

			var elapsed = 0.0
			update_timer.timeout.connect(func():
				if not is_instance_valid(particle):
					if is_instance_valid(update_timer):
						update_timer.queue_free()
					return

				elapsed += 0.016
				var current_angle = angle + elapsed * orbit_speed
				var current_radius = radius + sin(elapsed * 3.0) * 30.0

				var pos = center + Vector2(cos(current_angle), sin(current_angle)) * current_radius
				particle.global_position = pos

				# Pulse size
				var scale_pulse = 1.0 + sin(elapsed * 4.0) * 0.3
				particle.scale = Vector2(scale_pulse, scale_pulse)
			)

func hide_fusion_pending() -> void:
	if not fusion_pending:
		return
	core._is_fusion_pending_active = false

	# Kill all running fusion tweens
	for tween in fusion_tweens:
		if is_instance_valid(tween) and tween.is_running():
			tween.kill()
	fusion_tweens.clear()

	# Stop all timers in particles container
	if fusion_pending.has_node("ParticlesContainer"):
		var particles_container = fusion_pending.get_node("ParticlesContainer")
		for child in particles_container.get_children():
			for timer in child.get_children():
				if timer is Timer:
					timer.stop()
					timer.queue_free()

	# Fade out
	var t := create_tween()
	t.tween_property(fusion_pending, "modulate:a", 0.0, 0.3)
	await t.finished

	# Clean up all children
	if fusion_pending.has_node("CenterContainer/VBoxContainer/CardContainer"):
		var card_container = fusion_pending.get_node("CenterContainer/VBoxContainer/CardContainer")
		for child in card_container.get_children():
			child.queue_free()

	if fusion_pending.has_node("ParticlesContainer"):
		var particles_container = fusion_pending.get_node("ParticlesContainer")
		for child in particles_container.get_children():
			child.queue_free()

	fusion_pending.visible = false


func _on_cancel_pressed() -> void:
	# 🛑 Close the popup immediately
	if summon_mode_popup:
		summon_mode_popup.hide()
	## 🔇 Stop Fusion Pending audio if it's still playing
	#if has_node("FusionPendingSound"):
		#var snd := get_node("FusionPendingSound")
		#if snd and snd.playing:
			#snd.stop()
		#snd.queue_free()

	# 🧬 Hide fusion pending overlay if active
	if fusion_pending and fusion_pending.visible:
		await hide_fusion_pending()

	# 🧩 Restore fusion cards to hand if fusion was pending
	if core and core.fusion_selection.size() > 0:
		for c in core.fusion_selection:
			if c not in core.player_hand:
				core.player_hand.append(c)
		core.fusion_selection.clear()
		core.ui_sys.refresh_hand(core.player_hand, core.player_essence, true)

	# 🧹 Reset core summon state
	if core:
		core._log("❌ Summon canceled.", Color(1, 0.6, 0.6))
		core.dragging_card = null
		core.selected_card = null
		core.selected_pos = Vector2i(-1, -1)
		core._set_phase(core.Phase.SUMMON_OR_MOVE)
		core._update_phase_ui()

	# ✋ Clear visuals and restore UI
	cancel_drag()             # hides ghost, details, hover
	fade_hand_in()            # bring back hand
	show_battle_message("Summon canceled", 1.0)

	# 🧩 Clear any lingering summon highlights
	if core.battle_sys and core.battle_sys.has_method("clear_summon_highlights"):
		core.battle_sys.call("clear_summon_highlights")


## Hide all UI elements (for cutscenes)
func hide_all_ui() -> void:
	if has_node("BottomContainer"):
		$BottomContainer.visible = false
	if has_node("PhaseLabel"):
		$PhaseLabel.visible = false
	if has_node("PlayerHP"):
		$PlayerHP.visible = false
	if has_node("EnemyHP"):
		$EnemyHP.visible = false
	if has_node("VBoxContainer"):
		$VBoxContainer.visible = false
	if has_node("ArenaCardDetails"):
		$ArenaCardDetails.visible = false
	if has_node("ArenaLeaderDetails"):
		$ArenaLeaderDetails.visible = false
	if has_node("ArenaTerrainDetails"):
		$ArenaTerrainDetails.visible = false
	if has_node("SummonMode"):
		$SummonMode.visible = false
	if has_node("FusionPending"):
		$FusionPending.visible = false
	if has_node("EndTurnButton"):
		$EndTurnButton.visible = false
	if has_node("EndTurnButton"):
		$EndTurnButton.visible = false
	if has_node("DiscardPileButton"):
		$DiscardPileButton.visible = false
		
## Show all UI elements (after cutscenes)
func show_all_ui() -> void:
	if has_node("BottomContainer"):
		$BottomContainer.visible = true
	if has_node("PhaseLabel"):
		$PhaseLabel.visible = true
	if has_node("PlayerHP"):
		$PlayerHP.visible = true
	if has_node("EnemyHP"):
		$EnemyHP.visible = true
	if has_node("VBoxContainer"):
		$VBoxContainer.visible = true
	# Details panels stay hidden until needed
	# SummonMode stays hidden until needed
	# FusionPending stays hidden until needed
# ==========================================================
# 🪦 DISCARD PILE VIEWER EXTENSION
# ==========================================================
# This file extends ArenaUI with discard pile viewing functionality
# Add these functions to arena_ui.gd

var discard_viewer: Panel = null
var discard_button: Button = null
var _current_discard_view := "player"  # "player" or "enemy"
var _discard_grid: GridContainer = null  # Direct reference to card grid
var _discard_empty_label: Label = null  # Direct reference to empty state label

# Call this from _ready() to set up the discard pile UI
func _setup_discard_pile_ui() -> void:
	# Create button to open discard pile (positioned near bottom-right)
	discard_button = Button.new()
	discard_button.name = "DiscardPileButton"
	discard_button.text = "🪦 Discard (0)"
	discard_button.custom_minimum_size = Vector2(140, 45)
	discard_button.add_theme_font_size_override("font_size", 18)

	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	button_style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	button_style.set_border_width_all(2)
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	discard_button.add_theme_stylebox_override("normal", button_style)

	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.2, 0.2, 0.3, 0.95)
	discard_button.add_theme_stylebox_override("hover", hover_style)

	# Position button in bottom-right corner
	discard_button.position = Vector2(10, 10)
	discard_button.anchor_left = 1.0
	discard_button.anchor_top = 1.0
	discard_button.anchor_right = 1.0
	discard_button.anchor_bottom = 1.0
	discard_button.offset_left = -150
	discard_button.offset_top = -170
	discard_button.offset_right = -10
	discard_button.offset_bottom = -125
	discard_button.pressed.connect(_on_discard_button_pressed)
	add_child(discard_button)

	# Create the discard viewer panel (hidden by default)
	_create_discard_viewer_panel()

func _create_discard_viewer_panel() -> void:
	# Main panel (full screen overlay)
	discard_viewer = Panel.new()
	discard_viewer.name = "DiscardViewer"
	discard_viewer.visible = false
	discard_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	discard_viewer.z_index = 50
	# Semi-transparent dark background
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)

	discard_viewer.add_theme_stylebox_override("panel", panel_style)

	# Container for centered content
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 100)
	margin.add_theme_constant_override("margin_right", 100)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_bottom", 80)
	discard_viewer.add_child(margin)

	# Main VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	# === HEADER ===
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	vbox.add_child(header)

	# Title
	var title = Label.new()
	title.text = "🪦 DISCARD PILE"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.15, 0.1))
	title.add_theme_constant_override("outline_size", 8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "✕ CLOSE"
	close_btn.custom_minimum_size = Vector2(120, 50)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_close_discard_viewer)
	header.add_child(close_btn)

	# === TAB BUTTONS ===
	var tab_container = HBoxContainer.new()
	tab_container.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_container.add_theme_constant_override("separation", 10)
	vbox.add_child(tab_container)

	var player_tab = Button.new()
	player_tab.name = "PlayerTab"
	player_tab.text = "YOUR DISCARD"
	player_tab.custom_minimum_size = Vector2(200, 50)
	player_tab.add_theme_font_size_override("font_size", 20)
	player_tab.toggle_mode = true
	player_tab.button_pressed = true
	player_tab.pressed.connect(func(): _switch_discard_view("player"))
	tab_container.add_child(player_tab)

	var enemy_tab = Button.new()
	enemy_tab.name = "EnemyTab"
	enemy_tab.text = "ENEMY DISCARD"
	enemy_tab.custom_minimum_size = Vector2(200, 50)
	enemy_tab.add_theme_font_size_override("font_size", 20)
	enemy_tab.toggle_mode = true
	enemy_tab.pressed.connect(func(): _switch_discard_view("enemy"))
	tab_container.add_child(enemy_tab)

	# === CARD GRID CONTAINER ===
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_discard_grid = GridContainer.new()
	_discard_grid.name = "CardGrid"
	_discard_grid.columns = 6
	_discard_grid.add_theme_constant_override("h_separation", 15)
	_discard_grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(_discard_grid)

	# === EMPTY STATE LABEL ===
	_discard_empty_label = Label.new()
	_discard_empty_label.name = "EmptyLabel"
	_discard_empty_label.text = "No cards in discard pile"
	_discard_empty_label.add_theme_font_size_override("font_size", 32)
	_discard_empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_discard_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discard_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_discard_empty_label.visible = false
	_discard_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.add_child(_discard_empty_label)

	add_child(discard_viewer)

	print("🪦 Discard viewer panel created successfully!")

func _on_discard_button_pressed() -> void:
	print("\n🪦 ============ DISCARD BUTTON PRESSED ============")

	if not discard_viewer:
		print("❌ ERROR: discard_viewer is null!")
		return

	if not core:
		print("❌ ERROR: core is null!")
		return

	print("🪦 Setting up viewer: current_view=player")
	print("🪦 Player discard pile: %d cards" % core.player_discard_pile.size())
	print("🪦 Enemy discard pile: %d cards" % core.enemy_discard_pile.size())

	_current_discard_view = "player"
	discard_viewer.visible = true
	print("🪦 Viewer visible set to: %s" % discard_viewer.visible)

	# Set alpha to 0 for fade-in BEFORE refreshing
	discard_viewer.modulate.a = 0.0
	print("🪦 Viewer alpha set to: 0.0 (for fade-in)")

	# Refresh content
	print("🪦 Calling _refresh_discard_viewer()...")
	_refresh_discard_viewer()
	print("🪦 _refresh_discard_viewer() completed")

	# Fade in animation
	var tween = create_tween()
	tween.tween_property(discard_viewer, "modulate:a", 1.0, 0.3)
	print("🪦 Fade-in animation started")
	print("🪦 ============ END BUTTON PRESS ============\n")

func _close_discard_viewer() -> void:
	if not discard_viewer:
		return

	# Fade out animation
	var tween = create_tween()
	tween.tween_property(discard_viewer, "modulate:a", 0.0, 0.2)
	await tween.finished
	discard_viewer.visible = false

func _switch_discard_view(view: String) -> void:
	_current_discard_view = view
	_refresh_discard_viewer()

	# Update tab button states
	var player_tab = discard_viewer.find_child("PlayerTab")
	var enemy_tab = discard_viewer.find_child("EnemyTab")
	if player_tab and enemy_tab:
		player_tab.button_pressed = (view == "player")
		enemy_tab.button_pressed = (view == "enemy")

func _refresh_discard_viewer() -> void:
	if not discard_viewer or not discard_viewer.visible:
		print("🪦 Refresh skipped: viewer not visible or null")
		return
	if not core:
		print("🪦 Refresh skipped: core is null")
		return

	if not _discard_grid:
		print("❌ ERROR: _discard_grid reference is null!")
		return
	if not _discard_empty_label:
		print("❌ ERROR: _discard_empty_label reference is null!")
		return

	print("🪦 Refreshing discard viewer...")

	# Clear existing cards
	for child in _discard_grid.get_children():
		child.queue_free()

	# Get appropriate discard pile
	var pile: Array[CardData] = core.player_discard_pile if _current_discard_view == "player" else core.enemy_discard_pile

	print("🪦 View: %s | Pile size: %d | Player pile: %d | Enemy pile: %d" % [
		_current_discard_view,
		pile.size(),
		core.player_discard_pile.size(),
		core.enemy_discard_pile.size()
	])

	# Show empty state if no cards
	if pile.is_empty():
		_discard_empty_label.visible = true
		_discard_grid.visible = false
		print("🪦 Pile is empty, showing empty label")
		return
	else:
		_discard_empty_label.visible = false
		_discard_grid.visible = true

	# Create card UI for each card in discard pile
	var cards_added = 0
	for card in pile:
		if not card:
			print("⚠️ NULL card in discard pile!")
			continue

		print("🪦 Creating UI for card: %s (ATK:%d DEF:%d)" % [card.name, card.atk, card.def])
		var card_container = _create_discard_card_ui(card)
		if card_container:
			_discard_grid.add_child(card_container)
			cards_added += 1
			print("  ✅ Card container added to grid")
		else:
			print("  ❌ Failed to create card container!")

	print("🪦 Refresh complete: %d cards added to grid" % cards_added)

func _create_discard_card_ui(card: CardData) -> Control:
	if not card:
		print("    ❌ Card is null, returning null")
		return null

	print("    🔨 Creating container for: %s" % card.name)

	# Container with border
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(140, 196)

	var container_style = StyleBoxFlat.new()
	container_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	container_style.border_color = Color(0.3, 0.3, 0.4)
	container_style.set_border_width_all(2)
	container_style.corner_radius_top_left = 8
	container_style.corner_radius_top_right = 8
	container_style.corner_radius_bottom_left = 8
	container_style.corner_radius_bottom_right = 8
	container.add_theme_stylebox_override("panel", container_style)

	# Inner VBox
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	container.add_child(vbox)

	# Card art
	var art_rect = TextureRect.new()
	if card.art:
		art_rect.texture = card.art
		print("    🖼️ Card art texture set")
	else:
		print("    ⚠️ Card has no art texture")
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.custom_minimum_size = Vector2(130, 150)
	vbox.add_child(art_rect)

	# Card name
	var name_label = Label.new()
	name_label.text = card.name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# Hover effect
	container.mouse_entered.connect(func():
		var tween = create_tween()
		tween.tween_property(container, "scale", Vector2(1.05, 1.05), 0.1)
		# Show card details on hover
		if has_node("ArenaCardDetails"):
			var details = get_node("ArenaCardDetails")
			if details.has_method("show_card"):
				details.show_card(card)
				details.visible = true
	)

	container.mouse_exited.connect(func():
		var tween = create_tween()
		tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.1)
	)

	print("    ✅ Container created successfully")
	return container

# Call this to update discard button count
func update_discard_button() -> void:
	if not discard_button or not core:
		return

	var total_count = core.player_discard_pile.size() + core.enemy_discard_pile.size()
	discard_button.text = "🪦 Discard (%d)" % total_count
