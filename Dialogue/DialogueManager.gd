extends Node
# DialogueManager (autoload)

signal started(convo_id)
signal advanced(index)
signal finished(convo_id)

@export var default_portraits: DialoguePortraits

var _ui: DialogueUi = null
var _lines: Array[DialogueLine] = []
var _i := 0
var _is_running := false
var _convo_id: StringName = &""
var _ui_active := false
var _current_page: DialoguePage
var _just_revealed := false

func _ready() -> void:
	add_to_group("dialogue_manager")
	# Try linking immediately
	_link_ui()

func _process(_delta):
	if _ui == null:
		_link_ui()
		if _ui:
			print("[DialogueManager] UI linked (late).")
			set_process(false) # stop polling

func _link_ui() -> void:
	# Because DialogueUI is an autoload singleton:
	if DialogueUi:
		_ui = DialogueUi
		if default_portraits:
			_ui.portraits = default_portraits
		if not _ui.request_continue.is_connected(_on_ui_request_continue):
			_ui.request_continue.connect(_on_ui_request_continue)
		print("[DialogueManager] Linked ->", _ui)
	else:
		print("[DialogueManager] DialogueUI autoload missing!")

func _unhandled_input(event: InputEvent) -> void:
	if InputState.mode != InputState.Mode.DIALOGUE:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		on_player_continue_input()
		get_viewport().set_input_as_handled()


# -------------------------------------------------------
# 🗣️ Start a conversation
# -------------------------------------------------------
func start_convo(lines: Array[DialogueLine], convo_id: StringName = &"", page: DialoguePage = null) -> void:
	_current_page = page
	if lines.is_empty():
		push_warning("DialogueManager: start_convo() called with empty lines.")
		return

	if _is_running:
		push_warning("DialogueManager: Conversation already active.")
		return

	if _ui == null:
		_link_ui()
		if _ui == null:
			push_error("DialogueManager: DialogueUI singleton missing!")
			return

	_is_running = true
	_convo_id = convo_id
	_lines = lines.duplicate(true)
	_i = 0

	if not _ui.request_continue.is_connected(_on_ui_request_continue):
		_ui.request_continue.connect(_on_ui_request_continue)

	_ui.visible = true
	#_disable_player_inputs(true)

	emit_signal("started", _convo_id)
	_show_current_line()


# -------------------------------------------------------
# 🎮 Player pressed continue (input or click)
# -------------------------------------------------------
func on_player_continue_input() -> void:
	if not _is_running or not is_instance_valid(_ui):
		return

	if _ui._is_revealing:
		_ui.reveal_all_now()
		_just_revealed = true
		return

	if _just_revealed:
		_just_revealed = false
		return

	_advance_dialogue_line()

# -------------------------------------------------------
func _advance_dialogue_line() -> void:
	_i += 1
	if _i < _lines.size():
		_show_current_line()
	else:
		_end_convo()

# -------------------------------------------------------
func stop_convo() -> void:
	_end_convo()

# -------------------------------------------------------
func _show_current_line() -> void:
	if _ui == null:
		push_error("DialogueManager: No UI linked!")
		_end_convo()
		return

	var line: DialogueLine = _lines[_i]
	_ui.visible = true
	_ui.show_line(line, _current_page)

	emit_signal("advanced", _i)

	if not line.choices.is_empty():
		_ui.show_choices(line.choices)

# -------------------------------------------------------
func _on_ui_request_continue(choice_text := "") -> void:
	if _i < 0 or _i >= _lines.size():
		_end_convo()
		return

	var line: DialogueLine = _lines[_i]

	# Branching dialogue:
	if not line.choices.is_empty():
		var idx := line.choices.find(choice_text)
		if idx != -1 and idx < line.next_indices.size():
			var next := line.next_indices[idx]
			if next < 0 or next >= _lines.size():
				_end_convo()
			else:
				_i = next
				_show_current_line()
			return

	if line.end_after_line:
		_end_convo()
		return

	_advance_dialogue_line()

# -------------------------------------------------------
# ✅ End & unlock player input
# -------------------------------------------------------
func _end_convo() -> void:
	if _ui:
		await get_tree().create_timer(0.15).timeout
		_ui.visible = false

	var ended_id := _convo_id
	_is_running = false
	_convo_id = &""
	_lines.clear()
	_i = 0
	#_disable_player_inputs(false)
	emit_signal("finished", ended_id)

# -------------------------------------------------------
func _dl(s: String, t: String, expr := "neutral") -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker = s
	l.text = t
	l.expression = expr
	return l

# -------------------------------------------------------
func _disable_player_inputs(yes: bool) -> void:
	InputState.set_mode(InputState.Mode.DIALOGUE if yes else InputState.Mode.FREE)

func _find_player_character() -> Node:
	return get_tree().get_first_node_in_group("player")
