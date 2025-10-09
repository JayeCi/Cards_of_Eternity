extends Control

@export var card_data: CardData

@onready var art = $PanelContainer/VBoxContainer/Art
@onready var name_label = $PanelContainer/VBoxContainer/NameLabel
@onready var stat_label = $PanelContainer/VBoxContainer/StatLabel
@onready var cost_label: Label = $PanelContainer/CostLabel

signal request_show_zoom(card)
signal request_hide_zoom()

var is_hovering := false
var hover_timer = null

func _ready():
	await get_tree().process_frame
	if card_data:
		refresh()

	
	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = 0.05
	add_child(hover_timer)


func refresh():
	if card_data == null:
		if name_label: name_label.text = ""
		if art: art.texture = null
		if stat_label: stat_label.text = ""
		return

	if name_label:
		name_label.text = card_data.name
	if art:
		art.texture = card_data.art
	if stat_label:
		stat_label.text = "ATK: %d  DEF: %d" % [card_data.attack, card_data.defense]
	if cost_label:
		if card_data and card_data.cost > 0:
			cost_label.text = str(card_data.cost)
			cost_label.visible = true
		else:
			cost_label.visible = false


# Hover signals
func _on_card_hovered():
	if is_hovering:
		return
	is_hovering = true
	emit_signal("request_show_zoom", card_data)

func _on_card_hover_exit():
	if not is_hovering:
		return
	hover_timer.start()
	await hover_timer.timeout
	if not get_global_rect().has_point(get_global_mouse_position()):
		is_hovering = false
		emit_signal("request_hide_zoom")

func set_playable(is_playable: bool):
	modulate = Color(1, 1, 1, 1) if is_playable else Color(0.4, 0.4, 0.4, 0.5)
