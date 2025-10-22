extends Control

@export var card_data: CardData

@onready var art = $MarginContainer/Art
@onready var name_label = $MarginContainer/Name

@onready var atk: Label = $MarginContainer/ATK
@onready var def: Label = $MarginContainer/DEF

@onready var cost: Label = $MarginContainer/Cost

signal request_show_zoom(card)
signal request_hide_zoom()

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
	connect_mouse_signals()
	_disable_child_mouse_filters(self)

	# ✅ Make all labels have their own unique LabelSettings
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


# -------------------------------
# Debugging hover and clicks
# -------------------------------
func _gui_input(event: InputEvent) -> void:
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

		return

	print("[CardUI] Refreshing card:", card_data.name)
	if name_label: name_label.text = card_data.name
	if art: art.texture = card_data.art
	if atk: atk.text = str(card_data.atk)
	if def: def.text = str(card_data.def)
	if cost: cost.text = str(card_data.cost)
# -------------------------------
# State display
# -------------------------------
func set_playable(is_playable: bool):
	print("[CardUI] Playable state for", card_data.name, "=", is_playable)
	modulate = Color(1, 1, 1, 1) if is_playable else Color(0.4, 0.4, 0.4, 0.5)
