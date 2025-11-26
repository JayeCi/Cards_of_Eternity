extends Control

@export var card_data: CardData

@onready var art = $MarginContainer/Art
@onready var name_label = $MarginContainer/VBoxContainer2/Name
@onready var border: TextureRect = $Border

@onready var atk: Label = $MarginContainer/ATK
@onready var def: Label = $MarginContainer/DEF

@onready var cost: Label = $MarginContainer/VBoxContainer/Cost
@onready var fusion_glow: TextureRect = $FusionGlow
@onready var fusion_icon: TextureRect = $FusionIcon
@onready var quantity_label: Label = $QuantityLabel
@onready var ability_indicator = $Border/AbilityIndicator

@onready var fire_ball: AnimatedSprite2D = $FireBall
@onready var water_ball: AnimatedSprite2D = $WaterBall
@onready var earth_ball: AnimatedSprite2D = $EarthBall
@onready var shadow_ball: AnimatedSprite2D = $ShadowBall
@onready var wind_ball: AnimatedSprite2D = $WindBall

var _element_to_node := {}
var _all_balls: Array[AnimatedSprite2D] = []
signal request_show_zoom(card)
signal request_hide_zoom()
signal request_return_to_collection(card)

var is_hovering := false
var hover_timer: Timer

# 🔹 Preload rarity textures
const RARITY_TEXTURES := {
	"common": preload("res://UI/Rarity/common.png"),
	"uncommon": preload("res://UI/Rarity/uncommon.png"),
	"rare": preload("res://UI/Rarity/rare.jpg"),
	"epic": preload("res://UI/Rarity/epic.png"),
	"legendary": preload("res://UI/Rarity/legendary.png"),
	"mythic": preload("res://UI/Rarity/mythic.png"),
}

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_focus_mode(Control.FOCUS_NONE)
	set_drag_forwarding(Callable(self, "_get_drag_data"), Callable(self, "_can_drop_data"), Callable(self, "_drop_data"))


	connect_mouse_signals()
	_disable_child_mouse_filters(self)
	_make_unique_label_settings(self)

	await get_tree().process_frame
	if card_data:
		refresh()

	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = 0.05
	add_child(hover_timer)
	
	_element_to_node = {
		"fire":   fire_ball,
		"water":  water_ball,
		"earth":  earth_ball,
		"wind":   wind_ball,
		"shadow": shadow_ball,
	}
	_all_balls = [fire_ball, water_ball, earth_ball, wind_ball, shadow_ball]  # ✅ typed
	_hide_all_element_balls()
	_update_element_ball()
	#print("[CardUI] Ready:", card_data.name if card_data else "No data")

