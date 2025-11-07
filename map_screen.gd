extends Node2D
class_name MapCore

@onready var camera: Camera2D = $MapCamera
@onready var map_sprite: TextureRect = $MapRoot/Map  # your EarthMap
@onready var line_drawer: Node2D = $MapRoot/LineDrawer
@onready var ui_overlay: Control = $CanvasLayer/UIOverlay
@onready var click_valid: AudioStreamPlayer = $Sounds/ClickValid
@onready var click_invalid: AudioStreamPlayer = $Sounds/ClickInvalid

@onready var node_layer := $MapRoot/NodeLayer
@onready var player_icon := $MapRoot/NodeLayer/Player
@onready var start_node := $MapRoot/NodeLayer/Start
@export var player_offset := Vector2(25, 0)

@export var difficulty: int = 1
@export var enemy_deck: Array[CardData] = []
@export var reward_pool: Array[String] = []

var current_node: MapNode = null
var all_nodes: Array[MapNode] = []
var taken_edges: = {}  
var dragging := false
var zoom_speed := 0.1
var min_zoom := 0.5
var max_zoom := 2.0
var drag_button := MOUSE_BUTTON_RIGHT   # ✅ Use right-click instead of left

func _ready():
	TransitionFade.fade_in()
	GameSession.map_instance = self
	# Gather all MapNodes
	for child in node_layer.get_children():
		if child is MapNode:
			all_nodes.append(child)
			child.clicked.connect(_on_node_clicked)

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

	for node in get_tree().get_nodes_in_group("debug_pickables"):
		node.remove_from_group("debug_pickables")

	for child in $MapRoot.get_children():
		if child is Sprite2D:
			child.add_to_group("debug_pickables")
			print("Tracking Sprite2D:", child.name)

func _unhandled_input(event):

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
		
	# --- Handle clicks on empty map space ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_any_node := false

		for node in all_nodes:
			if node.get_global_rect().has_point(event.position):
				clicked_any_node = true
				break

		if not clicked_any_node:
			click_invalid.play()
			
func _update_node_reachability():
	for n in all_nodes:
		n.is_reachable = false

	# Always allow clicking the CURRENT node (to open InfoPanel again)
	current_node.is_reachable = true

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
	if not node.is_reachable:
		click_invalid.play()
		return
		
	click_valid.play()
	# Mark travel
	var key := _edge_key(current_node, node)
	taken_edges[key] = true

	current_node.is_current = false
	#current_node.is_completed = true
	current_node = node
	current_node.is_current = true

	# ✅ move the icon to the node
	player_icon.global_position = current_node.global_position + player_offset

	# ✅ PREPARE encounter — but do NOT fight yet
	_prepare_arena_payload(node)

	# ✅ show info panel instead of fighting
	ui_overlay.show_encounter_info(node)

	_update_node_reachability() # temporarily hides next nodes
	line_drawer.queue_redraw()
	

func _update_node_visuals():
	for n in all_nodes:
		if n.is_current:
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
	current_node.battle_completed = true
	current_node.is_completed = true
	_update_node_reachability()
	line_drawer.queue_redraw()
	ui_overlay.show_rewards()

func on_battle_loss():
	current_node.battle_completed = false
	_update_node_reachability()
	line_drawer.queue_redraw()
	ui_overlay.show_retry_message()

#ENCOUNTERS

func _trigger_node_encounter(node: MapNode) -> void:
	match node.encounter_type:
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
		"difficulty": node.difficulty,
		"ai_style": node.ai_style,
		"rewards": node.rewards,
		"completion": node.is_completed
	}

func _start_fight(node: MapNode):
	print("Starting fight at ", node.name)
	GameSession.last_selected_map_node = node

	GameSession.switch_to_arena()

func _start_elite(node: MapNode):
	print("Starting ELITE fight at ", node.name)

func _start_boss(node: MapNode):
	print("Starting BOSS battle!")

func _open_shop(node: MapNode):
	print("Opening shop UI")

func _show_event(node: MapNode):
	print("Showing story / event popup")

func _show_rest_site(node: MapNode):
	print("Resting: Heal, upgrade, remove card")

func _start_exploration(node: MapNode):
	print("Exploration mini-event triggered")

func mark_node_resolved(node: MapNode):
	if node.battle_completed:
		return
	node.is_completed = true
	node.battle_completed = true


func _on_button_2_pressed() -> void:
	pass # Replace with function body.
