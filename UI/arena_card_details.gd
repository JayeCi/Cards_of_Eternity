extends Control
class_name ArenaCardDetails

# --- UI ELEMENTS ---
@onready var art: TextureRect = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/Art
@onready var name_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var rarity_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Rarity
@onready var cost_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Cost
@onready var abilities_label: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/Abilities
@onready var abilities_name: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/AbilitiesName
@onready var abilities_desc: Label = $MarginContainer/PanelContainer/MarginContainer/HBoxContainer/VBoxContainer/AbilitiesDesc

@onready var terrain: TextureRect = $MarginContainer/PanelContainer/MarginContainer/Terrain
@onready var terrain_label: Label = $MarginContainer/PanelContainer/MarginContainer/TerrainLabel

# --- Combat stats ---

@onready var atk_label: Label = $VBoxContainer2/AtkLabel
@onready var atk: Label = $VBoxContainer2/Atk
@onready var def_label: Label = $VBoxContainer2/DefLabel
@onready var def: Label = $VBoxContainer2/Def

var current_unit: UnitData = null
var last_bonus_state: String = "neutral"  # "buff", "debuff", or "neutral"

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
		atk.add_theme_color_override("font_color", Color(1,1,1))
		def.add_theme_color_override("font_color", Color(1,1,1))
		last_bonus_state = "neutral"
func show_card(card: CardData) -> void:
	if not card:
		hide_card()
		return

	current_unit = null
	visible = true

	# --- Basic Info ---
	if art:
		art.texture = card.art if card.art else null

	name_label.text = card.name
	rarity_label.text = "Rarity: %s" % str(card.rarity)
	cost_label.text = "Cost: %d" % int(card.cost)

	# --- ATK / DEF (static card stats) ---
	if "atk" in card:
		atk.text = str(card.atk)
	else:
		atk.text = "—"
	if "def" in card:
		def.text = str(card.def)
	else:
		def.text = "—"

	atk_label.visible = true
	def_label.visible = true

	# --- Abilities ---
	if card.ability and "display_name" in card.ability:
		abilities_name.text = str(card.ability.display_name)
		abilities_desc.text = str(card.ability.description)
	else:
		abilities_name.text = "—"
		abilities_desc.text = ""

	# --- Terrain info (hide for hand preview) ---
	if terrain:
		terrain.visible = false
	if terrain_label:
		terrain_label.text = ""

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
	
	if card.ability and "display_name" in card.ability:
		abilities_name.text = str(card.ability.display_name)
		abilities_desc.text = str(card.ability.description)
	else:
		abilities_name.text = "—"
		abilities_desc.text = ""

	
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




	# --- Apply terrain-based color tint ---
	var core_node := get_tree().get_root().find_child("Arena3D", true, false)
	if core_node and core_node.has_method("get_terrain_for_unit"):
		var terrain_type = core_node.get_terrain_for_unit(unit)
		if terrain_type != "":
			show_terrain(terrain_type)
			# 👇 determine terrain multiplier for color tint
			if core_node.has_method("get_terrain_multiplier"):
				var mult = core_node.get_terrain_multiplier(unit, terrain_type)
				set_stat_color_from_bonus(mult)

func hide_card() -> void:
	current_unit = null
	visible = false

func refresh_if_showing(unit: UnitData) -> void:
	if not visible or not current_unit:
		return
	if unit and unit == current_unit:
		show_unit(unit)

func show_terrain(terrain_type: String) -> void:
	if not terrain:
		print("❌ Terrain node not found!")
		return

	var texture: Texture2D = null

	if Engine.has_singleton("TerrainTextures"):
		var tman = Engine.get_singleton("TerrainTextures")
		texture = tman.TERRAIN_TEXTURES.get(terrain_type, null)
	else:
		# fallback if not autoloaded
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
