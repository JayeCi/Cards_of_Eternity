extends Control

@export var card_ui_scene: PackedScene = preload("res://ui/CardUI.tscn")

@onready var grid = $ScrollContainer/MarginContainer/GridContainer
@onready var zoom: Control = $"../CanvasLayer/CardZoom"



# Track displayed cards
var displayed_cards := {}  # { "CARD_ID": card_ui_node }

func _ready():
	connect("visibility_changed", Callable(self, "_on_visibility_changed"))
	CardCollection.connect("card_added", Callable(self, "_on_card_added"))
	_load_existing_cards()
	zoom.hide()

func _on_visibility_changed():
	var battle_scene: Node = null

	# 🔍 Find the active battle scene via its group
	var nodes = get_tree().get_nodes_in_group("battle_scene")
	if nodes.size() > 0:
		battle_scene = nodes[0]

	if not battle_scene:
		print("⚠️ Could not find battle scene to toggle UI.")
		return

	# ✅ Toggle arena UI visibility (hide when collection is open)
	if visible:
		if battle_scene.has_method("hide_game_ui"):
			battle_scene.hide_game_ui()
	else:
		if battle_scene.has_method("show_game_ui"):
			battle_scene.show_game_ui()

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

	# ✅ Update existing entry
	if displayed_cards.has(card.id):
		var card_ui: Control = displayed_cards[card.id]
		var label := _find_count_label(card_ui)
		if label:
			label.text = "x" + str(count)
		return

	# ✅ Create new entry
	var card_ui: Control = card_ui_scene.instantiate()
	card_ui.card_data = card
	card_ui.refresh()
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

func _find_count_label(card_ui: Node) -> Label:
	# Adjust these as your CardUI structure changes
	var possible_paths = [
		"PanelContainer/CenterContainer/VBoxContainer/CountLabel",
		"PanelContainer/VBoxContainer/CountLabel",
		"CountLabel"
	]
	for path in possible_paths:
		var label = card_ui.get_node_or_null(path)
		if label:
			return label
	return null
	
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
	await get_tree().process_frame




func _hide_zoom() -> void:
	if zoom:
		zoom.visible=false
		
