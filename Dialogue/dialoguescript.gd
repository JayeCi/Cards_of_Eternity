extends Resource
class_name DialogueScript

@export var npc_name: String = ""
@export var pages: Array[DialoguePage] = []

func get_page(index: int) -> DialoguePage:
	return pages[index] if index >= 0 and index < pages.size() else null