# -------------------------------
# Utility: Recursively clone LabelSettings for each Label
# -------------------------------
func _make_unique_label_settings(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			if child.label_settings:
				child.label_settings = child.label_settings.duplicate() # deep copy
			else:
				child.label_settings = LabelSettings.new()
		_make_unique_label_settings(child) # recurse through children

func set_quantity(count: int):
	if not quantity_label:
		return
	if count > 1:
		quantity_label.visible = true
		quantity_label.text = "x" + str(count)
	else:
		quantity_label.visible = false
# -------------------------------
# Debugging hover and clicks
# -------------------------------
func _gui_input(event: InputEvent) -> void:
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		emit_signal("request_return_to_collection", card_data)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("[CardUI] 🖱️ Clicked on:", card_data.name)
		emit_signal("request_show_zoom", card_data)


func connect_mouse_signals():
	connect("mouse_entered", Callable(self, "_on_mouse_enter"))
	connect("mouse_exited", Callable(self, "_on_mouse_exit"))
	#print("[CardUI] Signals connected for:", card_data.name if card_data else "Unknown Card")

# ==========================================================
# ✨ Hover Animation
# ==========================================================
@export var hover_scale := Vector2(1.1, 1.1)
@export var hover_duration := 0.12
@export var hover_glow_modulate := Color(1.2, 1.2, 1.2, 1.0)

var _hover_tween: Tween
var _base_modulate := Color(1, 1, 1, 1)

func _on_mouse_enter():
	if is_hovering:
		return
	is_hovering = true
	
	_start_hover_animation(true)
	emit_signal("request_show_zoom", card_data)

func _on_mouse_exit():
	if not is_hovering:
		return
	is_hovering = false
	_start_hover_animation(false)
	emit_signal("request_hide_zoom")

func _start_hover_animation(entering: bool):
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()

	# 🧩 Determine if this card is playable before brightening
	var cost := 1
	if card_data:
		if card_data.has_meta("cost"):
			cost = int(card_data.get_meta("cost"))
		elif card_data.has_method("get_cost"):
			cost = card_data.get_cost()
		elif "cost" in card_data:
			cost = int(card_data.cost)

	var player_essence := 0
	var tree := get_tree()
	if tree and tree.root:
		var core := tree.root.get_node_or_null("Arena3D")
		if core and "player_essence" in core:
			player_essence = core.player_essence

	var can_play := cost <= player_essence

	# 🟢 Only brighten playable cards
	if entering:
		_hover_tween.tween_property(self, "scale", hover_scale, hover_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		if can_play:
			_hover_tween.parallel().tween_property(self, "modulate", hover_glow_modulate, hover_duration)
	else:
		_hover_tween.tween_property(self, "scale", Vector2.ONE, hover_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		# Only tween modulate back if the card is playable (was brightened on hover)
		if can_play:
			_hover_tween.parallel().tween_property(self, "modulate", _base_modulate, hover_duration)

# -------------------------------
# Mouse filter safety
# -------------------------------
func _disable_child_mouse_filters(node: Node):
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_disable_child_mouse_filters(child)

func hide_labels() -> void:
	if name_label: name_label.visible = false
	if atk: atk.visible = false
	if def: def.visible = false
	if cost: cost.visible = false

# -------------------------------
# Refresh visuals
# -------------------------------
func refresh():
	if card_data == null:
		print("[CardUI] ⚠️ refresh() called with null data")
		if name_label: name_label.text = ""
		if art: art.texture = null
		if atk: atk.text = ""
		if def: def.text = ""
		if cost: cost.text = ""
		return
	if atk and def:
		atk.visible = true
		def.visible = true
	#print("[CardUI] Refreshing card:", card_data.name)
	if name_label:
		name_label.text = card_data.name
		# 🎨 Set shadow color based on rarity
		if name_label.label_settings:
			name_label.label_settings.shadow_color = _get_rarity_shadow_color(card_data.rarity)
	if art: art.texture = card_data.art
	if cost: cost.text = str(card_data.cost)
	_update_element_ball()
	# 🧩 Only set ATK/DEF for Monster cards
	if card_data.card_type == CardData.CardType.MONSTER:
		if atk: atk.text = str(card_data.atk)
		if def: def.text = str(card_data.def)
	else:
		if atk:
			atk.visible = false
		if def:
			def.visible = false
		# 🛑 Skip setting ATK/DEF for non-monsters
		pass

	# 🎨 Tint border based on card type
	if border:
		match card_data.card_type:
			CardData.CardType.SPELL:
				border.modulate = Color(0.003, 0.0, 0.588, 1.0)  # Light blue for magic/spell cards
			CardData.CardType.EVENT:
				border.modulate = Color(0.447, 0.0, 1.0, 1.0)  # Light purple for event cards
			_:
				border.modulate = Color(1.0, 1.0, 1.0, 1.0)  # Default white for monsters

	# 🔮 Show AbilityIndicator only if card has abilities
	if ability_indicator:
		var has_ability := _card_has_ability(card_data)
		print("[CardUI] Card:", card_data.name, "has_ability:", has_ability, "ability:", card_data.ability, "ability_name:", card_data.ability_name if "ability_name" in card_data else "N/A")
		ability_indicator.visible = has_ability
	else:
		print("[CardUI] ⚠️ AbilityIndicator node not found!")

# --- Helpers ---
func _hide_all_element_balls() -> void:
	for b in _all_balls:
		if b:
			b.visible = false
			if b.sprite_frames:
				b.stop()

func _update_element_ball() -> void:
	_hide_all_element_balls()
	if card_data == null:
		return

	var elem := _resolve_element(card_data)
	if elem == "":
		return

	var node: AnimatedSprite2D = _element_to_node.get(elem, null)
	if node:
		node.visible = true
		if node.sprite_frames and node.sprite_frames.has_animation("default"):
			node.play("default")  # or whichever animation name you use

func _resolve_element(cd: CardData) -> String:
	var e

	# 1) direct property
	if cd.has_method("get"):
		e = cd.get("element")

	# 2) custom getter
	if e == null and cd.has_method("get_element"):
		e = cd.get_element()

	# 3) fallback: types array
	if e == null and cd.has_method("get"):
		var types = cd.get("types")
		if types is Array:
			for t in types:
				var tl := str(t).to_lower()
				if _element_to_node.has(tl):
					e = tl
					break

	if e == null:
		return ""

	# Normalize
	if typeof(e) == TYPE_INT:
		var enum_map := { 0:"fire", 1:"water", 2:"earth", 3:"wind", 4:"shadow" }
		return enum_map.get(e, "")
	else:
		return str(e).to_lower()

# -------------------------------
# Card Ability Check Helper
# -------------------------------
func _card_has_ability(card: CardData) -> bool:
	"""Check if a card has any abilities"""
	if not card:
		return false

	# Check if ability object exists
	if card.ability != null:
		return true

	# Check if ability name is defined
	if card.has_method("get_ability_name"):
		var ability_name := card.get_ability_name()
		if ability_name and not ability_name.is_empty():
			return true

	# Check if ability description is defined
	if card.has_method("get_ability_description"):
		var ability_desc := card.get_ability_description()
		if ability_desc and not ability_desc.is_empty():
			return true

	return false

# -------------------------------
# Rarity Shadow Color Helper
# -------------------------------
func _get_rarity_shadow_color(rarity: String) -> Color:
	"""Return shadow color based on rarity tier"""
	match rarity.to_lower():
		"common":
			return Color(0.5, 0.5, 0.5, 1.0)  # Grey
		"uncommon":
			return Color(1.0, 1.0, 1.0, 1.0)  # White
		"rare":
			return Color(0.3, 0.6, 1.0, 1.0)  # Blue
		"epic":
			return Color(0.8, 0.3, 1.0, 1.0)  # Purple
		"legendary":
			return Color(1.0, 0.6, 0.1, 1.0)  # Orange
		"mythic":
			return Color(1.0, 0.2, 0.2, 1.0)  # Red
		_:
			return Color(1.0, 1.0, 1.0, 1.0)  # Default white

# State display
# -------------------------------
func set_playable(is_playable: bool):
	if not card_data:
		return

	# 🩹 Prevent early-call crash
	if not is_inside_tree():
		await ready
		if not is_inside_tree():
			return

	var cost := int(card_data.get_meta("cost")) if card_data.has_meta("cost") else int(card_data.cost)
	var player_essence := 0

	var tree := get_tree()
	if tree and tree.root:
		var core := tree.root.get_node_or_null("Arena3D")
		if core and "player_essence" in core:
			player_essence = core.player_essence

	var can_play := is_playable and cost <= player_essence
	_base_modulate = Color(1, 1, 1, 1) if can_play else Color(0.4, 0.4, 0.4, 0.5)
	modulate = _base_modulate

func show_fusion_glow(on: bool = true) -> void:
	if not fusion_glow:
		return
	fusion_glow.visible = on
	if on:
		# Optionally reset shader params if animated glow is time-based
		if fusion_glow.material and fusion_glow.material.has_method("glow_strength"):
			fusion_glow.material.set("shader_param/glow_strength", 1.5)
	else:
		fusion_glow.visible = false
		

func _add_card_to_deck(card_data: CardData):
	var card_ui_scene := preload("res://UI/CardUI.tscn")
	var card_ui: Control = card_ui_scene.instantiate()
	card_ui.card_data = card_data
	card_ui.refresh()
	card_ui.modulate = Color(0.8, 1.0, 0.8) # visual cue

	# Right-click to remove from deck
	card_ui.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			card_ui.queue_free()
			print("[DeckBuilder] ❌ Removed card from deck:", card_data.name)
	)

	print("[DeckBuilder] ➕ Added card to deck:", card_data.name)


# ====================================
# FUSION ICON PULSE ANIMATION
# ====================================

var _fusion_pulse_tween: Tween = null

func start_fusion_icon_pulse():
	if not fusion_icon:
		return
	fusion_icon.visible = true

	# Kill existing tween if running
	if _fusion_pulse_tween and _fusion_pulse_tween.is_running():
		_fusion_pulse_tween.kill()

	# Create infinite pulsing animation
	_fusion_pulse_tween = create_tween()
	_fusion_pulse_tween.set_loops(0)  # Infinite loops
	_fusion_pulse_tween.tween_property(fusion_icon, "scale", Vector2(1.2, 1.2), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fusion_pulse_tween.tween_property(fusion_icon, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop_fusion_icon_pulse():
	# Kill tween if running
	if _fusion_pulse_tween and _fusion_pulse_tween.is_running():
		_fusion_pulse_tween.kill()

	# Hide icon and reset scale
	if fusion_icon:
		fusion_icon.visible = false
		fusion_icon.scale = Vector2(1.0, 1.0)
