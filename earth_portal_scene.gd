extends Control

@onready var fire_right_next_arrow: TextureButton = $FirePortal/FireRightNextArrow
@onready var earth_right_next_arrow: TextureButton = $EarthRightNextArrow
@onready var anim_player: AnimationPlayer = $EarthPortal/AnimPlayer
@onready var fire_not_unlocked: Panel = $FirePortal/FireNotUnlocked

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_earth_realm_button_pressed() -> void:
	await TransitionFade.fade_out()
	GameSession.switch_to_earth_map()
	queue_free()

func _on_earth_right_next_arrow_pressed() -> void:
	anim_player.play("Earth>Fire")

func _on_fire_right_next_arrow_pressed() -> void:
	anim_player.play("Fire>Earth")


func _on_fire_realm_button_pressed() -> void:
	fire_not_unlocked.visible = true
	get_tree().create_timer(2.0)
	fire_not_unlocked.visible = false
