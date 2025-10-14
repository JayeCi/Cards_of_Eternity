extends Node
class_name ArenaCutscene

var core: ArenaCore
var board: Node3D
var camera: Camera3D
var _is_cutscene_running := false

func init_cutscene(core_ref: ArenaCore) -> void:
	core = core_ref
	board = core.board
	camera = core.camera

func _unhandled_input(event: InputEvent) -> void:
	if _is_cutscene_running and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _intro() -> void:
	_is_cutscene_running = true
	core.is_cutscene_active = true  # 🔒 Tell systems to ignore hover
	_disable_input(true)
	_hide_battle_ui(true)
	
	var fade_rect: ColorRect = core.get_node("UISystem/FadeRect")
	fade_rect.modulate.a = 1.0
	await get_tree().process_frame

	# Start pulled back
	var spacing = board.spacing
	var board_center = Vector3(0, 0, 1)
	var board_depth = (core.BOARD_H - 1) * spacing
	var board_width = (core.BOARD_W - 1) * spacing
	var zdist = max(board_width, board_depth) * 1.2
	var angle = deg_to_rad(50)
	camera.position = Vector3(0, sin(angle) * zdist * 1.5, cos(angle) * zdist * 1.5)
	camera.look_at(board_center, Vector3.UP)

	await _fade(0.0, 1.0)
	# Reveal leaders with a smooth rise
	await _reveal_leader_with_rise(core.player_leader, 0.2)
	await _reveal_leader_with_rise(core.enemy_leader, 0.6)

			#tw.tween_property(m, "scale", Vector3.ONE, 0.4)

	# Enemy Leader fade-in
	await _fade_in_leader(get_leader_pos(core.ENEMY), "👑 The Enemy Leader has appeared!")

	# Player Leader fade-in
	await _fade_in_leader(get_leader_pos(core.PLAYER), "👑 Your Leader enters the battlefield!")

	# Final pull back
	await get_tree().create_timer(0.6).timeout
	await _smooth_return()
	await get_tree().create_timer(0.8).timeout

	_hide_battle_ui(false)
	core.is_cutscene_active = false  # 🔓 Allow hover again
	_disable_input(false)
	_is_cutscene_running = false
	
	
	
# -------------------------------------------------
# UI Helpers
# -------------------------------------------------
func _reveal_leader_with_rise(unit: UnitData, delay := 0.0, rise_height := 0.6, duration := 1.0):
	if not unit or not unit.has_meta("leader_model"):
		return

	var model: Node3D = unit.get_meta("leader_model")
	if not model:
		return

	await get_tree().create_timer(delay).timeout
	model.visible = true

	var start_pos = model.position
	model.position = start_pos - Vector3(0, rise_height, 0)
	var tw = create_tween()
	tw.tween_property(model, "position", start_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(model, "modulate:a", 1.0, duration * 0.8)

func _hide_battle_ui(hide: bool) -> void:
	if not core: return

	# Grab panels
	var card_details = core.get_node("UISystem/ArenaCardDetails")
	var terrain_details = core.get_node("UISystem/ArenaTerrainDetails")

	if hide:
		# During cutscene — hide immediately
		card_details.hide_card()
		card_details.visible = false
		terrain_details.hide_terrain()
		terrain_details.visible = false
	else:
		# After cutscene — keep hidden until player hovers something
		card_details.visible = false
		terrain_details.visible = false

# -------------------------------------------------
# Rest of your existing methods remain unchanged
# -------------------------------------------------
func _fade(to_alpha: float, dur: float):
	var rect: ColorRect = core.get_node("UISystem/FadeRect")
	var tw = create_tween()
	tw.tween_property(rect, "modulate:a", to_alpha, dur)
	await tw.finished


func _fade_in_leader(pos: Vector2i, label: String):
	var tile = board.get_tile(pos.x, pos.y)
	if not tile or not tile.has_node("CardMesh"):
		core._log("⚠ Missing CardMesh for leader at %s" % str(pos))
		return

	var mesh = tile.get_node("CardMesh")
	mesh.visible = true

	# ---- Prepare material for fade ----
	var mat = mesh.get_surface_override_material(0)
	if mat == null:
		mat = StandardMaterial3D.new()
	else:
		mat = mat.duplicate()
	mesh.set_surface_override_material(0, mat)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.flags_transparent = true

	var color = mat.albedo_color
	color.a = 0.0
	mat.albedo_color = color

	# ---- Instantly snap camera to leader ----
	var target_pos: Vector3 = tile.global_position + Vector3(0, 0.25, 0)
	var zoom_angle := deg_to_rad(65)
	var zoom_distance := 3.5

	# Compute the exact camera position
	var cam_pos := target_pos + Vector3(
		0,
		sin(zoom_angle) * zoom_distance,
		cos(zoom_angle) * zoom_distance * 0.5
	)

	camera.global_position = cam_pos
	camera.look_at(target_pos, Vector3.UP)

	# ---- Fade & Rise (cinematic) ----
	var start_pos = mesh.position
	mesh.position = start_pos - Vector3(0, 0.3, 0)

	var rise_tween := create_tween().set_trans(Tween.TRANS_SINE)
	rise_tween.tween_property(mesh, "position", start_pos, 1.2)

	# Smooth fade-in of alpha
	for step in range(0, 12):
		await get_tree().create_timer(0.07).timeout
		color.a = float(step) / 12.0
		mat.albedo_color = color

	await get_tree().create_timer(0.4).timeout
	core._log(label)

# helper so camera smoothly keeps aiming at target each frame
func _on_camera_follow_target(_delta, target_pos: Vector3) -> void:
	if camera:
		camera.look_at(target_pos, Vector3.UP)

func _smooth_return():
	var spacing = board.spacing
	var board_depth = (core.BOARD_H - 1) * spacing
	var board_width = (core.BOARD_W - 1) * spacing
	var target_zoom = max(board_width, board_depth) * 0.8
	var angle = deg_to_rad(45)
	var pos = Vector3(0, sin(angle) * target_zoom * 1.5, cos(angle) * target_zoom * 1.5)
	var t = create_tween()
	t.tween_property(core.camera, "position", pos, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): core.camera.look_at(Vector3(0, 0, 1), Vector3.UP))


func get_leader_pos(owner: int) -> Vector2i:
	for pos in core.units.keys():
		var u: UnitData = core.units[pos]
		if u.is_leader and u.owner == owner:
			return pos
	return Vector2i(-1, -1)


func _focus_camera_on(target_pos: Vector3, zoom_mult: float, duration: float):
	var angle = deg_to_rad(45)
	var distance = 20.0 * zoom_mult
	var desired_pos = Vector3(target_pos.x, sin(angle) * distance * 1.5, target_pos.z + cos(angle) * distance * 1.5)
	var t = create_tween()
	t.tween_property(core.camera, "position", desired_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): core.camera.look_at(target_pos, Vector3.UP))


func _disable_input(b: bool) -> void:
	core.set_process_input(not b)

	if b:
		# 🖱️ Lock mouse & hide cursor
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		# 🖱️ Restore normal mouse mode
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
