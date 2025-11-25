extends CardAbility
class_name Terrain_5x3_Spell

@export var fire_sound: AudioStream = preload("res://Audio/FIRE.mp3")
@export var water_sound: AudioStream = preload("res://Audio/Water.mp3")
@export var stone_sound: AudioStream = preload("res://Audio/Rocks.mp3")
@export var grass_sound: AudioStream = preload("res://Audio/Dirt_Grass.mp3")

# ✅ Declare these at the top so Godot recognizes them
var range_forward: int = 3   # how far forward the fissure extends
var range_side: int = 2      # 2 left and 2 right = 5 total width

func _init():
	display_name = "Elemental Fissure"
	description = "On Summon | Flip: Changes a 5x3 area in front of this card to match this card’s element."
	trigger = "on_summon"
	value = 0


# ===============================================================
# ✅ Standard Execution
# ===============================================================
func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit or not unit.card:
		return
	var pos = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		return
	await execute_at(arena, unit, pos)

	# 💨 Dissipate the spell card afterward
	await arena.get_tree().create_timer(0.4).timeout
	arena._log("💨 %s’s magic fissure fades into the elements." % unit.card.name, Color(0.7, 0.9, 1.0))
	if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
		arena.battle_sys._kill_unit(unit)


# ===============================================================
# 🌎 Main Effect — 5 tiles wide × 3 tiles forward
# ===============================================================
func execute_at(arena: Node, unit: UnitData, origin_pos: Vector2i) -> void:
	if not arena or not unit or not unit.card:
		return
	if origin_pos == Vector2i(-1, -1):
		return

	var board = arena.board
	var new_terrain := unit.card.preferred_terrain
	var changed_tiles: Array = []

	# --- Facing direction ---
	var dir := Vector2i(0, 1) if unit.owner == arena.PLAYER else Vector2i(0, -1)
	var side_dir := Vector2i(1, 0)  # horizontal spread

	for forward_i in range(1, range_forward + 1):
		for side_i in range(-range_side, range_side + 1):  # includes both sides
			var p = origin_pos + dir * forward_i + side_dir * side_i
			if p.x < 0 or p.y < 0 or p.x >= arena.BOARD_W or p.y >= arena.BOARD_H:
				continue

			var tile = board.get_tile(p.x, p.y)
			if not tile:
				continue

			# 🔊 Play sound once per forward row
			if side_i == 0:
				match new_terrain:
					"Lava": _play_fire_sound(arena)
					"Water": _play_water_sound(arena)
					"Stone": _play_earth_sound(arena)
					"Grass": _play_grass_sound(arena)

			# Skip if terrain already matches
			if tile.terrain_type == new_terrain:
				continue

			# ⚫ HOLES cannot be changed by terrain abilities
			if tile.terrain_type == "Hole":
				continue

			# Apply terrain change
			tile.terrain_type = new_terrain
			if tile.has_method("_apply_terrain_visual"):
				tile._apply_terrain_visual(new_terrain)
			changed_tiles.append(tile)

			# Re-apply buffs for any unit on this tile
			if tile.occupant:
				arena._apply_terrain_bonus(tile.occupant, new_terrain)
				arena._log("🌿 %s now resonates with %s terrain!" %
					[tile.occupant.card.name, new_terrain], Color(0.6, 1.0, 0.8))

			# Floating feedback
			if arena.has_method("_float_text"):
				arena._float_text(tile.global_position + Vector3(0, 1, 0),
					new_terrain, Color(0.5, 0.9, 1.0))

		await arena.get_tree().create_timer(0.15).timeout  # Stagger each forward row

	# 🌎 Summary feedback
	if changed_tiles.size() > 0:
		arena._log("🌪 %s’s Elemental Fissure reshaped %d tiles into %s terrain!" %
			[unit.card.name, changed_tiles.size(), new_terrain], Color(0.7, 1.0, 0.8))
		var center_tile = board.get_tile(origin_pos.x, origin_pos.y)
		if center_tile and center_tile.has_method("pulse_move_highlight"):
			center_tile.pulse_move_highlight()
	else:
		arena._log("💨 %s’s Elemental Fissure fizzled — no tiles changed." %
			unit.card.name, Color(0.8, 0.8, 0.8))


# ===============================================================
# 🔊 Sound Helpers
# ===============================================================
func _play_fire_sound(arena: Node) -> void:
	_play_sound(arena, fire_sound, -8, 0.95, 1.05)

func _play_water_sound(arena: Node) -> void:
	_play_sound(arena, water_sound, -10, 0.9, 1.9)

func _play_earth_sound(arena: Node) -> void:
	_play_sound(arena, stone_sound, -6, 0.9, 1.9)

func _play_grass_sound(arena: Node) -> void:
	_play_sound(arena, grass_sound, -6, 0.9, 1.9)

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
	player.finished.connect(func(): player.queue_free())
