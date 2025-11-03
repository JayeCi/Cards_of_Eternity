extends Node
class_name ArenaCutsceneTutorial

var core: ArenaCoreTutorial
var board: Node3D
var camera: Camera3D
var _is_cutscene_running := false
signal camera_focus_on_player_started

func wait_for_camera_focus_on_player() -> void:
	await camera_focus_on_player_started

func init_cutscene(core_ref: ArenaCoreTutorial) -> void:
	core = core_ref
	board = core.board
	camera = core.camera

func _unhandled_input(event: InputEvent) -> void:
	# If we’re in dialogue mode, DO NOT block click events!
	if InputState.mode == InputState.Mode.DIALOGUE:
		return

	if _is_cutscene_running and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

func _intro() -> void:
	# Prevent early camera motion flicker
	await get_tree().process_frame
	camera.force_update_transform()

	_is_cutscene_running = true
	core.is_cutscene_active = true
	_hide_battle_ui(true)


	## 🕶 Keep screen black while board initializes
	#camera.position = Vector3(0, 1000, 0)
	#camera.look_at(Vector3.ZERO, Vector3.UP)

	# ======================================================
	# 🎬 ENEMY LEADER REVEAL (Smooth camera + rise + sound)
	# ======================================================
	var enemy_pos := get_leader_pos(core.ENEMY)
	var enemy_tile = board.get_tile(enemy_pos.x, enemy_pos.y)
	if enemy_tile:
		var enemy_world = enemy_tile.global_position + Vector3(0, 0.25, 0)
		var zoom_angle := deg_to_rad(65)
		var zoom_distance := 3.5
		var enemy_cam_target = enemy_world + Vector3(0, sin(zoom_angle) * zoom_distance, cos(zoom_angle) * zoom_distance * 0.5)

		var cam_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(camera, "global_position", enemy_cam_target, 1.4)
		cam_tween.parallel().tween_method(func(val): camera.look_at(val, Vector3.UP), enemy_world, enemy_world, 1.4)

		# Play sound slightly after start of movement
		await get_tree().create_timer(0.2).timeout
		core._play_leader_spawn_sound(core.enemy_leader)
		await _reveal_leader_with_rise(core.enemy_leader, 0.0, 0.6, 1.2)

		await cam_tween.finished
		await _fade_in_leader(enemy_pos, "👑 The Enemy Leader has appeared!")

	# Hold briefly before switching
	#await get_tree().create_timer(0.8).timeout

	# ======================================================
	# 🎬 PLAYER LEADER REVEAL (Smooth camera + rise + sound)
	# ======================================================
	var player_pos := get_leader_pos(core.PLAYER)
	var player_tile = board.get_tile(player_pos.x, player_pos.y)
	if player_tile:
		var player_world = player_tile.global_position + Vector3(0, 0.25, 0)
		var zoom_angle := deg_to_rad(65)
		var zoom_distance := 3.5
		var player_cam_target = player_world + Vector3(0, sin(zoom_angle) * zoom_distance, cos(zoom_angle) * zoom_distance * 0.5)

		var cam_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tween.tween_property(camera, "global_position", player_cam_target, 1.4)
		cam_tween.parallel().tween_method(func(val): camera.look_at(val, Vector3.UP), player_world, player_world, 1.4)

		await get_tree().create_timer(0.2).timeout
		core._play_leader_spawn_sound(core.player_leader)
		await _reveal_leader_with_rise(core.player_leader, 0.0, 0.6, 1.2)

		await cam_tween.finished
		await _fade_in_leader(player_pos, "👑 Your Leader enters the battlefield!")
	# ======================================================
	# 🎥 RETURN CAMERA + END CUTSCENE
	# ======================================================
	await get_tree().create_timer(0.6).timeout
	#await _smooth_return()
	await camera.focus_on_leader(0)
	await get_tree().create_timer(0.8).timeout

	_hide_battle_ui(false)
	core.is_cutscene_active = false
	
	InputState.set_mode(InputState.Mode.DIALOGUE)
	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Welcome to your first battle!"),
		DialogueManager._dl("Guide", "This is a 7x7 battlefield."),
		DialogueManager._dl("Guide", "Your goal is to defeat their Leader!"),
		DialogueManager._dl("Guide", "Try summoning a monster in Attack Mode."),
		DialogueManager._dl("Guide", "Click a hand card, then click a highlighted tile.")
		
	])
	if !DialogueManager.finished.is_connected(_on_tutorial_dialogue_finished):
		DialogueManager.finished.connect(_on_tutorial_dialogue_finished, Object.CONNECT_ONE_SHOT)

	# ✅ Ensure both leaders remain visible after cutscene
	for leader in [core.player_leader, core.enemy_leader]:
		var pos = get_leader_pos(leader.owner)
		var tile = board.get_tile(pos.x, pos.y)
		if tile and tile.has_node("CardMesh"):
			var mesh = tile.get_node("CardMesh")
			mesh.visible = true
			if mesh.get_surface_override_material(0):
				var mat = mesh.get_surface_override_material(0)
				var color = mat.albedo_color
				color.a = 1.0
				mat.albedo_color = color

	_is_cutscene_running = false
	
