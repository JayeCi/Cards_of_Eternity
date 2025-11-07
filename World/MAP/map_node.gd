extends TextureButton
class_name MapNode

signal clicked(node: MapNode)

@export_enum("start", "fight", "elite", "boss", "shop", "fireevent", "waterevent", "windevent", "earthevent", "rest", "explore", "unknown")
var encounter_type := "fight"
@export var enemy_name: String = "Tutorial Enemy"
@export var enemy_deck: Array[CardData] = []

@export var difficulty: int = 1
@export var ai_style: String = "balanced"
@export var rewards: Array[CardData] = []
@export var arena_modifier: String = "none"
@export var connected_nodes: Array[NodePath] = []
@export var randomize_event: bool = true
@export var battle_completed := false
@export var is_completed := false
@export_multiline var description: String = "A mysterious encounter awaits..."

var is_reachable := false
var is_current := false

var battle_started := false


func _ready():
	self.pressed.connect(_on_pressed)

	if description == "":
		match encounter_type:
			"start":
				description = "The beginning of your journey."
			"fight":
				description = "Face off against an enemy in a tactical card duel."
			"elite":
				description = "A dangerous elite opponent awaits — tougher rewards too."
			"boss":
				description = "The ultimate test of this realm's strength."
			"shop":
				description = "Trade cards and items for gold."
			"fireevent":
				description = "An elemental event tied to fire energy unfolds here."


	self.pressed.connect(_on_pressed)
	match encounter_type:
		
		"shop":
			texture_normal = preload("res://World/MAP/Shop.png")
			
		"unknown":
			texture_normal = preload("res://World/MAP/Mystery.png")
		"fight":
			texture_normal = preload("res://World/MAP/Fight_Encounter_Node.png")
			texture_hover = preload("res://World/MAP/Fight_Encounter_Node_Hover.png")
		"fireevent":
			texture_normal = preload("res://World/MAP/Fire_Node.png")
		"start":
			texture_normal = preload("res://World/MAP/Knight_Node.png")
			
func _on_pressed():
	if is_reachable:
		emit_signal("clicked", self)
		
func get_line_anchor() -> Vector2:
	return global_position + size * 0.5

func is_connected_to(node: MapNode) -> bool:
	return connected_nodes.has(get_path_to(node))
