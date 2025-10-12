extends CharacterBody3D

@export var move_speed: float = 2.0
@export var turn_speed: float = 6.0
@export var idle_min_time: float = 1.0
@export var idle_max_time: float = 4.0
@export var roam_radius: float = 10.0
@export var wait_at_goal_chance: float = 0.3

@export var run_sound: AudioStream = preload("res://Audio/Sound FX/Rat/ratrun.mp3")

@export var ambient_sounds: Array[AudioStream] = [
	preload("res://Audio/Sound FX/Rat/rat-squeaks-1-fx-396297.wav"),
	preload("res://Audio/Sound FX/Rat/rat-squeaks-2-fx-396301.mp3"),
	preload("res://Audio/Sound FX/Rat/rat-squeaks-3-fx-396299.mp3"),
	preload("res://Audio/Sound FX/Rat/rat-squeaks-4-fx-396298.mp3")
]

@onready var nav: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var audio_run: AudioStreamPlayer3D = $AudioPlayer_Run
@onready var audio_ambient: AudioStreamPlayer3D = $AudioPlayer_Ambient

var _is_idling: bool = false
var _target_pos: Vector3

func _ready() -> void:
	randomize()
	audio_run.stream = run_sound
	_start_ambient_loop()
	_pick_new_destination()


func _physics_process(delta: float) -> void:
	if _is_idling:
		return

	if not nav.is_navigation_finished():
		var next_pos: Vector3 = nav.get_next_path_position()
		var direction: Vector3 = (next_pos - global_position)
		direction.y = 0
		direction = direction.normalized()

		if direction.length() > 0.01:
			var target_rot = atan2(direction.x, direction.z)
			rotation.y = lerp_angle(rotation.y, target_rot, delta * turn_speed)

		velocity = direction * move_speed
		move_and_slide()

		if anim.current_animation != "RatArmature|Rat_Run":
			anim.play("RatArmature|Rat_Run")
			if not audio_run.playing:
				audio_run.play()

	else:
		if audio_run.playing:
			audio_run.stop()
		if anim.current_animation != "RatArmature|Rat_Idle":
			anim.play("RatArmature|Rat_Idle")

		if randf() < wait_at_goal_chance:
			await _idle_random_time()
		_pick_new_destination()


func _pick_new_destination() -> void:
	var random_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	var random_dist = randf_range(roam_radius * 0.3, roam_radius)
	var target = global_position + random_dir * random_dist

	var nav_map = nav.get_navigation_map()
	var valid_point = NavigationServer3D.map_get_closest_point(nav_map, target)
	_target_pos = valid_point
	nav.set_target_position(valid_point)


func _idle_random_time() -> void:
	_is_idling = true
	if anim:
		anim.play("RatArmature|Rat_Idle")
	if audio_run.playing:
		audio_run.stop()
	var wait_time = randf_range(idle_min_time, idle_max_time)
	await get_tree().create_timer(wait_time).timeout
	_is_idling = false


# --- Ambient random squeaks ---
func _start_ambient_loop() -> void:
	# Run in background without blocking
	_play_ambient_sounds()


func _play_ambient_sounds() -> void:
	while true:
		await get_tree().create_timer(randf_range(3.0, 10.0)).timeout
		# 70% chance to skip if currently running
		if not _is_idling and randf() < 0.7:
			continue
		if ambient_sounds.size() > 0:
			audio_ambient.stream = ambient_sounds[randi() % ambient_sounds.size()]
			audio_ambient.pitch_scale = randf_range(0.9, 1.2)
			audio_ambient.play()
