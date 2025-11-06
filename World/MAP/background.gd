extends TextureRect

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed:
		print("🎯 Background got mouse:", event.button_index)

func _ready():
	set_block_signals(true)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process(false)
