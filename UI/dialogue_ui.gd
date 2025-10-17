extends Control

signal finished

@export var text_speed := 0.03
@onready var speaker_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Name
@onready var dialogue_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Text

var _lines: Array[String] = []
var _current_index := 0

func _ready():
	print("dialogue_label:", dialogue_label)
	print("speaker_label:", speaker_label)

func play_dialogue(lines: Array[String]) -> void:
	_lines = lines
	_current_index = 0
	show()
	await _display_next_line()
	hide()
	emit_signal("finished") # 👈 emits when all lines done

func _display_next_line() -> void:
	while _current_index < _lines.size():
		var line = _lines[_current_index]

		## Optional format: "Speaker: Text"
		#var parts = line.split(":", false, 2)
		#if parts.size() == 2:
			#speaker_label.text = parts[0].strip_edges()
			#line = parts[1].strip_edges()
		#else:
			#speaker_label.text = ""

		await _type_text(line)
		await _wait_for_next_input()
		_current_index += 1

func _type_text(text: String) -> void:
	if not dialogue_label:
		push_error("❌ dialogue_label missing! Check node path.")
		return
	dialogue_label.text = ""
	for c in text:
		dialogue_label.text += c
		await get_tree().create_timer(text_speed).timeout


func _wait_for_next_input() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interact"):
			return
