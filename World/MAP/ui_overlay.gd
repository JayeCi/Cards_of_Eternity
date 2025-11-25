extends Control

signal shop_button_pressed(node: MapNode)

@onready var card_collection_gui: Control = $"../Card_Collection_GUI"
@onready var taskbar: Control = $Taskbar
@onready var deck_count: Label = $Taskbar/Panel/VBoxContainer2/TextureRect/DeckCount
@onready var gold_count: Label = $Taskbar/Panel/VBoxContainer/GoldCounter
@onready var description: Label = $InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/ScrollContainer/Description
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var info_panel: Control = $InfoPanel
@onready var reward_animation_player: AnimationPlayer = $Reward/AnimationPlayer
@onready var art: TextureRect = $InfoPanel/MainPanel/VBoxContainer/ArtPanel/Art
@onready var reward: Control = $Reward
@onready var art_panel: Panel = $InfoPanel/MainPanel/VBoxContainer/ArtPanel

# Dynamic Info Panel Elements (created dynamically)
var _dynamic_info_container: VBoxContainer = null


var _info_panel_open := false
var _is_starting_encounter := false

func _ready():
	#GameSession.map_ui = self
	CardCollection.card_count_changed.connect(_update_deck_count)
	_update_deck_count()

	# Setup gold counter
	GameSession.gold_changed.connect(_update_gold_count)
	_update_gold_count(GameSession.gold)

	# Setup input handling for info panel to prevent map zoom while scrolling
	if info_panel:
		info_panel.gui_input.connect(_on_info_panel_input)

