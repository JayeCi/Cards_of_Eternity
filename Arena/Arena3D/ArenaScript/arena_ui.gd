# File: arena_ui.gd
extends Node
class_name ArenaUI

# Cached references
var core: ArenaCore
var board: Node3D
var camera: Camera3D

# UI nodes
@onready var hand_grid: GridContainer = $Hand
@onready var phase_label: Label = $PhaseLabel
@onready var player_hp_label: Label = $HPPanel/PlayerHP
@onready var enemy_hp_label: Label = $HPPanel/EnemyHP
@onready var fade_rect: ColorRect = $FadeRect
@onready var summon_mode_popup: PopupPanel = $SummonMode
@onready var battle_log: RichTextLabel = $VBoxContainer/BattleLogLabel
@onready var player_essence_label: Label = $EssencePanel/VBoxContainer/PlayerEssence
@onready var enemy_essence_label: Label = $EssencePanel/VBoxContainer/EnemyEssence
@onready var card_details_ui: ArenaCardDetails = $ArenaCardDetails


var hover_label: Label3D
var ghost_card: Sprite3D
var last_card_ui: Control = null

func init_ui(core_ref: ArenaCore) -> void:
	core = core_ref
	board = core.board
	camera = core.camera

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
		hand_grid.add_child(ui)
		last_card_ui = ui

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
	ghost_card.texture = card.art
	ghost_card.visible = true
	hand_grid.visible = false
	var forward = -camera.global_transform.basis.z
	ghost_card.position = camera.global_position + forward * 5.0

func cancel_drag() -> void:
	ghost_card.visible = false
	hand_grid.visible = true

func fade_hand_in() -> void:
	hand_grid.visible = true
	hand_grid.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hand_grid, "modulate:a", 1.0, 0.25)

func fade_hand_out() -> void:
	hand_grid.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hand_grid, "modulate:a", 1.0, 0.25)

# Hover label + card details
func show_hover_for_tile(tile: Node3D) -> void:
	if tile == null:
		hide_hover()
		return
	var text := ""
	if tile.occupant:
		var u: UnitData = tile.occupant
		ghost_card.position = (tile.position + Vector3(0,0.03,0)) if tile else ghost_card.position

		text += "🗡 " + str(u.current_atk) + " | 🛡 " + str(u.current_def)
		if u.is_leader: text += " | ❤️ " + str(u.hp)
		text += "\n"
	text += "🌍 Terrain: " + tile.terrain_type
	hover_label.global_position = tile.global_position + Vector3(0, 0.25, 0)
	hover_label.text = text
	hover_label.visible = true
	hover_label.modulate.a = 0.0
	var t = create_tween()
	t.tween_property(hover_label, "modulate:a", 1.0, 0.2)

	if tile.occupant:
		card_details_ui.call("show_unit", tile.occupant)
	else:
		card_details_ui.call("hide_card")

func move_ghost_over(tile: Node3D) -> void:
	if ghost_card.visible:
		ghost_card.position = (tile.position + Vector3(0,0.03,0)) if tile else ghost_card.position


func hide_hover() -> void:
	if not hover_label.visible: return
	var t = create_tween()
	t.tween_property(hover_label, "modulate:a", 0.0, 0.15)
	await t.finished
	card_details_ui.call("hide_card")
	hover_label.visible = false

# Labels / log
func _on_essence_changed(p: int, e: int) -> void:
	player_essence_label.text = "Player Essence: %d" % p
	enemy_essence_label.text = "Enemy Essence: %d" % e
	var tp = create_tween()
	tp.tween_property(player_essence_label, "modulate", Color(0.6,1,0.6), 0.15)
	tp.tween_property(player_essence_label, "modulate", Color(1,1,1), 0.25)
	var te = create_tween()
	te.tween_property(enemy_essence_label, "modulate", Color(1,1,0.5), 0.15)
	te.tween_property(enemy_essence_label, "modulate", Color(1,1,1), 0.25)

func _on_hp_changed(owner: int, hp: int) -> void:
	if owner == core.PLAYER:
		player_hp_label.text = "Player Leader HP: %d" % hp
		_flash(player_hp_label)
	else:
		enemy_hp_label.text = "Enemy Leader HP: %d" % hp
		_flash(enemy_hp_label)

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

func _update_hp_labels() -> void:
	player_hp_label.text = "Player Leader HP: %d" % core.player_leader.hp
	enemy_hp_label.text = "Enemy Leader HP: %d" % core.enemy_leader.hp


func _on_face_down_pressed() -> void:
	pass # Replace with function body.
