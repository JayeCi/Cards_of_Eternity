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
@onready var top_bar: Control = $TopBar
@onready var return_button: Button = $TopBar/ReturnButton
@onready var settings_button: Button = $TopBar/SettingsButton
@onready var realm_label: Label = $TopBar/RealmLabel
@onready var action_button: Button = $ActionButton
@onready var card_collection_gui: Control = null  # Will be set dynamically

var current_hovered_node: MapNode3D = null
var map_scene: MapScene3D = null
var current_displayed_node: MapNode3D = null  # Prevent double animations
var is_animating: bool = false  # Animation guard

func _ready():
	# Hide info panel initially
	if node_info_panel:
		node_info_panel.visible = false
		node_info_panel.modulate = Color(1, 1, 1, 0)  # Start transparent for fade-in

	if tooltip_label:
		tooltip_label.visible = false

	# Connect button signals
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)

	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)

	# Connect action button signal
	if action_button:
		action_button.pressed.connect(_on_action_button_pressed)
		action_button.visible = false  # Hidden by default
	else:
		print("⚠️ ActionButton not found! Please add a Button node named 'ActionButton' to MapUIOverlay3D")

	# Apply enhanced styling
	setup_ui_styling()

func setup_ui_styling():
	"""Apply enhanced styling to UI elements"""

	# Style the node info panel with DRAMATIC visuals
	if node_info_panel:
		# Create a StyleBoxFlat for the panel
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.05, 0.05, 0.1, 0.95)  # Much darker, more opaque
		panel_style.border_width_left = 4
		panel_style.border_width_top = 4
		panel_style.border_width_right = 4
		panel_style.border_width_bottom = 4
		panel_style.border_color = Color(0.6, 0.7, 1.0, 1.0)  # Bright glowing blue border
		panel_style.corner_radius_top_left = 20
		panel_style.corner_radius_top_right = 20
		panel_style.corner_radius_bottom_left = 20
		panel_style.corner_radius_bottom_right = 20
		panel_style.shadow_size = 20
		panel_style.shadow_color = Color(0.3, 0.4, 0.8, 0.8)  # Blue glow shadow
		panel_style.shadow_offset = Vector2(0, 0)

		# Add inner glow
		panel_style.border_blend = true

		# Add content margins for better spacing
		panel_style.content_margin_left = 20
		panel_style.content_margin_top = 20
		panel_style.content_margin_right = 20
		panel_style.content_margin_bottom = 20

		node_info_panel.add_theme_stylebox_override("panel", panel_style)

	# Style labels with better colors and text wrapping
	if node_name_label:
		node_name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		node_name_label.add_theme_font_size_override("font_size", 28)
		node_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if node_type_label:
		node_type_label.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
		node_type_label.add_theme_font_size_override("font_size", 18)
		node_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if difficulty_label:
		difficulty_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		difficulty_label.add_theme_font_size_override("font_size", 20)

	if node_description_label:
		node_description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		node_description_label.add_theme_font_size_override("font_size", 16)
		node_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Style tooltip
	if tooltip_label:
		var tooltip_style = StyleBoxFlat.new()
		tooltip_style.bg_color = Color(0.05, 0.05, 0.08, 0.95)
		tooltip_style.corner_radius_top_left = 8
		tooltip_style.corner_radius_top_right = 8
		tooltip_style.corner_radius_bottom_left = 8
		tooltip_style.corner_radius_bottom_right = 8
		tooltip_style.content_margin_left = 12
		tooltip_style.content_margin_right = 12
		tooltip_style.content_margin_top = 8
		tooltip_style.content_margin_bottom = 8
		tooltip_style.border_width_left = 2
		tooltip_style.border_width_top = 2
		tooltip_style.border_width_right = 2
		tooltip_style.border_width_bottom = 2
		tooltip_style.border_color = Color(0.5, 0.6, 0.8, 0.9)

		tooltip_label.add_theme_stylebox_override("normal", tooltip_style)
		tooltip_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		tooltip_label.add_theme_font_size_override("font_size", 16)

	# Style buttons
	style_button(return_button, Color(0.6, 0.3, 0.3))  # Red-ish for Hub
	style_button(settings_button, Color(0.3, 0.4, 0.6))  # Blue-ish for Settings
	style_button(action_button, Color(0.3, 0.7, 0.4))  # Green for Action

	# Style top bar
	if top_bar:
		var top_bar_style = StyleBoxFlat.new()
		top_bar_style.bg_color = Color(0.03, 0.03, 0.06, 0.9)
		top_bar_style.border_width_bottom = 3
		top_bar_style.border_color = Color(0.5, 0.6, 0.9, 0.8)
		top_bar_style.shadow_size = 10
		top_bar_style.shadow_color = Color(0, 0, 0, 0.6)

		# Try to apply to PanelContainer or Panel if it exists
		if top_bar is Panel or top_bar is PanelContainer:
			top_bar.add_theme_stylebox_override("panel", top_bar_style)

	# Style realm label - ensure it's centered
	if realm_label:
		realm_label.add_theme_color_override("font_color", Color(0.95, 1.0, 1.0))
		realm_label.add_theme_font_size_override("font_size", 32)
		realm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Position labels correctly on top bar
		# Collection button: left (changed from Hub)
		if return_button:
			return_button.position = Vector2(20, 10)
			return_button.text = "COLLECTION"

		# Settings button: right
		if settings_button:
			settings_button.anchor_left = 1.0
			settings_button.anchor_right = 1.0
			settings_button.offset_left = -120
			settings_button.offset_right = -20
			settings_button.text = "Settings"

		# Realm label: center
		realm_label.anchor_left = 0.5
		realm_label.anchor_right = 0.5
		realm_label.anchor_top = 0.0
		realm_label.anchor_bottom = 0.0
		realm_label.offset_left = -150
		realm_label.offset_right = 150
		realm_label.offset_top = 10
		realm_label.offset_bottom = 50

