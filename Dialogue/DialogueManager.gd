extends Node
# DialogueManager (autoload)

signal started(convo_id)
signal advanced(index)
signal finished(convo_id)

@export var dialogue_ui_path: NodePath = "DialogueUI"
@export var default_portraits: DialoguePortraits

var _ui: Control
var _lines: Array[DialogueLine] = []
var _i := 0
var _is_running := false
var _convo_id: StringName = &""
var _previous_input_state := {"physics": true, "input": true}
var _ui_active := false
var _current_page: DialoguePage

func _ready() -> void:
	add_to_group("dialogue_manager")


func _process(_delta):
	if _ui == null:
		var found = get_tree().get_root().find_child("DialogueUI", true, false)
		if found:
			_ui = found
			print("[DialogueManager] Found UI later ->", _ui.get_path())
			_ui.request_continue.connect(_on_ui_request_continue)
			set_process(false)


# -------------------------------------------------------
# 🔧 Locate DialogueUI once
# -------------------------------------------------------
func _init_ui() -> void:
	_ui = get_tree().get_root().find_child("DialogueUI", true, false)

	if not _ui:
		push_error("DialogueManager: Could not find DialogueUI!")
		return

	if not _ui.request_continue.is_connected(_on_ui_request_continue):
		_ui.request_continue.connect(_on_ui_request_continue)

	if default_portraits and "portraits" in _ui:
		_ui.portraits = default_portraits

	print("[DialogueManager] Linked to DialogueUI ->", _ui.get_path())


# -------------------------------------------------------
# 🗣️ Start a conversation
# -------------------------------------------------------
func start_convo(lines: Array[DialogueLine], convo_id: StringName = &"", page: DialoguePage = null) -> void:
	_current_page = page

	if lines.is_empty():
		push_warning("DialogueManager: start_convo() called with empty lines.")
		return
	if _is_running:
		push_warning("DialogueManager: a conversation is already running.")
		return

	if _ui == null or not is_instance_valid(_ui):
		_ui = get_tree().get_root().find_child("DialogueUI", true, false)
		if not _ui:
			push_warning("DialogueManager: UI not found, waiting one frame...")
			await get_tree().process_frame
			_ui = get_tree().get_root().find_child("DialogueUI", true, false)
			if not _ui:
				push_error("DialogueManager: Could not locate DialogueUI at all.")
				return

	_is_running = true
	_convo_id = convo_id
	_lines = lines.duplicate(true)
	_i = 0

	if not _ui.request_continue.is_connected(_on_ui_request_continue):
		_ui.request_continue.connect(_on_ui_request_continue)

	_ui.visible = true
	_disable_player_inputs(true)

	emit_signal("started", _convo_id)
	_show_current_line()

	print("[DialogueManager] Dialogue started ->", convo_id)
	print("[DialogueManager] Lines:", _lines.size())


# -------------------------------------------------------
# 🎮 Player pressed "Continue"
# -------------------------------------------------------
func on_player_continue_input() -> void:
	if not _is_running or not _ui or not is_instance_valid(_ui):
		return

	# 🧩 Only allow continue when line fully revealed
	if _ui._is_revealing:
		print("[DialogueManager] Ignored input: line still revealing.")
		return

	_advance_dialogue_line()


# -------------------------------------------------------
# 🔄 Move to next line or end convo
# -------------------------------------------------------
func _advance_dialogue_line() -> void:
	_i += 1
	if _i < _lines.size():
		_show_current_line()
	else:
		_end_convo()


# -------------------------------------------------------
# 🧩 Stop manually
# -------------------------------------------------------
func stop_convo() -> void:
	_end_convo()


# -------------------------------------------------------
# 🔄 Show the current line
# -------------------------------------------------------
func _show_current_line() -> void:
	_ui_active = true
	if not _ui:
		push_error("DialogueManager has no UI linked!")
		_end_convo()
		return

	if _i >= 0 and _i < _lines.size():
		var line: DialogueLine = _lines[_i]
		print("[DM] Showing line", _i, "end_after_line =", line.end_after_line)

		_ui.visible = true
		_ui.show_line(line, _current_page)

		emit_signal("advanced", _i)

		if not line.choices.is_empty():
			_ui.show_choices(line.choices)
	else:
		_end_convo()

# -------------------------------------------------------
# 📩 When UI emits request_continue
# -------------------------------------------------------
func _on_ui_request_continue(choice_text := "") -> void:
	if _i < 0 or _i >= _lines.size():
		print("[DM] ⚠️ Invalid dialogue index:", _i, " (size:", _lines.size(), ") — ending conversation safely.")
		_end_convo()
		return

	var line: DialogueLine = _lines[_i]

	# 🟨 1️⃣ Handle branching choices
	if not line.choices.is_empty():
		var idx := line.choices.find(choice_text)
		if idx != -1 and idx < line.next_indices.size():
			var next_idx := line.next_indices[idx]

			# If -1 or out of range → END dialogue
			if next_idx < 0 or next_idx >= _lines.size():
				_end_convo()
				return

			_i = next_idx
			_show_current_line()
			return

	# 🟩 2️⃣ If this line is flagged to end after player continues
	if line.end_after_line:
		print("[DialogueManager] Player continued end_after_line =", _i)
		_end_convo()
		return

	# 🟩 Otherwise, go to next line normally
	_advance_dialogue_line()

# -------------------------------------------------------
# ✅ End & unlock player input
# -------------------------------------------------------
func _end_convo() -> void:
	print("[DM] _end_convo() CALLED at index", _i)
	_ui_active = false
	if _ui:
		await get_tree().create_timer(0.2).timeout
		_ui.visible = false
		print("[DM] UI hidden")

	_is_running = false
	print("[DM] _is_running set to false")
	var ended_id := _convo_id
	_convo_id = &""
	_lines.clear()
	_i = 0

	_disable_player_inputs(false)
	emit_signal("finished", ended_id)
	print("[DM] finished signal emitted")


# -------------------------------------------------------
# 🚷 Lock/Unlock player movement
# -------------------------------------------------------
func _disable_player_inputs(yes: bool) -> void:
	var player := _find_player_character()
	if player:
		if yes:
			_previous_input_state["physics"] = player.is_physics_processing()
			_previous_input_state["input"] = player.is_processing_input()
			player.set_physics_process(false)
			player.set_process_input(true)  # keep E key active
		else:
			player.set_physics_process(_previous_input_state["physics"])
			player.set_process_input(_previous_input_state["input"])


# -------------------------------------------------------
# 🔍 Find player node by group
# -------------------------------------------------------
func _find_player_character() -> Node:
	return get_tree().get_first_node_in_group("player")
