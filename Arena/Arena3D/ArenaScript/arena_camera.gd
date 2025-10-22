# File: arena_camera.gd
extends Node
class_name ArenaCamera

var core: ArenaCore
var camera: Camera3D
var board: Node3D

var is_freelook := false
var _rotation_x := deg_to_rad(45.0)
var _rotation_y := 0.0
var _mouse_sensitivity := 0.005
var _zoom_distance := 20.0

# 🎥 --- NEW: Cinematic / Locking support ---
var _camera_locked := false
var _default_pos: Vector3
var _default_fov: float
var _cinematic_tween: Tween = null

# ====================================================
# INIT
# ====================================================
func init_camera(core_ref: ArenaCore) -> void:
	core = core_ref
	camera = core.camera
	board = core.board
	_position_default()
	_default_pos = camera.position
	_default_fov = camera.fov

func _physics_process(delta: float) -> void:
	if not camera or _camera_locked:  # 🚫 Ignore input while locked
		return
	_handle_wasd(delta)
	_handle_wheel(delta)
	_clamp_camera_to_board()

# ====================================================
# FREEMOVE + MOUSE LOOK
# ====================================================
func toggle_freelook(pressed: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if pressed else Input.MOUSE_MODE_VISIBLE)
	is_freelook = pressed
	if not pressed:
		_reset_to_topdown()

func forward_mouse_motion(relative: Vector2) -> void:
	if not is_freelook or _camera_locked:  # 🚫 Prevent rotation during cinematic
		return
	_rotation_y -= relative.x * _mouse_sensitivity
	_rotation_x += relative.y * _mouse_sensitivity
	_rotation_x = clamp(_rotation_x, deg_to_rad(10), deg_to_rad(80))

	var offset = Vector3()
	offset.x = sin(_rotation_y) * _zoom_distance
	offset.z = cos(_rotation_y) * _zoom_distance
	offset.y = tan(_rotation_x) * _zoom_distance * 0.75

	camera.position = offset
	camera.look_at(Vector3.ZERO, Vector3.UP)

# ====================================================
# CAMERA POSITION LOGIC
# ====================================================
func _position_default() -> void:
	var spacing = board.spacing
	var board_depth = (core.BOARD_H - 1) * spacing
	var board_width = (core.BOARD_W - 1) * spacing
	_zoom_distance = max(board_width, board_depth) * 0.8
	var angle = deg_to_rad(45)
	camera.position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	camera.look_at(Vector3(0, 0, 1), Vector3.UP)

func _reset_to_topdown() -> void:
	var angle = deg_to_rad(45)
	camera.position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	camera.look_at(Vector3(0, 0, 1), Vector3.UP)

# ====================================================
# MOVEMENT + ZOOM
# ====================================================
func _handle_wasd(delta: float) -> void:
	var move := Vector3.ZERO
	var forward := -camera.global_transform.basis.z; forward.y = 0; forward = forward.normalized()
	var right := camera.global_transform.basis.x; right.y = 0; right = right.normalized()
	if Input.is_action_pressed("ui_left") or Input.is_action_pressed("move_left"): move -= right
	if Input.is_action_pressed("ui_right") or Input.is_action_pressed("move_right"): move += right
	if Input.is_action_pressed("ui_up") or Input.is_action_pressed("move_forward"): move += forward
	if Input.is_action_pressed("ui_down") or Input.is_action_pressed("move_downward"): move -= forward
	if move != Vector3.ZERO:
		camera.position += move.normalized() * core.camera_move_speed * delta

func _handle_wheel(delta: float) -> void:
	var zm := false
	if Input.is_action_pressed("wheel_up"):
		_zoom_distance -= core.camera_zoom_speed * delta * 5; zm = true
	if Input.is_action_pressed("wheel_down"):
		_zoom_distance += core.camera_zoom_speed * delta * 5; zm = true
	_zoom_distance = clamp(_zoom_distance, core.min_zoom, core.max_zoom)
	if zm:
		var angle := deg_to_rad(45)
		camera.position.y = sin(angle) * _zoom_distance * 1.5
		camera.position.z = cos(angle) * _zoom_distance * 1.5
	camera.position.y = clamp(camera.position.y, 3.0, 25.0)

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

	var forward = -camera.global_transform.basis.z.normalized()
	var focus_distance := _zoom_distance * 0.6
	var focus_point = camera.position + forward * focus_distance
	focus_point.x = clamp(focus_point.x, min_x, max_x)
	focus_point.z = clamp(focus_point.z, min_z, max_z)
	var corrected_camera_pos = focus_point - forward * focus_distance
	camera.position = corrected_camera_pos

# ====================================================
# 🔹 Cinematic Battle Focus
# ====================================================
func focus_on_battle(att_pos: Vector3, def_pos: Vector3, zoom_in := true) -> void:
	if not camera:
		return
	if _cinematic_tween:
		_cinematic_tween.kill()

	_camera_locked = true

	if zoom_in:
		# --- Save current transform so we can restore perfectly later ---
		_default_pos = camera.position
		_default_fov = camera.fov
		var default_basis := camera.global_transform.basis.orthonormalized()

		# --- Calculate midpoint of both fighters ---
		var midpoint := (att_pos + def_pos) * 0.5
		var focus_point := midpoint + Vector3(0, 0.6, 0)

		# --- Direction the camera is already facing ---
		var forward := -camera.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()

		# --- Position directly in front of the midpoint (toward enemy side) ---
		var height := 4.5
		var push := 3.0
		var target_pos := midpoint - forward * push + Vector3(0, height, 0)

		# --- Tween position + FOV only (rotation unchanged) ---
		_cinematic_tween = create_tween()
		_cinematic_tween.tween_property(camera, "position", target_pos, 0.6)
		_cinematic_tween.parallel().tween_property(camera, "fov", _default_fov * 0.85, 0.6)
		await _cinematic_tween.finished

		# Maintain focus without changing rotation each frame
		camera.look_at(focus_point, Vector3.UP)
		camera.global_transform.basis = default_basis.orthonormalized()

	else:
		# --- Return to original position + FOV + rotation ---
		_cinematic_tween = create_tween()
		_cinematic_tween.tween_property(camera, "position", _default_pos, 0.6)
		_cinematic_tween.parallel().tween_property(camera, "fov", _default_fov, 0.6)
		await _cinematic_tween.finished

		_camera_locked = false

# ====================================================
# RAY PICKING
# ====================================================
func ray_pick(screen_pos: Vector2) -> Dictionary:
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	var to = from + dir * 100
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return core.get_world_3d().direct_space_state.intersect_ray(q)

# ====================================================
# 🌪 CAMERA SHAKE EFFECT
# ====================================================
func shake(intensity: float = 0.2, duration: float = 0.3) -> void:
	if not camera:
		return

	# Prevent overlapping shakes
	if camera.has_meta("is_shaking") and camera.get_meta("is_shaking"):
		return

	camera.set_meta("is_shaking", true)

	var original_pos := camera.position
	var tween := create_tween()
	tween.set_loops()  # run continuously until killed
	tween.set_parallel(true)

	# Internal helper to randomize offset
