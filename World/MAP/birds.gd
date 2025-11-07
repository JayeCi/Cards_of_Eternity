extends Node3D   # or CharacterBody2D / 3D if it’s 3D

@export var point_a_path: NodePath
@export var point_b_path: NodePath
@export var fly_duration: float = 3.0  # seconds for each trip

var _going_to_b := true
var _tween: Tween

@onready var point_a = get_node(point_a_path)
@onready var point_b = get_node(point_b_path)
@onready var anim_player: AnimationPlayer = $AnimationPlayer  # optional

func _ready():
	_start_flight_cycle()

func _start_flight_cycle():
	_fly_to_next_point()

func _fly_to_next_point():
	if _tween and _tween.is_running():
		_tween.kill()

	var target = point_b if _going_to_b else point_a

	# Flip or rotate toward target (optional)
	look_at(target.global_position)

	# Optional animation
	if anim_player:
		anim_player.play("fly")

	# Smooth tween movement
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "global_position", target.global_position, fly_duration)
	_tween.tween_callback(_on_reached_target)

func _on_reached_target():
	_going_to_b = !_going_to_b
	# Optional idle pause before turning back
	await get_tree().create_timer(randf_range(0.5, 1.5)).timeout
	_fly_to_next_point()
