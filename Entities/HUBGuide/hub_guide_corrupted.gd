extends CharacterBody3D
class_name GuideNPC

# --- Nodes ---
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var player: Node3D = get_tree().get_first_node_in_group("player")
var sit_spots: Array = []

@export var earth_portal_path: NodePath
var earth_portal: Node3D

@export var deck_table_target_path: NodePath
var table_target: Node3D = null
var table_nav_pos: Vector3 = Vector3.ZERO  # clamped target on navmesh


# --- Signals ---
signal reached_player
signal reached_table
signal reached_target

# --- Movement constants ---
const SPEED := 2.5
const TURN_SPEED := 6.0
const WANDER_RADIUS := 15.0

# --- States ---
enum {
	STATE_WANDER,
	STATE_GO_SIT,
	STATE_SITTING,
	STATE_STAND_UP,

	STATE_CUTSCENE_APPROACH_PLAYER,
	STATE_CUTSCENE_IDLE,
	STATE_CUTSCENE_GO_TABLE,
	STATE_CUTSCENE_FINISHED,
}
var state := STATE_WANDER

# --- Cutscene vars ---
var cutscene_player_target: Node3D = null
var has_reached_player := false
var sit_target: Node = null

# --- Debug ---
var _last_state := -1
func _dbg_state():
	if _last_state != state:
		_last_state = state
		print("[Guide] STATE -> ", state)

func _ready() -> void:
	sit_spots = get_tree().get_nodes_in_group("sit_spots")

	_randomize_agent()
	_resolve_table_target() # also sets table_nav_pos

	reached_player.connect(_on_guide_reached_player)
	reached_table.connect(_on_guide_reached_table)

	if state == STATE_WANDER:
		_pick_new_target()
	if earth_portal_path != NodePath():
		earth_portal = get_node_or_null(earth_portal_path)
		
func _on_enable_input(_id := StringName("")) -> void:
	InputState.set_mode(InputState.Mode.FREE)
	resume_wandering()

func _physics_process(delta: float) -> void:
	_dbg_state()
	agent.set_velocity(velocity)

	match state:
		STATE_WANDER:
			if agent.is_navigation_finished():
				if randf() < 0.2:
					_idle_pause()
				elif randf() < 0.15:
					_idle_pause()
				else:
					_pick_new_target()
			_move_agent(delta)

		STATE_GO_SIT:
			if global_position.distance_to(agent.get_final_position()) < 0.5:
				_start_sit()
			else:
				_move_agent(delta)

		STATE_SITTING:
			velocity = Vector3.ZERO

		STATE_STAND_UP:
			pass

		STATE_CUTSCENE_APPROACH_PLAYER:
			if cutscene_player_target == null or !is_instance_valid(cutscene_player_target):
				_set_state(STATE_WANDER)
				return
			agent.target_position = cutscene_player_target.global_position
			var dist := global_position.distance_to(agent.get_final_position())
			if dist < 1.0 or agent.is_navigation_finished():
				if !has_reached_player:
					has_reached_player = true
					velocity = Vector3.ZERO
					anim.play("Idle")
					emit_signal("reached_player")
			else:
				_move_agent(delta)

		STATE_CUTSCENE_IDLE:
			velocity = Vector3.ZERO
			# Do nothing; we've already rotated once.

		STATE_CUTSCENE_GO_TABLE:
			# Ensure we always chase the NAV-CLAMPED point
			if table_target == null or !is_instance_valid(table_target):
				_resolve_table_target()
				if table_target == null:
					_set_state(STATE_WANDER)
					return

			# If agent thinks it's finished but we're still far, reissue target
			var real_dist := global_position.distance_to(table_nav_pos)
			if agent.is_navigation_finished() and real_dist > 1.2:
				agent.target_position = table_nav_pos  # re-path
			elif real_dist <= 1.2:
				velocity = Vector3.ZERO
				anim.play("Idle")
				emit_signal("reached_table")
				_set_state(STATE_CUTSCENE_IDLE)
			else:
				agent.target_position = table_nav_pos
				_move_agent(delta)

		STATE_CUTSCENE_FINISHED:
			velocity = Vector3.ZERO

	move_and_slide()

# ===========================
# Public API
# ===========================
func approach_player(p: Node3D) -> void:
	cutscene_player_target = p
	if p:
		agent.target_position = p.global_position
	anim.play("Walk")
	_set_state(STATE_CUTSCENE_APPROACH_PLAYER)
	InputState.set_mode(InputState.Mode.CUTSCENE)

