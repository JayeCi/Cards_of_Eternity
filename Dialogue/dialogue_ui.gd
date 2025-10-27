extends Control
signal request_continue()  # Emitted when player presses "continue" (after text fully shown)

@export var text_speed: float = 0.03   # Delay between characters
@export var portraits: DialoguePortraits

@onready var portrait: TextureRect = %Portrait
@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: Label = %TextLabel
@onready var sfx_player: AudioStreamPlayer = $Sfx
@onready var auto_timer: Timer = $AutoAdvanceTimer
@onready var choices_container: VBoxContainer = %ChoicesContainer
@onready var choice_button_a: Button = %ChoiceButtonA
#@onready var choice_button_b: Button = %ChoiceButtonB

var _is_revealing := false
var _full_text := ""
var _char_index := 0
var _accum_time := 0.0

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	auto_timer.one_shot = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	
func show_choices(choices: Array[String]) -> void:
	choices_container.visible = true
	for c in choices:
		var btn := choice_button_a.duplicate()
		btn.visible = true
		btn.text = c
		btn.pressed.connect(func(): _on_choice_pressed(c))
		choices_container.add_child(btn)

# ---------------------------------------------------------
# Display a line with typewriter reveal
# ---------------------------------------------------------
func show_line(line: DialogueLine, page: DialoguePage = null) -> void:
	visible = true
	_is_revealing = true
	_char_index = 0
	_accum_time = 0.0

	# --- Speaker & Portrait ---
# --- Speaker priority: always line speaker first ---
	var speaker_name := ""
	if page.speaker != "":
		speaker_name = page.speaker
	elif page and page.speaker != "":
		speaker_name = page.speaker


	# --- Portrait priority: always line key first ---
	var portrait_key := ""
	if line.portrait_key != "":
		portrait_key = line.portrait_key
	#elif page and page.portrait_key != "":
		#portrait_key = page.portrait_key


	if line.has_meta("portrait_key"):
		portrait_key = line.portrait_key
	#elif page and page.portrait_key != "":
		#portrait_key = page.portrait_key

	speaker_label.text = speaker_name

	if portraits and portrait_key != "":
		portrait.texture = portraits.get_face(portrait_key)
	else:
		portrait.texture = null

	# --- Prepare text ---
	_full_text = line.text
	text_label.text = _full_text
	text_label.visible_characters = 0

	# --- Optional sound ---
	if line.sfx:
		sfx_player.stream = line.sfx
		sfx_player.play()

	# --- Auto-advance setup ---
	auto_timer.stop()
	if not line.wait_for_input and line.has_meta("auto_advance_time") and line.auto_advance_time > 0.0:
		auto_timer.start(line.auto_advance_time)

	set_process(true)

# ---------------------------------------------------------
# Typewriter reveal loop (non-skippable)
# ---------------------------------------------------------

func _process(delta: float) -> void:
	if not _is_revealing:
		return

	# 🟢 Skip instantly if player presses continue
	if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		text_label.visible_characters = -1
		_is_revealing = false
		set_process(false)
		return

	# ✍️ Normal typewriter reveal
	_accum_time += delta
	if _accum_time >= text_speed:
		_accum_time = 0.0
		_char_index += 1
		text_label.visible_characters = _char_index

		if _char_index >= _full_text.length():
			text_label.visible_characters = -1
			_is_revealing = false
			set_process(false)

func _on_choice_pressed(choice_text: String) -> void:
	print("[DialogueUI] Player chose:", choice_text)
	choices_container.visible = false
	for child in choices_container.get_children():
		if child != choice_button_a:
			child.queue_free()
	emit_signal("request_continue", choice_text)

# ---------------------------------------------------------
# Called when player presses "continue"
# (only works once the text is fully revealed)
# ---------------------------------------------------------
func on_player_pressed_continue() -> void:
	if _is_revealing:
		print("[DialogueUI] Continue ignored: still revealing text.")
		return

	print("[DialogueUI] Player pressed continue after text complete.")
	emit_signal("request_continue")


# ---------------------------------------------------------
# Auto-advance timer
# ---------------------------------------------------------
func _on_AutoAdvanceTimer_timeout() -> void:
	if not _is_revealing:
		print("[DialogueUI] Auto-advancing line.")
		emit_signal("request_continue")
