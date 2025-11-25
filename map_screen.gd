extends Node2D
class_name MapCore

@onready var camera: Camera2D = $MapCamera
@onready var map_sprite: TextureRect = $MapRoot/Map  # your EarthMap
@onready var line_drawer: Node2D = $MapRoot/LineDrawer
@onready var ui_overlay: Control = $CanvasLayer/UIOverlay
@onready var click_valid: AudioStreamPlayer = $Sounds/ClickValid
@onready var click_invalid: AudioStreamPlayer = $Sounds/ClickInvalid
@onready var shop_panel: Control = null  # Will be instantiated when needed

const SHOP_PANEL_SCENE = preload("res://World/MAP/shop_panel.tscn")

@onready var node_layer := $MapRoot/NodeLayer
@onready var player_icon := $MapRoot/NodeLayer/Player
@onready var start_node := $MapRoot/NodeLayer/PortalHub
@export var player_offset := Vector2(25, 0)

var current_shop_node: MapNode = null  # Track which shop is currently open

@export var difficulty: int = 1
@export var enemy_deck: Array[CardData] = []
@export var reward_pool: Array[String] = []

var current_node: MapNode = null
var preview_node: MapNode = null  # Node being previewed (not committed yet)
var all_nodes: Array[MapNode] = []
var taken_edges: = {}
var dragging := false
var zoom_speed := 0.1
var min_zoom := 0.5
var max_zoom := 2.0
var drag_button := MOUSE_BUTTON_RIGHT  

var is_in_intro := false
var intro_complete := false
var is_in_collection_tutorial := false
var collection_tutorial_complete := false
var in_in_post_intro := false
var post_intro_complete := false
var tutorial_started := false

func _ready():
	TransitionFade.fade_in()
	GameSession.map_instance = self


	# Gather all MapNodes
	for child in node_layer.get_children():
		if child is MapNode:
			all_nodes.append(child)
			child.clicked.connect(_on_node_clicked)

	# Connect UI overlay signals
	ui_overlay.shop_button_pressed.connect(_open_shop)

	# Set starting node
	current_node = start_node
	current_node.is_current = true
	# Move player icon
	player_icon.global_position = current_node.global_position + player_offset


	_update_node_reachability()

	# Disable input handling on the background Sprite2D
	var bg = $MapRoot/Map
	bg.set_process_input(false)
	bg.set_process_unhandled_input(false)
	
	set_process_unhandled_input(true)
	await get_tree().process_frame
	camera.make_current()
	
	print("Camera current:", camera.is_current())

	# ✅ Auto-refresh encounter info if a node was active before
	if GameSession.last_selected_map_node and ui_overlay:
		ui_overlay.show_encounter_info(GameSession.last_selected_map_node, false)
		
	for node in get_tree().get_nodes_in_group("debug_pickables"):
		node.remove_from_group("debug_pickables")

	for child in $MapRoot.get_children():
		if child is Sprite2D:
			child.add_to_group("debug_pickables")
			print("Tracking Sprite2D:", child.name)
			
			
	var intro = get_node_or_null("../Intro_Earth_Realm")

	# 🚀 Tutorial Skip: Bypass all tutorials
	if Globals.TUTORIAL_SKIP:
		is_in_intro = false
		intro_complete = true
		is_in_collection_tutorial = false
		collection_tutorial_complete = true
		in_in_post_intro = false
		post_intro_complete = true
		tutorial_started = true
		GameSession.tutorial_started = true

		# Give player starting resources for testing
		if GameSession.gold < 50:  # Only give gold if they don't have enough
			GameSession.gold = 100  # Give 100 gold for testing

		# Add starter cards if collection is empty
		if CardCollection.count() < 10:
			_add_starter_cards_for_testing()

		print("🚀 TUTORIAL SKIP ENABLED - All tutorials bypassed, starting gold: ", GameSession.gold)
	elif intro and not GameSession.tutorial_started:
		intro.intro_finished.connect(_on_intro_finished)
		intro.post_intro_finished.connect(_on_post_intro_finished)
		is_in_intro = true
		GameSession.tutorial_started = true
	else:
		is_in_intro = false
		intro_complete = true
		in_in_post_intro = false
		post_intro_complete = true


	var collection_gui = ui_overlay.get_node_or_null("../CanvasLayer/Card_Collection_GUI")

func _unhandled_input(event):
	# --- Lock logic ---
	if is_in_intro and not intro_complete:
		# Allow only Collection tab clicks
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			ui_overlay.handle_collection_click(event)
		return

	if is_in_collection_tutorial and not collection_tutorial_complete:
		# Still allow Collection UI interactions only
		if event is InputEventMouseButton:
			ui_overlay.handle_collection_tutorial_input(event)
		return
		
	if in_in_post_intro and not post_intro_complete:
		return 

	# --- Normal map interaction ---
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_zoom(camera.zoom * (1 - zoom_speed))
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_zoom(camera.zoom * (1 + zoom_speed))
			drag_button:
				dragging = event.pressed

	elif event is InputEventMouseMotion and dragging:
		camera.position -= event.relative / camera.zoom

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_any_node := false
		for node in all_nodes:
			if node.get_global_rect().has_point(event.position):
				clicked_any_node = true
				break

		if not clicked_any_node:
			click_invalid.play()

