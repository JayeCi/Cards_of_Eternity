extends Control

signal deck_selected(selected_index: int)

@onready var deck_grid: GridContainer = $DeckGrid
var _decks: Array = []  # will store arrays of CardData

func _ready():
	visible = false  # hidden until revealed

	# Connect all deck buttons
	for i in range(deck_grid.get_child_count()):
		var btn := deck_grid.get_child(i)
		if btn is Button:
			btn.pressed.connect(_on_deck_pressed.bind(i))

func show_decks(deck_defs: Array):
	_decks = deck_defs
	visible = true

func _on_deck_pressed(index: int):
	emit_signal("deck_selected", index)
	visible = false
