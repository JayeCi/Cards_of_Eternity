extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer


var intro_lines: Array[DialogueLine] = [
	DialogueManager._dl("???", "…[i]So, it begins, Card Wielder.[/i]"),
	DialogueManager._dl("???", "The [color=yellow]balance of eternity[/color] falters, and the realms stir once more."),

	DialogueManager._dl("???", "Long ago, [b]six realms[/b] thrived — [color=orangered]Fire[/color], [color=deepskyblue]Water[/color], [color=lightgreen]Wind[/color], [color=peru]Earth[/color], [color=gold]Light[/color], and [color=purple]Shadow[/color]."),
	DialogueManager._dl("???", "When the [b]Eternals[/b] fell into slumber, the [b]Arbiters[/b] rose and sealed their worlds away."),

	DialogueManager._dl("???", "Now, their power seeps through the [b]Cards of Eternity[/b] — fragments of [i]creation itself[/i]."),
	DialogueManager._dl("???", "Each card you hold carries the memory of a sleeping realm, waiting to awaken."),

	DialogueManager._dl("???", "But beware… every element bears both [color=red]blessing[/color] and [color=gray]curse[/color]."),
	DialogueManager._dl("???", "[color=orangered]Fire[/color] burns with passion — and destruction."),
	DialogueManager._dl("???", "[color=deepskyblue]Water[/color] flows with wisdom — and sorrow."),
	DialogueManager._dl("???", "[color=lightgreen]Wind[/color] whispers freedom — yet breeds chaos."),
	DialogueManager._dl("???", "[color=peru]Earth[/color] endures — but hardens into pride."),
	DialogueManager._dl("???", "[color=gold]Light[/color] reveals truth — yet blinds those who gaze too long."),
	DialogueManager._dl("???", "[color=purple]Shadow[/color] conceals all — salvation and despair alike."),

	DialogueManager._dl("???", "Six realms. Six Arbiters. Six hearts waiting for your hand, [b]Card Wielder[/b]."),
	DialogueManager._dl("???", "Awaken them… or let them fade into oblivion."),

	DialogueManager._dl("???", "The [b]Shrine[/b] calls."),
	DialogueManager._dl("???", "[color=orangered]Fire[/color]. [color=deepskyblue]Water[/color]. [color=lightgreen]Wind[/color]. [color=peru]Earth[/color]."),
	DialogueManager._dl("???", "Choose your path, and your journey shall begin…"),
]

# reference your deck UI instance
@onready var deck_ui := $IntroDeckSelect

# Four beginner decks
var starter_decks := [

	#FIRE
	[CardDB.PATH["FIREBALL"], CardDB.PATH["IMP"], CardDB.PATH["MOLTEN_PIG"], CardDB.PATH["VOIDLING_ERO"], CardDB.PATH["CONFLAGURATION_BLADE"]],
	#EARTH
	[CardDB.PATH["GOBLIN"], CardDB.PATH["DIRT"], CardDB.PATH["STONE_FAE"], CardDB.PATH["IMP"], CardDB.PATH["MUSHMONK"]],
	#WIND
	[CardDB.PATH["DRAKE_OF_EMERALD"], CardDB.PATH["FALCREEP"], CardDB.PATH["BOOGLES"], CardDB.PATH["AXO_THE_KNIGHT"], CardDB.PATH["YORG_ARCHER"]],
	#WATER
	[CardDB.PATH["FYSH"], CardDB.PATH["AQUA_WHIP"], CardDB.PATH["COLD_SLOTH"], CardDB.PATH["FINN"], CardDB.PATH["NINJOAD"]],
]


func _ready() -> void:
	visible = true
	process_mode = PROCESS_MODE_ALWAYS
	TransitionFade.fade_in()
	
	DialogueManager.advanced.connect(_on_dialogue_advanced)
	DialogueManager.finished.connect(_on_convo_finished)
	DialogueManager.start_convo(intro_lines)

	# connect deck result
	deck_ui.deck_selected.connect(_on_deck_picked)
	
func _on_dialogue_advanced(index: int) -> void:
	if index == 5:  # when reaching “Each card you hold carries…”
		print("🎬 Triggering FadeIn animation")
		if animation_player and not animation_player.is_playing():
			animation_player.play("FadeIn")


func _on_convo_finished() -> void:
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
	GameSession.switch_to_hub()
	queue_free()
