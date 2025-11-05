extends Control

@onready var tab: Button = $MarginContainer/Panel/MarginContainer/HBoxContainer/GridContainer/Tab
@onready var notification: Label = $MarginContainer/Panel/Notification

func _ready() -> void:
	# connect button
	tab.pressed.connect(_on_tab_pressed)

func _on_tab_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("_toggle_collection"):
		player._toggle_collection()
		
# 🚨 Make notification visible
func show_notification() -> void:
	notification.visible = true

# ✅ Hide when collection closes
func hide_notification() -> void:
	notification.visible = false
