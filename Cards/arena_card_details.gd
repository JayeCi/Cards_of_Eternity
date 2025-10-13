extends Control
class_name ArenaCardDetails

@onready var art: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Art
@onready var name_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var rarity_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Rarity
@onready var cost_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Cost
@onready var abilities_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Abilities
@onready var abilities_name: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/AbilitiesName

# --- Combat stats ---
@onready var atk_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/AtkLabel
@onready var atk: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/Atk
@onready var def_label: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/DefLabel
@onready var def: Label = $PanelContainer/MarginContainer/HBoxContainer/VBoxContainer2/Def

var current_unit: UnitData = null

func show_unit(unit: UnitData) -> void:
	if not unit or not unit.card:
		hide_card()
		return

	current_unit = unit
	visible = true

	var card = unit.card

	# --- Basic Info ---
	if art:
		art.texture = card.art if card.art else null

	name_label.text = card.name
	rarity_label.text = "Rarity: %s" % str(card.rarity)
	cost_label.text = "Cost: %d" % int(card.cost)
	abilities_label.text = "Abilities:"

	# --- ATK / DEF (using dynamic stats) ---
	atk.text = str(unit.current_atk)
	def.text = str(unit.current_def)

	atk_label.visible = true
	def_label.visible = true

	# --- Abilities ---
	var ability_list := []
	if card.ability:
		if typeof(card.ability) == TYPE_STRING:
			ability_list.append(card.ability)
		elif "name" in card.ability:
			ability_list.append(card.ability.name)
	abilities_name.text = ", ".join(ability_list) if ability_list.size() > 0 else "None"

func hide_card() -> void:
	current_unit = null
	visible = false

func refresh_if_showing(unit: UnitData) -> void:
	if not visible or not current_unit:
		return
	if unit and unit == current_unit:
		show_unit(unit)
