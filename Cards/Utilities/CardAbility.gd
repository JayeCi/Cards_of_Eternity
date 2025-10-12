extends Resource
class_name CardAbility

@export_enum("on_summon", "on_attack", "on_destroyed", "passive") var trigger: String = "on_summon"
@export var display_name: String = ""
@export var value: int = 0
@export var range: int = 1
@export var description: String = ""

# Virtual function (override in child ability scripts)
func execute(arena: Node, unit: UnitData) -> void:
	pass

func get_description_text() -> String:
	return "%s\n[Value: %d | Range: %d]" % [description, value, range]
