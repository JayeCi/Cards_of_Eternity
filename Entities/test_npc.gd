extends Node3D
class_name NPC

@export var npc_name := "Bandit"
@export var card_ids: Array[String] = ["GOBLIN"]  # Default template, but overridden below
@export var deck_size := 20  # number of cards in deck

func _ready():
	add_to_group("npcs")
	# Ensure deck has 20 IMP cards at start
	card_ids = []
	for i in range(deck_size):
		card_ids.append("GOBLIN")

func on_interact():
	print("💬 Player talked to", npc_name)
	var world = get_tree().get_root().get_node("Main")
	world.start_battle_at(global_position, self)  # ✅ pass self to main.gd

func get_deck_cards() -> Array:
	var deck: Array = []
	for id in card_ids:
		var path := "res://Cards/" + id + ".tres"  # ensure this matches your folder structure
		if ResourceLoader.exists(path):
			var card := ResourceLoader.load(path)
			if card:
				deck.append(card.duplicate())
			else:
				push_warning("⚠️ Failed to load NPC card data for " + id)
		else:
			push_warning("⚠️ Missing card file: " + path)
		print("🃏 NPC deck built:", deck.size(), "cards (" + id + ")")
	return deck
