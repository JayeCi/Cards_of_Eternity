extends Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle()

func toggle():
	visible = !visible
	get_tree().paused = visible

	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_resume_pressed() -> void:
	toggle()


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/main_menu.tscn")
	toggle()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
