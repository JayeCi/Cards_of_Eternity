extends Node

var cards: Dictionary = {}

func _ready():
	_load_all_cards()

func _load_all_cards():
	var dir = DirAccess.open("res://cards")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var card = ResourceLoader.load("res://cards/" + file_name)
				if card and card.has_method("get_id"):
					cards[card.get_id()] = card
				elif card and card.has_property("id"):
					cards[card.id] = card
			file_name = dir.get_next()
		dir.list_dir_end()

func get_card(id: String) -> CardData:
	return cards.get(id)
