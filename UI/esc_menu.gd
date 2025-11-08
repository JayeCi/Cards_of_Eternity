extends Control

var _was_mouse_visible := false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle()

func toggle():
	if not visible:
		# about to open pause menu — remember current mouse mode
		_was_mouse_visible = (Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE)

	visible = !visible
	get_tree().paused = visible

	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# only re-capture if it wasn’t visible before pausing
		if not _was_mouse_visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_exit_pressed() -> void:
	get_tree().paused = false
	await get_tree().process_frame
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().quit()

func _on_resume_pressed() -> void:
	toggle()

func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false
	await get_tree().process_frame
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")
