extends Resource
class_name CardData

@export_enum("Beast", "Demon", "Machine", "Elemental", "Spirit", "Flying") var type = "Beast"
@export_enum("Common", "Rare", "Epic", "Legendary") var rarity := "Common"  # String
@export_enum("Fire", "Water", "Earth", "Wind", "Neutral") var element: String = "Neutral"

@export var id: String
@export var name: String
@export var description: String
@export var art: Texture2D
@export var cost: int = 1
@export var atk: int = 0
@export var def: int = 0
@export var hp: int = 0
@export var ability: CardAbility

@export var place_sound: AudioStream
@export var attack_sound: AudioStream
@export var defense_sound: AudioStream
@export var death_sound: AudioStream

@export var fusion_materials: Array[String] = []
@export var attack_moves: Array[String] = []
