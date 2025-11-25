# File: arena_gd
extends Camera3D
class_name ArenaCamera

var core: ArenaCore
var board: Node3D

var is_freelook := false
var _rotation_x := deg_to_rad(45.0)
var _rotation_y := 0.0
var _mouse_sensitivity := 0.005
var _zoom_distance := 20.0

# 🎥 --- Cinematic / Locking support ---
var _camera_locked := false
var _default_pos: Vector3
var _default_fov: float
var _cinematic_tween: Tween = null

# ====================================================
# INIT
# ====================================================
func init_camera(core_ref: ArenaCore) -> void:
	core = core_ref
	board = core.board
	_position_default()
	_default_pos = position
	_default_fov = fov

func _unhandled_input(event):
	if InputState.mode == InputState.Mode.DIALOGUE:
		return
	if event.is_action_pressed("ui_accept"): # press Enter
		print("Camera position:", position)
		print("Camera rotation_degrees:", rotation_degrees)

# ====================================================
# FREEMOVE + MOUSE LOOK
# ====================================================
func toggle_freelook(pressed: bool) -> void:
	if not self:
		return
	if pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		is_freelook = true
		var rot = rotation
		_rotation_x = rot.x
		_rotation_y = rot.y
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		is_freelook = false
		recenter_to_default()

func forward_mouse_motion(relative: Vector2) -> void:
	if not is_freelook or _camera_locked:
		return
	_rotation_y -= relative.x * _mouse_sensitivity
	_rotation_x -= relative.y * _mouse_sensitivity
	_rotation_x = clamp(_rotation_x, deg_to_rad(-80), deg_to_rad(-10))
	rotation.x = _rotation_x
	rotation.y = _rotation_y
	rotation.z = 0.0

func _physics_process(delta: float) -> void:
	if not core or _camera_locked:
		return
	if is_freelook:
		_handle_freelook_movement(delta)
	else:
		_handle_wasd(delta)
		_handle_wheel(delta)
		_clamp_camera_to_board()

func _handle_freelook_movement(delta: float) -> void:
	var move_dir := Vector3.ZERO
	var forward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()
	var up := Vector3.UP

	if Input.is_action_pressed("move_forward"): move_dir += forward
	if Input.is_action_pressed("move_downward"): move_dir -= forward
	if Input.is_action_pressed("move_left"): move_dir -= right
	if Input.is_action_pressed("move_right"): move_dir += right
	if Input.is_action_pressed("move_up"): move_dir += up
	if Input.is_action_pressed("move_down"): move_dir -= up

	if move_dir != Vector3.ZERO:
		position += move_dir.normalized() * core.camera_move_speed * delta

	if Input.is_action_pressed("wheel_up"):
		position += forward * core.camera_zoom_speed * delta * 5
	elif Input.is_action_pressed("wheel_down"):
		position -= forward * core.camera_zoom_speed * delta * 5

# ====================================================
# CAMERA POSITION LOGIC
# ====================================================
func _position_default() -> void:
	position = Vector3(0, 5.41941, 3.5)
	rotation_degrees = Vector3(-59.99313, 0, 0)
	_zoom_distance = 8.934
	
func focus_on_leader(owner: int, duration := 0.6) -> void:
	if not core:
		return
	var leader := core.player_leader if owner == core.PLAYER else core.enemy_leader
	if not leader:
		return
	var pos := core.board.get_tile_position_for_unit(leader)
	if not pos:
		return
	var tile := core.board.get_tile(pos.x, pos.y)
	if not tile:
		return
	# 🎯 Maintain default zoom level (matching intro cutscene position)
	var target_pos := tile.global_position + Vector3(0, 5.41941, 3.5)
	var target_rot := Vector3(-59.99313, 0, 0)
	if _cinematic_tween:
		_cinematic_tween.kill()
	_cinematic_tween = create_tween()
	_cinematic_tween.tween_property(self, "position", target_pos, duration)
	_cinematic_tween.parallel().tween_property(self, "rotation_degrees", target_rot, duration)