func _on_intro_finished():
	is_in_intro = false
	intro_complete = true
	print("Intro finished — gameplay unlocked.")
	
#func _on_collection_tutorial_finished():
	#is_in_collection_tutorial = false
	#collection_tutorial_complete = true
	#print("✅ Collection tutorial finished — gameplay fully unlocked.")
	#
func _on_post_intro_finished():
	in_in_post_intro = false
	post_intro_complete = true
	print("🌍 Post intro complete — all gameplay unlocked.")
	
func _update_node_reachability():
	for n in all_nodes:
		n.is_reachable = false

	# Always allow clicking the CURRENT node (to open InfoPanel again)
	current_node.is_reachable = true

	# 🏠 Always allow clicking the Portal Hub (for returning to hub anytime)
	for n in all_nodes:
		if n.name == "PortalHub" or n.encounter_type == "hub":
			n.is_reachable = true

	# If battle not finished, don't unlock others yet
	if not current_node.battle_completed:
		_update_node_visuals()
		return

	# Otherwise unlock neighbors
	for connection_path in current_node.connected_nodes:
		var node = current_node.get_node(connection_path)
		if node:
			node.is_reachable = true

	_update_node_visuals()

func _on_node_clicked(node: MapNode):
	if is_in_intro and not intro_complete:
		click_invalid.play()
		return

	if not node.is_reachable:
		click_invalid.play()
		return

	click_valid.play()

	# Preview the node - move player sprite for visual feedback
	preview_node = node
	_prepare_arena_payload(node)

	# 👟 Move player sprite to previewed node immediately (visual preview)
	player_icon.global_position = node.global_position + player_offset
	print("👁️ Previewing node: ", node.name)

	var animate = not ui_overlay.is_info_panel_open()
	ui_overlay.show_encounter_info(node, animate)

func reset_preview():
	"""Reset player sprite back to current node position (cancel preview)"""
	if current_node and player_icon:
		player_icon.global_position = current_node.global_position + player_offset
		print("🔙 Preview canceled, sprite returned to: ", current_node.name)

func _commit_node_choice(node: MapNode):
	"""Actually move to the node and lock in the choice"""
	if node == current_node:
		return  # Already at this node

	# Mark the edge as taken
	var key := _edge_key(current_node, node)
	taken_edges[key] = true

	# Move player to new node
	current_node.is_current = false
	current_node = node
	current_node.is_current = true

	player_icon.global_position = current_node.global_position + player_offset

	# Update reachability to lock out other options
	_update_node_reachability()
	_update_node_visuals()
	line_drawer.queue_redraw()

	print("✅ Committed to node:", node.name)

func _update_node_visuals():
	for n in all_nodes:
		# 🏠 Portal Hub always looks bright and active
		if n.name == "PortalHub" or n.encounter_type == "hub":
			n.modulate = Color(1, 1, 1, 1)  # always bright
		elif n.is_current:
			n.modulate = Color(1, 1, 1, 1)  # bright
		elif n.is_completed:
			n.modulate = Color(0.6, 0.6, 0.6, 1)
		elif n.is_reachable:
			n.modulate = Color(1, 1, 1, 0.9)
		else:
			n.modulate = Color(0.4, 0.4, 0.4, 0.3)

func get_nodes():
	return all_nodes


func _edge_key(a: MapNode, b: MapNode) -> String:
	return str(a.name, "|", b.name)

func get_taken_edges() -> Dictionary:
	return taken_edges
	
func _set_zoom(new_zoom: Vector2):
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	camera.zoom = new_zoom


func on_battle_win():
	if current_node and not current_node.battle_completed:
		current_node.battle_completed = true
		current_node.is_completed = true

	# ✅ Give gold reward
	if GameSession.pending_gold_reward > 0:
		GameSession.add_gold(GameSession.pending_gold_reward)

	# ✅ Give card rewards
	if GameSession.encounter_data.has("rewards"):
		var rewards = GameSession.encounter_data["rewards"]
		for r in rewards:
			_grant_reward(r)
		# Show rewards with gold
		ui_overlay.show_rewards(rewards, GameSession.pending_gold_reward)
		GameSession.pending_gold_reward = 0  # Reset after showing

	_update_node_reachability()
	line_drawer.queue_redraw()
	ui_overlay.show_encounter_info(current_node, false)

	print("✅ Battle won at:", current_node.name)


func _grant_reward(card_data: CardData) -> void:
	if card_data == null:
		print("⚠️ Tried to grant null reward card")
		return

	# Add the card to the player's collection
	CardCollection.add_card(card_data)
	print("🃏 Granted card reward: ", card_data.name)

func on_battle_loss():
	current_node.battle_completed = false
	_update_node_reachability()
	line_drawer.queue_redraw()
	#ui_overlay.show_retry_message()

#ENCOUNTERS

