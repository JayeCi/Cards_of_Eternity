extends CardAbility
class_name LavaTrail

@export var fire_sound: AudioStream = preload("res://Audio/FIRE.mp3")

func _init():
	display_name = "Lava Trail"
	description = "When faceup, every tile this card occupies turns into scorching Lava terrain."
	trigger = "on_summon"
	value = 0


func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit:
		return

	# Mark this unit as creating lava trails
	unit.set_meta("creates_lava_trail", true)

	# Apply lava to current tile
	var pos = arena.board.get_unit_position(unit)
	if pos != Vector2i(-1, -1):
		await apply_lava_trail(arena, unit, pos)


# Reusable method called from multiple places (summon, movement, flip)
func apply_lava_trail(arena: Node, unit: UnitData, tile_pos: Vector2i) -> void:
	if not arena or not unit:
		return

	var board = arena.board
	var tile = board.get_tile(tile_pos.x, tile_pos.y)
	if not tile:
		return

	# Skip if already Lava
	if tile.terrain_type == "Lava":
		return

	# Skip holes (cannot be changed)
	if tile.terrain_type == "Hole":
		return

	# Store old terrain for logging
	var old_terrain = tile.terrain_type

	# Play fire sound effect
	_play_fire_sound(arena)

	# Change to Lava
	tile.terrain_type = "Lava"
	if tile.has_method("_apply_terrain_visual"):
		tile._apply_terrain_visual("Lava")

	# Apply terrain bonus to pig
	arena._apply_terrain_bonus(unit, "Lava")

	# Log and visual feedback
	arena._log("🔥 %s's hooves scorch the %s, creating LAVA!" % [unit.card.name, old_terrain],
		Color(1.0, 0.5, 0.2))

	if arena.has_method("_float_text"):
		arena._float_text(tile.global_position + Vector3(0, 1, 0), "LAVA", Color(1.0, 0.3, 0.0))


# Play fire sound effect
func _play_fire_sound(arena: Node) -> void:
	if not fire_sound or not arena:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = fire_sound
	player.volume_db = -10
	player.pitch_scale = randf_range(0.9, 1.1)
	player.position = Vector3(0, 1, 0)
	arena.add_child(player)
	player.play()

	# Auto-cleanup
	player.finished.connect(func(): player.queue_free())