func go_to_table(target: Node3D) -> void:
	if target:
		table_target = target
	# Always resolve + clamp to navmesh
	_resolve_table_target()

	if table_target == null:
		push_error("[GuideNPC] go_to_table() called but table target is null.")
		return

	agent.target_position = table_nav_pos
	anim.play("Walk")
	_set_state(STATE_CUTSCENE_GO_TABLE)
	InputState.set_mode(InputState.Mode.CUTSCENE)
	print("[Guide] go_to_table -> nav_pos:", table_nav_pos)

func resume_wandering() -> void:
	_set_state(STATE_WANDER)
	_pick_new_target()

# ===========================
# Dialogue callbacks
# ===========================
func _on_guide_reached_player() -> void:
	if player:
		look_at(player.global_position, Vector3.UP)
		rotate_y(deg_to_rad(180))

		rotation.x = 0
		rotation.z = 0

	# ✅ Freeze rotation behavior
	_set_state(STATE_CUTSCENE_IDLE)
	has_reached_player = true

	DialogueManager.start_convo([
		_dl("Guide", "You feel it too, don't you?", "concerned"),
		_dl("Guide", "The Cards of Eternity... they're awakening again."),
		_dl("Guide", "And you. You’ve been chosen to wield their power.")
	])

	if !DialogueManager.finished.is_connected(_on_first_dialogue_done):
		DialogueManager.finished.connect(_on_first_dialogue_done, Object.CONNECT_ONE_SHOT)

func _on_first_dialogue_done(_id := StringName("")) -> void:
	DialogueManager.start_convo([
		_dl("Guide", "Come. You must choose your first deck.")
	])
	if !DialogueManager.finished.is_connected(_on_follow_me):
		DialogueManager.finished.connect(_on_follow_me, Object.CONNECT_ONE_SHOT)

func _on_follow_me(_id := StringName("")) -> void:
	has_reached_player = false
	go_to_table(null)

func _on_guide_reached_table() -> void:
	if player:
		look_at(player.global_position, Vector3.UP)
		rotation.x = 0
		rotation.z = 0

	DialogueManager.start_convo([
		_dl("Guide", "Each realm offers a different path..."),
		_dl("Guide", "Choose the deck that calls to you.")
	])

	if !DialogueManager.finished.is_connected(_on_final_cutscene_done):
		DialogueManager.finished.connect(_on_final_cutscene_done, Object.CONNECT_ONE_SHOT)

func _on_final_cutscene_done(_id := StringName("")) -> void:
	InputState.set_mode(InputState.Mode.FREE)
	_set_state(STATE_CUTSCENE_FINISHED)

# ===========================
# Helpers
# ===========================
func _randomize_agent() -> void:
	randomize()
	agent.max_speed = SPEED
	agent.radius = 0.4
	agent.height = 1.8
	agent.path_max_distance = 2.0
	agent.avoidance_enabled = true

func _nav_point(world_pos: Vector3) -> Vector3:
	var map_rid := agent.get_navigation_map()
	if map_rid == RID():
		return world_pos
	return NavigationServer3D.map_get_closest_point(map_rid, world_pos)

func _resolve_table_target() -> void:
	if deck_table_target_path != NodePath():
		table_target = get_node_or_null(deck_table_target_path)
	if table_target == null:
		table_target = get_node_or_null("../DeckTableTarget") as Node3D
	if table_target != null:
		table_nav_pos = _nav_point(table_target.global_position)
	else:
		push_error("[GuideNPC] NO DeckTableTarget found in scene!")

func _set_state(s: int) -> void:
	state = s

func on_player_chosen_deck(element_type: String) -> void:
	# Stop player control
	InputState.set_mode(InputState.Mode.CUTSCENE)

	# Save current camera orientation
	player.save_camera_rotation()

	# 1) Look at portal
	var tween1 = player.look_toward_point(earth_portal.get_look_point(), 1.5)

	await tween1.finished

	await get_tree().create_timer(1.2).timeout  # hold moment

	# Now look like we're talking to the player
	if player:
		var to_player = (player.global_position - global_position)
		to_player.y = 0
		rotation.y = atan2(to_player.x, to_player.z)


	rotation.x = 0
	rotation.z = 0
	anim.play("Idle")

	var description = _deck_description(element_type)

	DialogueManager.start_convo([
		_dl("Guide", "Ahh, you chose the " + element_type + " Deck."),
		_dl("Guide", description),
		_dl("Guide", "Your journey begins now. Gather all Eternity Cards."),
		_dl("Guide", "Reform the ancient realm pillars. Awaken the sleeping worlds."),
		_dl("Guide", "Watch closely… your first portal now opens.")
	])

	if !DialogueManager.finished.is_connected(_on_show_first_portal):
		DialogueManager.finished.connect(_on_show_first_portal, Object.CONNECT_ONE_SHOT)

