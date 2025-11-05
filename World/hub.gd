extends Node3D

func _enter_tree():
	GameSession.hub_instance = self

	if Globals.pending_post_tutorial_dialogue:
		Globals.pending_post_tutorial_dialogue = false
		call_deferred("_begin_post_tutorial_dialogue")

func _begin_post_tutorial_dialogue():
	var reward_card := load("res://Cards/Monster Cards/Voidling_Ero.tres")
	if reward_card:
		CardCollection.add_card(reward_card)

		# show pickup UI if manager exists
		var pickup := get_tree().get_first_node_in_group("card_pickups")
		if pickup:
			pickup.show_card([reward_card] as Array[CardData])


		# taskbar badge
		var taskbar := get_tree().get_first_node_in_group("taskbar")
		if taskbar:
			taskbar.show_notification()
			
	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Well done! You understand the basics of combat."),
		DialogueManager._dl("Guide", "Remember to manage your hand and control the board."),
		DialogueManager._dl("Guide", "The realms will only grow more dangerous from here..."),
		DialogueManager._dl("Guide", "You're ready — walk through the Earth Portal."),
		DialogueManager._dl("Guide", "Take this creature — it will serve you well in the Earth Realm."),

	])

	if !DialogueManager.finished.is_connected(_resume_control):
		DialogueManager.finished.connect(_resume_control, Object.CONNECT_ONE_SHOT)

func _resume_control(_id = ""):
	InputState.set_mode(InputState.Mode.FREE)
