extends Resource
class_name CardData

# --- CARD CLASSIFICATIONS ---
# You can now assign multiple types like ["Beast", "Flying"]
@export var types: Array[String] = ["Beast"]

# Optional: you can define the allowed set for safety
const TYPE_OPTIONS := ["Beast", "Demon", "Machine", "Elemental", "Spirit", "Flying"]

@export_enum("common", "uncommon", "rare", "epic", "legendary", "mythic")
var rarity := "common"

@export_enum("Fire", "Water", "Earth", "Wind", "Shadow", "Neutral")
var element: String = "Neutral"

@export_enum("WATER", "LAVA", "FOREST", "GRASS", "STONE", "ICE")
var preferred_terrain: String = "GRASS"

# --- CARD CATEGORY ---
enum CardType { MONSTER, SPELL, EVENT }
@export var card_type: CardType = CardType.MONSTER

# --- STATS ---
@export var id: String
@export var name: String
@export var description: String
@export var art: Texture2D
@export var cost: int = 1
@export var atk: int = 0
@export var def: int = 0
@export var hp: int = 0
@export var ability: CardAbility
@export var model_path: String = ""
@export var model_scale: Vector3 = Vector3(.5, .5, .5)
@export var model_position: Vector3 = Vector3(0, 0, 0)

# --- AUDIO ---
@export var place_sound: AudioStream
@export var attack_sound: AudioStream
@export var defense_sound: AudioStream
@export var death_sound: AudioStream = preload("res://Audio/Sound FX/CardDeath.mp3")

# --- SPECIAL ---
@export var fusion_materials: Array[String] = []
@export var attack_moves: Array[String] = []

# --- UTILITY HELPERS ---
func has_type(t: String) -> bool:
	# Case-insensitive type check
	for typ in types:
		if typ.to_lower() == t.to_lower():
			return true
	return false

func add_type(t: String) -> void:
	if not has_type(t):
		types.append(t)
