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
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_focus_mode(Control.FOCUS_NONE)
	connect_mouse_signals()
	_disable_child_mouse_filters(self)
	await get_tree().process_frame

	if card_data:
		refresh()

	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = 0.05
	add_child(hover_timer)

	print("[CardUI] Ready:", card_data.name if card_data else "No data")


# -------------------------------
# Debugging hover and clicks
# -------------------------------
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[CardUI] 🖱️ Clicked on:", card_data.name)
		emit_signal("request_show_zoom", card_data)


func connect_mouse_signals():
	connect("mouse_entered", Callable(self, "_on_mouse_enter"))
	connect("mouse_exited", Callable(self, "_on_mouse_exit"))
	print("[CardUI] Signals connected for:", card_data.name if card_data else "Unknown Card")


# -------------------------------
# Hover behavior
# -------------------------------
func _on_mouse_enter():
	if is_hovering:
		return
	is_hovering = true
	emit_signal("request_show_zoom", card_data)

func _on_mouse_exit():
	if not is_hovering:
		return
	is_hovering = false
	emit_signal("request_hide_zoom")

# -------------------------------
# Hover signals (backup, not used by default)
# -------------------------------

# -------------------------------
# Mouse filter safety
# -------------------------------
func _disable_child_mouse_filters(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filters(child)


# -------------------------------
# Refresh visuals
# -------------------------------
func refresh():
	if card_data == null:
		print("[CardUI] ⚠️ refresh() called with null data")
		if name_label: name_label.text = ""
		if art: art.texture = null
		if atk: atk.text = ""
		if def: def.text = ""
		if rarity_label: rarity_label.text = ""
		if cost_label: cost_label.visible = false
		return

	print("[CardUI] Refreshing card:", card_data.name)
	if name_label: name_label.text = card_data.name
	if art: art.texture = card_data.art
	if atk: atk.text = str(card_data.atk)
	if def: def.text = str(card_data.def)

	if rarity_label:
		var rarity_text = card_data.rarity if card_data.rarity != "" else "Common"
		rarity_label.text = rarity_text.capitalize()
		match rarity_text.to_lower():
			"common": rarity_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
			"uncommon": rarity_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			"rare": rarity_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0))
			"epic": rarity_label.add_theme_color_override("font_color", Color(0.7, 0.4, 1.0))
			"legendary": rarity_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
			_: rarity_label.add_theme_color_override("font_color", Color.WHITE)

	if cost_label:
		if card_data.cost > 0:
			cost_label.text = str(card_data.cost)
			cost_label.visible = true
		else:
			cost_label.visible = false


# -------------------------------
# State display
# -------------------------------
func set_playable(is_playable: bool):
	print("[CardUI] Playable state for", card_data.name, "=", is_playable)
	modulate = Color(1, 1, 1, 1) if is_playable else Color(0.4, 0.4, 0.4, 0.5)
