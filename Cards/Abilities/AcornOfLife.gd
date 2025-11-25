extends CardAbility
class_name AcornOfLife

@export var plant_sound: AudioStream = preload("res://Audio/Dirt_Grass.mp3")
@export var spread_sound: AudioStream = preload("res://Audio/Dirt_Grass.mp3")

func _init():
	display_name = "Acorn of Life"
	description = "Plants itself and converts its tile to Grass. Each turn, spreads Grass to 1 adjacent tile. Dies if destroyed, replaced, or if its tile becomes Lava."
	trigger = "on_summon"
	value = 0


# ✅ Initial planting when card is revealed
func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit or not unit.card:
		return

	var pos = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		return

	await execute_at(arena, unit, pos)


# ✅ Plant the acorn and convert tile to Grass
func execute_at(arena: Node, unit: UnitData, tile_pos: Vector2i) -> void:
	if not arena or not arena.board:
		return

	var board = arena.board
	var tile = board.get_tile(tile_pos.x, tile_pos.y)
	if not tile:
		return

	# 🔊 Play planting sound
	_play_sound(arena, plant_sound, -8, 0.9, 1.1)

	# Log the planting
	arena._log("🌱 %s plants itself in the ground!" % unit.card.name, Color(0.5, 1.0, 0.5))

	# 🌿 Transform tile to Grass
	tile.terrain_type = "Grass"
	if tile.has_method("_apply_terrain_visual"):
		tile._apply_terrain_visual("Grass")

	# Floating feedback
	if arena.has_method("_float_text"):
		arena._float_text(tile.global_position + Vector3(0, 1, 0), "🌱 PLANTED", Color(0.5, 1.0, 0.5))

	# Mark this unit as "planted" so it can spread grass each turn
	unit.set_meta("is_acorn_planted", true)
	unit.set_meta("acorn_tile_pos", tile_pos)

	# 🌱 Mark as persistent spell so it doesn't get auto-removed after casting
	unit.set_meta("persistent_spell", true)

	# 🔒 Mark as immobile - cannot be moved once planted
	unit.set_meta("immobile", true)

	await arena.get_tree().create_timer(0.3).timeout


# ===============================================================
# 🌿 Per-Turn Grass Spreading (called by battle system)
# ===============================================================
func spread_grass_per_turn(arena: Node, unit: UnitData) -> void:
	if not arena or not unit or not arena.board:
		return

	# Check if acorn is still planted
	if not unit.get_meta("is_acorn_planted", false):
		return

	var board = arena.board
	var current_pos = unit.get_meta("acorn_tile_pos", Vector2i(-1, -1))

	# Verify the acorn is still at its original position
	if current_pos == Vector2i(-1, -1):
		return

	var current_tile = board.get_tile(current_pos.x, current_pos.y)
	if not current_tile:
		return

	# 💀 Death Condition: Check if tile became LAVA
	if current_tile.terrain_type == "Lava":
		arena._log("🔥 %s withers and dies in the scorching lava!" % unit.card.name, Color(1.0, 0.5, 0.3))
		unit.current_def = 0
		if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
			await arena.battle_sys._kill_unit(unit, false)
		return

	# 💀 Death Condition: Check if tile became a HOLE (shouldn't happen due to protection, but safety check)
	if current_tile.terrain_type == "Hole":
		arena._log("💀 %s falls into the void!" % unit.card.name, Color(0.5, 0.5, 0.5))
		unit.current_def = 0
		if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
			await arena.battle_sys._kill_unit(unit, false)
		return

	# 🌿 Find all Grass tiles on the board
	var grass_tiles: Array[Vector2i] = []
	for y in range(arena.BOARD_H):
		for x in range(arena.BOARD_W):
			var t = board.get_tile(x, y)
			if t and t.terrain_type == "Grass":
				grass_tiles.append(Vector2i(x, y))

	if grass_tiles.is_empty():
		return

	# 🌿 Collect all adjacent non-Grass tiles
	var adjacent_tiles: Array[Vector2i] = []
	var directions := [
		Vector2i(0, 1), Vector2i(0, -1),  # up/down
		Vector2i(1, 0), Vector2i(-1, 0),  # left/right
	]

	for grass_pos in grass_tiles:
		for dir in directions:
			var adj_pos = grass_pos + dir

			# Check bounds
			if adj_pos.x < 0 or adj_pos.y < 0 or adj_pos.x >= arena.BOARD_W or adj_pos.y >= arena.BOARD_H:
				continue

			var adj_tile = board.get_tile(adj_pos.x, adj_pos.y)
			if not adj_tile:
				continue

			# Skip if already Grass
			if adj_tile.terrain_type == "Grass":
				continue

			# Skip if HOLE (holes cannot be changed)
			if adj_tile.terrain_type == "Hole":
				continue

			# Skip if Lava (grass won't spread to lava)
			if adj_tile.terrain_type == "Lava":
				continue

			# Add to candidates (avoid duplicates)
			if not adjacent_tiles.has(adj_pos):
				adjacent_tiles.append(adj_pos)

	# 🌿 Pick one random adjacent tile to convert
	if adjacent_tiles.is_empty():
		arena._log("🌿 %s has no more tiles to spread to." % unit.card.name, Color(0.7, 0.9, 0.7))
		return

	var target_pos := adjacent_tiles[randi() % adjacent_tiles.size()]
	var target_tile = board.get_tile(target_pos.x, target_pos.y)

	if target_tile:
		# 🔊 Play spreading sound
		_play_sound(arena, spread_sound, -10, 0.85, 1.0)

		# Convert to Grass
		target_tile.terrain_type = "Grass"
		if target_tile.has_method("_apply_terrain_visual"):
			target_tile._apply_terrain_visual("Grass")

		# Apply terrain bonus if occupied
		if target_tile.occupant:
			arena._apply_terrain_bonus(target_tile.occupant, "Grass")
			arena._log("🌿 %s spreads grass beneath %s!" % [unit.card.name, target_tile.occupant.card.name], Color(0.6, 1.0, 0.8))
		else:
			arena._log("🌿 %s spreads grass to a new tile!" % unit.card.name, Color(0.6, 1.0, 0.8))

		# Floating feedback
		if arena.has_method("_float_text"):
			arena._float_text(target_tile.global_position + Vector3(0, 1, 0), "🌿 SPREAD", Color(0.5, 1.0, 0.5))

		await arena.get_tree().create_timer(0.2).timeout


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
