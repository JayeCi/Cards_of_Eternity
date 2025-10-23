extends CardAbility
class_name ElementalFan

@export var fire_sound: AudioStream = preload("res://Audio/FIRE.mp3")
@export var water_sound: AudioStream = preload("res://Audio/Water.mp3")
@export var earth_sound: AudioStream = preload("res://Audio/Rocks.mp3")
#@export var ice_sound: AudioStream = preload("res://Audio/Water.mp3")
#@export var shadow_sound: AudioStream = preload("res://Audio/Water.mp3")

func _init():
	display_name = "Elemental Fan"
	description = "On Summon | Flip: Spreads elemental energy forward in a widening fan, converting up to 3 rows of tiles to this card’s terrain — tiles rumble and quake as the energy spreads."
	trigger = "on_summon"
	value = 0
	range = 3


func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit or not unit.card:
		return
	var pos = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		return
	await execute_at(arena, unit, pos)


func execute_at(arena: Node, unit: UnitData, origin_pos: Vector2i) -> void:
	if not arena or not unit or not unit.card:
		return
	if origin_pos == Vector2i(-1, -1):
		return

	var board = arena.board
	var new_terrain := unit.card.preferred_terrain
	var changed_tiles: Array = []
	

	
	var dir := Vector2i(0, 1) if unit.owner == arena.PLAYER else Vector2i(0, -1)

	for step in range(1, range + 1):
		var forward := origin_pos + dir * step

		for side in range(-step, step + 1):
			var p := forward + Vector2i(side, 0)
			if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
				continue

			var tile = board.get_tile(p.x, p.y)
			if not tile or tile.terrain_type == new_terrain:
				continue
				
		# 🔥 Play sound only if this is a Lava-based Elemental Fan
			if new_terrain == "Lava":
				_play_fire_sound(arena)
			if new_terrain == "Water":
				_play_water_sound(arena)
			if new_terrain == "Stone":
				_play_earth_sound(arena)
				
			# 🌊 Delay ripple outward
			await arena.get_tree().create_timer(0.02 * step).timeout

			# 🔹 Shake tile visibly
			tile_start_shake(tile, step)


			# 🔹 Change terrain
			await arena.get_tree().create_timer(0.02).timeout
			tile.terrain_type = new_terrain
			if tile.has_method("_apply_terrain_visual"):
				tile._apply_terrain_visual(new_terrain)

			changed_tiles.append(tile)

			# Log and float text
			if tile.occupant:
				arena._apply_terrain_bonus(tile.occupant, new_terrain)
				arena._log("🌿 %s now resonates with %s terrain!" %
					[tile.occupant.card.name, new_terrain], Color(0.6, 1.0, 0.8))

			if arena.has_method("_float_text"):
				arena._float_text(tile.global_position + Vector3(0, 1, 0),
					new_terrain, Color(0.5, 0.9, 1.0))

	if changed_tiles.size() > 0:
		arena._log("🌪 %s unleashes Elemental Fan — %d tiles reshaped into %s terrain!" %
			[unit.card.name, changed_tiles.size(), new_terrain], Color(0.7, 1.0, 0.8))
	else:
		arena._log("💨 %s’s Elemental Fan fizzled — no tiles changed." %
			[unit.card.name], Color(0.8, 0.8, 0.8))

func tile_start_shake(tile: Node3D, step: int = 1) -> void:
	if not tile:
		return

	var strength = clamp(0.15 / float(step), 0.05, 0.1)
	var original := tile.position

	# ✅ Use tile.create_tween() — runs safely under its scene
	var tw := tile.create_tween()
	tw.set_parallel(true)

	# Bounce up & jitter
	tw.tween_property(tile, "position", original + Vector3(0, strength, 0), 0.06)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(tile, "position", original + Vector3(randf_range(-strength, strength), 0, randf_range(-strength, strength)), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(tile, "position", original, 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
