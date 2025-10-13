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

func init_camera(core_ref: ArenaCore) -> void:
	core = core_ref
	camera = core.camera
	board = core.board
	_position_default()

func _physics_process(delta: float) -> void:
	if not camera: return
	_handle_wasd(delta)
	_handle_wheel(delta)
	_clamp_camera_to_board()

func toggle_freelook(pressed: bool) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if pressed else Input.MOUSE_MODE_VISIBLE)
	is_freelook = pressed
	if not pressed:
		_reset_to_topdown()


func forward_mouse_motion(relative: Vector2) -> void:
	if not is_freelook: return
	_rotation_y -= relative.x * _mouse_sensitivity
	_rotation_x += relative.y * _mouse_sensitivity
	_rotation_x = clamp(_rotation_x, deg_to_rad(10), deg_to_rad(80))

	var offset = Vector3()
	offset.x = sin(_rotation_y) * _zoom_distance
	offset.z = cos(_rotation_y) * _zoom_distance
	offset.y = tan(_rotation_x) * _zoom_distance * 0.75

	camera.position = offset
	camera.look_at(Vector3.ZERO, Vector3.UP)

func _position_default() -> void:
	var spacing = board.spacing
	var board_depth = (core.BOARD_H - 1) * spacing
	var board_width = (core.BOARD_W - 1) * spacing
	_zoom_distance = max(board_width, board_depth) * 0.8
	var angle = deg_to_rad(45)
	camera.position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	camera.look_at(Vector3(0,0,1), Vector3.UP)

func _reset_to_topdown() -> void:
	var angle = deg_to_rad(45)
	camera.position = Vector3(0, sin(angle) * _zoom_distance * 1.5, cos(angle) * _zoom_distance * 1.5)
	camera.look_at(Vector3(0,0,1), Vector3.UP)

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

# --- Picking (used by battle to update hover)
func ray_pick(screen_pos: Vector2) -> Dictionary:
	var from = camera.project_ray_origin(screen_pos)
	var dir = camera.project_ray_normal(screen_pos)
	var to = from + dir * 100
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	return core.get_world_3d().direct_space_state.intersect_ray(q)
