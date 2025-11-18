extends Node3D

# ===================================================================
# 🎨 PROFESSIONAL AAA MODEL DISPLAY SYSTEM
# ===================================================================

# Reference to the card data being displayed
var card_data: CardData = null

# Reference to previous scene to return to
var previous_scene_path: String = ""
var collection_gui_instance: Node = null

# Scene references
@onready var pedestal: Node3D = $Pedestal
@onready var camera: Camera3D = $Camera3D
@onready var animation_player: AnimationPlayer = $Camera3D/AnimationPlayer
@onready var smoke_burst: CPUParticles3D = $SmokeBurst

# UI references
@onready var ui_overlay: CanvasLayer = $Model_Display_UI
@onready var ui_container: Control = $Model_Display_UI/UIContainer
@onready var name_label: Label = $"Model_Display_UI/UIContainer/VBoxContainer/VBoxContainer#Panel/VBoxContainer_Panel#ScrollContainer/VBoxContainer_Panel_ScrollContainer#VBoxContainer/VBoxContainer_Panel_ScrollContainer_VBoxContainer#Name"
@onready var rarity_label: Label = $"Model_Display_UI/UIContainer/VBoxContainer/VBoxContainer#Panel/VBoxContainer_Panel#ScrollContainer/VBoxContainer_Panel_ScrollContainer#VBoxContainer/VBoxContainer_Panel_ScrollContainer_VBoxContainer#InfoPanel1/VBoxContainer_Panel_ScrollContainer_VBoxContainer_InfoPanel1#Rarity"
@onready var element_label: Label = $"Model_Display_UI/UIContainer/VBoxContainer/VBoxContainer#Panel/VBoxContainer_Panel#ScrollContainer/VBoxContainer_Panel_ScrollContainer#VBoxContainer/VBoxContainer_Panel_ScrollContainer_VBoxContainer#InfoPanel2/VBoxContainer_Panel_ScrollContainer_VBoxContainer_InfoPanel2#Element"
@onready var ability_label: Label = $"Model_Display_UI/UIContainer/VBoxContainer/VBoxContainer#Panel/VBoxContainer_Panel#ScrollContainer/VBoxContainer_Panel_ScrollContainer#VBoxContainer/VBoxContainer_Panel_ScrollContainer_VBoxContainer_InfoPanel3#MarginContainer/VBoxContainer_Panel_ScrollContainer_VBoxContainer_InfoPanel3_MarginContainer#Ability"
@onready var description_label: Label = $"Model_Display_UI/UIContainer/VBoxContainer/VBoxContainer#Panel/VBoxContainer_Panel#ScrollContainer/VBoxContainer_Panel_ScrollContainer#VBoxContainer/VBoxContainer_Panel_ScrollContainer_VBoxContainer_InfoPanel4#MarginContainer/VBoxContainer_Panel_ScrollContainer_VBoxContainer_InfoPanel4_MarginContainer#Description"
@onready var card_ui: Control = $Model_Display_UI/UIContainer/VBoxContainer/CardUIDisplay

# Current model instance
var current_model: Node3D = null

func _ready() -> void:
	# Hide UI initially for dramatic entrance
	if ui_container:
		ui_container.modulate.a = 0.0

	# Wait a frame for everything to load
	await get_tree().process_frame

	if card_data:
		_display_card(card_data)
	else:
		push_warning("⚠️ No card data provided to MODEL_DISPLAY_SCREEN")

	# Fade in UI after model loads
	if ui_container:
		var tween := create_tween()
		tween.tween_property(ui_container, "modulate:a", 1.0, 0.8).set_delay(0.5)

func set_card_data(data: CardData, return_to_gui: Node = null) -> void:
	"""Called from card_collection_gui to set which card to display"""
	card_data = data
	collection_gui_instance = return_to_gui

	if is_inside_tree():
		_display_card(card_data)

func _display_card(data: CardData) -> void:
	if not data:
		return

	print("🎨 [ModelDisplay] Loading model for:", data.name)

	# 1. Load and spawn the 3D model
	_load_model(data)

	# 2. Update UI with card information
	_update_ui(data)

	# 3. Trigger particle effect
	if smoke_burst:
		smoke_burst.emitting = true

	# 4. Start camera animation
	if animation_player:
		animation_player.play("cam")

func _load_model(data: CardData) -> void:
	"""Load and position the card's 3D model on the pedestal"""

	# Remove existing model
	if current_model:
		current_model.queue_free()
		current_model = null

	# Check if card has a model path
	if data.model_path.is_empty():
		push_warning("⚠️ No model_path defined for card:", data.name)
		return

	# Load the model scene
	var model_scene: PackedScene = load(data.model_path)
	if not model_scene:
		push_error("❌ Failed to load model at:", data.model_path)
		return

	# Instantiate the model
	current_model = model_scene.instantiate()
	if not current_model:
		push_error("❌ Failed to instantiate model for:", data.name)
		return

	# Add to pedestal
	pedestal.add_child(current_model)

	# Position and scale the model using card's preferences (or defaults)
	if data.model_position != Vector3.ZERO:
		current_model.position = data.model_position
	else:
		current_model.position = Vector3(0, 0.62, 0)  # Default: on top of pedestal

	# Face forward toward camera
	current_model.rotation.y = 0

	# Use card's scale or default
	if data.model_scale != Vector3.ZERO:
		current_model.scale = data.model_scale
	else:
		current_model.scale = Vector3(0.61, 0.61, 0.61)  # Default scale

	print("✅ [ModelDisplay] Model loaded:", data.name, "at scale:", current_model.scale)

