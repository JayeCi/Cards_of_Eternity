extends Resource
class_name FusionRecipe

## Defines a single fusion recipe
## Drag CardData resources into card_a and card_b slots
## Set the result card path or drag the CardData resource

@export var card_a: CardData  ## First card for fusion (order doesn't matter)
@export var card_b: CardData  ## Second card for fusion (order doesn't matter)
@export var result: CardData  ## The resulting fused card
@export var element: String = ""
## Optional: Use card name strings instead (for easier editing)
@export var card_a_name: String = ""
@export var card_b_name: String = ""
@export var result_name: String = ""

## Validate that the recipe is properly configured
func is_valid() -> bool:
	# Either use CardData resources OR name strings (not both)
	if card_a and card_b and result:
		return true
	if card_a_name != "" and card_b_name != "" and result_name != "":
		return true
	return false

## Check if this recipe matches the two cards (order independent)
func matches(a: CardData, b: CardData) -> bool:
	if not is_valid():
		return false

	if not a or not b:
		return false

	# Get names of cards being checked
	var check_a_name = a.name
	var check_b_name = b.name

	# Check by CardData resources (compare by name, not reference)
	if card_a and card_b:
		var recipe_a_name = card_a.name
		var recipe_b_name = card_b.name
		return (check_a_name == recipe_a_name and check_b_name == recipe_b_name) or \
			   (check_a_name == recipe_b_name and check_b_name == recipe_a_name)

	# Check by card name strings
	if card_a_name != "" and card_b_name != "":
		return (check_a_name == card_a_name and check_b_name == card_b_name) or \
			   (check_a_name == card_b_name and check_b_name == card_a_name)

	return false

## Get the result card (either from resource or by name lookup)
func get_result(card_paths: Dictionary) -> CardData:
	if result:
		return result

	if result_name != "" and card_paths.has(result_name):
		return load(card_paths[result_name])

	return null
