extends Control

@onready var music: AudioStreamPlayer = $BackgroundMusic
@onready var fade: AnimationPlayer = $FadeInAnimation
@onready var click_sfx: AudioStreamPlayer = $ClickSound
@onready var hover_sfx: AudioStreamPlayer = $HoverSound
@onready var exit_button: TextureButton = $ButtonContainer/ExitButton
@onready var background: TextureRect = $Background
@onready var game_logo: TextureRect = $GameLogo

# Keep track of tweens per button
var active_tweens := {}

func _ready():
	music.play()
	fade.play("Intro")
	_connect_buttons()

func _connect_buttons():
	for button in $ButtonContainer.get_children():
		if button is TextureButton:
			button.mouse_entered.connect(_on_button_hovered.bind(button))
			button.mouse_exited.connect(_on_button_unhovered.bind(button))
			button.pressed.connect(_on_button_pressed.bind(button))

func _on_button_hovered(button: TextureButton):
	hover_sfx.play()

	# cancel old tween
	if active_tweens.has(button):
		active_tweens[button].kill()

	var tween = create_tween()
	active_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color(1.2, 1.2, 1.2, 1), 0.15)

func _on_button_unhovered(button: TextureButton):
	if active_tweens.has(button):
		active_tweens[button].kill()

	var tween = create_tween()
	active_tweens[button] = tween
	tween.tween_property(button, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(button, "modulate", Color(1, 1, 1, 1), 0.15)

func _on_button_pressed(button: TextureButton):
	click_sfx.play()
	match button.name:
		"PlayButton": _start_new_game()
		"ContinueButton": _continue_game()
		"CollectionButton": _open_collection()
		"OptionsButton": _open_options()
		"ExitButton": get_tree().quit()

func _start_new_game():
	get_tree().change_scene_to_file("res://Arena/Arena3D/arena_3d.tscn")

func _continue_game():
	get_tree().change_scene_to_file("")

func _open_collection():
	get_tree().change_scene_to_file("res://UI/card_collection_gui.tscn")

func _open_options():
	get_tree().change_scene_to_file("res://UI/OptionsMenu.tscn")