func recenter_to_default(duration := 0.6) -> void:
	if not self:
		return
	if _cinematic_tween:
		_cinematic_tween.kill()
	_cinematic_tween = create_tween()
	_cinematic_tween.tween_property(self, "position", Vector3(0, 5.41941, 3.5), duration)
	_cinematic_tween.parallel().tween_property(self, "rotation_degrees", Vector3(-59.99313, 0, 0), duration)

func _reset_to_topdown() -> void:
	var angle = deg_to_rad(45)
	position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	look_at(Vector3(0, 0, 1), Vector3.UP)

# ====================================================
# MOVEMENT + ZOOM
# ====================================================
func _handle_wasd(delta: float) -> void:
	var move := Vector3.ZERO
	var forward := -global_transform.basis.z; forward.y = 0; forward = forward.normalized()
	var right := global_transform.basis.x; right.y = 0; right = right.normalized()
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"): move -= right
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"): move += right
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward"): move += forward
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_downward"): move -= forward
	if move != Vector3.ZERO:
		position += move.normalized() * core.camera_move_speed * delta

func _handle_wheel(delta: float) -> void:
	var zm := false
	if Input.is_action_pressed("wheel_up"):
		_zoom_distance -= core.camera_zoom_speed * delta * 5; zm = true
	if Input.is_action_pressed("wheel_down"):
		_zoom_distance += core.camera_zoom_speed * delta * 5; zm = true
	_zoom_distance = clamp(_zoom_distance, core.min_zoom, core.max_zoom)
	if zm:
		var angle := deg_to_rad(45)
		position.y = sin(angle) * _zoom_distance * 1.5
		position.z = cos(angle) * _zoom_distance * 1.5
	position.y = clamp(position.y, 3.0, 25.0)

func _clamp_camera_to_board() -> void:
	var spacing: float = board.spacing
	var half_w = (core.BOARD_W - 1) * spacing * 0.5
	var half_h = (core.BOARD_H - 1) * spacing * 0.5
	var margin = spacing * 3.5
	var forward_extra = spacing * 3.0
	var min_x = -half_w - margin
	var max_x = half_w + margin
	var min_z = -half_h - margin
	var max_z = half_h + margin + forward_extra
	var forward = -global_transform.basis.z.normalized()
	var focus_distance := _zoom_distance * 0.6
	var focus_point = position + forward * focus_distance
	focus_point.x = clamp(focus_point.x, min_x, max_x)
	focus_point.z = clamp(focus_point.z, min_z, max_z)
	var corrected_camera_pos = focus_point - forward * focus_distance
	position = corrected_camera_pos

# ====================================================
# 🔹 Cinematic Battle Focus
# ====================================================
func focus_on_battle(att_pos: Vector3, def_pos: Vector3, zoom_in := true) -> void:
	if not self:
		return
	if _cinematic_tween:
		_cinematic_tween.kill()
	_camera_locked = true
	if zoom_in:
		_default_pos = position
		_default_fov = fov
		var default_basis := global_transform.basis.orthonormalized()
		var midpoint := (att_pos + def_pos) * 0.5
		var focus_point := midpoint + Vector3(0, 0.6, 0)
		var forward := -global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		var height := 4.5
		var push := 3.0
		var target_pos := midpoint - forward * push + Vector3(0, height, 0)
		_cinematic_tween = create_tween()
		_cinematic_tween.tween_property(self, "position", target_pos, 0.6)
		_cinematic_tween.parallel().tween_property(self, "fov", _default_fov * 0.85, 0.6)
		await _cinematic_tween.finished
		look_at(focus_point, Vector3.UP)
		global_transform.basis = default_basis.orthonormalized()
	else:
		_cinematic_tween = create_tween()
		_cinematic_tween.tween_property(self, "position", _default_pos, 0.6)
		_cinematic_tween.parallel().tween_property(self, "fov", _default_fov, 0.6)
		await _cinematic_tween.finished
		_camera_locked = false

