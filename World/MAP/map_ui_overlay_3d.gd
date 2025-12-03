extends CanvasLayer
class_name MapUIOverlay3D

signal return_to_hub_pressed()
signal settings_pressed()

# UI Components
@onready var node_info_panel: Panel = $NodeInfoPanel
@onready var node_name_label: Label = $NodeInfoPanel/Main/NodeNameLabel
@onready var node_description_label: Label = $NodeInfoPanel/Main/DescriptionLabel
@onready var node_type_label: Label = $NodeInfoPanel/Main/TypeLabel
@onready var difficulty_label: Label = $NodeInfoPanel/Main/DifficultyLabel
@onready var leader_art: TextureRect = $NodeInfoPanel/MarginContainer/Art
@onready var tooltip_label: Label = $TooltipLabel
@onready var return_button: Button = $TopBar/ReturnButton
@onready var settings_button: Button = $TopBar/SettingsButton
@onready var realm_label: Label = $TopBar/RealmLabel

var current_hovered_node: MapNode3D = null
var map_scene: MapScene3D = null

func _ready():
	# Hide info panel initially
	if node_info_panel:
		node_info_panel.visible = false

	if tooltip_label:
		tooltip_label.visible = false

	# Connect button signals
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)

	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)

func set_map_scene(scene: MapScene3D):
	"""Connect to the map scene for receiving updates"""
	map_scene = scene

	if map_scene:
		# Connect to map scene signals
		map_scene.node_clicked.connect(_on_node_clicked)
		map_scene.player_arrived.connect(_on_player_arrived)

func show_node_info(node: MapNode3D):
	"""Display information about a node"""
	if not node_info_panel:
		return

	node_info_panel.visible = true

	# Set node name
	if node_name_label:
		if node.is_revealed:
			node_name_label.text = node.enemy_name
		else:
			node_name_label.text = "???"

	# Set description
	if node_description_label:
		if node.is_revealed:
			node_description_label.text = node.description
		else:
			node_description_label.text = "This location is shrouded in mystery..."

	# Set node type
	if node_type_label:
		if node.is_revealed:
			var type_text = get_node_type_display_name(node.encounter_type)
			node_type_label.text = "Type: " + type_text
		else:
			node_type_label.text = "Type: Unknown"

	# Set difficulty
	if difficulty_label:
		if node.is_revealed and node.difficulty > 0 and node.encounter_type != "hub":
			difficulty_label.text = "Difficulty: " + "★".repeat(node.difficulty)
			difficulty_label.visible = true
		else:
			difficulty_label.visible = false

	# Set enemy leader art
	if leader_art:
		if node.is_revealed:
			# Check for enemy art override first
			if node.enemy_art_override:
				leader_art.texture = node.enemy_art_override
				leader_art.visible = true
			elif node.enemy_leader:
				# Display the enemy leader's card art
				leader_art.texture = node.enemy_leader.art
				leader_art.visible = true
			else:
				# Hide the art if no enemy leader or override
				leader_art.visible = false
		else:
			# Hide the art if not revealed
			leader_art.visible = false

func hide_node_info():
	"""Hide the node info panel"""
	if node_info_panel:
		node_info_panel.visible = false

func show_tooltip(text: String, position: Vector2 = Vector2.ZERO):
	"""Show a tooltip at the given position"""
	if not tooltip_label:
		return

	tooltip_label.text = text
	tooltip_label.visible = true

	# Position tooltip near mouse if position is given
	if position != Vector2.ZERO:
		tooltip_label.position = position + Vector2(20, 20)
	else:
		tooltip_label.position = get_viewport().get_mouse_position() + Vector2(20, 20)

func hide_tooltip():
	"""Hide the tooltip"""
	if tooltip_label:
		tooltip_label.visible = false

func set_realm_name(realm: String):
	"""Set the realm name displayed in the UI"""
	if realm_label:
		realm_label.text = realm + " Realm"

func get_node_type_display_name(type: String) -> String:
	"""Get a user-friendly display name for a node type"""
	match type:
		"fight":
			return "Combat Encounter"
		"elite":
			return "Elite Encounter"
		"boss":
			return "Boss Battle"
		"shop":
			return "Merchant"
		"fireevent":
			return "Fire Event"
		"waterevent":
			return "Water Event"
		"windevent":
			return "Wind Event"
		"earthevent":
			return "Earth Event"
		"rest":
			return "Rest Site"
		"explore":
			return "Exploration"
		"hub":
			return "Portal Hub"
		_:
			return "Unknown"

# Signal handlers

func _on_node_clicked(node: MapNode3D):
	"""Handle when a node is clicked in the map"""
	show_node_info(node)

func _on_player_arrived(node: MapNode3D):
	"""Handle when the player arrives at a node"""
	show_node_info(node)

func _on_node_hovered(node: MapNode3D):
	"""Handle when mouse hovers over a node"""
	current_hovered_node = node

	if node.is_revealed:
		show_tooltip(node.enemy_name + "\n" + get_node_type_display_name(node.encounter_type))

func _on_node_unhovered(node: MapNode3D):
	"""Handle when mouse stops hovering over a node"""
	if current_hovered_node == node:
		current_hovered_node = null
		hide_tooltip()

func _on_return_button_pressed():
	"""Handle return to hub button press"""
	emit_signal("return_to_hub_pressed")

func _on_settings_button_pressed():
	"""Handle settings button press"""
	emit_signal("settings_pressed")

func _input(event: InputEvent):
	"""Update tooltip position on mouse move"""
	if event is InputEventMouseMotion and tooltip_label and tooltip_label.visible:
		tooltip_label.position = event.position + Vector2(20, 20)
