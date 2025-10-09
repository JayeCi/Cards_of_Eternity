extends Node


var arena_scene := preload("res://Arena/Arena.tscn")
var arena_instance: Node = null
var current_result: String = ""

# Start a battle
func start_battle(player_party, enemy_party):
	print("⚔️ Starting battle between", player_party, "and", enemy_party)

	# Pause world
	get_tree().paused = true

	# Load arena scene dynamically
	arena_instance = arena_scene.instantiate()
	get_tree().root.add_child(arena_instance)

	# (Optional) Pass data into arena before it starts
	arena_instance.player_team_data = player_party
	arena_instance.enemy_team_data = enemy_party

	# Listen for a signal when battle ends
	if not arena_instance.is_connected("battle_finished", Callable(self, "_on_battle_finished")):
		arena_instance.connect("battle_finished", Callable(self, "_on_battle_finished"))

func _on_battle_finished(result: String):
	print("🏁 Battle finished:", result)
	current_result = result

	# Remove the arena
	if arena_instance:
		arena_instance.queue_free()
		arena_instance = null

	# Resume the overworld
	get_tree().paused = false

	# Optionally inform the world scene about result
	get_tree().call_group("world", "on_battle_end", result)