# ====================================================
# RAY PICKING
# ====================================================
func ray_pick(screen_pos: Vector2) -> Dictionary:
	if not core:
		return {}

	var from = project_ray_origin(screen_pos)
	var dir = project_ray_normal(screen_pos)
	var to = from + dir * 1000  # ✅ Much longer range

	# Raycast targeting StaticBody3D on layer 1 (tile collision)
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1  # Layer 1 (StaticBody3D)
	q.collide_with_bodies = true
	q.collide_with_areas = false

	return core.get_world_3d().direct_space_state.intersect_ray(q)

# ====================================================
# 🌪 CAMERA SHAKE EFFECT (AAA-Style)
# ====================================================
var _shake_active := false
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _shake_frequency := 0.0
var _shake_origin := Vector3.ZERO

func shake(strength: float = 0.2, duration: float = 0.4, frequency: float = 6.0) -> void:
	if _shake_active:
		return
	_shake_active = true
	_shake_time = 0.0
	_shake_duration = duration
	_shake_strength = strength
	_shake_frequency = frequency
	_shake_origin = position
	set_process(true)

func _process(delta: float) -> void:
	if not _shake_active:
		return
	_shake_time += delta
	var progress = clamp(_shake_time / _shake_duration, 0.0, 1.0)
	var falloff := pow(1.0 - progress, 2.0)
	if int(_shake_time * _shake_frequency) != int((_shake_time - delta) * _shake_frequency):
		var offset := Vector3(
			randf_range(-1, 1),
			randf_range(-0.5, 0.5),
			randf_range(-1, 1)
		).normalized() * _shake_strength * falloff
		position = _shake_origin + offset
	if progress >= 1.0:
		_stop_shake()

func _stop_shake() -> void:
	_shake_active = false
	position = _shake_origin
	set_process(false)


# ====================================================
# 🎬 CINEMATIC CAMERA MOVEMENTS
# ====================================================

## Focus camera on a specific tile position
func focus_on_tile(tile_pos: Vector3, duration := 0.5, zoom_amount := 0.9) -> void:
	if not self:
		return
	if _cinematic_tween:
		_cinematic_tween.kill()

	_camera_locked = true
	_default_pos = position
	_default_fov = fov

	# Position camera with consistent zoom level (matching default)
	var target_pos := tile_pos + Vector3(0, 5.41941, 3.5)
	var target_rot := Vector3(-59.99313, 0, 0)

	_cinematic_tween = create_tween()
	_cinematic_tween.tween_property(self, "position", target_pos, duration)
	_cinematic_tween.parallel().tween_property(self, "rotation_degrees", target_rot, duration)
	_cinematic_tween.parallel().tween_property(self, "fov", _default_fov * zoom_amount, duration)
	await _cinematic_tween.finished


## Zoom out to show the entire board
func zoom_out_full_board(duration := 0.6) -> void:
	if not self:
		return
	if _cinematic_tween:
		_cinematic_tween.kill()

	_camera_locked = true
	_default_pos = position
	_default_fov = fov

	# High bird's eye view to see entire board
	var target_pos := Vector3(0, 12, 8)
	var target_rot := Vector3(-55, 0, 0)

	_cinematic_tween = create_tween()
	_cinematic_tween.tween_property(self, "position", target_pos, duration)
	_cinematic_tween.parallel().tween_property(self, "rotation_degrees", target_rot, duration)
	_cinematic_tween.parallel().tween_property(self, "fov", _default_fov * 1.1, duration)
	await _cinematic_tween.finished


## Return camera to default after cinematic
func return_to_default(duration := 0.5) -> void:
	if not self:
		return
	if _cinematic_tween:
		_cinematic_tween.kill()

	_cinematic_tween = create_tween()
	_cinematic_tween.tween_property(self, "position", _default_pos, duration)
	_cinematic_tween.parallel().tween_property(self, "rotation_degrees", Vector3(-59.99313, 0, 0), duration)
	_cinematic_tween.parallel().tween_property(self, "fov", _default_fov, duration)
	await _cinematic_tween.finished
	_camera_locked = false
