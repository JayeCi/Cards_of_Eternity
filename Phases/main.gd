extends Node3D

@onready var player = $Player
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var dir_light: DirectionalLight3D = $DirectionalLight3D

var arena_scene: PackedScene = preload("res://Arena/Arena3D/arena_3d.tscn")
var active_battle: Node3D = null
var in_battle := false
var hidden_nodes: Array = []
var player_start_transform: Transform3D
var active_npc: Node = null

func _ready():
	fade_rect.visible = false
	fade_rect.color = Color(0, 0, 0, 0)  # 🔹 ensure it starts fully transparent black


# -----------------------------
# Enter Battle
# -----------------------------
func start_battle_at(_position: Vector3, npc: Node = null):
	if in_battle:
		return
	in_battle = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	player_start_transform = player.global_transform
	await _fade_to_black(0.6)

	# Hide overworld visuals but keep same world/physics
	hidden_nodes.clear()
	for node in get_children():
		if node is Node3D and node != player and not node.name.begins_with("CanvasLayer"):
			hidden_nodes.append(node)
			node.visible = false
			_disable_collisions_recursively(node)

	# ✅ Instantiate arena before connecting
	active_battle = arena_scene.instantiate()
	add_child(active_battle)

	# ✅ Now it exists, so we can safely connect
	if not active_battle.battle_finished.is_connected(_on_battle_finished):
		active_battle.battle_finished.connect(_on_battle_finished)

	# Pass NPC deck data
	if npc and npc.has_method("get_deck_cards"):
		active_battle.enemy_deck = npc.get_deck_cards()

	active_npc = npc  

	await _fade_from_black(0.6)
	print("⚔️ Entered battle in same world.")


func _disable_collisions_recursively(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = true
	elif node is CollisionObject3D:
		for i in range(1, 33):
			node.set_collision_layer_value(i, false)
			node.set_collision_mask_value(i, false)
	for child in node.get_children():
		_disable_collisions_recursively(child)
		
func _enable_collisions_recursively(node: Node) -> void:
	if node is CollisionShape3D:
		node.disabled = false
	elif node is CollisionObject3D:
		for i in range(1, 33):
			node.set_collision_layer_value(i, true)
			node.set_collision_mask_value(i, true)
	for child in node.get_children():
		_enable_collisions_recursively(child)

# -----------------------------
# Exit Battle
# -----------------------------
func _on_battle_finished(result: String):
	print("🏁 Battle finished:", result)
	if active_battle and active_battle.battle_finished.is_connected(_on_battle_finished):
		active_battle.battle_finished.disconnect(_on_battle_finished)

	await get_tree().create_timer(3.0).timeout
	await _fade_to_black(0.6)

	# Cleanly remove arena (still same world)
	if active_battle and active_battle.is_inside_tree():
		active_battle.queue_free()
	active_battle = null
	
	await get_tree().process_frame

	# 🟢 NEW: Notify the NPC that triggered the battle
	# 🟢 Notify the correct NPC
	# 🧹 Reset DialogueManager in case it was left active
	var dm = get_tree().get_first_node_in_group("dialogue_manager")
	if dm:
		dm.active = false
		dm.queue.clear()
		dm.current_ui = null
		
	if active_npc and active_npc.has_method("on_battle_end"):
		active_npc.on_battle_end(result)

		# 🟢 Immediately start post-battle dialogue once the world is visible
		if active_npc.has_method("_handle_post_battle_interaction"):
			await active_npc._handle_post_battle_interaction()

		active_npc = null

	else:
		print("⚠️ No active NPC to notify about battle result.")

	# Restore overworld visuals
	for node in hidden_nodes:
		if node and node.is_inside_tree():
			node.visible = true
			_enable_collisions_recursively(node)
	hidden_nodes.clear()

	await get_tree().physics_frame

	# Restore player position
	if player:
		player.global_transform = player_start_transform
		player.visible = true
		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO
			player.move_and_slide()

	if player.has_node("Head/Camera3D"):
		var cam: Camera3D = player.get_node("Head/Camera3D")
		cam.current = true

	await _fade_from_black(0.6)
	in_battle = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("🌍 Returned to overworld safely.")

# -----------------------------
# Fade Helpers
# -----------------------------
func _fade_to_black(duration: float = 0.5):
	fade_rect.visible = true
	fade_rect.color = Color(0, 0, 0, 0)  # ensure starting from transparent black
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, duration)
	await tw.finished

func _fade_from_black(duration: float = 0.5):
	# Force it visible black first
	fade_rect.visible = true
	fade_rect.color = Color(0, 0, 0, 1.0)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, duration)
	await tw.finished
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.visible = false
	print("🎬 Fade from black complete — screen visible again")
