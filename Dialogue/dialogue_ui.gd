extends CanvasLayer


signal request_continue()

@export var text_speed: float = 0.03
@export var portraits: DialoguePortraits

@onready var portrait: TextureRect = %Portrait
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var sfx_player: AudioStreamPlayer = $Sfx
@onready var auto_timer: Timer = $AutoAdvanceTimer
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var choice_button_a: Button = %ChoiceButtonA

var _is_revealing := false
var _full_text := ""
var _char_index := 0
var _accum_time := 0.0
var _choices_active := false

func _ready() -> void:
	visible = false
	auto_timer.one_shot = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_choices(choices: Array[String]) -> void:
	choices_container.visible = true
	_choices_active = true
	for c in choices:
		var btn = choice_button_a.duplicate()
		btn.visible = true
		btn.text = c
		btn.pressed.connect(func(): _on_choice_pressed(c))
		choices_container.add_child(btn)


func show_line(line: DialogueLine, page: DialoguePage = null) -> void:
	visible = true
	_is_revealing = true
	_char_index = 0
	_accum_time = 0.0

	var speaker = line.speaker
	if speaker == "" and page:
		speaker = page.speaker
	speaker_label.text = speaker

	var portrait_key = line.portrait_key
	if portrait_key == "" and page:
		portrait_key = page.portrait_key

	portrait.texture = portraits.get_face(portrait_key) if portraits else null

	_full_text = line.text
	text_label.text = _full_text
	text_label.visible_characters = 0

	if line.sfx:
		sfx_player.stream = line.sfx
		sfx_player.play()

	auto_timer.stop()
	if not line.wait_for_input and line.auto_advance_time > 0.0:
		auto_timer.start(line.auto_advance_time)

	set_process(true)


func _process(delta: float) -> void:
	if not _is_revealing:
		return

	_accum_time += delta
	if _accum_time >= text_speed:
		_accum_time = 0.0
		_char_index += 1
		text_label.visible_characters = _char_index

		if _char_index >= _full_text.length():
			text_label.visible_characters = -1
			_is_revealing = false
			set_process(false)

	if _choices_active:
		return

	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		text_label.visible_characters = -1
		_is_revealing = false
		set_process(false)


func _on_choice_pressed(choice: String) -> void:
	choices_container.visible = false
	_choices_active = false
	for child in choices_container.get_children():
		if child != choice_button_a:
			child.queue_free()
	emit_signal("request_continue", choice)


func on_player_pressed_continue() -> void:
	if _choices_active:
		return
	if _is_revealing:
		return
	emit_signal("request_continue")


func reveal_all_now():
	_is_revealing = false
	text_label.visible_characters = -1
	set_process(false)


func _on_AutoAdvanceTimer_timeout() -> void:
	if not _is_revealing:
		emit_signal("request_continue")
