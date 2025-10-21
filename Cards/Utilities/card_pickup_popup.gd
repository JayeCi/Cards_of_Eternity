extends Control

@onready var art: TextureRect = $PanelContainer/HBoxContainer/TextureRect
@onready var name_label: Label = $"PanelContainer/HBoxContainer/VBoxContainer/Card Name"
@onready var rarity_label: Label = $PanelContainer/HBoxContainer/VBoxContainer/Rarity

func show_card(card: CardData):
	if not card:
		return

	# --- Basic visuals ---
	art.texture = card.art
	name_label.text = card.name

	# --- Handle rarity ---
	var rarity_text := "Common"
	var rarity_color := Color(0.8, 0.8, 0.8) # default grayish white

	if "rarity" in card and card.rarity != "":
		match card.rarity.to_lower():
			"common":
				rarity_text = "Common"
				rarity_color = Color(0.8, 0.8, 0.8)
			"uncommon":
				rarity_text = "Uncommon"
				rarity_color = Color(0.5, 1.0, 0.5)
			"rare":
				rarity_text = "Rare"
				rarity_color = Color(0.001, 0.31, 0.964, 1.0)
			"epic":
				rarity_text = "Epic"
				rarity_color = Color(0.305, 0.001, 0.501, 1.0)
			"legendary":
				rarity_text = "Legendary"
				rarity_color = Color(0.894, 0.286, 0.0, 1.0)
			"mythic":
				rarity_text = "Mythic"
				rarity_color = Color(1.0, 0.059, 0.0, 1.0)
			_:
				rarity_text = card.rarity.capitalize()
				rarity_color = Color(1, 1, 1)

	rarity_label.text = rarity_text
	rarity_label.modulate = rarity_color

	# --- Appear / fade animation ---
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	show()

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.tween_interval(2.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): hide())
