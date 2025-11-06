extends Node2D

@onready var camera: Camera2D = $CanvasLayer/MapCamera
@onready var map_sprite: TextureRect = $CanvasLayer/MapRoot/Map  # your EarthMap

var dragging := false
var zoom_speed := 0.1
var min_zoom := 0.5
var max_zoom := 2.0
var drag_button := MOUSE_BUTTON_RIGHT   # ✅ Use right-click instead of left

func _ready():
	# Disable input handling on the background Sprite2D
	var bg = $CanvasLayer/MapRoot/Map
	bg.set_process_input(false)
	bg.set_process_unhandled_input(false)
	
	set_process_unhandled_input(true)
	await get_tree().process_frame
	camera.make_current()
	
	print("Camera current:", camera.is_current())

	for node in get_tree().get_nodes_in_group("debug_pickables"):
		node.remove_from_group("debug_pickables")

	for child in $CanvasLayer/MapRoot.get_children():
		if child is Sprite2D:
			child.add_to_group("debug_pickables")
			print("Tracking Sprite2D:", child.name)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		print("--- CLICK DETECTED ---")
		print("Mouse pos (viewport): ", event.position)
		print("Mouse over:", get_tree().get_nodes_in_group("debug_pickables"))

	if event is InputEventMouseButton:
		print("Mouse Button:", event.button_index, "Pressed:", event.pressed)
	elif event is InputEventMouseMotion:
		print("Mouse Motion:", event.relative)

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_set_zoom(camera.zoom * (1 - zoom_speed))
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_set_zoom(camera.zoom * (1 + zoom_speed))
			drag_button:
				dragging = event.pressed

	elif event is InputEventMouseMotion and dragging:
		camera.position -= event.relative / camera.zoom

func _set_zoom(new_zoom: Vector2):
	new_zoom.x = clamp(new_zoom.x, min_zoom, max_zoom)
	new_zoom.y = clamp(new_zoom.y, min_zoom, max_zoom)
	camera.zoom = new_zoom
