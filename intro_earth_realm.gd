extends Control
signal intro_finished
signal post_intro_finished   # NEW

@onready var card_collection_gui: MarginContainer = $"../CanvasLayer/Card_Collection_GUI"
@onready var taskbar: Control = $"../CanvasLayer/UIOverlay/Taskbar"

var tutorial_has_run := false
var post_intro_has_run := false


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
	# 🚀 Tutorial Skip: Hide intro if skip is enabled
	if Globals.TUTORIAL_SKIP:
		self.visible = false
		self.queue_free()  # Clean up since we don't need it
		return

	# ✅ Check if tutorial already finished globally
	if GameSession.tutorial_started:
		self.visible = false
		return

	# ✅ Otherwise run the intro normally
	tutorial_has_run = true
	GameSession.tutorial_started = true

	await get_tree().process_frame
	GameSession.map_instance.is_in_intro = true

	if not DialogueManager.finished.is_connected(_on_convo_finished):
		DialogueManager.finished.connect(_on_convo_finished)

	DialogueManager.start_convo(intro_lines)


func _on_convo_finished():
	GameSession.map_instance.intro_complete = true
	GameSession.map_instance.is_in_intro = false
	GameSession.map_instance.is_in_collection_tutorial = true

	card_collection_gui.visible = true
	taskbar.visible = false
	hide()

func play_post_intro_dialogue():
	if post_intro_has_run:
		return
	post_intro_has_run = true

	show()
	if DialogueManager.finished.is_connected(_on_convo_finished):
		DialogueManager.finished.disconnect(_on_convo_finished)
	if not DialogueManager.finished.is_connected(_on_post_intro_finished):
		DialogueManager.finished.connect(_on_post_intro_finished)
	DialogueManager.start_convo(post_intro_lines)
	
func _on_post_intro_finished():
	hide()
	GameSession.map_instance.in_in_post_intro = false
	GameSession.map_instance.post_intro_complete = true
	emit_signal("post_intro_finished")
	print("🌿 Post intro finished — map fully unlocked.")
