extends Control
signal request_continue
@onready var speaker_label: Label = find_child("SpeakerLabel", true, false)
@onready var text_label: RichTextLabel = find_child("TextLabel", true, false)
var _full := ""
var _idx := 0
var text_speed := 0.03

func show_line(line):
	_full = line.text
	if speaker_label: speaker_label.text = line.speaker
	if text_label:
		text_label.text = _full
		text_label.visible_characters = 0
	set_process(true)

func _process(_dt):
	if not text_label: return
	if text_label.visible_characters < len(_full):
		text_label.visible_characters += 1
	else:
		set_process(false)

func on_player_pressed_continue():
	if not text_label: return
	if text_label.visible_characters < len(_full):
		text_label.visible_characters = -1
	else:
		emit_signal("request_continue")
'''
	script.reload()
	root.set_script(script)

	_ui = root
