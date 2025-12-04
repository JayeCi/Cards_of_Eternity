extends Area3D
class_name MapNode3DSimple

# Minimal version for testing

@export var node_name: String = "Test Node"
@export var encounter_type: String = "fight"

func _ready():
	print("MapNode3DSimple created: ", node_name)
