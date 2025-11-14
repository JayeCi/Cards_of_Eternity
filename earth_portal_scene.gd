extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_earth_realm_button_pressed() -> void:
	await TransitionFade.fade_out()
	GameSession.switch_to_earth_map()
