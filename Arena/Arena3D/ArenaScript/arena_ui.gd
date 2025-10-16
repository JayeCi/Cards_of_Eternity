# File: arena_ui.gd
extends Node
class_name ArenaUI

# Cached references
var core: ArenaCore
var board: Node3D
var camera: Camera3D
var is_dragging_card := false

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
@onready var battle_sys: ArenaBattle = $"../BattleSystem"
@onready var hp_progress_bar: ProgressBar = $PlayerHP/TextureRect/HPProgressBar
@onready var enemy_hp_progress_bar: ProgressBar = $EnemyHP/TextureRect/HPProgressBar



var hover_label: Label3D
var ghost_card: Sprite3D
var last_card_ui: Control = null
var _is_hovering_hand_card := false

func _ready():
	$ArenaCardDetails.visible = false
	$ArenaTerrainDetails.visible = false
	$BottomContainer/OrbGrid/OrbGrid.visible = false 
	

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

func refresh_hand(player_hand: Array, player_essence: int) -> void:
	for c in hand_grid.get_children(): c.queue_free()
	last_card_ui = null

	for c: CardData in player_hand:
		var ui = preload("res://UI/CardUI.tscn").instantiate()
		ui.card_data = c
		ui.refresh()

		var cost := 1
		if c.has_meta("cost"): cost = int(c.get_meta("cost"))
		elif c.has_method("get_cost"): cost = c.get_cost()
		elif "cost" in c: cost = int(c.cost)

		ui.set_playable(cost <= player_essence)

		ui.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				if cost > player_essence:
					var t = create_tween()
					t.tween_property(ui, "modulate", Color(1, 0.5, 0.5, 1), 0.1)
					t.tween_property(ui, "modulate", Color(0.4, 0.4, 0.4, 0.5), 0.25)
					_on_log("❌ Not enough Essence for %s (Cost %d, you have %d)" % [c.name, cost, player_essence], Color.WHITE)
					return
				core.on_hand_card_clicked(c)
		)
		
		ui.request_show_zoom.connect(Callable(self, "_on_card_hovered_in_hand"))
		ui.request_hide_zoom.connect(Callable(self, "_on_card_hovered_in_hand_exit"))


		hand_grid.add_child(ui)
		last_card_ui = ui
		
	if orb_grid:
		orb_grid.visible = player_hand.size() > 0
		
func get_last_hand_card_ui() -> Control:
	return last_card_ui

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

# Buttons in popup must be connected in the scene to these methods:
func _on_attack_mode_pressed() -> void:
	summon_mode_popup.hide()
	core.confirm_summon_in_mode(UnitData.Mode.ATTACK)

func _on_defense_mode_pressed() -> void:
	summon_mode_popup.hide()
	core.confirm_summon_in_mode(UnitData.Mode.DEFENSE)

func _on_facedown_mode_pressed() -> void:
	summon_mode_popup.hide()
	core.confirm_summon_in_mode(UnitData.Mode.FACEDOWN)

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
	hand_grid.visible = true
	hand_grid.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hand_grid, "modulate:a", 1.0, 0.25)

func fade_hand_out() -> void:
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


func _on_card_hovered_in_hand(card: CardData) -> void:
	_is_hovering_hand_card = true
	if card_details_ui:
		card_details_ui.show_card(card)
		card_details_ui.visible = true

func _on_card_hovered_in_hand_exit() -> void:
	if not _is_hovering_hand_card:
		return  # already cleared
	_is_hovering_hand_card = false
	
	if card_details_ui:
		card_details_ui.hide_card()
		card_details_ui.visible = false

	# Hide terrain/card hover completely when leaving hand cards
	hide_hover()


func show_hover_for_tile(tile: Node3D) -> void:
	# 🛑 Don’t update board hover while hovering a card in hand
	if _is_hovering_hand_card:
		return

	if is_dragging_card:
		return
	if not tile or (core and core.is_cutscene_active):
		return

	if tile.occupant:
		if has_node("ArenaTerrainDetails"):
			$ArenaTerrainDetails.visible = false
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.show_unit(tile.occupant)
	else:
		if has_node("ArenaCardDetails"):
			$ArenaCardDetails.hide_card()
		if has_node("ArenaTerrainDetails"):
			if $ArenaTerrainDetails.has_method("show_terrain"):
				$ArenaTerrainDetails.show_terrain(tile.terrain_type)
			else:
				$ArenaTerrainDetails.visible = true

func hide_hover() -> void:
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
	# Update orb grid for player essence
	if orb_grid and orb_grid.has_method("set_essence"):
		orb_grid.set_essence(p)


func _on_hp_changed(owner: int, hp: int) -> void:
	if owner == core.PLAYER:
		player_hp_label.text = str(hp)
		_flash(player_hp_label)
		_update_hp_bar()  # 🟢 Add this line
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

func _on_log(msg: String, color := Color.WHITE) -> void:
	if not battle_log: return
	battle_log.append_text("[color=%s]%s[/color]\n" % [color.to_html(false), msg])
	battle_log.scroll_to_line(battle_log.get_line_count() - 1)

func show_battle_message(text: String, duration := 2.0) -> void:
	var label: Label = $"../UISystem/BattlePopup"
	label.text = text
	label.show()
	var t = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(duration).timeout
	var t2 = create_tween()
	t2.tween_property(label, "modulate:a", 0.0, 0.5)

func _update_hp_bar() -> void:
	var t = create_tween()
	t.tween_property(hp_progress_bar, "value", core.player_leader.hp, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(enemy_hp_progress_bar, "value", core.enemy_leader.hp, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _update_hp_labels() -> void:
	player_hp_label.text = str(core.player_leader.hp)
	enemy_hp_label.text = str(core.enemy_leader.hp)


func _on_face_down_pressed() -> void:
	pass # Replace with function body.
