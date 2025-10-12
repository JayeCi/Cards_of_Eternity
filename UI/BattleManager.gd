extends Node

var arena_scene := preload("res://Arena/Arena.tscn")
var arena_instance: Node = null
var current_result: String = ""
var player_ref: Node3D = null
var saved_transform: Transform3D

func start_battle(player_party, enemy_party):
	print("⚔️ Starting battle between", player_party, "and", enemy_party)

	player_ref = get_tree().get_first_node_in_group("player")
	if player_ref:
		saved_transform = player_ref.global_transform
		player_ref.visible = false
		# 🔒 freeze player movement
		if player_ref is CharacterBody3D:
			player_ref.set_physics_process(false)

	get_tree().paused = true

	arena_instance = arena_scene.instantiate()
	get_tree().root.add_child(arena_instance)
	arena_instance.player_team_data = player_party
	arena_instance.enemy_team_data = enemy_party

	if not arena_instance.is_connected("battle_finished", Callable(self, "_on_battle_finished")):
		arena_instance.connect("battle_finished", Callable(self, "_on_battle_finished"))


func _on_battle_finished(result: String):
	print("🏁 Battle finished:", result)
	current_result = result

	if arena_instance:
		arena_instance.queue_free()
		arena_instance = null

	# ✅ STEP 1: Restore player *while still paused*
	if player_ref:
		var pos = saved_transform.origin
		var ground_y = _find_ground_y(pos)
		if ground_y != -INF:
			pos.y = ground_y + 0.1

		var t := saved_transform
		t.origin = pos
		player_ref.global_transform = t
		player_ref.visible = true

		if player_ref is CharacterBody3D:
			player_ref.velocity = Vector3.ZERO
			player_ref.set_physics_process(true)

	# ✅ STEP 2: wait one physics frame AFTER placement
	await get_tree().physics_frame

	# ✅ STEP 3: unpause world
	get_tree().paused = false

	get_tree().call_group("world", "on_battle_end", result)


func _find_ground_y(from_pos: Vector3) -> float:
	if not player_ref or not player_ref.get_world_3d():
		return -INF

	var space_state := player_ref.get_world_3d().direct_space_state
	var from := from_pos + Vector3.UP * 5.0
	var to := from_pos - Vector3.UP * 50.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if player_ref is CollisionObject3D:
		query.exclude = [player_ref.get_rid()]

	var result := space_state.intersect_ray(query)
	if result.has("position"):
		return result["position"].y
	return -INF
