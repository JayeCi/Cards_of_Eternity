extends MapNode
class_name PortalReturnNode

@export var hub_name: String = "Portal Hub"

@export var return_scene_path: String = "res://World/MAP/Portal_Hub.tscn"


@onready var click_sfx: AudioStreamPlayer = $ClickSFX if has_node("ClickSFX") else null

func _ready():
	self.pressed.connect(_on_pressed)

	# Assign a distinct texture for the portal node
	if not texture_normal:
		texture_normal = preload("res://World/MAP/portal_hub.png")
	#if not texture_hover:
		#texture_hover = preload("res://World/MAP/portal_hub_hover.png")

func _on_pressed():
	if not is_reachable:
		return
	
	if click_sfx:
		click_sfx.play()

	emit_signal("clicked", self)

	# Update info panel (if it exists)
	var map_screen := get_tree().get_first_node_in_group("map_screen")
	if map_screen and map_screen.has_method("show_encounter_info"):
		map_screen.show_encounter_info(self)

# ---------------------------------------------------------
# Called by map_screen when showing info
# ---------------------------------------------------------
func get_node_info() -> Dictionary:
	return {
		"title": hub_name,
		"description": description,
		"type": "portal_return"
	}

# ---------------------------------------------------------
# Called by map_screen’s “Start” button
# ---------------------------------------------------------
func on_return_to_hub_pressed():
	var game_session := get_tree().get_first_node_in_group("game_session")
	if game_session and game_session.has_method("switch_to_hub"):
		game_session.switch_to_hub()
	else:
		get_tree().change_scene_to_file(return_scene_path)