func style_button(button: Button, base_color: Color):
	"""Apply enhanced styling to a button"""
	if not button:
		return

	# Normal state
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = base_color.darkened(0.3)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	normal_style.content_margin_left = 16
	normal_style.content_margin_right = 16
	normal_style.content_margin_top = 10
	normal_style.content_margin_bottom = 10
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = base_color

	# Hover state
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = base_color.lightened(0.1)
	hover_style.border_color = base_color.lightened(0.3)

	# Pressed state
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = base_color.darkened(0.5)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1))
	button.add_theme_font_size_override("font_size", 16)

func set_map_scene(scene: MapScene3D):
	"""Connect to the map scene for receiving updates"""
	map_scene = scene

	if map_scene:
		# Connect to map scene signals
		map_scene.node_clicked.connect(_on_node_clicked)
		map_scene.player_arrived.connect(_on_player_arrived)

func show_node_info(node: MapNode3D):
	"""Display information about a node with smooth animation"""
	if not node_info_panel:
		return

	# Prevent double animations for the same node
	if current_displayed_node == node and is_animating:
		return

	current_displayed_node = node
	is_animating = true
	node_info_panel.visible = true

	# Animate panel appearance
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(node_info_panel, "modulate", Color(1, 1, 1, 1), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node_info_panel, "scale", Vector2(1, 1), 0.3).from(Vector2(0.95, 0.95)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Show and update action button
	update_action_button(node)

	await tween.finished
	is_animating = false

func update_action_button(node: MapNode3D):
	"""Update the action button text based on node type"""
	if not action_button or not node:
		return

	# Determine button text based on encounter type
	var button_text = ""
	match node.encounter_type:
		"fight":
			button_text = "DUEL"
		"elite":
			button_text = "CHALLENGE"
		"boss":
			button_text = "FACE BOSS"
		"shop":
			button_text = "ENTER SHOP"
		"rest":
			button_text = "REST"
		"explore":
			button_text = "EXPLORE"
		"fireevent", "waterevent", "windevent", "earthevent":
			button_text = "INVESTIGATE"
		"hub":
			button_text = "RETURN"
		_:
			button_text = "ENTER"

	action_button.text = button_text
	action_button.visible = node.is_reachable  # Only show if node is reachable

	# Animate button appearance
	if action_button.visible:
		action_button.modulate = Color(1, 1, 1, 0)
		var tween = create_tween()
		tween.tween_property(action_button, "modulate", Color(1, 1, 1, 1), 0.3).set_delay(0.2)

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
	"""Hide the node info panel with smooth animation"""
	if not node_info_panel:
		return

	# Animate panel disappearance
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(node_info_panel, "modulate", Color(1, 1, 1, 0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(node_info_panel, "scale", Vector2(0.9, 0.9), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Hide action button too
	if action_button:
		action_button.visible = false

	# Hide after animation completes
	await tween.finished
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
	"""Handle collection button press - opens CardCollectionGUI"""
	print("🎴 Opening Card Collection GUI...")

	# Try to find the CardCollectionGUI in the scene tree
	if not card_collection_gui:
		# Look for it in common locations
		card_collection_gui = get_node_or_null("../Card_Collection_GUI")
		if not card_collection_gui:
			card_collection_gui = get_node_or_null("../../Card_Collection_GUI")
		if not card_collection_gui:
			# Try to find it anywhere in the tree
			var root = get_tree().root
			for child in root.get_children():
				var found = child.find_child("Card_Collection_GUI", true, false)
				if found:
					card_collection_gui = found
					break

	if card_collection_gui:
		# Hide this UI overlay
		visible = false
		# Show the collection GUI
		card_collection_gui.visible = true
		print("✅ Card Collection GUI opened")
	else:
		print("❌ Card Collection GUI not found in scene tree!")
		push_warning("CardCollectionGUI not found. Make sure it exists in the scene.")

func _on_settings_button_pressed():
	"""Handle settings button press"""
	emit_signal("settings_pressed")

func _on_action_button_pressed():
	"""Handle action button press - enter the node"""
	print("🎯 Action button pressed for node: ", current_displayed_node.name if current_displayed_node else "none")

	if not current_displayed_node:
		return

	# Trigger the appropriate action based on node type
	if map_scene:
		map_scene.trigger_node_encounter(current_displayed_node)

func _input(event: InputEvent):
	"""Update tooltip position on mouse move"""
	if event is InputEventMouseMotion and tooltip_label and tooltip_label.visible:
		tooltip_label.position = event.position + Vector2(20, 20)
