extends Node


enum Mode {
	FREE,
	CUTSCENE,
	DIALOGUE,
	UI
}

var mode: Mode = Mode.FREE
var player: Node = null

func register_player(p: Node):
	player = p

func set_mode(new_mode: Mode):
	mode = new_mode
	_apply()

func _apply():
	if not player:
		return

	match mode:
		Mode.FREE:
			player.set_physics_process(true)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player.mouse_locked = true

		Mode.CUTSCENE:
			player.set_physics_process(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player.mouse_locked = false

		Mode.DIALOGUE:
			player.set_physics_process(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			player.mouse_locked = false

		Mode.UI:
			player.set_physics_process(false)
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			player.mouse_locked = false
