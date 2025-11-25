extends CardAbility
class_name EssenceFlairAbility

@export var gain_sound: AudioStream = preload("res://Audio/Dirt_Grass.mp3")

func _init():
	display_name = "Essence Flair"
	description = "Grants 1 Essence to the caster immediately."
	trigger = "on_summon"
	value = 1


func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit:
		return

	var owner = unit.owner

	# 🔊 Play essence gain sound
	_play_sound(arena, gain_sound, -8, 1.0, 1.2)

	# ✨ Grant essence to the player
	arena._gain_essence(owner, value)

	# 📝 Log the essence gain
	var owner_name = "Player" if owner == arena.PLAYER else "Enemy"
	arena._log("✨ %s gains %d Essence from %s!" % [owner_name, value, unit.card.name], Color(0.7, 0.9, 1.0))

	# 💫 Visual feedback
	if arena.has_method("_float_text"):
		var pos = arena.board.get_unit_position(unit)
		if pos != Vector2i(-1, -1):
			var tile = arena.board.get_tile(pos.x, pos.y)
			if tile:
				arena._float_text(tile.global_position + Vector3(0, 1, 0), "+1 ESSENCE", Color(0.5, 0.8, 1.0))

	await arena.get_tree().create_timer(0.3).timeout


# -------------------------------------------------------------
# 🔊 Sound Helper
# -------------------------------------------------------------
func _play_sound(arena: Node, stream: AudioStream, vol: float, pitch_min: float, pitch_max: float) -> void:
	if not stream or not arena:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = vol
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	player.position = Vector3(0, 1, 0)
	arena.add_child(player)
	player.play()

	# Auto-cleanup
	player.finished.connect(func(): player.queue_free())
