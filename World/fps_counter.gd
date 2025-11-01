
extends CanvasLayer

@onready var fps_label = $Label

func _process(delta):
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
