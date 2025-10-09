extends Control

@export var card_ui_scene: PackedScene = preload("res://ui/CardUI.tscn")

@onready var grid = $ScrollContainer/GridContainer
@onready var zoom = $CardZoom

# ✅ Track which cards are displayed (by card.resource_path)
var displayed_cards := {}  # { "CARD_ID": card_ui_node }

func _ready():
	CardCollection.connect("card_added", Callable(self, "_on_card_added"))
	_load_existing_cards()

func _load_existing_cards():
	for card_id in CardCollection.get_all_cards():
		var card_data = CardCollection.get_card_data(card_id)
		var count = CardCollection.get_card_count(card_id)
		_add_or_update_card_ui(card_data, count)

func _on_card_added(card: CardData, count: int) -> void:
	_add_or_update_card_ui(card, count)

func _add_or_update_card_ui(card: CardData, count: int) -> void:
	if card == null or card.resource_path == "":
		return

	# ✅ Update existing card if already shown
	print("Checking for existing UI:", card.name, "id =", card.resource_path)
	print("Currently displayed IDs:", displayed_cards.keys())

	if displayed_cards.has(card.resource_path):
		var card_ui = displayed_cards[card.resource_path]
		var label = card_ui.get_node_or_null("CountLabel")
		if label:
			label.text = "x" + str(count)
			# Optional: small visual feedback
			var t = create_tween()
			t.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
			t.tween_property(label, "scale", Vector2(1, 1), 0.1)
		return

	# ✅ Otherwise create new card UI
	var card_ui = card_ui_scene.instantiate()
	card_ui.card_data = card
	card_ui.refresh()

	var label = card_ui.get_node_or_null("CountLabel")
	if label:
		label.text = "x" + str(count)

	grid.add_child(card_ui)
	displayed_cards[card.resource_path] = card_ui  # ✅ store by card.resource_path

func _on_card_hovered(card: CardData):
	zoom.show_card(card)

func _on_card_hover_exit():
	zoom.hide()
