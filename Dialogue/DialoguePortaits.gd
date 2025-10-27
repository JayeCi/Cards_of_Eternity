# res://Systems/Dialogue/dialogue_portraits.gd
extends Resource
class_name DialoguePortraits

# Map of key -> Texture2D (typed dictionary for safety)
@export var faces: Dictionary[StringName, Texture2D] = {}

## Returns the portrait Texture2D for a key, or null if missing.
func get_face(key: StringName) -> Texture2D:
	var tex = faces.get(key)
	return tex if tex is Texture2D else null
