extends Node

# Format: { "IMP": { "card": CardData, "count": 2 }, ... }
var collection: Dictionary = {}

signal card_added(card: CardData, count: int)
signal card_count_changed(card_id: String, new_count: int)

func add_card(card: CardData, count: int = 1) -> void:
	if card == null:
		push_warning("Tried to add null card.")
		return
	if not (card is CardData):
		push_warning("⚠️ Skipping invalid card type: %s" % [card])
		return

	# Use card.id as key consistently
	var key := card.id

	if collection.has(key):
		collection[key].count += count
		print("🔁 Added more of", card.name, "→ new count:", collection[key].count)
	else:
		collection[key] = {
			"card": card,
			"count": count
		}
		print("🆕 Added new card:", card.name)

	# 🔗 Emit consistent signals
	emit_signal("card_added", card, count)
	emit_signal("card_count_changed", key, collection[key].count)


func has_card(card_id: String) -> bool:
	return collection.has(card_id)


func get_card(card_id: String) -> CardData:
	if not collection.has(card_id):
		return null
	return collection[card_id].card


func get_card_count(card_id: String) -> int:
	if not collection.has(card_id):
		return 0
	return collection[card_id].count

func get_all_cards() -> Array[CardData]:
	var arr: Array[CardData] = []
	for entry in collection.values():
		arr.append(entry.card)
	return arr

func get_all_cardss() -> Array:
	return collection.keys()  # return IDs
#

func get_card_data(id: String) -> CardData:
	if not collection.has(id):
		return null
	return collection[id].card
