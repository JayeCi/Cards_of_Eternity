extends Node3D

@onready var player = $player
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect
var arena_scene: PackedScene = preload("res://Arena/Arena3D/arena_3d.tscn")

var active_battle: Node3D = null
var in_battle := false

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fade_rect.visible = false
	fade_rect.color.a = 0.0


func start_battle_at(_position: Vector3, npc: Node = null):
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if in_battle:
		return
	in_battle = true

	await _fade_to_black(0.6)

	# Hide world visuals
	for node in get_children():
		if node is Node3D and not node.name.begins_with("CanvasLayer"):
			node.visible = false

	# 🧩 Create arena but DO NOT add yet
	active_battle = arena_scene.instantiate()

	# 💥 Assign NPC deck BEFORE adding arena to tree
	if npc and npc.has_method("get_deck_cards"):
		active_battle.enemy_deck = npc.get_deck_cards()
		print("✅ Assigned NPC deck with ", active_battle.enemy_deck.size(), " cards")

	add_child(active_battle)

	active_battle.battle_finished.connect(_on_battle_finished)

	await _fade_from_black(0.6)

func _on_battle_finished(result: String):
	print("🏁 Battle finished:", result)

	# 🕒 Wait 3 seconds before leaving the Arena
	await get_tree().create_timer(3.0).timeout

	await _fade_to_black(0.6)

	# --- Remove Arena scene safely ---
	if active_battle:
		if active_battle.is_inside_tree():
			active_battle.queue_free()
		active_battle = null

	await get_tree().process_frame  # allow world cleanup

	# --- 🔹 Restore correct world context ---
	var main_world: World3D = get_world_3d()

	# --- 🔹 Reactivate overworld visuals ---
	for node in get_children():
		if node is Node3D and not node.name.begins_with("CanvasLayer"):
			node.visible = true

	player.visible = true
	for npc in get_tree().get_nodes_in_group("npcs"):
		npc.visible = true

	# --- 🔹 Restore collisions ---
	for node in get_tree().get_nodes_in_group("overworld"):
		if node is CollisionObject3D:
			node.collision_layer = 1
			node.collision_mask = 1

	# --- 🔹 Restore lighting & environment if hidden ---
	if has_node("WorldEnvironment"):
		var we = $WorldEnvironment
		if we.environment == null and we.has_meta("saved_env"):
			we.environment = we.get_meta("saved_env")

	if has_node("DirectionalLight3D"):
		$DirectionalLight3D.visible = true

	get_viewport().set_world_3d(main_world)

	# --- 🔹 Reactivate camera ---
	await get_tree().process_frame
	if player.has_node("Head/Camera3D"):
		var cam: Camera3D = player.get_node("Head/Camera3D")
		cam.current = true
		print("🎥 Player camera reactivated")

	await _fade_from_black(0.6)
	in_battle = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	print("🌍 Returned to overworld.")

# -----------------------------
# Fade Helpers
# -----------------------------
func _fade_to_black(duration: float = 0.5):
	fade_rect.visible = true
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, duration)
	await tw.finished

func _fade_from_black(duration: float = 0.5):
	var tw = create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, duration)
	await tw.finished
	fade_rect.visible = false
