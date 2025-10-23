extends Node3D
class_name FusionEffect

@export var duration := 1.5
@export var swirl_radius := 1.2
@export var swirl_speed := 8.0
@export var target_pos := Vector3.ZERO

var _elapsed := 0.0
var _a: Node3D
var _b: Node3D

func start(a: Node3D, b: Node3D, pos: Vector3):
	_a = a
	_b = b
	target_pos = pos
	_elapsed = 0.0
	set_process(true)

	# Optional: start a sound
	if has_node("AudioStreamPlayer3D"):
		$AudioStreamPlayer3D.play()

	# optional flash
	if has_node("OmniLight3D"):
		$OmniLight3D.light_energy = 2.0

func _process(delta):
	_elapsed += delta
	var t = _elapsed / duration
	if t >= 1.0:
		queue_free()
		return

	# circular swirl motion
	var angle := swirl_speed * _elapsed
	if _a:
		_a.global_position = target_pos + Vector3(cos(angle), sin(angle)*0.5, sin(angle)) * swirl_radius * (1.0 - t)
	if _b:
		_b.global_position = target_pos + Vector3(cos(angle + PI), sin(angle)*0.5, sin(angle + PI)) * swirl_radius * (1.0 - t)

	# fade & shrink
	if _a and _a.has_method("set_scale"):
		_a.scale = Vector3.ONE * (1.0 - t * 0.5)
	if _b and _b.has_method("set_scale"):
		_b.scale = Vector3.ONE * (1.0 - t * 0.5)

	if has_node("OmniLight3D"):
		$OmniLight3D.light_energy = lerp(2.0, 0.0, t)
