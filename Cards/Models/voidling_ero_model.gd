extends Node3D

@export var float_height := 0.08    # how far it rises/falls
@export var float_speed := 1.0       # how fast the bobbing happens

var _base_y := 0.0
var _time := 0.0

func _ready() -> void:
	_base_y = global_position.y
	set_process(true)

func _process(delta: float) -> void:
	_time += delta * float_speed
	var offset := sin(_time) * float_height
	global_position.y = _base_y + offset
