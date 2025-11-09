extends Control

@onready var not_unlocked: Panel = $Not_unlocked

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	TransitionFade.fade_in()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_fire_pressed() -> void:
	not_unlocked.visible = true
	await get_tree().create_timer(3.0).timeout
	not_unlocked.visible = false
	
func _on_earth_pressed() -> void:
	await TransitionFade.fade_out()
	get_tree().change_scene_to_file("res://World/MAP/map_screen.tscn")

func _on_water_pressed() -> void:
	not_unlocked.visible = true
	await get_tree().create_timer(3.0).timeout
	not_unlocked.visible = false

func _on_wind_pressed() -> void:
	not_unlocked.visible = true
	await get_tree().create_timer(3.0).timeout
	not_unlocked.visible = false