func _on_tutorial_dialogue_finished(_id := StringName("")):
	InputState.set_mode(InputState.Mode.FREE)
	_disable_input(false)

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
	# ✅ Show the full model hierarchy now that the reveal is happening
	model.visible = true
	for child in model.get_children():
		if child.name == "CardMesh" or child is MeshInstance3D:
			child.visible = true


	var start_pos = model.position
	model.position = start_pos - Vector3(0, rise_height, 0)
	var tw = create_tween()
	tw.tween_property(model, "position", start_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#tw.tween_property(model, "modulate:a", 1.0, duration * 0.8)

func _hide_battle_ui(hide: bool) -> void:
	if not core: return

	# Grab panels
	var card_details = core.get_node("UISystemTutorial/ArenaCardDetails")
	var terrain_details = core.get_node("UISystemTutorial/ArenaTerrainDetails")

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
	var rect: ColorRect = core.get_node("UISystemTutorial/FadeRect")
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

	# ---- Material fade setup ----
	var mat = mesh.get_surface_override_material(0)
	if mat == null:
		mat = StandardMaterial3D.new()
		mesh.set_surface_override_material(0, mat)

	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.flags_transparent = true
	var color = mat.albedo_color
	color.a = 0.0
	mat.albedo_color = color

	# ---- Smooth camera tween ----
	var target_pos: Vector3 = tile.global_position + Vector3(0, 0.25, 0)
	var zoom_angle := deg_to_rad(65)
	var zoom_distance := 3.5
	var cam_target := target_pos + Vector3(0, sin(zoom_angle) * zoom_distance, cos(zoom_angle) * zoom_distance * 0.5)

	# Kill any old tweens
	if camera.has_meta("intro_tween") and camera.get_meta("intro_tween"):
		var old := camera.get_meta("intro_tween") as Tween
		if old and old.is_running():
			old.kill()

	var tw := create_tween()
	camera.set_meta("intro_tween", tw)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(camera, "global_position", cam_target, 1.2)
	tw.parallel().tween_method(func(val): camera.look_at(val, Vector3.UP), target_pos, target_pos, 1.2)
	await tw.finished

	# ---- Fade & Rise ----
	var start_pos = mesh.position
	mesh.position = start_pos - Vector3(0, 0.3, 0)
	var rise_tween := create_tween().set_trans(Tween.TRANS_SINE)
	rise_tween.tween_property(mesh, "position", start_pos, 1.2)

	for step in range(0, 12):
		await get_tree().create_timer(0.07).timeout
		color.a = float(step) / 12.0
		mat.albedo_color = color

	color.a = 1.0
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
