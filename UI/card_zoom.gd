extends Control

@onready var art = $VBoxContainer/Art
@onready var name_label = $VBoxContainer/NameLabel
@onready var desc_label = $VBoxContainer/DescLabel
@onready var rarity_label = $VBoxContainer/RarityLabel

const RARITY_NAMES = ["Common", "Rare", "Epic", "Legendary"]

func show_card(card: CardData):
	if card == null:
		hide()
		return

	art.texture = card.art
	name_label.text = card.name
	desc_label.text = card.description
	rarity_label.text = card.rarity  # Map enum to text
	
	# Place near the mouse, slightly offset
	var mouse_pos = get_viewport().get_mouse_position()
	global_position = mouse_pos + Vector2(30, 30)
	show()
