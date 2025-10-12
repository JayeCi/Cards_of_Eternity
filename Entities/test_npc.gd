extends Node3D
class_name NPC

@onready var name_label: Label3D = $NameLabel

@export var npc_name := "Ivory"
@export var card_ids: Array[String] = ["GOBLIN"]
@export var deck_size := 20
@export var dialogue_data: DialogueData
@export var post_battle_dialogue: DialogueData  

var _battle_started := false
var _battle_completed := false
var _reward_given := false

func _ready():
	add_to_group("npcs")
	card_ids.clear()
	for i in range(deck_size):
		card_ids.append("GOBLIN")

func on_interact():
	if _battle_completed:
		await _handle_post_battle_interaction()
		return

	if dialogue_data:
		print("💬 Player started talking to ", npc_name)
		await DialogueManager.start_dialogue(dialogue_data.lines)

		await get_tree().process_frame
		if DialogueManager.current_ui and DialogueManager.current_ui.is_inside_tree():
			DialogueManager.current_ui.queue_free()
			DialogueManager.current_ui = null

	if not _battle_started:
		_battle_started = true
		var world = get_tree().root.get_node("Phase1")
		if world and world.has_method("start_battle_at"):
			print("⚔️ Starting battle with", npc_name)
			world.start_battle_at(global_position, self)
		else:
			push_warning("❌ Could not find world or start_battle_at method")

func on_battle_end(result: String) -> void:
	if not _battle_started:
		return
	print("🎯 NPC", npc_name, "received battle result:", result)
	_battle_completed = true
	_battle_started = false

func _handle_post_battle_interaction() -> void:
	print("🏆 Post-battle talk with", npc_name)
	if post_battle_dialogue:
		await DialogueManager.start_dialogue(post_battle_dialogue.lines)
	else:
		await DialogueManager.start_dialogue([
			npc_name + ": That was a great duel!",
			npc_name + ": You’ve earned a reward — take this card."
		])

	await get_tree().process_frame
	if DialogueManager.current_ui and DialogueManager.current_ui.is_inside_tree():
		DialogueManager.current_ui.queue_free()
		DialogueManager.current_ui = null

	_give_reward_card()

func _give_reward_card() -> void:
	if card_ids.is_empty():
		push_warning("⚠️ NPC " + npc_name + " has no cards to give.")
		return
	if _reward_given:
		print("✅ Reward already given to", npc_name)
		return

	var random_id = card_ids[randi() % card_ids.size()]
	var path = "res://Cards/" + random_id + ".tres"
	if not ResourceLoader.exists(path):
		push_warning("⚠️ Reward card missing: " + path)
		return

	var card := ResourceLoader.load(path)
	if card:
		CardCollection.add_card(card)
		print("🎁 Player received reward card:", card.name)

		var popup_manager = get_tree().get_first_node_in_group("popup_manager")
		if popup_manager and popup_manager.has_method("show_card"):
			popup_manager.show_card(card)

		_reward_given = true
