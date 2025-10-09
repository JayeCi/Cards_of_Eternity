extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

@onready var cam: Camera3D = $Head/Camera3D
@onready var head = $Head
@onready var collection_ui: Control = get_node("/root/Main/CollectionUI")

var rotation_x = 0.0
var mouse_locked = true

func _ready() -> void:
	await get_tree().process_frame 
	_lock_mouse()


func _input(event):
	if event.is_action_pressed("interact"):
		var space_state = get_world_3d().direct_space_state
		var from = cam.global_position
		var to = from + -cam.global_transform.basis.z * 3.0
		var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		if result and result.collider.is_in_group("npcs"):
			result.collider.on_interact()

	if Input.is_action_just_pressed("open_collection"):
		_toggle_collection()

func _unhandled_input(event: InputEvent) -> void:
	# Skip all player input when UI is visible
	if collection_ui.visible:
		return

	if event is InputEventMouseMotion and mouse_locked:
		# Horizontal rotation (yaw)
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)

		# Vertical rotation (pitch)
		rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		rotation_x = clamp(rotation_x, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = rotation_x

		# Toggle mouse lock with ESC
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mouse_locked:
			_unlock_mouse()
		else:
			_lock_mouse()

func _physics_process(delta: float) -> void:
	# Skip physics input while UI is open
	if collection_ui.visible:
		return

	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_downward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

func _toggle_collection():
	if collection_ui.visible:
		collection_ui.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_locked = true
	else:
		collection_ui.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_locked = false

func _lock_mouse():
	mouse_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unlock_mouse():
	mouse_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