func _on_show_first_portal(_id := StringName("")) -> void:
	if player == null or earth_portal == null:
		_on_enable_input()
		return

	# Stop the player from using the mouse during pans
	InputState.set_mode(InputState.Mode.CUTSCENE)

	# Save where they were looking
	player.save_camera_rotation()


	# 2) Return to guide
	var tween2 = player.look_toward_point(get_look_point(),1.5)

	await tween2.finished

	await get_tree().create_timer(0.3).timeout

	# Dialogue and unlock
	DialogueManager.start_convo([
		_dl("Guide", "This portal leads to the Earth Realm."),
		_dl("Guide", "Enemies are weakening its foundations."),
		_dl("Guide", "Enter and restore stability. Only then can we move on.")
	])

	if !DialogueManager.finished.is_connected(_on_enable_input):
		DialogueManager.finished.connect(_on_enable_input, Object.CONNECT_ONE_SHOT)
		
# Always return a good chest-height look target
func get_look_point() -> Vector3:
	return global_transform.origin + Vector3(0, 1.0, 0)

func _deck_description(element_type: String) -> String:
	match element_type:
		"Fire":
			return "Fueled by fury and volcanic power, these creatures strike fast and scorching."
		"Water":
			return "Adaptive, fluid, and relentless — tides shift the flow of battle."
		"Earth":
			return "Sturdy, defensive, ancient. Their roots run deep through realm history."
		"Wind":
			return "Swift, evasive, unpredictable – they dominate with speed and precision."
	return "A mysterious force with untold potential."

func _face_player(delta: float) -> void:
	if player == null or !is_instance_valid(player):
		return
	var to_player := (player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length() > 0.001:
		var target_rot_y := atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, delta * TURN_SPEED)

func _move_agent(delta: float) -> void:
	var next := agent.get_next_path_position()
	var direction := (next - global_transform.origin)
	direction.y = 0.0
	if direction.length() > 0.2:
		direction = direction.normalized()
		velocity = direction * SPEED
		if anim.current_animation != "Walk":
			anim.play("Walk")
		var target_rot_y := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rot_y, delta * TURN_SPEED)
	else:
		velocity = Vector3.ZERO
		if anim.current_animation != "Idle":
			anim.play("Idle")

# --- Wander / Sit ---
func _pick_new_target() -> void:
	if state != STATE_WANDER:
		return
	var origin := global_transform.origin
	var random_pos := origin + Vector3(
		randf_range(-WANDER_RADIUS, WANDER_RADIUS),
		0.0,
		randf_range(-WANDER_RADIUS, WANDER_RADIUS)
	)
	random_pos = _nav_point(random_pos)
	if origin.distance_to(random_pos) < 2.0:
		_pick_new_target()
		return
	agent.target_position = random_pos

func _pick_sit_spot() -> void:
	if sit_spots.is_empty():
		return

	sit_target = sit_spots[randi() % sit_spots.size()] as Node3D
	print("[Guide] Sitting at: ", sit_target.name)

	var forward = sit_target.global_transform.basis.z.normalized()
	var sit_pos := _nav_point(sit_target.global_position - forward * 0.6)

	agent.target_position = sit_pos
	_set_state(STATE_GO_SIT)


func _start_sit() -> void:
	anim.play("StandToSit")
	_set_state(STATE_SITTING)
	await get_tree().create_timer(anim.current_animation_length).timeout

	var forward = sit_target.global_transform.basis.z
	rotation.y = atan2(forward.x, forward.z)

	anim.play("Sitting")
	await get_tree().create_timer(randf_range(3.0, 7.0)).timeout
	_stand_up()

func _stand_up() -> void:
	anim.play("SitToStand")
	_set_state(STATE_STAND_UP)
	await get_tree().create_timer(anim.current_animation_length).timeout
	_set_state(STATE_WANDER)
	_pick_new_target()

func _idle_pause() -> void:
	_set_state(STATE_SITTING)
	anim.play("Idle")
	await get_tree().create_timer(randf_range(2.0, 5.0)).timeout
	_set_state(STATE_WANDER)
	_pick_new_target()

# --- Dialogue line helper ---
func _dl(speaker: String, text: String, expr := "neutral") -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker = speaker
	l.text = text
	l.expression = expr
	return l
