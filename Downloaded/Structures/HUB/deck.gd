extends MeshInstance3D

@export var outline_param_name := "outline_enabled"
var _material : ShaderMaterial

func _ready():
	_material = get_active_material(0)

func enable_outline():
	if _material:
		_material.set_shader_parameter(outline_param_name, true)

func disable_outline():
	if _material:
		_material.set_shader_parameter(outline_param_name, false)
