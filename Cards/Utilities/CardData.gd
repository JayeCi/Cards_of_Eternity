extends Resource
class_name CardData

@export_enum("Beast", "Demon", "Machine", "Elemental", "Spirit") var type = "Beast"
@export_enum("Common", "Rare", "Epic", "Legendary") var rarity := "Common"  # String


@export var id: String = ""            # unique id (use "card_001", etc)
@export var name: String = "New Card"
@export var description: String = ""
@export var art: Texture2D
@export var cost: int = 1
@export var attack: int = 0
@export var defense: int = 0
@export var card_type: String = "Monster"  # free string for now
@export var effect_script: Script = null   # optional, for later

@export var fusion_materials: Array[String] = []
@export var attack_moves: Array[String] = []
