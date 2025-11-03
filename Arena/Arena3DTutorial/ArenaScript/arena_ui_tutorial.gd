# File: arena_ui.gd
extends Node
class_name ArenaUITutorial

# Cached references
var core: ArenaCoreTutorial
var board: Node3D
var camera: Camera3D
var is_dragging_card := false
var _hover_tween: Tween = null
var _current_hover_card: CardData = null
var _last_hand_snapshot: Array = []
var _selected_card_ui_map: Dictionary = {}

@onready var fusion_pending := $FusionPending
@onready var fusion_label := $FusionPending/FusionLabel

# UI nodes
@onready var hand_grid: GridContainer = $BottomContainer/Hand
@onready var phase_label: Label = $PhaseLabel
@onready var player_hp_label: Label = $PlayerHP/TextureRect/HPLabel
@onready var enemy_hp_label: Label = $EnemyHP/TextureRect/HPLabel
@onready var fade_rect: ColorRect = $FadeRect
@onready var summon_mode_popup: PopupPanel = $SummonMode
@onready var battle_log: RichTextLabel = $VBoxContainer/BattleLogLabel
@onready var card_details_ui: ArenaCardDetails = $ArenaCardDetails
@onready var orb_grid: Control = $BottomContainer/OrbGrid/OrbGrid
@onready var battle_sys: ArenaBattleTutorial = $"../BattleSystem"
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
var summon_mode_locked: bool = false

func _ready():
	$ArenaCardDetails.visible = false
	$ArenaTerrainDetails.visible = false
	$BottomContainer/OrbGrid/OrbGrid.visible = false 


func init_ui(core_ref: ArenaCoreTutorial) -> void:
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
	# 🖱️ Right-click cancels summon popup if it's open
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if summon_mode_popup and summon_mode_popup.visible:
			_cancel_summon_popup()
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

func refresh_hand(player_hand: Array, player_essence: int, force_update := false) -> void:
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
		var ui = preload("res://UI/CardUI.tscn").instantiate()
		ui.card_data = c
		ui.refresh()
		ui.set_meta("base_y", ui.position.y)  # remember its original Y

		ui.modulate = Color(0.8, 1.0, 0.8, 1) if core.fusion_selection.has(c) else Color(1, 1, 1, 1)
		ui.position.y = -25.0 if core.fusion_selection.has(c) else 0.0

		var cost := 1
		if c.has_meta("cost"): cost = int(c.get_meta("cost"))
		elif c.has_method("get_cost"): cost = c.get_cost()
		elif "cost" in c: cost = int(c.cost)
		ui.set_playable(cost <= player_essence)

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
		ui.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(ui, "modulate:a", 1.0, 0.25)
		hand_grid.add_child(ui)
		last_card_ui = ui

	if orb_grid:
		orb_grid.visible = player_hand.size() > 0

func get_last_hand_card_ui() -> Control:
	return last_card_ui
	
# Smoothly animate card selection raise/lower
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
	pulse_tween.set_loops()
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
	summon_mode_popup.visible = true
	summon_mode_popup.popup_centered()


	# NEW: lock input
	summon_mode_locked = true
	_disable_summon_buttons()

	# mark the tutorial state
	core.tutorial_waiting_for_attack_choice = true

	# start dialogue
	InputState.set_mode(InputState.Mode.DIALOGUE)
	get_viewport().set_input_as_handled()


	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Attack Mode places your card face-up activating any On Summon abilities. Lets try that now"),
	])
	if !DialogueManager.finished.is_connected(_on_attack_explanation_finished):
		DialogueManager.finished.connect(_on_attack_explanation_finished, Object.CONNECT_ONE_SHOT)

func _on_attack_explanation_finished(_id := StringName("")):
	InputState.set_mode(InputState.Mode.FREE)
	summon_mode_locked = false
	_enable_summon_buttons()
	core._log("✅ Now click ATTACK MODE!", Color(0.8,1.0,0.6))

func is_popup_open() -> bool:
	return summon_mode_popup != null and summon_mode_popup.visible

func hide_popup() -> void:
	if summon_mode_popup:
		summon_mode_popup.visible = false
		
func _disable_summon_buttons():
	for b in summon_mode_popup.get_children():
		if b is BaseButton:
			b.disabled = true

func _enable_summon_buttons():
	for b in summon_mode_popup.get_children():
		if b is BaseButton:
			b.disabled = false

func _on_popup_button_pressed(callback: Callable, mode: int, popup: PopupPanel) -> void:
	if summon_mode_locked:
		core._log("📘 Listen to the guide first.", Color(0.7,0.9,1.0))
		return

	if popup:
		popup.hide()

	if callback and callback.is_valid():
		callback.call(mode)

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
	card_ui.modulate.a = 0.0
	card_ui.scale = Vector2(0.8, 0.8)
	card_ui.visible = true
	var t = create_tween()
	t.tween_property(card_ui, "modulate:a", 1.0, 0.25)
	t.tween_property(card_ui, "scale", Vector2(1,1), 0.25)
	await t.finished

