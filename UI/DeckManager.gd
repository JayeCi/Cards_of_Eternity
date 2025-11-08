# File: DeckManager.gd
extends Node

const MAX_DECK_SIZE := 20
const MAX_COPIES_PER_CARD := 3

# Store deck as card IDs (String)
var _deck: Array[String] = []


# ==========================================================
# 🔧 BASIC MANAGEMENT
# ==========================================================
func clear() -> void:
	_deck.clear()

func size() -> int:
	return _deck.size()

func get_ids() -> Array[String]:
	return _deck.duplicate()


# ==========================================================
# 📥 ADD / REMOVE
# ==========================================================
func add(card: CardData) -> bool:
	if not card:
		return false
	var id := card.id
	if not can_add(id):
		return false
	_deck.append(id)
	print("[DeckManager] Added: ", id)
	return true


func remove_one(card: CardData) -> bool:
	if not card:
		return false
	var id := card.id
	for i in range(_deck.size()):
		if _deck[i] == id:
			_deck.remove_at(i)
			print("[DeckManager] Removed: ", id)
			return true
	return false


# ==========================================================
# 📊 CHECKS
# ==========================================================
func can_add(id: String) -> bool:
	if size() >= MAX_DECK_SIZE:
		return false
	if count_of(id) >= MAX_COPIES_PER_CARD:
		return false
	return true


func count_of(id: String) -> int:
	var c := 0
	for x in _deck:
		if x == id:
			c += 1
	return c


# ==========================================================
# 📦 AVAILABILITY (UI helpers)
# ==========================================================
func remaining_available(card: CardData) -> int:
	if not card:
		return 0
	var owned := _owned_count(card.id)
	return max(0, owned - count_of(card.id))


func _owned_count(id: String) -> int:
	if CardCollection and CardCollection.has_method("get_card_count"):
		return CardCollection.get_card_count(id)
	return 1


# ==========================================================
# 🧩 CONVERSION HELPERS
# ==========================================================
func get_deck_carddatas() -> Array[CardData]:
	var arr: Array[CardData] = []
	for id in _deck:
		var cd := CardCollection.get_card_data(id)
		if cd:
			arr.append(cd)
	return arr
