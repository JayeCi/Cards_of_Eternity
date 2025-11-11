extends Control

@onready var card_collection_gui: Control = $"../Card_Collection_GUI"
@onready var taskbar: Control = $Taskbar
@onready var deck_count: Label = $Taskbar/Panel/VBoxContainer2/TextureRect/DeckCount
@onready var description: Label = $InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/ScrollContainer/Description
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var info_panel: Control = $InfoPanel
@onready var reward_animation_player: AnimationPlayer = $Reward/AnimationPlayer
@onready var art: TextureRect = $InfoPanel/MainPanel/VBoxContainer/ArtPanel/Art
@onready var reward: Control = $Reward


var _info_panel_open := false

func _ready():
	#GameSession.map_ui = self
	CardCollection.card_count_changed.connect(_update_deck_count)
	_update_deck_count()

# ---------------------------------------------------------
# Show encounter info (with dynamic art)
# ---------------------------------------------------------
func show_encounter_info(node: MapNode, animate: bool = true) -> void:
	info_panel.visible = true

	# Basic info
	$InfoPanel/MainPanel/VBoxContainer/EnemyName.text = node.enemy_name
	$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Difficulty.text = str("Difficulty: ", node.difficulty)

	if node.is_completed:
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Completion.text = "(Completed)"
	else:
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Completion.text = "(Not Completed)"

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
		return

	# -----------------------------------------------------
	# 🧩 Regular encounter node
	# -----------------------------------------------------
	description.text = node.description if node.description != "" else "No description available."

	if "custom_art" in node and node.custom_art:
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

	if node.name == "PortalHub":
		start_button.text = "Return to Hub"
	else:
		start_button.text = "Start Encounter"
	if node.is_completed:
		start_button.tooltip_text = "This encounter has already been completed."
	else:
		start_button.tooltip_text = ""

	# -----------------------------------------------------
	# ✅ Disable start button if node is already completed
	# -----------------------------------------------------
	if node.is_completed:
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
func show_rewards(rewards: Array[CardData]) -> void:
	var card_grid: GridContainer = $Reward/CardGrid
	reward.visible = true
	
	for child in card_grid.get_children():
		child.queue_free()

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

func _on_collection_button_pressed() -> void:
	visible = false
	taskbar.visible = false
	card_collection_gui.visible = true
	if Globals.tutorial_stage == 0:
		Globals.tutorial_stage = 1

func _on_start_button_pressed(node: MapNode) -> void:
	if node.name == "PortalHub":
		GameSession.switch_to_hub()
	else:
		GameSession.switch_to_arena()
