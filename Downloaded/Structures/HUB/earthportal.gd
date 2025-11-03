extends Node3D

func get_look_point() -> Vector3:
	return global_transform.origin + Vector3(0, 2.0, 0)
