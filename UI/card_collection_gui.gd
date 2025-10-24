extends Control

@onready var main_panel := $CollectionPanel/ScrollContainer/GridContainer
@onready var deck_collection_grid: GridContainer = $DeckPanel/Collection/ScrollContainer/CollectionGrid
@onready var deck_grid: GridContainer = $DeckPanel/Deck/ScrollContainer/DeckGrid


var left_panel: Control
var card_name_label: Label
var rarity_label: Label
var cost_label: Label
var atk_label: Label
var def_label: Label
var subtype_label: Label
var abilities_label: Label
var ability_desc_label: Label
var description_label: Label
var art_texture_rect: TextureRect
var art_border: TextureRect
var displayed_cards := {}
var player = null

@onready var collection_panel: Panel = $CollectionPanel
@onready var leader_panel: Panel = $LeaderPanel
@onready var deck_panel: Panel = $DeckPanel
@onready var main_panel_label: Label = $Toolbar/MainPanelLabel

var selected_card: CardData = null

func _ready():

	# 🧩 Setup layout references
	left_panel = get_node_or_null("LeftPanel")
	if not left_panel:
		push_error("[CollectionGUI] ❌ LeftPanel not found.")
		return

	# 🧩 Populate existing collection cards
	_populate_existing_cards()

	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("[CollectionGUI] ⚠️ Player group not found.")
	else:
		print("[CollectionGUI] ✅ Player found:", player.name)

	# 🔗 Connect collection singleton signals
	if not CardCollection.is_connected("card_added", Callable(self, "_on_card_added_signal")):
		CardCollection.connect("card_added", Callable(self, "_on_card_added_signal"))
	if not CardCollection.is_connected("card_count_changed", Callable(self, "_on_card_count_changed")):
		CardCollection.connect("card_count_changed", Callable(self, "_on_card_count_changed"))

	# 🧾 Cache label nodes
	card_name_label = left_panel.get_node_or_null("CardName/Name")
	rarity_label = left_panel.get_node_or_null("CardName/Rarity")
	cost_label = left_panel.get_node_or_null("CardName/Cost/CostLabel")
	atk_label = left_panel.get_node_or_null("Panel/Border/HBoxContainer/ATK")
	def_label = left_panel.get_node_or_null("Panel/Border/HBoxContainer/DEF")
	subtype_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Subtype")
	abilities_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Abilities")
	ability_desc_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Ability Description")
	description_label = left_panel.get_node_or_null("ScrollContainer/VBoxContainer/Description")
	art_texture_rect = left_panel.get_node_or_null("Panel/Art")
	art_border = left_panel.get_node_or_null("Panel/Border")
	_clear_left_panel()
	
	print("[CollectionGUI] ✅ Ready – drag/drop initialized.")

# ==========================================================
# 🖱️ CARD INTERACTION (Click + Hover)
# ==========================================================
func _on_card_hovered(card_data: CardData):
	if selected_card and selected_card == card_data:
		return
	_update_left_panel(card_data, true)

func _on_card_unhovered(card_data: CardData = null):
	if selected_card:
		_update_left_panel(selected_card)
	else:
		_clear_left_panel()

func _on_card_clicked(event: InputEvent, card_ui):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var parent_grid = card_ui.get_parent()

		# --- Move from Collection to Deck ---
		if deck_collection_grid.is_ancestor_of(card_ui) or parent_grid == deck_collection_grid:
			_move_card_to_deck(card_ui.card_data)
			card_ui.queue_free()
			print("[DeckBuilder] ➕ Moved", card_ui.card_data.name, "→ Deck")

		# --- Move from Deck to Collection ---
		elif deck_grid.is_ancestor_of(card_ui) or parent_grid == deck_grid:
			_move_card_to_collection(card_ui.card_data)
			card_ui.queue_free()
			print("[DeckBuilder] ↩️ Moved", card_ui.card_data.name, "→ Collection")

		selected_card = card_ui.card_data
		_update_left_panel(selected_card)

func _move_card_to_deck(card_data: CardData):
	if deck_grid.get_child_count() >= 10:
		print("[DeckBuilder] ⚠️ Deck full!")
		return
	for child in deck_grid.get_children():
		if child.card_data and child.card_data.id == card_data.id:
			print("[DeckBuilder] ⚠️ Already in deck:", card_data.name)
			return

	var card_ui_scene := preload("res://UI/CardUI.tscn")
	var new_card_ui: Control = card_ui_scene.instantiate()
	new_card_ui.card_data = card_data
	new_card_ui.refresh()
	deck_grid.add_child(new_card_ui)
	new_card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(new_card_ui))

