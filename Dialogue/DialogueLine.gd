extends Resource
class_name DialogueLine



@export var end_after_line: bool = false
@export var text: String = "" # The line of dialogue. Supports \n for new lines.
@export var speed_scale: float = 1.0 # 1.0 = normal type speed; <1 faster, >1 slower
@export var wait_for_input: bool = true 
@export var sfx = null
@export var portrait_key: String = ""

@export var choices: Array[String] = []     # e.g. ["Yes", "No", "Ask for info"]
@export var next_indices: Array[int] = []   # index in dialogue array each choice leads to
@export var speaker: String = ""
@export var expression: String = "neutral"