func _update_ui(data: CardData) -> void:
	"""Update all UI elements with card information - AAA quality formatting"""

	if not data:
		push_error("❌ [ModelDisplay] _update_ui called with null data")
		return

	print("🎨 [ModelDisplay] Updating UI for:", data.name)

	# Update card UI preview (top-left card display)
	if card_ui:
		card_ui.card_data = data
		# Wait a frame for the data to be set
		await get_tree().process_frame
		if card_ui.has_method("refresh"):
			card_ui.refresh()
			print("✅ [ModelDisplay] Card UI refreshed")
	else:
		push_warning("⚠️ [ModelDisplay] card_ui reference is null")

	# Name - Bold, large, center-aligned
	if name_label:
		name_label.text = data.name.to_upper()
		name_label.add_theme_font_size_override("font_size", 24)
		name_label.modulate = Color(1.0, 0.95, 0.7, 1.0)  # Warm golden tint
		print("✅ [ModelDisplay] Name updated:", name_label.text)
	else:
		push_warning("⚠️ [ModelDisplay] name_label is null")

	# Rarity - Color-coded by rarity tier
	if rarity_label:
		var rarity_text := str(data.rarity).capitalize()
		rarity_label.text = "✦ " + rarity_text + " ✦"
		rarity_label.add_theme_font_size_override("font_size", 18)
		rarity_label.modulate = _get_rarity_color(data.rarity)
		print("✅ [ModelDisplay] Rarity updated:", rarity_label.text)
	else:
		push_warning("⚠️ [ModelDisplay] rarity_label is null")

	# Element - Color-coded by element type
	if element_label:
		element_label.text = "◆ " + data.element.to_upper() + " ◆"
		element_label.add_theme_font_size_override("font_size", 18)
		element_label.modulate = _get_element_color(data.element)
		print("✅ [ModelDisplay] Element updated:", element_label.text)
	else:
		push_warning("⚠️ [ModelDisplay] element_label is null")

	# Ability - Professional formatting
	if ability_label:
		var ability_name := data.get_ability_name()
		if ability_name and not ability_name.is_empty():
			ability_label.text = ability_name
			ability_label.add_theme_font_size_override("font_size", 16)
			ability_label.modulate = Color(0.8, 0.9, 1.0, 1.0)  # Soft blue
		else:
			ability_label.text = "None"
			ability_label.modulate = Color(0.5, 0.5, 0.5, 1.0)
		print("✅ [ModelDisplay] Ability updated:", ability_label.text)
	else:
		push_warning("⚠️ [ModelDisplay] ability_label is null")

	# Description - Wrapped text with good readability
	if description_label:
		var desc := data.get_ability_description()
		if desc and not desc.is_empty():
			description_label.text = desc
		else:
			description_label.text = data.description if data.description else "A mysterious card..."

		description_label.add_theme_font_size_override("font_size", 14)
		description_label.modulate = Color(0.9, 0.9, 0.9, 1.0)
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		print("✅ [ModelDisplay] Description updated")
	else:
		push_warning("⚠️ [ModelDisplay] description_label is null")

func _get_rarity_color(rarity: String) -> Color:
	"""Return color based on rarity tier"""
	match rarity.to_lower():
		"common":
			return Color(0.7, 0.7, 0.7, 1.0)  # Grey
		"uncommon":
			return Color(0.3, 0.9, 0.3, 1.0)  # Green
		"rare":
			return Color(0.3, 0.6, 1.0, 1.0)  # Blue
		"epic":
			return Color(0.8, 0.3, 1.0, 1.0)  # Purple
		"legendary":
			return Color(1.0, 0.6, 0.1, 1.0)  # Orange/Gold
		"mythic":
			return Color(1.0, 0.2, 0.2, 1.0)  # Red
		_:
			return Color(1.0, 1.0, 1.0, 1.0)  # White default

func _get_element_color(element: String) -> Color:
	"""Return color based on element type"""
	match element.to_lower():
		"fire":
			return Color(1.0, 0.3, 0.1, 1.0)  # Red-orange
		"water":
			return Color(0.2, 0.5, 1.0, 1.0)  # Blue
		"earth":
			return Color(0.5, 0.8, 0.3, 1.0)  # Green
		"wind":
			return Color(0.7, 1.0, 0.9, 1.0)  # Cyan
		"shadow":
			return Color(0.5, 0.2, 0.8, 1.0)  # Purple
		_:
			return Color(0.8, 0.8, 0.8, 1.0)  # Grey default

func _on_back_pressed() -> void:
	"""Return to card collection GUI"""
	print("🔙 [ModelDisplay] Returning to Card Collection")

	# Fade out
	await TransitionFade.fade_out()

	# Show the collection GUI again
	if collection_gui_instance and is_instance_valid(collection_gui_instance):
		collection_gui_instance.visible = true

		# Re-show earth map if it was hidden
		if collection_gui_instance.has_method("get_earth_map_scene"):
			var em = collection_gui_instance.get_earth_map_scene()
			if em:
				em.visible = true

	# Remove this display screen
	queue_free()

	# Fade back in
	await TransitionFade.fade_in()
