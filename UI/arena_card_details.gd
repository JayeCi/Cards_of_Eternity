extends Control
class_name ArenaCardDetails

# --- UI ELEMENTS ---
@onready var art: TextureRect = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Art
@onready var name_label: Label = $MarginContainer/PanelContainer/NameLabel
@onready var rarity_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Rarity
@onready var cost_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Cost
#@onready var abilities_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Abilities
@onready var abilities_name: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/AbilitiesName
@onready var abilities_desc: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/ScrollContainer/VBoxContainer/AbilitiesDesc
@onready var description: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/ScrollContainer/VBoxContainer/Description
@onready var atk_spacer: Label = $VBoxContainer2/HBoxContainer/AtkSpacer
@onready var def_spacer: Label = $VBoxContainer2/HBoxContainer2/DefSpacer

@onready var terrain: TextureRect = $MarginContainer/PanelContainer/MarginContainer/Terrain
@onready var terrain_label: Label = $MarginContainer/PanelContainer/MarginContainer/TerrainLabel

# --- Combat stats ---
@onready var atk_label: Label = $VBoxContainer2/AtkLabel
@onready var atk: Label = $VBoxContainer2/HBoxContainer/Current_Atk
@onready var original_atk: Label = $VBoxContainer2/HBoxContainer/Original_Atk

@onready var def_label: Label = $VBoxContainer2/DefLabel
@onready var def: Label = $VBoxContainer2/HBoxContainer2/Current_Def
@onready var original_def: Label = $VBoxContainer2/HBoxContainer2/Original_Def

@onready var type_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Type
@onready var status_effects_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/StatusEffects
@onready var panel_container: PanelContainer = $MarginContainer/PanelContainer

# --- Data tracking ---
var card_data: CardData = null
var current_unit: UnitData = null
var last_bonus_state: String = "neutral"  # "buff", "debuff", or "neutral"

# -------------------------------------------------------------
# STAT COLORING
# -------------------------------------------------------------
func set_stat_color_from_bonus(mult: float) -> void:
	if mult > 1.0:
		atk.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		def.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		last_bonus_state = "buff"
	elif mult < 1.0:
		atk.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		def.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		last_bonus_state = "debuff"
	else:
		atk.add_theme_color_override("font_color", Color(1, 1, 1))
		def.add_theme_color_override("font_color", Color(1, 1, 1))
		last_bonus_state = "neutral"

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
# STATUS EFFECTS
# -------------------------------------------------------------
func update_status_effects(unit: UnitData) -> void:
	if not status_effects_label or not unit:
		return

	var status_texts: Array[String] = []

	# ❄️ Check for Frozen status
	if FrozenStatusEffect.is_frozen(unit):
		var turns_left = unit.get_meta("frozen_turns_remaining", 0)
		var frozen_text = "❄️ Frozen (%d turn%s)" % [turns_left, "s" if turns_left != 1 else ""]
		status_texts.append(frozen_text)

	# 🔮 Add more status effects here in the future
	# Example:
	# if unit.has_meta("poisoned"):
	#     var poison_text = "[color=#44FF44]☠️ Poisoned[/color]"
	#     status_texts.append(poison_text)

	# Display status effects or hide if none
	if status_texts.size() > 0:
		status_effects_label.text = " • ".join(status_texts)
		status_effects_label.visible = true
	else:
		status_effects_label.text = ""
		status_effects_label.visible = false

