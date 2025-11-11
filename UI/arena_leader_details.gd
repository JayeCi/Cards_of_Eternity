extends Control
class_name ArenaLeaderDetails

# --- UI ELEMENTS ---
@onready var art: TextureRect = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Art
@onready var name_label: Label = $MarginContainer/PanelContainer/NameLabel
@onready var rarity_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Rarity
@onready var cost_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Cost
@onready var type_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Type
@onready var description_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/ScrollContainer/VBoxContainer/Description

@onready var panel_container: PanelContainer = $MarginContainer/PanelContainer

# --- Data ---
var card_data: CardData = null
var current_unit: UnitData = null

# -------------------------------------------------------------
# RARITY COLORING
# -------------------------------------------------------------
func set_rarity_color(rarity: String) -> void:
	if not rarity_label:
		return

	var rarity_lower := rarity.to_lower()
	var color := Color(1, 1, 1) # default

	match rarity_lower:
		"common": color = Color(0.8, 0.8, 0.8)
		"uncommon": color = Color(0.5, 1.0, 0.5)
		"rare": color = Color(0.4, 0.6, 1.0)
		"epic": color = Color(0.414, 0.002, 0.67)
		"legendary": color = Color(0.626, 0.399, 0.0)
		"mythic": color = Color(1.0, 0.098, 0.0)
		_: color = Color(1, 1, 1)

	if rarity_label.label_settings == null:
		rarity_label.label_settings = LabelSettings.new()
	rarity_label.label_settings.font_color = color

# -------------------------------------------------------------
# SHOW LEADER CARD
# -------------------------------------------------------------
func show_card(card: CardData) -> void:
	if not card:
		hide_card()
		return

	card_data = card
	current_unit = null
	visible = true

	# Art
	if art:
		art.texture = card.art if card.art else null

	# Basic info
	name_label.text = card.name
	rarity_label.text = str(card.rarity)
	set_rarity_color(str(card.rarity))
	cost_label.text = "Cost: %d" % int(card.cost) if "cost" in card else "Cost: —"
	type_label.text = " / ".join(card.types) if card.types and card.types.size() > 0 else "Leader"

	# Description (leader ability or passive)
	if "description" in card:
		description_label.text = str(card.description)
	else:
		description_label.text = "No leader ability description."

	_apply_card_background(Color(0.25, 0.25, 0.25, 0.8))

# -------------------------------------------------------------
# SHOW LEADER UNIT INSTANCE
# -------------------------------------------------------------
func show_unit(unit: UnitData) -> void:
	if not unit or not unit.card:
		hide_card()
		return

	current_unit = unit
	card_data = unit.card
	visible = true

	var card = unit.card
	if art:
		art.texture = card.art if card.art else null

	name_label.text = card.name
	rarity_label.text = str(card.rarity)
	set_rarity_color(str(card.rarity))
	type_label.text = str(card.types)

	if card.description != "":
		description_label.text = str(card.description)
	else:
		description_label.text = "No ability description."

	# Differentiate by owner (player vs enemy)
	if unit.owner == 0:
		_apply_card_background(Color(0.2, 0.3, 0.9, 0.6))
	else:
		_apply_card_background(Color(0.9, 0.1, 0.1, 0.6))

# -------------------------------------------------------------
func _apply_card_background(color: Color) -> void:
	if not panel_container:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://UI/panel_ripple.gdshader")
	mat.set_shader_parameter("base_color", color)
	panel_container.material = mat

# -------------------------------------------------------------
func hide_card() -> void:
	card_data = null
	current_unit = null
	visible = false

# -------------------------------------------------------------
func refresh_if_showing(unit: UnitData) -> void:
	if not visible or not card_data:
		return
	show_unit(unit)
