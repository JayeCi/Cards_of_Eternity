extends Control

@export var card_data: CardData

@onready var art = $MarginContainer/Art
@onready var name_label = $MarginContainer/Name

@onready var atk: Label = $MarginContainer/ATK
@onready var def: Label = $MarginContainer/DEF

@onready var cost: Label = $MarginContainer/VBoxContainer/Cost
@onready var fusion_glow: TextureRect = $FusionGlow
@onready var quantity_label: Label = $QuantityLabel

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

	print("[CardUI] Ready:", card_data.name if card_data else "No data")

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
	print("[CardUI] Signals connected for:", card_data.name if card_data else "Unknown Card")


# -------------------------------
# Hover behavior
# -------------------------------
func _on_mouse_enter():
	if is_hovering:
		return
	is_hovering = true
	emit_signal("request_show_zoom", card_data)

func _on_mouse_exit():
	if not is_hovering:
		return
	is_hovering = false
	emit_signal("request_hide_zoom")


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
	print("[CardUI] Refreshing card:", card_data.name)
	if name_label: name_label.text = card_data.name
	if art: art.texture = card_data.art
	if cost: cost.text = str(card_data.cost)
	
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


# -------------------------------
# State display
# -------------------------------
func set_playable(is_playable: bool):
	print("[CardUI] Playable state for", card_data.name, "=", is_playable)
	modulate = Color(1, 1, 1, 1) if is_playable else Color(0.4, 0.4, 0.4, 0.5)

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
