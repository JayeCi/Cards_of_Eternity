extends Node

var hub_scene_path := "res://World/HUB.tscn"
var arena_scene_path := "res://Arena/Arena3D/arena_3d.tscn"

var hub_instance: Node = null
var arena_instance: Node = null

var current_realm := ""

var encounter_data : Dictionary = {}
var map_instance: Node = null

var last_selected_map_node: MapNode = null

# =====================================================
# Switch TO HUB
# =====================================================
func switch_to_hub() -> void:
	await TransitionFade.fade_out()

	InputState.set_mode(InputState.Mode.FREE)

	# remove + free arena if present
	if arena_instance and is_instance_valid(arena_instance):
		var parent := arena_instance.get_parent()
		if parent:
			parent.remove_child(arena_instance)
		arena_instance.queue_free()
		arena_instance = null

	# ensure hub exists and is in the tree
	if hub_instance and not hub_instance.get_parent():
		get_tree().root.add_child(hub_instance)
	get_tree().current_scene = hub_instance

	# ✅ restore player
	var player := hub_instance.get_node_or_null("Player")
	if player:
		if player.has_method("_enable_controls"):
			player.call_deferred("_enable_controls")
		if player.has_method("_lock_mouse"):
			player.call_deferred("_lock_mouse")

	await TransitionFade.fade_in()


# =====================================================
# Switch TO ARENA
# =====================================================
func switch_to_arena(tutorial := false) -> void:
	await TransitionFade.fade_out()

	var tree := get_tree()
	var hub := tree.current_scene
	hub_instance = hub

	if hub.get_parent():
		hub.get_parent().remove_child(hub)

	var packed := load(arena_scene_path)
	arena_instance = packed.instantiate()
	tree.root.add_child(arena_instance)
	tree.current_scene = arena_instance

	# ✅ CONNECT SIGNAL HERE:
	arena_instance.connect("battle_finished", Callable(self, "_on_battle_finished"))

	if tutorial and arena_instance.has_method("enable_tutorial_mode"):
		arena_instance.enable_tutorial_mode()

	await TransitionFade.fade_in()

# In GameSession.gd or Arena setup code
func setup_arena(core: ArenaCore):
	core.ai_sys.configure_style(
		encounter_data.get("ai_style", "balanced"),
		int(encounter_data.get("difficulty", 1))
	)

func _on_battle_finished(result: String) -> void:
	if map_instance:
		if result == "player_won":
			map_instance.on_battle_win()
		else:
			map_instance.on_battle_loss()

	switch_to_map()

# =====================================================
# Switch TO MAP
# =====================================================
func switch_to_map():
	await TransitionFade.fade_out()

	# Remove arena
	if arena_instance and is_instance_valid(arena_instance):
		var parent := arena_instance.get_parent()
		if parent:
			parent.remove_child(arena_instance)
		arena_instance.queue_free()
		arena_instance = null

	# ✅ Ensure map exists
	if map_instance == null:
		map_instance = load("res://World/MAP/map_screen.tscn").instantiate()

	var root := get_tree().root
	if map_instance.get_parent() != root:
		if map_instance.get_parent():
			map_instance.get_parent().remove_child(map_instance)
		root.add_child(map_instance)

	# ✅ Switch scene
	get_tree().current_scene = map_instance
	await get_tree().process_frame

	# ✅ FIRST: restore completed node status
	if last_selected_map_node:
		map_instance.mark_node_resolved(last_selected_map_node)

	# ✅ THEN update reachability + lines
	map_instance._update_node_reachability()
	map_instance.line_drawer.queue_redraw()

	await TransitionFade.fade_in()
