extends Node

# Dictionary to store owned cards and quantity
# Format: { "IMP": { "card": CardData, "count": 2 }, ... }
var collection: Dictionary = {}

signal card_added(card: CardData, count: int)


func add_card(card: CardData) -> void:
	if card == null:
		return

	if collection.has(card.resource_path):
		collection[card.resource_path].count += 1
		var new_count = collection[card.resource_path].count
		print("SIGNAL: Emitting card_added for", card.name, "count = ", new_count)
		emit_signal("card_added", card, new_count)
	else:
		collection[card.resource_path] = {
			"card": card,
			"count": 1
		}
		print("🆕 Added card to collection:", card.name)
		emit_signal("card_added", card, 1)  # ✅ emit here too


func get_card(card_id: String) -> CardData:
	if not collection.has(card_id):
		return null
	return collection[card_id].card

func get_card_count(card_id: String) -> int:
	if not collection.has(card_id):
		return 0
	return collection[card_id].count

func get_all_cards() -> Array:
	return collection.keys()  # return IDs, not cards

func get_card_data(id: String) -> CardData:
	if not collection.has(id):
		return null
	return collection[id].card
