# MainMenu.gd
extends Control

@onready var music: AudioStreamPlayer = $BackgroundMusic
@onready var fade: AnimationPlayer = $FadeInAnimation
@onready var click_sfx: AudioStreamPlayer = $ClickSound
@onready var hover_sfx: AudioStreamPlayer = $HoverSound
@onready var exit_button: Button = $ButtonContainer/ExitButton

func _ready():
	music.play()
	fade.play("Intro")
	_connect_buttons()

func _connect_buttons():
	for button in $ButtonContainer.get_children():
		if button is Button:
			button.mouse_entered.connect(_on_button_hovered)
			button.pressed.connect(_on_button_pressed.bind(button))

func _on_button_hovered():
	hover_sfx.play()

func _on_button_pressed(button: Button):
	click_sfx.play()
	match button.name:
		"PlayButton": _start_new_game()
		"ContinueButton": _continue_game()
		"CollectionButton": _open_collection()
		"OptionsButton": _open_options()
		"ExitButton": get_tree().quit()

func _start_new_game():
	get_tree().change_scene_to_file("res://Phases/INTRO_WORLD.tscn")

func _continue_game():
	get_tree().change_scene_to_file("")

func _open_collection():
	get_tree().change_scene_to_file("res://UI/card_collection_gui.tscn")

func _open_options():
	get_tree().change_scene_to_file("res://UI/OptionsMenu.tscn")
