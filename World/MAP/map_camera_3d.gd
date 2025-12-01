extends Camera3D
class_name MapCamera3D

signal focus_complete()

@export var default_distance: float = 10.0  # Distance above the map
@export var default_angle: float = -70.0  # Look down angle (degrees) - more top-down
@export var focus_distance: float = 8.0  # Distance when focused on a node (not too close)
@export var focus_angle: float = -70.0  # Angle when focused (keep same angle)
@export var move_speed: float = 3.0  # Speed of camera transitions
@export var pan_speed: float = 10.0  # Speed of WASD camera panning

var is_focusing: bool = false
var focus_target: Vector3
var default_position: Vector3
var current_focus_node: MapNode3D = null
var camera_offset: Vector3 = Vector3.ZERO  # Offset from panning

func _ready():
	# Make this the current camera
	make_current()

	# Set up default camera position
	setup_default_position()

	print("📷 Camera ready at: ", global_position, " rotation: ", rotation_degrees)

func _process(delta: float):
	if is_focusing:
		process_focus_transition(delta)
	else:
		# Handle WASD panning when not focusing
		process_camera_panning(delta)

func setup_default_position():
	"""Set the camera to default overview position"""
	# Position camera above the center of the map
	default_position = Vector3(0, default_distance, 0)
	camera_offset = Vector3.ZERO
	position = default_position

	# Look down at an angle
	rotation_degrees = Vector3(default_angle, 0, 0)

	print("📷 Camera default setup: pos=", position, " rot=", rotation_degrees)

func focus_on_position(target_pos: Vector3, immediate: bool = false):
	"""Focus camera on a specific position"""
	is_focusing = true
	focus_target = target_pos

	if immediate:
		set_focused_position()
		is_focusing = false
		emit_signal("focus_complete")

func focus_on_node(node: MapNode3D, immediate: bool = false):
	"""Focus camera on a specific node"""
	current_focus_node = node
	focus_on_position(node.global_position, immediate)

func return_to_default(immediate: bool = false):
	"""Return camera to default overview position"""
	current_focus_node = null
	reset_camera_pan()  # Reset panning offset

	if immediate:
		position = default_position
		rotation_degrees = Vector3(default_angle, 0, 0)
		is_focusing = false
		emit_signal("focus_complete")
	else:
		# Smoothly transition back
		is_focusing = true
		focus_target = Vector3.ZERO  # Signal to return to default

func process_focus_transition(delta: float):
	"""Smoothly transition camera to focus position"""

	if current_focus_node:
		# Focusing on a node
		var target_pos = calculate_focus_position(current_focus_node.global_position)
		position = position.lerp(target_pos, delta * move_speed)

		# Adjust angle
		var target_rot = Vector3(focus_angle, 0, 0)
		rotation_degrees = rotation_degrees.lerp(target_rot, delta * move_speed)

		# Check if close enough to target
		if position.distance_to(target_pos) < 0.1:
			position = target_pos
			rotation_degrees = target_rot
			is_focusing = false
			emit_signal("focus_complete")

	else:
		# Returning to default
		position = position.lerp(default_position, delta * move_speed)
		rotation_degrees = rotation_degrees.lerp(Vector3(default_angle, 0, 0), delta * move_speed)

		# Check if close enough to default
		if position.distance_to(default_position) < 0.1:
			position = default_position
			rotation_degrees = Vector3(default_angle, 0, 0)
			is_focusing = false
			emit_signal("focus_complete")

func calculate_focus_position(target: Vector3) -> Vector3:
	"""Calculate the camera position when focusing on a target"""

	# Position camera directly above the target (centered)
	var offset = Vector3(0, focus_distance, 0)
	return target + offset

func set_focused_position():
	"""Immediately set camera to focused position"""
	if current_focus_node:
		position = calculate_focus_position(current_focus_node.global_position)
		rotation_degrees = Vector3(focus_angle, 0, 0)

# Zoom functions disabled - camera stays at fixed height
# func zoom_in(amount: float = 2.0):
# 	"""Zoom camera in"""
# 	default_distance = max(10.0, default_distance - amount)
# 	if not is_focusing:
# 		setup_default_position()

# func zoom_out(amount: float = 2.0):
# 	"""Zoom camera out"""
# 	default_distance = min(40.0, default_distance + amount)
# 	if not is_focusing:
# 		setup_default_position()

func rotate_around_center(angle: float):
	"""Rotate camera around the map center"""
	if not is_focusing:
		rotation_degrees.y += angle

func process_camera_panning(delta: float):
	"""Handle WASD camera panning"""
	var pan_direction = Vector3.ZERO

	# Get input direction
	if Input.is_key_pressed(KEY_W):
		pan_direction.z -= 1
	if Input.is_key_pressed(KEY_S):
		pan_direction.z += 1
	if Input.is_key_pressed(KEY_A):
		pan_direction.x -= 1
	if Input.is_key_pressed(KEY_D):
		pan_direction.x += 1

	# Normalize to prevent faster diagonal movement
	if pan_direction.length() > 0:
		pan_direction = pan_direction.normalized()
		camera_offset += pan_direction * pan_speed * delta

		# Apply offset to position
		position = default_position + camera_offset
		# print("📷 Camera panning: ", camera_offset)  # Uncomment for debug

func reset_camera_pan():
	"""Reset camera panning to center"""
	camera_offset = Vector3.ZERO
	position = default_position
