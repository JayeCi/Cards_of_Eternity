extends Control

@onready var art = $MarginContainer/VBoxContainer/Card/Art
@onready var name_label = $MarginContainer/VBoxContainer/NamePlate/NameLabel
@onready var desc = $Panel/DescriptionContainer/VBoxContainer/Desc
@onready var attack_label = $Stats/AtkPlate/Atk
@onready var defense_label = $Stats/DefPlate/Def
@onready var rarity_label: Label = $MarginContainer/VBoxContainer/Card/Rarity
@onready var ability_name = $Panel/MarginContainer/AbilitiesContainer/Ability_name
@onready var ability_desc = $Panel/MarginContainer/AbilitiesContainer/Ability_desc
@onready var types_label: Label = $Panel/DescriptionContainer/VBoxContainer/Types

func _ready():
	set_process_unhandled_input(true)
	set_process_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP


func show_card(card: CardData):
	if not card:
		return

	# --- Basic visuals ---
	art.texture = card.art
	name_label.text = card.name
	attack_label.text = str(card.atk)
	defense_label.text = str(card.def)

	# --- Rarity handling ---
	var rarity_text := "Common"
	var rarity_color := Color(0.8, 0.8, 0.8)  # default gray

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
				rarity_color = Color(0.4, 0.6, 1.0)
			"epic":
				rarity_text = "Epic"
				rarity_color = Color(0.7, 0.4, 1.0)
			"legendary":
				rarity_text = "Legendary"
				rarity_color = Color(1.0, 0.7, 0.3)
			"mythic":
				rarity_text = "Mythic"
				rarity_color = Color(0.9, 0.2, 1.0)
			_:
				rarity_text = str(card.rarity)
				rarity_color = Color(1, 1, 1)

	# Apply rarity text + color
	rarity_label.text = rarity_text
	rarity_label.add_theme_color_override("font_color", rarity_color)

	# --- Type display (multi-type array support) ---
	if "types" in card and card.types and card.types.size() > 0:
		types_label.text = " / ".join(card.types)
	else:
		types_label.text = "—"

	# --- Description ---
	if "description" in card and card.description != "":
		desc.text = card.description
	else:
		desc.text = "No description."

	# --- Ability info ---
	if card.ability:
		ability_name.text = card.ability.display_name
		ability_desc.text = card.ability.description
	else:
		ability_name.text = "No ability"
		ability_desc.text = ""

	# --- Intro animation ---
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
		_hide_zoom()


func _hide_zoom():
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): hide())
