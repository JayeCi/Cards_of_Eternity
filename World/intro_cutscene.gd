extends Control

var intro_lines: Array[DialogueLine] = [
	DialogueManager._dl("???", "…Awaken, chosen one."),
	DialogueManager._dl("???", "The realms stir, and their power leaks into our world."),
	DialogueManager._dl("???", "Prove yourself worthy, or be consumed by eternity."),
	DialogueManager._dl("???", "Choose your path, summoner."),
]

# reference your deck UI instance
@onready var deck_ui := $IntroDeckSelect

# Four beginner decks
var starter_decks := [
	#EARTH
	[CardDB.PATH["GOBLIN"], CardDB.PATH["DIRT"], CardDB.PATH["FOREST_FAE"], CardDB.PATH["IMP"], CardDB.PATH["MUSHMONK"]],
	
	#WATER
	[CardDB.PATH["FYSH"], CardDB.PATH["AQUA_WHIP"], CardDB.PATH["COLD_SLOTH"], CardDB.PATH["FINN"], CardDB.PATH["NINJOAD"]],
	
	#FIRE
	[CardDB.PATH["FIREBALL"], CardDB.PATH["IMP"], CardDB.PATH["MOLTEN_PIG"], CardDB.PATH["VOIDLING_ERO"], CardDB.PATH["CONFLAGURATION_BLADE"]],
	
	#WIND
	[CardDB.PATH["DRAKE_OF_EMERALD"], CardDB.PATH["FALCREEP"], CardDB.PATH["BOOGLES"], CardDB.PATH["AXO_THE_KNIGHT"], CardDB.PATH["YORG_ARCHER"]],
]


func _ready() -> void:
	visible = true
	process_mode = PROCESS_MODE_ALWAYS
	TransitionFade.fade_in()

	DialogueManager.finished.connect(_on_convo_finished)
	DialogueManager.start_convo(intro_lines)

	# connect deck result
	deck_ui.deck_selected.connect(_on_deck_picked)

func _on_convo_finished(id: StringName) -> void:
	print("Intro dialogue finished!")
	_show_deck_select()

func _show_deck_select():
	print("Showing deck selection!")
	deck_ui.show_decks(starter_decks)

func _on_deck_picked(i: int):
	print("Player picked deck index:", i)
	var chosen = starter_decks[i]

	for path in chosen:
		var card := load(path)
		CardCollection.add_card(card)

	# optional toast
	DialogueManager.start_convo([
		DialogueManager._dl("???", "Your first deck… let us see what destiny brings.")
	])

	await DialogueManager.finished
	deck_ui.visible = false
	_start_game()

# fade out → map
func _start_game():
	await TransitionFade.fade_out()
	get_tree().change_scene_to_file("res://World/MAP/map_screen.tscn")
	queue_free()
