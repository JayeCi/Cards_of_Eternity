extends Node

var hub_scene_path := "res://World/HUB.tscn"
var arena_scene_path := "res://Arena/Arena3D/arena_3d.tscn"

var hub_instance: Node = null
var arena_instance: Node = null

var current_realm := ""


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

	# remove hub from tree
	if hub.get_parent():
		hub.get_parent().remove_child(hub)

	# load arena
	var packed := load(arena_scene_path)
	arena_instance = packed.instantiate()
	tree.root.add_child(arena_instance)
	tree.current_scene = arena_instance

	# optional tutorial mode hook
	if tutorial and arena_instance.has_method("enable_tutorial_mode"):
		arena_instance.enable_tutorial_mode()

	# remove hub from anywhere it was (safety)
	if hub_instance and hub_instance.get_parent():
		hub_instance.get_parent().remove_child(hub_instance)

	await TransitionFade.fade_in()
