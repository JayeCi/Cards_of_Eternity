extends Control

@export var card_ui_scene: PackedScene = preload("res://ui/CardUI.tscn")

@onready var grid = $ScrollContainer/GridContainer
@onready var zoom = $"../CanvasLayer/CardZoom"

# Track displayed cards
var displayed_cards := {}  # { "CARD_ID": card_ui_node }

func _ready():
	CardCollection.connect("card_added", Callable(self, "_on_card_added"))
	_load_existing_cards()
	zoom.hide()

func _load_existing_cards():
	for card_id in CardCollection.get_all_cards():
		var card_data = CardCollection.get_card_data(card_id)
		var count = CardCollection.get_card_count(card_id)
		_add_or_update_card_ui(card_data, count)

func _on_card_added(card: CardData, count: int) -> void:
	_add_or_update_card_ui(card, count)

func _add_or_update_card_ui(card: CardData, count: int) -> void:
	if card == null or card.id == "":
		return

	if displayed_cards.has(card.id):
		var card_ui = displayed_cards[card.id]
		var label = card_ui.get_node_or_null("PanelContainer/CenterContainer/VBoxContainer/CountLabel")
		if label:
			label.text = "x" + str(count)
		return

	var card_ui = card_ui_scene.instantiate()
	card_ui.card_data = card
	card_ui.refresh()

	var label = card_ui.get_node_or_null("PanelContainer/CenterContainer/VBoxContainer/CountLabel")
	if label:
		label.text = "x" + str(count)

	# 🟢 Add click to enlarge card
	card_ui.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				_show_zoom(card)
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				_hide_zoom()
	)

	grid.add_child(card_ui)
	displayed_cards[card.id] = card_ui

func _show_zoom(card: CardData) -> void:
	if not zoom:
		return

	# Reparent to root canvas to avoid ScrollContainer offsets
	if not zoom.get_parent() == get_tree().root.get_child(0):
		var root_canvas = get_tree().root.get_node("Main/CanvasLayer") if get_tree().root.has_node("Main/CanvasLayer") else null
		if root_canvas:
			zoom.get_parent().remove_child(zoom)
			root_canvas.add_child(zoom)

	zoom.show_card(card)
	zoom.show()
	zoom.grab_focus()


func _hide_zoom() -> void:
	if zoom:
		zoom.hide()
