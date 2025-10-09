# res://battle/unit_data.gd
extends Resource
class_name UnitData

enum Mode { ATTACK, DEFENSE, FACEDOWN }

@export var card: CardData
@export var owner: int = 0        # 0 = player, 1 = enemy
@export var move_range: int = 1
@export var face_down: bool = false
@export var cost: int = 1

var is_leader: bool = false

var hp: int = 0  # used only for leader

var atk:int
var def:int
var current_def: int     
var mode: int = Mode.ATTACK


func init_from_card(c: CardData, o: int) -> UnitData:
	card = c
	owner = o
	atk = c.attack
	def = c.defense
	current_def = def     
	mode = UnitData.Mode.ATTACK
	is_leader = false
	hp = 0
	return self
	
func is_facedown() -> bool:
	return mode == Mode.FACEDOWN
