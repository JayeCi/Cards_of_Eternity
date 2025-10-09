extends Control

@export var card_ui_scene: PackedScene = preload("res://ui/CardUI.tscn")

@onready var grid = $ScrollContainer/GridContainer
@onready var zoom = $CardZoom

func _ready():
	# Connect to CardCollection signal
	CardCollection.connect("card_added", Callable(self, "_on_card_added"))
	# Load all existing cards
	_load_existing_cards()

func _load_existing_cards():
	for card in CardCollection.get_all_cards():
		_add_card_ui(card)

func _on_card_added(card: CardData) -> void:
	_add_card_ui(card)

func _add_card_ui(card: CardData) -> void:
	var card_ui = card_ui_scene.instantiate()
	card_ui.card_data = card
	# connect hover signals
	card_ui.request_show_zoom.connect(Callable(self, "_on_card_hovered"))
	card_ui.request_hide_zoom.connect(Callable(self, "_on_card_hover_exit"))
	grid.add_child(card_ui)

func _on_card_hovered(card: CardData):
	zoom.show_card(card)

func _on_card_hover_exit():
	zoom.hide()
