# File: DeckManager.gd
extends Node

const MAX_DECK_SIZE := 20
const MAX_COPIES_PER_CARD := 3  # tweak per your rules

# Store deck as IDs (stable, serializable)
var _deck: Array[String] = []  # e.g., ["GOBLIN_ID", "IMP_ID", ...]

func clear():
	_deck.clear()

func get_ids() -> Array[String]:
	return _deck.duplicate()

func size() -> int:
	return _deck.size()

func count_of(id: String) -> int:
	var c := 0
	for x in _deck:
		if x == id:
			c += 1
	return c

func can_add(id: String) -> bool:
	if size() >= MAX_DECK_SIZE:
		return false
	var owned := _owned_count(id)     # << change
	var already := count_of(id)
	if already >= MAX_COPIES_PER_CARD:
		return false
	return (already < owned)



func add(id: String) -> bool:
	if not can_add(id):
		return false
	_deck.append(id)
	return true

func remove_one(id: String) -> bool:
	for i in range(_deck.size()):
		if _deck[i] == id:
			_deck.remove_at(i)
			return true
	return false

# Useful for UI: how many are still available to add (owned - already in deck)
func remaining_available(id: String) -> int:
	return max(0, _owned_count(id) - count_of(id))  # << change

# ---- Battle helpers ----
# If your Arena expects CardData resources:
func get_deck_carddatas() -> Array:  # Array[CardData]
	var arr: Array = []
	for id in _deck:
		var cd := CardCollection.get_card_data(id)
		if cd:
			arr.append(cd)
	return arr

# File: DeckManager.gd (add this helper)
func _owned_count(id: String) -> int:
	# Prefer an explicit count method if your CardCollection has one
	if CardCollection and CardCollection.has_method("get_count"):
		return int(CardCollection.get_count(id))
	# Some projects name it differently:
	if CardCollection and CardCollection.has_method("get_card_count"):
		return int(CardCollection.get_card_count(id))

	# Fallbacks: derive from available APIs
	if CardCollection and CardCollection.has_method("get_all_cardss"):
		var cnt := 0
		for cid in CardCollection.get_all_cardss():
			if cid == id:
				cnt += 1
		# If IDs are unique (no duplicates), treat presence as 1
		if cnt == 0 and CardCollection.has_method("get_card_data") and CardCollection.get_card_data(id) != null:
			return 1
		return cnt

	# Last-resort default (assume you own 1)
	return 1
