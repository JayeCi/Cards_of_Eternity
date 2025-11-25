extends CardAbility
class_name WingedGustAbility

@export var buff_sound: AudioStream = preload("res://Audio/Dirt_Grass.mp3")

func _init():
	display_name = "Winged Gust"
	description = "When fused with a WIND type, grants +1 Movement."
	trigger = "on_fusion"
	value = 1


# Called automatically when monster moves onto this upgrade spell
# 'arena' is the ArenaCore, 'base_unit' is the monster being upgraded
func execute(arena: Node, base_unit: UnitData) -> void:
	if not base_unit or not base_unit.card:
		print("❌ WingedGust: Invalid base_unit or card")
		return

	# Only apply if the monster's element is WIND
	var element = str(base_unit.card.element)
	print("🔍 WingedGust: Checking element '%s'" % element)
	if element.to_lower() != "wind":
		print("❌ WingedGust: Element mismatch - expected Wind, got %s" % element)
		return

	print("✅ WingedGust: Element check passed, applying upgrade to %s" % base_unit.card.name)

	# 🔊 Play buff sound
	_play_sound(arena, buff_sound, -8, 0.9, 1.1)

	# 💨 Grant +1 movement bonus
	var bonus := int(value)
	if base_unit.has_meta("movement_bonus_from_gust"):
		base_unit.set_meta("movement_bonus_from_gust", base_unit.get_meta("movement_bonus_from_gust") + bonus)
	else:
		base_unit.set_meta("movement_bonus_from_gust", bonus)

	# Log and visual feedback
	if arena and arena.has_method("_log"):
		arena._log("💨 Winged Gust empowers %s! +%d Movement" %
			[base_unit.card.name, bonus],
			Color(0.7, 1.0, 0.9))

	# Optional floating combat text
	if arena and arena.has_method("_float_text"):
		var pos = arena.board.get_unit_position(base_unit)
		if pos != Vector2i(-1, -1):
			var tile = arena.board.get_tile(pos.x, pos.y)
			if tile:
				arena._float_text(tile.global_position + Vector3(0, 1, 0), "+1 MOVE 💨", Color(0.7, 1.0, 0.9))


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
