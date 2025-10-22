extends CardAbility
class_name ElementalSurge

@export var fire_sound: AudioStream = preload("res://Audio/FIRE.mp3")
@export var water_sound: AudioStream = preload("res://Audio/Water.mp3")
@export var earth_sound: AudioStream = preload("res://Audio/Rocks.mp3")

func _init():
	display_name = "Elemental Surge"
	description = "On Summon | Flip: Changes all adjacent tiles to match this card’s element."
	trigger = "on_summon"
	value = 0
	range = 1  # adjacent tiles

# ✅ Standard execution (for when summoned directly)
func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit or not unit.card:
		return
	var pos = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		return
	execute_at(arena, unit, pos)


# ✅ Position-based execution (for when moved/flipped and landed on a new tile)
func execute_at(arena: Node, unit: UnitData, target_pos: Vector2i) -> void:
	if not arena or not unit or not unit.card:
		return
	if target_pos == Vector2i(-1, -1):
		return

	var board = arena.board
	var new_terrain := unit.card.preferred_terrain
	var changed_tiles: Array = []

	for dx in range(-range, range + 1):
		for dy in range(-range, range + 1):
			if dx == 0 and dy == 0:
				continue
			var p = target_pos + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
				continue

			var tile = board.get_tile(p.x, p.y)
			if not tile:
				continue
		# 🔥 Play sound only if this is a Lava-based Elemental Fan
			if new_terrain == "Lava":
				_play_fire_sound(arena)
			if new_terrain == "Water":
				_play_water_sound(arena)
			if new_terrain == "Stone":
				_play_earth_sound(arena)
				
			# Skip if already that terrain
			if tile.terrain_type == new_terrain:
				continue

			tile.terrain_type = new_terrain
			if tile.has_method("_apply_terrain_visual"):
				tile._apply_terrain_visual(new_terrain)
			changed_tiles.append(tile)

			# Reapply terrain buffs
			if tile.occupant:
				arena._apply_terrain_bonus(tile.occupant, new_terrain)
				arena._log("🌿 %s now resonates with %s terrain!" % [tile.occupant.card.name, new_terrain],
					Color(0.6, 1.0, 0.8))

			if arena.has_method("_float_text"):
				arena._float_text(tile.global_position + Vector3(0, 1, 0), new_terrain, Color(0.5, 0.9, 1.0))

	# Slight pause for visuals
	await arena.get_tree().create_timer(0.3).timeout

	if changed_tiles.size() > 0:
		if arena.has_method("_log"):
			arena._log("🌎 %s’s Elemental Surge reshaped %d nearby tiles into %s!" % [
				unit.card.name, changed_tiles.size(), new_terrain
			], Color(0.7, 1.0, 0.8))

		var center_tile = board.get_tile(target_pos.x, target_pos.y)
		if center_tile and center_tile.has_method("pulse_move_highlight"):
			center_tile.pulse_move_highlight()
	else:
		if arena.has_method("_log"):
			arena._log("💨 %s’s Elemental Surge fizzled — no tiles changed." % unit.card.name,
				Color(0.8, 0.8, 0.8))

# -------------------------------------------------------------
# 🔊 Play Fire Sound Effect
# -------------------------------------------------------------
func _play_fire_sound(arena: Node) -> void:
	if not fire_sound or not arena:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = fire_sound
	player.volume_db = -8
	player.pitch_scale = randf_range(0.95, 1.05)
	player.position = Vector3(0, 1, 0)
	arena.add_child(player)
	player.play()

	# Auto-cleanup
	player.finished.connect(func(): player.queue_free())

func _play_water_sound(arena: Node) -> void:
	if not water_sound or not arena:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = water_sound
	player.volume_db = -10
	player.pitch_scale = randf_range(0.90, 1.9)
	player.position = Vector3(0, 1, 0)
	arena.add_child(player)
	player.play()

	# Auto-cleanup
	player.finished.connect(func(): player.queue_free())

func _play_earth_sound(arena: Node) -> void:
	if not earth_sound or not arena:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = earth_sound
	player.volume_db = -6
	player.pitch_scale = randf_range(0.90, 1.9)
	player.position = Vector3(0, 1, 0)
	arena.add_child(player)
	player.play()

	# Auto-cleanup
	player.finished.connect(func(): player.queue_free())
