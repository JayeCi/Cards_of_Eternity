# res://scripts/CardCollection.gd
extends Node

# Dictionary to store all collected cards
# Key: card ID, Value: CardData resource
var collection: Dictionary = {}

# Signal for UI updates
signal card_added(card: CardData)

# Add a card to the collection
func add_card(card: CardData) -> void:
	if card == null:
		return
	if not collection.has(card.id):
		collection[card.id] = card
		emit_signal("card_added", card)
		print("Added card to collection:", card.name)  # <-- correct
	else:
		print("Card already in collection:", card.name) # <-- correct


# Check if a card is owned
func has_card(card_id: String) -> bool:
	return collection.has(card_id)

# Get a list of all owned cards
func get_all_cards() -> Array:
	return collection.values()

# Optional: Save / Load
func save_collection(path: String = "user://collection.json") -> void:
	var id_list = []
	for c in collection.values():
		id_list.append(c.id)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(id_list))
		file.close()


func load_collection(path: String = "user://collection.json") -> void:
	if not FileAccess.file_exists(path):
		return
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var text = file.get_as_text()
		file.close()
		var result = JSON.parse_string(text)
		if result.error != OK:
			return
		var id_list = result.result
		# Assuming all CardData resources are loaded in `res://cards/`
		for id in id_list:
			var card = find_card_by_id(id)
			if card:
				collection[id] = card

# Helper function to find a card by ID from all card resources
func find_card_by_id(id: String) -> CardData:
	var dir = DirAccess.open("res://cards")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if not dir.current_is_dir() and file.ends_with(".tres"):
				var card = ResourceLoader.load("res://cards/" + file)
				if card and card is CardData and card.id == id:
					dir.list_dir_end()
					return card
			file = dir.get_next()
		dir.list_dir_end()
	return null
