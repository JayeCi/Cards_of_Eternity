extends Resource
class_name FusionDatabase

## Central database for all fusion recipes
## Add/remove recipes by editing this resource in the inspector

@export var recipes: Array[FusionRecipe] = []

## Find a matching recipe for two cards (order independent)
func find_fusion(card_a: CardData, card_b: CardData, card_paths: Dictionary) -> CardData:
	if not card_a or not card_b:
		return null

	for recipe in recipes:
		if recipe and recipe.matches(card_a, card_b):
			return recipe.get_result(card_paths)

	return null

## Get all recipes (for debugging/display)
func get_all_recipes() -> Array[FusionRecipe]:
	return recipes

## Add a new recipe programmatically
func add_recipe(recipe: FusionRecipe) -> void:
	if recipe and recipe.is_valid():
		recipes.append(recipe)

## Remove a recipe
func remove_recipe(recipe: FusionRecipe) -> void:
	recipes.erase(recipe)

## Clear all recipes
func clear_recipes() -> void:
	recipes.clear()
