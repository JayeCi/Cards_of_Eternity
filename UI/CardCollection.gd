# File: CardCollection.gd
extends Node


# ==========================================================
# 📦 COLLECTION STRUCTURE
# ==========================================================
# collection = {
#     "IMP": { "card": <CardData>, "count": 2 },
#     "GOBLIN": { "card": <CardData>, "count": 1 }
# }
# ==========================================================
var collection: Dictionary = {}

signal card_added(card: CardData, count: int)
signal card_count_changed(card_id: String, new_count: int)
signal collection_changed


# ==========================================================
# 🏁 INITIALIZATION / TESTING
# ==========================================================
func _ready():
	_test_set()

func _test_set():
	clear_collection()
	var card_names := [
		"PLAGUE_SENTINEL", 
		"FIREBALL",
		"JESTER_OF_FLAMES",
		"FYSH",
		"BOOGLES"
		
		]
	for name in card_names:
		add_card_by_name(name)


func clear_collection():
	collection.clear()
	print("🧹 Collection cleared.")
	emit_signal("collection_changed")


# ==========================================================
# 🔧 ADD / REMOVE
# ==========================================================
func add_card_by_name(name: String, count: int = 1):
	var path := CardDB.lookup(name)
	if path == "":
		push_warning("❌ No card path found for: %s" % name)
		return

	var card := load(path)
	if card and card is CardData:
		add_card(card, count)
	else:
		push_warning("⚠️ Failed to load CardData for: %s" % name)


func add_card(card: CardData, count: int = 1) -> void:
	if not card:
		push_warning("⚠️ Tried to add null card.")
		return

	var key := card.id

	if collection.has(key):
		collection[key].count += count
		print("🔁 Added more of", card.name, "→ new count:", collection[key].count)
	else:
		collection[key] = {"card": card, "count": count}
		print("🆕 Added new card:", card.name)

	emit_signal("card_added", card, count)
	emit_signal("card_count_changed", key, collection[key].count)
	emit_signal("collection_changed")


func remove_card(card: CardData, count: int = 1):
	if not card:
		return
	var key := card.id
	if not collection.has(key):
		push_warning("⚠️ Tried to remove %s but it's not in collection." % card.name)
		return
	collection[key].count -= count
	if collection[key].count <= 0:
		collection.erase(key)
		print("🗑 Removed all of %s" % card.name)
	else:
		print("➖ Removed %d of %s (remaining %d)" % [count, card.name, collection[key].count])
	emit_signal("collection_changed")


# ==========================================================
# 📖 ACCESSORS
# ==========================================================
func has_card(card_id: String) -> bool:
	return collection.has(card_id)

func get_card_data(id: String) -> CardData:
	return collection[id].card if collection.has(id) else null

func get_card_count(card_id: String) -> int:
	return collection[card_id].count if collection.has(card_id) else 0

func get_all_cards() -> Array[CardData]:
	var arr: Array[CardData] = []
	for entry in collection.values():
		arr.append(entry.card)
	return arr

func get_all_card_ids() -> Array[String]:
	return collection.keys()

func count() -> int:
	return collection.size()
