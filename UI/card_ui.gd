extends Control

@export var card_data: CardData

@onready var art = $PanelContainer/VBoxContainer/ArtPanel/Art
@onready var name_label = $PanelContainer/VBoxContainer/NamePlate/NameLabel
@onready var rarity_label: Label = $PanelContainer/VBoxContainer/RarityPlate/RarityLabel
@onready var atk: Label = $PanelContainer/VBoxContainer/StatPlate/Panel/AtkContainer/Atk
@onready var def: Label = $PanelContainer/VBoxContainer/StatPlate/Panel/DefContainer/Def
@onready var cost_label: Label = $PanelContainer/VBoxContainer/CostPlate/CostLabel

signal request_show_zoom(card)
signal request_hide_zoom()

var is_hovering := false
var hover_timer: Timer


func _ready():
	connect_mouse_signals()
	await get_tree().process_frame
	if card_data:
		refresh()

	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = 0.05
	add_child(hover_timer)

func connect_mouse_signals():
	connect("mouse_entered", Callable(self, "_on_mouse_enter"))
	connect("mouse_exited", Callable(self, "_on_mouse_exit"))

func refresh():
	if card_data == null:
		if name_label: name_label.text = ""
		if art: art.texture = null
		if atk: atk.text = ""
		if def: def.text = ""
		if rarity_label: rarity_label.text = ""
		if cost_label: cost_label.visible = false
		return

	if name_label:
		name_label.text = card_data.name

	if art:
		art.texture = card_data.art

	if atk:
		atk.text = str(card_data.atk)

	if def:
		def.text = str(card_data.def)

	if rarity_label:
		# Set rarity text and optional color flair
		var rarity_text = card_data.rarity if card_data.rarity != "" else "Common"
		rarity_label.text = rarity_text.capitalize()

		match rarity_text.to_lower():
			"common":
				rarity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			"uncommon":
				rarity_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			"rare":
				rarity_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
			"epic":
				rarity_label.add_theme_color_override("font_color", Color(0.7, 0.4, 1.0))
			"legendary":
				rarity_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			_:
				rarity_label.add_theme_color_override("font_color", Color.WHITE)

	if cost_label:
		if card_data.cost > 0:
			cost_label.text = str(card_data.cost)
			cost_label.visible = true
		else:
			cost_label.visible = false

func _on_mouse_enter():
	if is_hovering:
		return
	is_hovering = true
	emit_signal("request_show_zoom", card_data)

	# Optional visual feedback
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)

func _on_mouse_exit():
	hover_timer.start()
	await hover_timer.timeout

	# Prevent accidental hide if the mouse comes back quickly
	if not get_global_rect().has_point(get_global_mouse_position()):
		is_hovering = false
		emit_signal("request_hide_zoom")

	# Optional shrink back
	var t = create_tween()
	t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

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
