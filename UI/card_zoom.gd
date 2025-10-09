extends Control

@onready var art = $VBoxContainer/Art
@onready var name_label = $VBoxContainer/NameLabel
@onready var stats_label = $VBoxContainer/StatsLabel
@onready var desc_label = $VBoxContainer/DescLabel

func show_card(card: CardData):
	if not card:
		return

	art.texture = card.art
	name_label.text = card.name
	stats_label.text = "ATK: %d | DEF: %d | Cost: %d" % [card.attack, card.defense, card.cost]

	# ✅ Safe property check
	if "description" in card and card.description != "":
		desc_label.text = card.description
	else:
		desc_label.text = "No description."

	# fade-in / scale animation
	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	show()

	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.tween_property(self, "scale", Vector2(1, 1), 0.25)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		hide()
