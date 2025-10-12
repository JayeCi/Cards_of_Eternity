extends Control

@onready var art = $MarginContainer/VBoxContainer/Card/Art
@onready var name_label = $MarginContainer/VBoxContainer/NamePlate/NameLabel
@onready var desc = $Panel/DescriptionContainer/VBoxContainer/Desc
@onready var attack_label = $Stats/AtkPlate/Atk
@onready var defense_label = $Stats/DefPlate/Def
@onready var rarity_label = $MarginContainer/VBoxContainer/Card/Rarity
@onready var ability_name = $Panel/MarginContainer/AbilitiesContainer/Ability_name
@onready var ability_desc = $Panel/MarginContainer/AbilitiesContainer/Ability_desc

func _ready():
	set_process_unhandled_input(true)
	set_process_input(true)  # 🔹 add this line
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_card(card: CardData):
	if not card:
		return

	art.texture = card.art
	name_label.text = card.name
	attack_label.text = str(card.atk)
	defense_label.text = str(card.def)
	rarity_label = card.rarity
	
	if "description" in card and card.description != "":
		desc.text = card.description
	else:
		desc.text = "No description."
		
	# 🧩 Ability
	if card.ability:
		var ability = card.ability
		ability_name.text = card.ability.display_name
		ability_desc.text = card.ability.description
	else:
		ability_name.text = str("No ability")
		ability_desc.text = ""

	modulate.a = 0.0
	scale = Vector2(0.9, 0.9)
	show()

	var t = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.25)
	t.tween_property(self, "scale", Vector2(1, 1), 0.25)

func _input(event):
	if not visible:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		hide()


func _hide_zoom():
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): hide())
