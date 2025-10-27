extends Resource
class_name DialoguePage

@export var speaker: String = ""  # Default speaker for all lines
@export var portrait_key: String = ""  # Default portrait
@export var lines: Array[DialogueLine] = []
@export var conditions: Array[String] = [] # optional quest/flag requirements