func show_card(card: CardData) -> void:
	if not card:
		hide_card()
		return

	card_data = card
	current_unit = null
	visible = true

	if art:
		art.texture = card.art if card.art else null

	name_label.text = card.name
	rarity_label.text = str(card.rarity)
	set_rarity_color(str(card.rarity))
	cost_label.text = "Cost: %d" % int(card.cost)
	description.text = str(card.description)

	if card.types and card.types.size() > 0:
		type_label.text = " / ".join(card.types)
	else:
		type_label.text = "—"

	# 🟩 Hide stats for Spell / Magic / Event cards
	if card.card_type in [CardData.CardType.SPELL, CardData.CardType.EVENT]:
		atk_spacer.visible = false
		def_spacer.visible = false
		atk.visible = false
		def.visible = false
		atk_label.visible = false
		def_label.visible = false
		original_atk.visible = false
		original_def.visible = false
	else:
		atk_spacer.visible = true
		def_spacer.visible = true
		atk.visible = true
		def.visible = true
		atk_label.visible = true
		def_label.visible = true
		original_atk.visible = true
		original_def.visible = true
		atk.text = str(card.atk)
		def.text = str(card.def)
		original_atk.text = str(card.atk)
		original_def.text = str(card.def)

	if card.ability and "display_name" in card.ability:
		abilities_name.text = str(card.ability.display_name)
		abilities_desc.text = str(card.ability.description)
	else:
		abilities_name.text = "—"
		abilities_desc.text = ""

	if terrain:
		terrain.visible = false
	if terrain_label:
		terrain_label.text = ""

	# Hide status effects for non-unit cards
	if status_effects_label:
		status_effects_label.text = ""
		status_effects_label.visible = false

	_apply_card_background(Color(0.2, 0.2, 0.2))


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
	cost_label.text = "Cost: %d" % int(card.cost)

	# 🟩 Hide stats for Leaders or Spell/Event cards
	if unit.is_leader or card.card_type in [CardData.CardType.SPELL, CardData.CardType.EVENT]:
		atk_spacer.visible = false
		def_spacer.visible = false
		atk.visible = false
		def.visible = false
		atk_label.visible = false
		def_label.visible = false
		original_atk.visible = false
		original_def.visible = false
	else:
		atk_spacer.visible = true
		def_spacer.visible = true
		atk.visible = true
		def.visible = true
		atk_label.visible = true
		def_label.visible = true
		original_atk.visible = true
		original_def.visible = true
		atk.text = str(unit.current_atk)
		def.text = str(unit.current_def)
		original_atk.text = str(card.atk)
		original_def.text = str(card.def)
		_update_stat_colors(unit, card)

	if card.types and card.types.size() > 0:
		type_label.text = " / ".join(card.types)
	else:
		type_label.text = "—"

	if card.ability and "display_name" in card.ability:
		abilities_name.text = str(card.ability.display_name)
		abilities_desc.text = str(card.ability.description)
	else:
		abilities_name.text = "—"
		abilities_desc.text = ""

	var core_node := get_tree().get_root().find_child("Arena3D", true, false)
	if core_node and core_node.has_method("get_terrain_for_unit"):
		var terrain_type = core_node.get_terrain_for_unit(unit)
		if terrain_type != "":
			show_terrain(terrain_type)
			if core_node.has_method("get_terrain_multiplier"):
				var mult = core_node.get_terrain_multiplier(unit, terrain_type)
				set_stat_color_from_bonus(mult)
	else:
		set_stat_color_from_bonus(1.0)

	if unit.owner == 0:
		_apply_card_background(Color(0.2, 0.3, 0.9, 0.6))
	else:
		_apply_card_background(Color(0.9, 0.1, 0.1, 0.6))

	# Update status effects display
	update_status_effects(unit)

# -------------------------------------------------------------
func _apply_card_background(color: Color) -> void:
	if not panel_container:
		return
	var mat := ShaderMaterial.new()
	mat.shader = load("res://UI/panel_ripple.gdshader")
	mat.set_shader_parameter("base_color", color)
	panel_container.material = mat


func _update_stat_colors(unit: UnitData, card: CardData) -> void:
	if atk.label_settings == null:
		atk.label_settings = LabelSettings.new()
	if def.label_settings == null:
		def.label_settings = LabelSettings.new()

	if unit.current_atk > card.atk:
		atk.label_settings.font_color = Color(0.4, 1.0, 0.4)
	elif unit.current_atk < card.atk:
		atk.label_settings.font_color = Color(1.0, 0.4, 0.4)
	else:
		atk.label_settings.font_color = Color(1, 1, 1)

	if unit.current_def > card.def:
		def.label_settings.font_color = Color(0.4, 1.0, 0.4)
	elif unit.current_def < card.def:
		def.label_settings.font_color = Color(1.0, 0.4, 0.4)
	else:
		def.label_settings.font_color = Color(1, 1, 1)

func hide_card() -> void:
	card_data = null
	current_unit = null
	visible = false

func refresh_if_showing(unit: UnitData) -> void:
	if not visible or not card_data:
		return
	var arena_core := get_tree().get_root().find_child("ArenaCore", true, false)
	if arena_core and arena_core.has_method("_get_unit_tile"):
		for pos in arena_core.units.keys():
			if arena_core.units[pos] == unit:
				unit = arena_core.units[pos]
				break
	show_unit(unit)
	# Ensure status effects are updated when refreshing
	if current_unit == unit:
		update_status_effects(unit)

func show_terrain(terrain_type: String) -> void:
	if not terrain:
		return

	var texture: Texture2D = null
	var path = "res://UI/Terrains/%s.png" % terrain_type.to_lower()
	if ResourceLoader.exists(path):
		texture = load(path)

	if texture:
		terrain_label.text = terrain_type
		terrain.texture = texture
		terrain.visible = true
	else:
		terrain.visible = false

func flash_stat_change(is_buff: bool) -> void:
	var color := Color(0.5, 1.0, 0.5) if is_buff else Color(1.0, 0.4, 0.4)
	var t = create_tween()
	t.tween_property(atk, "modulate", color, 0.15)
	t.parallel().tween_property(def, "modulate", color, 0.15)
	t.tween_property(atk, "modulate", Color(1,1,1), 0.3)
	t.parallel().tween_property(def, "modulate", Color(1,1,1), 0.3)
