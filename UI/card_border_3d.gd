extends Node3D
class_name CardBorder3D

@export var is_leader: bool = false

@onready var border_mesh: MeshInstance3D = $BorderMesh

func _ready():
	
	_set_border_material()
	if is_leader:
		_start_pulse()

func _set_border_material():
	var mat := StandardMaterial3D.new()
	mat.unshaded = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	mat.emission_enabled = true
	mat.render_priority = 1

	if is_leader:
		mat.albedo_color = Color(1.0, 0.8, 0.2, 0.9)
		mat.emission = Color(1.0, 0.8, 0.2)
		mat.emission_energy = 2.5
	else:
		mat.albedo_color = Color(0.2, 0.8, 1.0, 0.7)
		mat.emission = Color(0.2, 0.8, 1.0)
		mat.emission_energy = 1.2

	border_mesh.material_override = mat

func _start_pulse():
	var tw = create_tween()
	tw.set_loops()
	tw.tween_property(border_mesh, "scale", Vector3(1.15, 1.15, 1.15), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(border_mesh, "scale", Vector3(1.05, 1.05, 1.05), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