func update_phase_label(phase: int) -> void:
	match phase:
		core.Phase.SUMMON_OR_MOVE:
			phase_label.text = "Your Turn: Summon or Move"
			$"../UISystemTutorial/EndTurnButton".disabled = false
		core.Phase.SELECT_SUMMON_TILE:
			phase_label.text = "Choose a tile to Summon"
			$"../UISystemTutorial/EndTurnButton".disabled = true
		core.Phase.SELECT_MOVE_TARGET:
			phase_label.text = "Choose a tile to Move"
			$"../UISystemTutorial/EndTurnButton".disabled = true
		core.Phase.ENEMY_TURN:
			phase_label.text = "Enemy Turn"
			$"../UISystemTutorial/EndTurnButton".disabled = true

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
	if InputState.mode == InputState.Mode.DIALOGUE:
		return

		# 🧬 If this card is part of fusion selection, keep it persistently visible
	if core and core.fusion_selection.has(card):
		card_details_ui.show_card(card)
		card_details_ui.visible = true
		_hover_state = "visible"
		print("[ArenaUI] 🧬 Persistent hover for selected card:", card.name)
		return

	# 1️⃣ Cancel any scheduled hide
	if _hide_task:
		_hide_task = null

	# 2️⃣ If already showing this same card, ignore
	if _current_hover_card == card and _hover_state == "visible":
		return

	_current_hover_card = card
	_is_hovering_hand_card = true

	# 🧩 NEW FIX — hide terrain when hovering a hand card
	if has_node("ArenaTerrainDetails"):
		if $ArenaTerrainDetails.has_method("hide_terrain"):
			$ArenaTerrainDetails.hide_terrain()
		else:
			$ArenaTerrainDetails.visible = false

	if not card_details_ui:
		return

	# 3️⃣ Stop ongoing animations
	if _hover_tween and _hover_tween.is_running():
		_hover_tween.kill()

	match _hover_state:
		"idle", "hiding":
			card_details_ui.modulate.a = 0.0
			card_details_ui.show_card(card)
			card_details_ui.visible = true
			_hover_tween = create_tween()
			_hover_tween.tween_property(card_details_ui, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE)
			_hover_state = "visible"
			print("[ArenaUI] 🟢 Showing details for:", card.name)
		"visible", "showing":
			card_details_ui.show_card(card)
			print("[ArenaUI] 🔁 Updating details for:", card.name)
	

func _on_card_hovered_in_hand_exit() -> void:
	# 🧩 If any card is selected for fusion, disable hover exit
	if core and core.fusion_selection.size() > 0:
		print("[ArenaUI] 🧬 Fusion selection active — hover exit ignored.")
		return

	if not _is_hovering_hand_card:
		return

	_is_hovering_hand_card = false

	# Fade out or hide details
	if card_details_ui:
		card_details_ui.hide_card()
		card_details_ui.visible = false

	# 🔁 Reset hover state to allow re-hover of the same card
	_current_hover_card = null
	_hover_state = "idle"

	print("[ArenaUI] 🔻 Hover ended — state reset.")

func show_hover_for_tile(tile: Node3D) -> void:
	if InputState.mode == InputState.Mode.DIALOGUE:
		return

	# 🛑 Prevent terrain hover while hovering a hand card
	if _is_hovering_hand_card:
		return

	if not tile or (core and core.is_cutscene_active):
		return

	# Block terrain hover ONLY if dragging a card
	if is_dragging_card:
		return

	# --- TILE WITH UNIT ---
	if tile.occupant:
		var unit = tile.occupant
		var is_enemy = unit.owner != core.PLAYER
		var is_facedown = unit.has_meta("is_facedown") and unit.get_meta("is_facedown")

		# 🧩 Hide terrain when hovering a unit card
		if has_node("ArenaTerrainDetails"):
			if $ArenaTerrainDetails.has_method("hide_terrain"):
				$ArenaTerrainDetails.hide_terrain()
			else:
				$ArenaTerrainDetails.visible = false

		if is_enemy and is_facedown:
			if has_node("ArenaCardDetails"):
				$ArenaCardDetails.hide_card()
			# Show terrain only for facedown enemies
			if has_node("ArenaTerrainDetails"):
				$ArenaTerrainDetails.show_terrain(tile.terrain_type)
				$ArenaTerrainDetails.visible = true
			return
		else:
			if has_node("ArenaCardDetails"):
				$ArenaCardDetails.show_unit(unit)
			# Terrain stays hidden while showing card details
	else:
		# --- EMPTY TILE: SHOW TERRAIN DETAILS ONLY ---
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.hide_card()
		if has_node("ArenaTerrainDetails"):
			$ArenaTerrainDetails.show_terrain(tile.terrain_type)
			$ArenaTerrainDetails.visible = true

