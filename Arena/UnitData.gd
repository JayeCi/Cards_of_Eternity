extends Resource
class_name UnitData

enum Mode { ATTACK, DEFENSE, FACEDOWN }

@export var card: CardData
@export var owner: int
@export var atk: int = 0
@export var def: int = 0
@export var hp: int = 0
@export var mode: int = Mode.ATTACK
@export var is_leader: bool = false

# Runtime (not exported)
var current_atk: int
var current_def: int
var max_def: int

func init_from_card(c: CardData, owner_id: int) -> UnitData:
	if c == null:
		push_error("❌ UnitData.init_from_card called with null CardData!")
		return self

	card = c
	owner = owner_id
	atk = c.atk
	def = c.def
	hp = c.hp if "hp" in c else 0
	current_atk = atk
	current_def = def
	max_def = def 
	
	if c.ability:
		card.ability = c.ability.duplicate(true)
	return self

func reset_stats():
	current_atk = atk
	current_def = def
	max_def = def
	
func is_facedown() -> bool:
	return mode == Mode.FACEDOWN
