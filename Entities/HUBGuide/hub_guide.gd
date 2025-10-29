extends CharacterBody3D

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var sit_spots := get_tree().get_nodes_in_group("sit_spots")

const SPEED := 2.5
const TURN_SPEED := 6.0
const WANDER_RADIUS := 15.0

# State machine
enum { STATE_WANDER, STATE_GO_SIT, STATE_SITTING, STATE_STAND_UP }
var state = STATE_WANDER
var sit_target: Node = null

func _ready():
	randomize()
	agent.max_speed = SPEED

	# 🔥 Required to avoid getting stuck on corners
	agent.radius = 0.4
	agent.height = 1.8

	agent.path_max_distance = 2.0

	# 🔥 Make agent turn & navigate around obstacles
	agent.avoidance_enabled = true

	_pick_new_target()

func _physics_process(delta: float) -> void:
		# If velocity is basically zero while in GO_SIT, still sitting
	if state == STATE_GO_SIT and velocity.length() < 0.01:
		# give up and just sit
		_start_sit()

	if agent.is_navigation_finished() and state == STATE_WANDER:
		_pick_new_target()

	match state:
		STATE_WANDER:
			_wander(delta)
		STATE_GO_SIT:
			_go_sit(delta)
		STATE_SITTING:
			# No movement
			velocity = Vector3.ZERO
		STATE_STAND_UP:
			# Animation callback will switch back to wander
			pass

	move_and_slide()

# ======================================================
# Wandering behavior
# ======================================================
func _wander(delta):
	if agent.is_navigation_finished():
		# 20% chance to sit when reaching a point
		if randf() < 0.2:
			_pick_sit_spot()
			return

		_pick_new_target()

	_move_agent(delta)

# ======================================================
# Going to sit spot
# ======================================================
func _go_sit(delta):
	var dist = global_transform.origin.distance_to(sit_target.global_transform.origin)

	# Close enough to the bench?
	if dist < 1.2:
		_start_sit()
		return

	# If walking target is reached by path logic
	if agent.is_navigation_finished():
		_start_sit()
		return

	_move_agent(delta)

# ======================================================
# Shared movement handling
# ======================================================
func _move_agent(delta):
	var next := agent.get_next_path_position()
	var direction := next - global_transform.origin
	direction.y = 0

	if direction.length() > 0.2:
		direction = direction.normalized()
		velocity = direction * SPEED
		anim.play("Walk")

		# ✅ Snap rotation (simple, no shrinking ever)
		var target_rot_y = atan2(direction.x, direction.z)
		rotation.y = target_rot_y

	else:
		velocity = Vector3.ZERO
		anim.play("Idle")

# ======================================================
# Sit spot selection
# ======================================================
func _pick_sit_spot():
	if sit_spots.size() == 0:
		return

	sit_target = sit_spots[randi() % sit_spots.size()]
	var sit_pos = sit_target.global_transform.origin

	var forward = sit_target.global_transform.basis.z.normalized()
	sit_pos -= forward * 0.6

	sit_pos = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), sit_pos)

	agent.target_position = sit_pos
	state = STATE_GO_SIT

# ======================================================
# Start sitting
# ======================================================
func _start_sit():
	anim.play("StandToSit")
	state = STATE_SITTING

	await anim.animation_finished

	# Face bench direction
	var forward = sit_target.global_transform.basis.z
	rotation.y = atan2(forward.x, forward.z)

	anim.play("Sitting")

	var t = randf_range(3.0, 7.0)
	await get_tree().create_timer(t).timeout

	_stand_up()

# ======================================================
# Stand up
# ======================================================
func _stand_up():
	anim.play("SitToStand")
	state = STATE_STAND_UP
	await anim.animation_finished

	# Return to wandering
	state = STATE_WANDER
	_pick_new_target()

# ======================================================
# Random wander target
# ======================================================
func _pick_new_target():
	var origin = global_transform.origin
	var random_pos = origin + Vector3(
		randf_range(-WANDER_RADIUS, WANDER_RADIUS),
		0,
		randf_range(-WANDER_RADIUS, WANDER_RADIUS)
	)

	# Clamp to navmesh
	random_pos = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), random_pos)

	# Don't choose tiny movement
	if origin.distance_to(random_pos) < 2.0:
		_pick_new_target()
		return

	agent.target_position = random_pos