func hide_hover() -> void:

	if _is_hovering_hand_card:
		return
	if core and core.is_cutscene_active:
		return
	if is_dragging_card:
		return
		
	# 👇 only skip this during *active* hand hover
	if _is_hovering_hand_card:
		if card_details_ui:
			card_details_ui.hide_card()
			card_details_ui.visible = false
		return

	# Hide both info panels safely
	if has_node("ArenaCardDetails"):
		$ArenaCardDetails.hide_card()

	if has_node("ArenaTerrainDetails"):
		if $ArenaTerrainDetails.has_method("hide_terrain"):
			$ArenaTerrainDetails.hide_terrain()
		else:
			$ArenaTerrainDetails.visible = false

	# Reset hover label too
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
	if core.tutorial_waiting_for_attack_choice and mode != UnitData.Mode.ATTACK:
		core._log("Try ATTACK mode first!", Color(1,0.6,0.6))
		return

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

	# 🧩 Clear old card UIs
	for child in fusion_pending.get_children():
		if child.name.begins_with("FusionCardUI_") or child.name.begins_with("FusionGlow_"):
			child.queue_free()

	var card_ui_scene := preload("res://UI/CardUI.tscn")

	# Helper to make glowing frame
	

	# 🟩 Create glow + card UI for both cards
	var card_ui_a: Control = card_ui_scene.instantiate()
	card_ui_a.name = "FusionCardUI_A"
	card_ui_a.card_data = a
	card_ui_a.refresh()
	card_ui_a.z_index = 100
	card_ui_a.scale = Vector2(0.8, 0.8)
	card_ui_a.modulate.a = 0.0
	card_ui_a.position = Vector2(200, 200)

	var card_ui_b: Control = card_ui_scene.instantiate()
	card_ui_b.name = "FusionCardUI_B"
	card_ui_b.card_data = b
	card_ui_b.refresh()
	card_ui_b.z_index = 101
	card_ui_b.scale = Vector2(0.8, 0.8)
	card_ui_b.modulate.a = 0.0
	card_ui_b.position = Vector2(240, 200)

	fusion_pending.add_child(card_ui_a)
	fusion_pending.add_child(card_ui_b)

	# 🌟 Enable fusion glow visuals
	if card_ui_a.has_method("show_fusion_glow"):
		card_ui_a.show_fusion_glow(true)
	if card_ui_b.has_method("show_fusion_glow"):
		card_ui_b.show_fusion_glow(true)

	# 🧬 Label text
	fusion_label.text = "Fusion: %s" % result_card.name if result_card != null else "Fusion Ready!"


	# 🟢 Fade in overlay
	fusion_pending.visible = true
	fusion_pending.modulate.a = 0.0
	var fade_overlay := create_tween()
	fade_overlay.tween_property(fusion_pending, "modulate:a", 1.0, 0.25)

	# 🎴 Staggered card fade
	var fade_cards := create_tween()
	fade_cards.tween_property(card_ui_b, "modulate:a", 1.0, 0.35).set_delay(0.05)
	fade_cards.tween_property(card_ui_a, "modulate:a", 1.0, 0.35).set_delay(0.25)

	# 🔄 Rotation swing
	if fusion_enable_rotation:
		var tw_a := create_tween()
		tw_a.set_loops()
		tw_a.tween_property(card_ui_a, "rotation_degrees", fusion_rotate_amplitude, fusion_rotate_speed).as_relative()
		tw_a.tween_property(card_ui_a, "rotation_degrees", -fusion_rotate_amplitude, fusion_rotate_speed).as_relative()

		var tw_b := create_tween()
		tw_b.set_loops()
		tw_b.tween_property(card_ui_b, "rotation_degrees", -fusion_rotate_amplitude, fusion_rotate_speed).as_relative()
		tw_b.tween_property(card_ui_b, "rotation_degrees", fusion_rotate_amplitude, fusion_rotate_speed).as_relative()
		
	#if core and core.FUSION_PENDING_SOUND:
		#var p := AudioStreamPlayer.new()
		#p.name = "FusionPendingSound"
		#add_child(p)
		#p.stream = core.FUSION_PENDING_SOUND
		#p.volume_db = -6.0
		#p.play()
		#p.connect("finished", Callable(p, "queue_free"))


func hide_fusion_pending() -> void:
	if not fusion_pending:
		return
	core._is_fusion_pending_active = false

	var t := create_tween()
	t.tween_property(fusion_pending, "modulate:a", 0.0, fusion_fade_in_duration)
	await t.finished

	for child in fusion_pending.get_children():
		if child.name.begins_with("FusionCardUI_") or child.name.begins_with("FusionGlow_"):
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