func _trigger_node_encounter(node: MapNode) -> void:
	match node.encounter_type:
		"hub":
			_return_to_hub(node)
		"fight":
			_start_fight(node)
		"elite":
			_start_elite(node)
		"boss":
			_start_boss(node)
		"shop":
			_open_shop(node)
		"event":
			_show_event(node)
		"rest":
			_show_rest_site(node)
		"explore":
			_start_exploration(node)
			
func _prepare_arena_payload(node : MapNode):
	GameSession.encounter_data = {
		"enemy_name": node.enemy_name,
		"enemy_deck": node.enemy_deck,
		"enemy_leader": node.enemy_leader,
		"difficulty": node.difficulty,
		"ai_style": node.ai_style,
		"rewards": node.rewards,
		"completion": node.is_completed,
		"biome": node.biome
	}

	

func on_encounter_confirmed():
	"""Called when player presses Start button to confirm their node choice"""
	if preview_node and preview_node != current_node:
		_commit_node_choice(preview_node)

func _start_fight(node: MapNode):
	print("Starting fight at ", node.name)
	GameSession.last_selected_map_node = node

	GameSession.switch_to_arena()

func _start_elite(node: MapNode):
	print("🔥 Starting ELITE fight at ", node.name)
	GameSession.last_selected_map_node = node
	# Elite fights use same arena but with harder enemies
	GameSession.switch_to_arena()

func _start_boss(node: MapNode):
	print("💀 Starting BOSS battle at ", node.name)
	GameSession.last_selected_map_node = node
	# Boss battle - could add special arena modifiers here
	GameSession.switch_to_arena()

func _open_shop(node: MapNode):
	print("🛒 Opening shop UI at ", node.name)

	# Store reference to current shop node
	current_shop_node = node

	# Instantiate shop panel if it doesn't exist
	if not shop_panel:
		_initialize_shop_panel()

	# Open the shop
	if shop_panel:
		shop_panel.open_shop()

		# Hide UI overlay while shop is open
		ui_overlay.hide_info_panel(false)

func _initialize_shop_panel():
	"""Instantiate and setup the shop panel"""
	shop_panel = SHOP_PANEL_SCENE.instantiate()
	$CanvasLayer.add_child(shop_panel)

	# Connect signals
	shop_panel.shop_closed.connect(_on_shop_closed)
	shop_panel.card_purchased.connect(_on_card_purchased)
	shop_panel.pack_purchased.connect(_on_pack_purchased)

	print("✅ Shop panel initialized")

func _on_shop_closed():
	"""Handle shop panel closing"""
	print("🚪 Shop closed")

	# Mark shop node as completed and progress player
	if current_shop_node and not current_shop_node.is_completed:
		current_shop_node.is_completed = true
		current_shop_node.battle_completed = true  # Use same flag as battles

		# Move player to the shop node (progress)
		if current_node:
			current_node.is_current = false
		current_node = current_shop_node
		current_node.is_current = true
		player_icon.global_position = current_node.global_position + player_offset

		# Update map visuals
		_update_node_reachability()
		_update_node_visuals()
		line_drawer.queue_redraw()

		print("✅ Shop completed and progressed to:", current_node.name)

	# Clear shop reference
	current_shop_node = null

func _on_card_purchased(card: CardData):
	"""Handle individual card purchase"""
	print("🛒 Card purchased: ", card.name)

func _on_pack_purchased(cards: Array[CardData]):
	"""Handle card pack purchase"""
	print("📦 Pack purchased! Got ", cards.size(), " cards")
	for card in cards:
		print("  - ", card.name)

func _add_starter_cards_for_testing():
	"""Add starter cards for tutorial skip testing"""
	print("🎴 Adding starter cards for tutorial skip...")

	var starter_cards = [
		"res://Cards/Monster Cards/Goblin.tres",
		"res://Cards/Monster Cards/Imp.tres",
		"res://Cards/Monster Cards/Dirt.tres",
		"res://Cards/Monster Cards/Fysh.tres",
		"res://Cards/Monster Cards/Lava_Hare.tres",
		"res://Cards/Monster Cards/Forest_Fae.tres",
		"res://Cards/Monster Cards/Cloud_Monkey.tres",
		"res://Cards/Spells/Fireball.tres",
		"res://Cards/Spells/Tidal_Wave.tres",
		"res://Cards/Monster Cards/Flame_Fae.tres",
	]

	for card_path in starter_cards:
		if ResourceLoader.exists(card_path):
			var card = load(card_path) as CardData
			if card:
				CardCollection.add_card(card, 1)
				print("  ✅ Added: ", card.name)

	print("🎴 Starter cards added!")

func _show_event(node: MapNode):
	print("Showing story / event popup")

func _show_rest_site(node: MapNode):
	print("Resting: Heal, upgrade, remove card")

func _start_exploration(node: MapNode):
	print("Exploration mini-event triggered")

func _return_to_hub(node: MapNode):
	print("Returning to hub...")
	await TransitionFade.fade_out()
	GameSession.switch_to_hub()

func mark_node_resolved(node: MapNode):
	if node.battle_completed:
		return
	node.is_completed = true
	node.battle_completed = true


func _on_button_2_pressed() -> void:
	pass # Replace with function body.