func _move_card_to_collection(card_data: CardData):
	var card_ui_scene := preload("res://UI/CardUI.tscn")
	var new_card_ui: Control = card_ui_scene.instantiate()
	new_card_ui.card_data = card_data
	new_card_ui.refresh()
	deck_collection_grid.add_child(new_card_ui)
	new_card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(new_card_ui))

# ==========================================================
# 🧩 ADD/REMOVE CARDS
# ==========================================================
func _populate_existing_cards():
	for id in CardCollection.get_all_cards():
		var data = CardCollection.get_card_data(id)
		if data:
			_add_card_to_gui(data)

func _add_card_to_gui(card_data: CardData):
	if not card_data or displayed_cards.has(card_data.id):
		return
	displayed_cards[card_data.id] = true

	var card_ui_scene := preload("res://UI/CardUI.tscn")

	var card_ui: Control = card_ui_scene.instantiate()
	card_ui.card_data = card_data
	card_ui.refresh()
	main_panel.add_child(card_ui)

	# Connect hover/click
	card_ui.connect("request_show_zoom", Callable(self, "_on_card_hovered"))
	card_ui.connect("request_hide_zoom", Callable(self, "_on_card_unhovered"))
	card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(card_ui))
	card_ui.connect("request_return_to_collection", Callable(self, "_on_card_return_requested"))

	# Mirror in deck builder’s collection grid
	var deck_card_ui: Control = card_ui_scene.instantiate()
	deck_card_ui.card_data = card_data
	deck_card_ui.refresh()
	deck_collection_grid.add_child(deck_card_ui)

	# 🟢 Make these clickable too
	deck_card_ui.connect("gui_input", Callable(self, "_on_card_clicked").bind(deck_card_ui))
	deck_card_ui.connect("request_show_zoom", Callable(self, "_on_card_hovered"))
	deck_card_ui.connect("request_hide_zoom", Callable(self, "_on_card_unhovered"))


func _on_card_added_signal(card: CardData, count: int):
	if displayed_cards.has(card.id):
		return
	print("[CollectionGUI] ➕ Card added:", card.name, "x", count)
	_add_card_to_gui(card)

func _on_card_return_requested(card_data: CardData):
	if not card_data:
		return

	var card_ui_scene := preload("res://UI/CardUI.tscn")
	var new_card_ui: Control = card_ui_scene.instantiate()
	new_card_ui.card_data = card_data
	new_card_ui.refresh()
	deck_collection_grid.add_child(new_card_ui)

	print("[DeckBuilder] ↩️ Returned", card_data.name, "to collection")

	for child in deck_grid.get_children():
		if child.card_data and child.card_data.id == card_data.id:
			child.queue_free()
			print("[DeckBuilder] ❌ Removed", card_data.name, "from deck grid")
			break

# ==========================================================
# 🧾 LEFT PANEL UPDATES
# ==========================================================
func _update_left_panel(card_data: CardData, temporary := false):
	if not card_data:
		return
	if card_name_label: card_name_label.text = card_data.name
	if rarity_label: rarity_label.text = str(card_data.rarity).capitalize()
	if cost_label: cost_label.text = str(card_data.cost)
	if atk_label: atk_label.text = str(card_data.atk)
	if def_label: def_label.text = str(card_data.def)
	if subtype_label:
		subtype_label.text = ", ".join(card_data.types) if card_data.types.size() > 0 else "-"
	if abilities_label: abilities_label.text = card_data.get_ability_name()
	if ability_desc_label: ability_desc_label.text = card_data.get_ability_description()
	if description_label: description_label.text = card_data.description
	if art_texture_rect and card_data.art:
		art_texture_rect.texture = card_data.art
	if art_border: art_border.visible = true

func _clear_left_panel():
	for label in [card_name_label, rarity_label, cost_label, atk_label, def_label, subtype_label, abilities_label, ability_desc_label, description_label]:
		if label:
			label.text = ""
	if art_texture_rect:
		art_texture_rect.texture = null
	art_border.visible = false

# ==========================================================
# 🧭 PANEL SWITCHING
# ==========================================================
func _on_leader_button_pressed() -> void:
	collection_panel.visible = false
	deck_panel.visible = false
	leader_panel.visible = true
	main_panel_label.text = "Leader Selection"

func _on_deck_button_pressed() -> void:
	collection_panel.visible = false
	deck_panel.visible = true
	leader_panel.visible = false
	main_panel_label.text = "Deck Builder"

func _on_collection_button_pressed() -> void:
	collection_panel.visible = true
	deck_panel.visible = false
	leader_panel.visible = false
	main_panel_label.text = "Card Collection"


func _on_x_pressed() -> void:
	player._toggle_collection()