# ---------------------------------------------------------
# 🎮 Input Handling
# ---------------------------------------------------------
func _on_info_panel_input(event: InputEvent) -> void:
	"""Consume scroll wheel events when over info panel to prevent map zoom"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			# Mark the event as handled so it doesn't reach the map's zoom logic
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------
# 🔍 Deck Analysis Helpers
# ---------------------------------------------------------
func _analyze_enemy_deck(deck: Array[CardData]) -> Dictionary:
	"""Analyze enemy deck to determine primary element and card types"""
	var analysis = {
		"primary_element": "Neutral",
		"elements": {},
		"types": {},
		"card_count": deck.size(),
		"avg_cost": 0,
		"has_spells": false
	}

	if deck.is_empty():
		return analysis

	var total_cost = 0

	for card in deck:
		if not card:
			continue

		# Count elements
		var element = card.element if card.element else "Neutral"
		analysis.elements[element] = analysis.elements.get(element, 0) + 1

		# Count types
		for type_str in card.types:
			analysis.types[type_str] = analysis.types.get(type_str, 0) + 1

		# Check for spells
		if card.card_type == CardData.CardType.SPELL:
			analysis.has_spells = true

		# Sum cost
		total_cost += card.cost

	# Determine primary element
	var max_element_count = 0
	for element in analysis.elements:
		if analysis.elements[element] > max_element_count:
			max_element_count = analysis.elements[element]
			analysis.primary_element = element

	# Calculate average cost
	if deck.size() > 0:
		analysis.avg_cost = total_cost / deck.size()

	return analysis

func _get_primary_types(types_dict: Dictionary, max_count: int = 2) -> String:
	"""Get top N most common card types as a string"""
	if types_dict.is_empty():
		return "Mixed"

	# Sort types by count
	var sorted_types = []
	for type_name in types_dict:
		sorted_types.append({"name": type_name, "count": types_dict[type_name]})

	sorted_types.sort_custom(func(a, b): return a.count > b.count)

	# Get top types
	var result = []
	for i in range(min(max_count, sorted_types.size())):
		result.append(sorted_types[i].name)

	return " / ".join(result)

func _estimate_gold_reward(difficulty: int) -> String:
	"""Estimate gold reward based on difficulty"""
	var min_gold = 10 + (difficulty * 2)
	var max_gold = 30 + (difficulty * 5)
	return str(min_gold) + "-" + str(max_gold) + "g"

# ---------------------------------------------------------
# 🎨 Dynamic Info Panel Builders
# ---------------------------------------------------------
func _clear_dynamic_info():
	"""Clear previous dynamic info content"""
	if _dynamic_info_container:
		_dynamic_info_container.queue_free()
		_dynamic_info_container = null

	# Hide old description panel elements
	description.visible = false
	if has_node("InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Difficulty"):
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Difficulty.visible = false
	if has_node("InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Completion"):
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Completion.visible = false

func _create_dynamic_container() -> VBoxContainer:
	"""Create and return new dynamic info container"""
	_dynamic_info_container = VBoxContainer.new()
	_dynamic_info_container.name = "DynamicInfo"
	_dynamic_info_container.add_theme_constant_override("separation", 10)
	_dynamic_info_container.size_flags_horizontal = Control.SIZE_FILL

	# Add to ScrollContainer to ensure it appears inside the gray panel
	var scroll_container = $InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/ScrollContainer

	# Check if ScrollContainer already has a content container, if not create one
	var content_container = scroll_container.get_node_or_null("ContentContainer")
	if not content_container:
		# Create a content container to hold both description and dynamic content
		content_container = VBoxContainer.new()
		content_container.name = "ContentContainer"
		content_container.add_theme_constant_override("separation", 15)
		content_container.size_flags_horizontal = Control.SIZE_FILL

		# Move existing Description label into the content container
		if description and description.get_parent() == scroll_container:
			scroll_container.remove_child(description)
			content_container.add_child(description)

		scroll_container.add_child(content_container)

	# Add dynamic content to the content container
	content_container.add_child(_dynamic_info_container)
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return _dynamic_info_container

func _create_info_label(text: String, font_size: int = 14, color: Color = Color.WHITE) -> Label:
	"""Helper to create styled info labels"""
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)

	var label_settings = LabelSettings.new()
	label_settings.font_size = font_size
	label_settings.font_color = color
	label_settings.outline_size = 2
	label_settings.outline_color = Color.BLACK
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.label_settings = label_settings

	return label

func _create_section_header(text: String) -> Label:
	"""Create a section header label"""
	return _create_info_label(text, 16, Color(1, 0.9, 0.5, 1))  # Gold color

func _populate_combat_info(node: MapNode):
	"""Populate beautiful AAA combat encounter info"""
	var container = _create_dynamic_container()

	# Analyze enemy deck
	var deck_analysis = _analyze_enemy_deck(node.enemy_deck)

	# 🎯 Difficulty (prominent)
	var diff_text = "⚔️ DIFFICULTY: " + str(node.difficulty)
	var diff_color = Color.WHITE
	if node.difficulty >= 5:
		diff_color = Color(1.0, 0.3, 0.3)  # Red for hard
	elif node.difficulty >= 3:
		diff_color = Color(1.0, 0.8, 0.3)  # Orange for medium
	else:
		diff_color = Color(0.5, 1.0, 0.5)  # Green for easy
	container.add_child(_create_info_label(diff_text, 18, diff_color))

	# Add spacing
	container.add_child(Control.new())  # Spacer

	# 🔥 Deck Composition
	container.add_child(_create_section_header("═══ ENEMY DECK ═══"))

	var element_text = "Primary Element: " + deck_analysis.primary_element
	var element_color = _get_element_color(deck_analysis.primary_element)
	container.add_child(_create_info_label(element_text, 15, element_color))

	var types_text = "Card Types: " + _get_primary_types(deck_analysis.types)
	container.add_child(_create_info_label(types_text, 14))

	var deck_size_text = "Deck Size: " + str(deck_analysis.card_count) + " cards"
	container.add_child(_create_info_label(deck_size_text, 14))

	if deck_analysis.has_spells:
		container.add_child(_create_info_label("⚡ Contains Spell Cards", 14, Color(0.8, 0.5, 1.0)))

	# Add spacing
	container.add_child(Control.new())

	# 💰 Rewards
	container.add_child(_create_section_header("═══ POTENTIAL REWARDS ═══"))

	var gold_estimate = _estimate_gold_reward(node.difficulty)
	container.add_child(_create_info_label("💰 Gold: " + gold_estimate, 15, Color.GOLD))

	# Card rewards
	var reward_count = node.rewards.size() if node.rewards else randi_range(1, 3)
	if reward_count > 0:
		container.add_child(_create_info_label("🃏 " + str(reward_count) + " Card Reward(s)", 15, Color(0.5, 0.8, 1.0)))

	# Add spacing
	container.add_child(Control.new())

	# ✅ Completion status
	if node.is_completed:
		container.add_child(_create_info_label("✅ COMPLETED", 16, Color(0.5, 1.0, 0.5)))
	else:
		container.add_child(_create_info_label("⚔️ READY TO BATTLE", 16, Color(1.0, 0.7, 0.3)))

func _populate_shop_info(node: MapNode):
	"""Populate shop encounter info"""
	var container = _create_dynamic_container()

	container.add_child(_create_section_header("═══ SHOP ═══"))

	# Description
	var desc_text = node.description if node.description != "" else "Browse and purchase cards to strengthen your deck."
	var desc_label = _create_info_label(desc_text, 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_label)

	# Add spacing
	container.add_child(Control.new())

	# Shop info
	container.add_child(_create_info_label("💰 Purchase individual cards", 14, Color(1.0, 0.9, 0.5)))
	container.add_child(_create_info_label("📦 Buy card packs (3 random cards)", 14, Color(1.0, 0.9, 0.5)))

	# Completion status
	container.add_child(Control.new())
	if node.is_completed:
		container.add_child(_create_info_label("✅ Visited", 14, Color(0.7, 0.7, 0.7)))

func _populate_rest_info(node: MapNode):
	"""Populate rest site info"""
	var container = _create_dynamic_container()

	container.add_child(_create_section_header("═══ REST SITE ═══"))

	var desc_label = _create_info_label("Take a moment to rest and prepare for the journey ahead.", 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_label)

	container.add_child(Control.new())
	container.add_child(_create_info_label("❤️ Heal your wounds", 14, Color(1.0, 0.5, 0.5)))
	container.add_child(_create_info_label("⬆️ Upgrade cards", 14, Color(0.5, 0.8, 1.0)))
	container.add_child(_create_info_label("🗑️ Remove unwanted cards", 14, Color(0.8, 0.8, 0.8)))

func _populate_event_info(node: MapNode):
	"""Populate elemental event info"""
	var container = _create_dynamic_container()

	var event_name = node.encounter_type.capitalize().replace("event", " Event")
	container.add_child(_create_section_header("═══ " + event_name.to_upper() + " ═══"))

	var desc_text = node.description if node.description != "" else "An elemental event unfolds before you."
	var desc_label = _create_info_label(desc_text, 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_label)

	container.add_child(Control.new())
	container.add_child(_create_info_label("🎲 Random outcome", 14, Color(1.0, 0.8, 0.5)))
	container.add_child(_create_info_label("💫 Potential rewards or challenges", 14, Color(0.8, 0.8, 1.0)))

func _populate_explore_info(node: MapNode):
	"""Populate exploration info"""
	var container = _create_dynamic_container()

	container.add_child(_create_section_header("═══ EXPLORATION ═══"))

	var desc_label = _create_info_label("Venture into the unknown. What mysteries await?", 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_label)

	container.add_child(Control.new())
	container.add_child(_create_info_label("❓ Mystery encounter", 14, Color(0.8, 0.8, 1.0)))

func _populate_generic_info(node: MapNode):
	"""Populate generic encounter info"""
	var container = _create_dynamic_container()

	var desc_text = node.description if node.description != "" else "An encounter awaits..."
	var desc_label = _create_info_label(desc_text, 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(desc_label)

func _get_element_color(element: String) -> Color:
	"""Get color for each element"""
	match element:
		"Fire":
			return Color(1.0, 0.4, 0.2)  # Orange-red
		"Water":
			return Color(0.2, 0.6, 1.0)  # Blue
		"Earth":
			return Color(0.6, 0.5, 0.2)  # Brown
		"Wind":
			return Color(0.7, 1.0, 0.9)  # Cyan
		"Shadow":
			return Color(0.6, 0.3, 0.8)  # Purple
		_:
			return Color.WHITE

# ---------------------------------------------------------
# Show encounter info (with dynamic art)
# ---------------------------------------------------------
func show_encounter_info(node: MapNode, animate: bool = true) -> void:
	info_panel.visible = true

	# ✅ Reset encounter start flag when showing new encounter info
	_is_starting_encounter = false

	# Basic info
	$InfoPanel/MainPanel/VBoxContainer/EnemyName.text = node.enemy_name

	# Clear previous dynamic content
	_clear_dynamic_info()

	# 🎨 Create dynamic content based on encounter type
	match node.encounter_type:
		"fight", "elite", "boss":
			_populate_combat_info(node)
		"shop":
			_populate_shop_info(node)
		"rest":
			_populate_rest_info(node)
		"fireevent", "waterevent", "windevent", "earthevent":
			_populate_event_info(node)
		"explore":
			_populate_explore_info(node)
		_:
			_populate_generic_info(node)

	# -----------------------------------------------------
	# 🌀 Portal Return Node special handling
	# -----------------------------------------------------
	if node is PortalReturnNode:
		var info = node.get_node_info()
		$InfoPanel/MainPanel/VBoxContainer/EnemyName.text = info.title
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/ScrollContainer/Description.text = info.description
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Difficulty.text = ""
		$InfoPanel/StartButton.text = "Return to Hub"

		# Properly reconnect start button
		var start_button := $InfoPanel/StartButton
		for conn in start_button.pressed.get_connections():
			start_button.pressed.disconnect(conn["callable"])
		start_button.pressed.connect(node.on_return_to_hub_pressed)

		# ✅ Dynamic art for portal
		_set_dynamic_art("portal")

	# 🧩 Regular encounter node
	# -----------------------------------------------------
	# ✅ Show defeat message if completed, otherwise show description
	if node.is_completed and node.defeat_message != "":
		description.text = node.defeat_message
	else:
		description.text = node.description if node.description != "" else "No description available."

	# ✅ Check for defeated/completed state first
	if node.is_completed and "custom_art_defeated" in node and node.custom_art_defeated:
		art.texture = node.custom_art_defeated
	elif "custom_art" in node and node.custom_art:
		art.texture = node.custom_art
	else:
		_set_dynamic_art(node.encounter_type)
	if animate and not _info_panel_open:
		animation_player.play("Slide_In")

	_info_panel_open = true

	# 🎮 Dynamic start button setup
	var start_button := $InfoPanel/StartButton
	for conn in start_button.pressed.get_connections():
		start_button.pressed.disconnect(conn["callable"])
	start_button.pressed.connect(_on_start_button_pressed.bind(node))

	if node.name == "PortalHub" or node.encounter_type == "hub":
		start_button.text = "Return to Hub"
	elif node.encounter_type == "shop":
		start_button.text = "Enter Shop"
	else:
		start_button.text = "Start Encounter"
	if node.is_completed:
		start_button.tooltip_text = "This encounter has already been completed."
	else:
		start_button.tooltip_text = ""

	# -----------------------------------------------------
	# ✅ Disable start button if node is already completed
	# 🏠 BUT keep Portal Hub button always enabled
	# -----------------------------------------------------
	if node.is_completed and node.name != "PortalHub" and node.encounter_type != "hub":
		start_button.disabled = true
		start_button.modulate = Color(0.6, 0.6, 0.6, 0.7)  # slightly dimmed
		start_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		start_button.disabled = false
		start_button.modulate = Color(1, 1, 1, 1)
		start_button.mouse_filter = Control.MOUSE_FILTER_STOP

# ---------------------------------------------------------
# 🎨 Dynamic art setter
# ---------------------------------------------------------
func _set_dynamic_art(encounter_type: String) -> void:
	var art_path := ""

	match encounter_type:
		"fight":
			art_path = "res://Art/UI/fight_banner.png"
		"elite":
			art_path = "res://Art/UI/elite_banner.png"
		"boss":
			art_path = "res://Art/UI/boss_banner.png"
		"shop":
			art_path = "res://Art/UI/shop_banner.png"
		"fireevent":
			art_path = "res://Art/UI/fire_event_banner.png"
		"waterevent":
			art_path = "res://Art/UI/water_event_banner.png"
		"windevent":
			art_path = "res://Art/UI/wind_event_banner.png"
		"earthevent":
			art_path = "res://Art/UI/earth_event_banner.png"
		"explore":
			art_path = "res://Art/UI/explore_banner.png"
		"rest":
			art_path = "res://Art/UI/rest_banner.png"
		"unknown":
			art_path = "res://Art/UI/mystery_banner.png"
		"hub":
			art_path = "res://World/MAP/portal_hub.png"
		_:
			art_path = "res://Art/UI/default_banner.png"

	if ResourceLoader.exists(art_path):
		art.texture = load(art_path)
	else:
		push_warning("❌ Missing art for type: %s" % encounter_type)
		art.texture = null


# ---------------------------------------------------------
func hide_info_panel(animate: bool = true) -> void:
	if animate:
		animation_player.play("Slide_Out")
	else:
		info_panel.visible = false
	_info_panel_open = false

	# 🔙 Reset player sprite to current node position when closing without confirming
	if GameSession.map_instance and GameSession.map_instance.has_method("reset_preview"):
		GameSession.map_instance.reset_preview()

func is_info_panel_open() -> bool:
	return _info_panel_open

func _on_slide_button_pressed() -> void:
	if _info_panel_open:
		hide_info_panel(true)
	else:
		info_panel.visible = true
		animation_player.play("Slide_In")
		_info_panel_open = true

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
	if anim_name == "Slide_In":
		_info_panel_open = true
		info_panel.visible = true
	elif anim_name == "Slide_Out":
		_info_panel_open = false

# ---------------------------------------------------------
# 🎁 Reward handling
# ---------------------------------------------------------
func show_rewards(rewards: Array[CardData], gold_amount: int = 0) -> void:
	var card_grid: GridContainer = $Reward/CardGrid
	reward.visible = true

	for child in card_grid.get_children():
		child.queue_free()

	# Add gold label if gold was earned
	if gold_amount > 0:
		var gold_label = Label.new()
		gold_label.text = "💰 +" + str(gold_amount) + " Gold"
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gold_label.add_theme_font_size_override("font_size", 32)
		var label_settings = LabelSettings.new()
		label_settings.font_size = 32
		label_settings.outline_size = 4
		label_settings.outline_color = Color.BLACK
		label_settings.font_color = Color.GOLD
		gold_label.label_settings = label_settings
		gold_label.custom_minimum_size = Vector2(200, 60)
		card_grid.add_child(gold_label)

	for card_data in rewards:
		var card_ui = preload("res://UI/CardUI.tscn").instantiate()
		card_grid.add_child(card_ui)
		card_ui.card_data = card_data
		card_ui.refresh()

		# ✅ Disable hover / input during reward animation
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if card_ui.has_method("set_hover_enabled"):
			card_ui.set_hover_enabled(false)

		# ✅ Make FusionGlow visible during reward presentation
		var fusion_glow := card_ui.get_node_or_null("FusionGlow")
		if fusion_glow:
			fusion_glow.visible = true


	reward_animation_player.play("Fade_In")
	await reward_animation_player.animation_finished
	await get_tree().create_timer(3.0).timeout
	reward_animation_player.play("Fade_Out")
	await reward_animation_player.animation_finished
	for child in card_grid.get_children():
		child.queue_free()

	reward.visible = false
# ---------------------------------------------------------
# 🧩 Misc (tutorial / deck updates)
# ---------------------------------------------------------
func handle_collection_click(event: InputEventMouseButton) -> void:
	if not event.is_pressed() or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var collection_button := $Taskbar/Panel/VBoxContainer/CollectionButton if has_node("Taskbar/Panel/VBoxContainer/CollectionButton") else null
	if collection_button and collection_button.get_global_rect().has_point(event.position):
		_on_collection_button_pressed()
	else:
		print("❌ Click ignored — only Collection button allowed right now.")

func handle_collection_tutorial_input(event: InputEventMouseButton) -> void:
	if card_collection_gui and card_collection_gui.visible:
		card_collection_gui.propagate_call("_gui_input", [event])

func _update_deck_count():
	deck_count.text = str(CardCollection.count())

func _update_gold_count(new_amount: int):
	"""Update gold counter display"""
	if gold_count:
		gold_count.text = str(new_amount)

func _on_collection_button_pressed() -> void:
	visible = false
	taskbar.visible = false
	card_collection_gui.visible = true
	if Globals.tutorial_stage == 0:
		Globals.tutorial_stage = 1

func _on_start_button_pressed(node: MapNode) -> void:
	# 🚫 Prevent double-clicking
	if _is_starting_encounter:
		return

	_is_starting_encounter = true

	# Disable button immediately
	var start_button := $InfoPanel/StartButton
	start_button.disabled = true
	start_button.modulate = Color(0.6, 0.6, 0.6, 0.7)

	# Commit the node choice before proceeding
	# 🏠 BUT don't commit when returning to hub (player stays at current node)
	if GameSession.map_instance and node.name != "PortalHub" and node.encounter_type != "hub":
		GameSession.map_instance.on_encounter_confirmed()

	if node.name == "PortalHub" or node.encounter_type == "hub":
		# 🏠 Don't move player, just switch to hub
		GameSession.switch_to_hub()
	elif node.encounter_type == "shop":
		# Emit signal for shop - map_screen will handle opening shop panel
		shop_button_pressed.emit(node)
		# Re-enable the flag since we're not leaving the map
		_is_starting_encounter = false
		start_button.disabled = false
		start_button.modulate = Color(1, 1, 1, 1)
	else:
		GameSession.switch_to_arena()
