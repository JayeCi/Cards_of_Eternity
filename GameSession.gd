extends Node

signal gold_changed(new_amount: int)

var hub_scene_path := "res://EarthPortalScene.tscn"
var arena_scene_path := "res://Arena/Arena3D/arena_3d.tscn"
var map_scene_path := "res://World/MAP/earth_map_screen.tscn"

var hub_instance: Node = null
var arena_instance: Node = null
var map_instance: Node = null

var current_realm := ""
var realm_maps := {}
var encounter_data: Dictionary = {}
var last_selected_map_node: MapNode = null
var tutorial_started := false
var last_battle_result: String = ""

# 💰 Gold Currency System
var gold: int = 10:
	set(value):
		gold = max(0, value)  # Cannot go below 0
		gold_changed.emit(gold)

var pending_gold_reward: int = 0  # Gold earned from last battle


# =====================================================
# 🧩 Utility — safely detach a scene
# =====================================================
func _detach_scene(scene: Node) -> void:
	if not scene or not is_instance_valid(scene):
		return
	if scene.get_parent():
		scene.get_parent().remove_child(scene)


# =====================================================
# 🚪 Switch TO HUB
# =====================================================
func switch_to_hub() -> void:
	# 🟣 Start fade FIRST to cover screen
	await TransitionFade.fade_out()
	InputState.set_mode(InputState.Mode.FREE)

	# --- Cache and remove old scenes ---
	if map_instance and is_instance_valid(map_instance):
		realm_maps[current_realm] = map_instance
		_detach_scene(map_instance)

	if arena_instance and is_instance_valid(arena_instance):
		_detach_scene(arena_instance)
		arena_instance.queue_free()
		arena_instance = null

	# --- Load / reuse hub ---
	if hub_instance == null or not is_instance_valid(hub_instance):
		hub_instance = load(hub_scene_path).instantiate()

	var root := get_tree().root
	if not hub_instance.get_parent():
		root.add_child(hub_instance)

	get_tree().current_scene = hub_instance
	await TransitionFade.fade_in()


# =====================================================
# ⚔️ Switch TO ARENA
# =====================================================
func switch_to_arena(tutorial := false) -> void:
	# 🟣 Fade out first to hide hub immediately
	await TransitionFade.fade_out()

	# --- Cleanly remove hub/map while screen is dark ---
	if hub_instance and is_instance_valid(hub_instance):
		hub_instance.queue_free()   # ✅ completely free it
		hub_instance = null

	await get_tree().process_frame
	
	if map_instance and is_instance_valid(map_instance):
		_detach_scene(map_instance) # safe to detach but keep cached
		realm_maps[current_realm] = map_instance

	# --- Load new arena ---
	arena_instance = load(arena_scene_path).instantiate()
	var root := get_tree().root
	root.add_child(arena_instance)
	get_tree().current_scene = arena_instance

	# --- Setup arena state ---
	if not arena_instance.is_connected("battle_finished", Callable(self, "_on_battle_finished")):
		arena_instance.connect("battle_finished", Callable(self, "_on_battle_finished"))
	if tutorial and arena_instance.has_method("enable_tutorial_mode"):
		arena_instance.enable_tutorial_mode()

	await TransitionFade.fade_in()

# =====================================================
# 🗺️ Switch TO MAP
# =====================================================
func switch_to_earth_map() -> void:

	# --- Clean arena/hub while screen is dark ---
	if arena_instance and is_instance_valid(arena_instance):
		_detach_scene(arena_instance)
		arena_instance.queue_free()
		arena_instance = null

	if hub_instance and is_instance_valid(hub_instance):
		hub_instance.queue_free()
		hub_instance = null

	# --- Restore or create map ---
	if current_realm != "" and current_realm in realm_maps and is_instance_valid(realm_maps[current_realm]):
		map_instance = realm_maps[current_realm]
	elif map_instance == null or not is_instance_valid(map_instance):
		map_instance = load(map_scene_path).instantiate()

	var root := get_tree().root
	if not map_instance.get_parent():
		root.add_child(map_instance)

	get_tree().current_scene = map_instance
	await get_tree().process_frame

	# --- Restore map state ---
	if last_selected_map_node and map_instance.has_method("mark_node_resolved"):
		map_instance.mark_node_resolved(last_selected_map_node)
	if map_instance.has_method("_update_node_reachability"):
		map_instance._update_node_reachability()
	if map_instance.has_node("LineDrawer"):
		map_instance.line_drawer.queue_redraw()

	# ✅ Handle battle results (win/loss)
	if last_battle_result != "":
		if last_battle_result == "player_won" and map_instance.has_method("on_battle_win"):
			map_instance.on_battle_win()
		elif last_battle_result == "player_lost" and map_instance.has_method("on_battle_loss"):
			map_instance.on_battle_loss()
		last_battle_result = ""

	await TransitionFade.fade_in()

# =====================================================
# 💰 Gold Management Methods
# =====================================================
func add_gold(amount: int) -> void:
	"""Add gold to player's total"""
	if amount > 0:
		gold += amount
		print("💰 Gained ", amount, " gold. Total: ", gold)

func spend_gold(amount: int) -> bool:
	"""Attempt to spend gold. Returns true if successful"""
	if gold >= amount:
		gold -= amount
		print("💸 Spent ", amount, " gold. Remaining: ", gold)
		return true
	else:
		print("❌ Not enough gold! Need ", amount, ", have ", gold)
		return false

func has_gold(amount: int) -> bool:
	"""Check if player has enough gold"""
	return gold >= amount

# =====================================================
# ⚔️ Battle Finished Callback
# =====================================================
func _on_battle_finished(result: String) -> void:
	print("🏁 Battle finished with result: ", result)
	last_battle_result = result

	# Store gold reward for display when returning to map
	if result == "player_won":
		pending_gold_reward = randi_range(10, 30)
		print("💰 Earned ", pending_gold_reward, " gold from battle (will display on map)")
