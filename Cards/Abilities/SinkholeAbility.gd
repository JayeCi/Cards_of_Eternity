extends CardAbility
class_name SinkholeAbility

@export var collapse_sound: AudioStream = preload("res://Audio/Rocks.mp3")

func _init():
	display_name = "Sinkhole"
	description = "When this trap is revealed, transforms its tile into a deadly HOLE."
	trigger = "on_summon"
	value = 0

# ✅ Standard execute (when EVENT card is revealed)
func execute(arena: Node, unit: UnitData) -> void:
	if not arena or not unit or not unit.card:
		return

	var pos = arena.board.get_unit_position(unit)
	if pos == Vector2i(-1, -1):
		return

	await execute_at(arena, unit, pos)

# ✅ Transform the tile into a HOLE
func execute_at(arena: Node, unit: UnitData, tile_pos: Vector2i) -> void:
	if not arena or not arena.board:
		return

	var board = arena.board
	var tile = board.get_tile(tile_pos.x, tile_pos.y)
	if not tile:
		return

	# 🔊 Play collapse sound
	_play_collapse_sound(arena)

	# Log the sinkhole opening
	arena._log("💀 A SINKHOLE suddenly opens where %s was placed!" % unit.card.name, Color(0.3, 0.3, 0.3))

	# ⚫ Transform tile to HOLE
	tile.terrain_type = "Hole"
	if tile.has_method("_apply_terrain_visual"):
		tile._apply_terrain_visual("Hole")

	# Floating feedback
	if arena.has_method("_float_text"):
		arena._float_text(tile.global_position + Vector3(0, 1, 0), "⚫ SINKHOLE", Color(0.3, 0.3, 0.3))

	await arena.get_tree().create_timer(0.5).timeout

	# 💀 The EVENT card itself falls into the hole it created
	arena._log("💨 %s collapses into the void!" % unit.card.name, Color(0.5, 0.5, 0.5))

	# Set DEF to 0 to allow _kill_unit to work
	unit.current_def = 0
	if arena.battle_sys and arena.battle_sys.has_method("_kill_unit"):
		await arena.battle_sys._kill_unit(unit, false)


# -------------------------------------------------------------
# 🔊 Play Collapse Sound Effect
# -------------------------------------------------------------
func _play_collapse_sound(arena: Node) -> void:
	if not collapse_sound or not arena:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = collapse_sound
	player.volume_db = -8
	player.pitch_scale = randf_range(0.7, 0.9)  # Lower pitch for ominous effect
	player.position = Vector3(0, 1, 0)
	arena.add_child(player)
	player.play()

	# Auto-cleanup
	player.finished.connect(func(): player.queue_free())
