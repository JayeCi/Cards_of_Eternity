extends Control
signal intro_finished
signal post_intro_finished   # NEW

@onready var card_collection_gui: MarginContainer = $"../CanvasLayer/Card_Collection_GUI"
@onready var taskbar: Control = $"../CanvasLayer/UIOverlay/Taskbar"

var intro_lines: Array[DialogueLine] = [
	DialogueManager._dl("Earth Sprite", "…[i]Whoa! Welcome to the Earth Realm[/i]"),
	DialogueManager._dl("Earth Sprite", "…[i]You must be here to help![/i]"),
	DialogueManager._dl("Earth Sprite", "…[i]You can return to the Portal Hub at anytime[/i]"),
	DialogueManager._dl("Earth Sprite", "…[i]I see you got your hands on some new Cards of Eternity![/i]"),
	DialogueManager._dl("Earth Sprite", "…[i]Open up your collection![/i]")
]

var post_intro_lines: Array[DialogueLine] = [
	DialogueManager._dl("Earth Sprite", "…[i]Wonderful! You’re getting the hang of this already.[/i]"),
	DialogueManager._dl("Earth Sprite", "…[i]Now venture forth and awaken the slumbering spirits of the Earth Realm![/i]"),
	DialogueManager._dl("Earth Sprite", "…[i]Good luck, Champion![/i]")
]

func _ready():
	await get_tree().process_frame
	GameSession.map_instance.is_in_intro = true
	DialogueManager.finished.connect(_on_convo_finished)
	DialogueManager.start_convo(intro_lines)

func _on_convo_finished():
	GameSession.map_instance.intro_complete = true
	GameSession.map_instance.is_in_intro = false
	GameSession.map_instance.is_in_collection_tutorial = true

	card_collection_gui.visible = true
	taskbar.visible = false
	hide()

# Called by MapCore after the collection tutorial closes
func play_post_intro_dialogue():
	show()
	DialogueManager.finished.disconnect(_on_convo_finished)
	DialogueManager.finished.connect(_on_post_intro_finished)
	DialogueManager.start_convo(post_intro_lines)

func _on_post_intro_finished():
	hide()
	GameSession.map_instance.in_in_post_intro = false
	GameSession.map_instance.post_intro_complete = true
	emit_signal("post_intro_finished")
	print("🌿 Post intro finished — map fully unlocked.")
