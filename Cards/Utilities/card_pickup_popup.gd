extends Control

@onready var art: TextureRect = $PanelContainer/HBoxContainer/TextureRect
@onready var name_label: Label = $"PanelContainer/HBoxContainer/VBoxContainer/Card Name"
@onready var rarity_label: Label = $PanelContainer/HBoxContainer/VBoxContainer/Rarity

func show_card(card: CardData):
	if not card:
		return

	# Basic visuals
	art.texture = card.art
	name_label.text = card.name

	# Handle rarity (optional property)
	var rarity_text := "Common"
	var rarity_color := Color.WHITE
	if "rarity" in card:
		match card.rarity:
			"Rare":
				rarity_text = "Rare"
				rarity_color = Color(0.2, 0.6, 1.0)
			"Epic":
				rarity_text = "Epic"
				rarity_color = Color(0.8, 0.2, 1.0)
			"Legendary":
				rarity_text = "Legendary"
				rarity_color = Color(1.0, 0.6, 0.1)

	rarity_label.text = rarity_text
	rarity_label.modulate = rarity_color

	# Start animation
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	show()

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): hide())
