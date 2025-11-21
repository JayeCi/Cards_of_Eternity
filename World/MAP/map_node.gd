extends TextureButton
class_name MapNode

signal clicked(node: MapNode)

@export_enum("hub", "fight", "elite", "boss", "shop", "fireevent", "waterevent", "windevent", "earthevent", "rest", "explore", "unknown")

var encounter_type := "fight"

@export var enemy_name: String = "Tutorial Enemy"
@export var enemy_deck: Array[CardData] = []
@export var enemy_leader: CardData = null
@export var difficulty: int = 1
@export var ai_style: String = "balanced"
@export var rewards: Array[CardData] = []
@export var arena_modifier: String = "none"
@export_enum("OCEAN", "VOLCANO", "FOREST", "MEADOW", "MOUNTAIN", "TUNDRA") var biome: String = "FOREST"
@export var connected_nodes: Array[NodePath] = []
@export var randomize_event: bool = true
@export var battle_completed := false
@export var is_completed := false
@export var custom_art: Texture = null
@export var custom_art_defeated: Texture = null
@export var bg_color := Color.TRANSPARENT

@export_multiline var defeat_message: String
@export_multiline var description: String = "A mysterious encounter awaits..."

var is_reachable := false
var is_current := false

var battle_started := false



func _ready():
	self.pressed.connect(_on_pressed)
	
	# Set default bg_color based on encounter type if not manually set
	if bg_color == Color.TRANSPARENT:
		match encounter_type:
			"fight":
				bg_color = Color(0.8, 0.3, 0.3, 1)  # Reddish
			"elite":
				bg_color = Color(0.6, 0.3, 0.8, 1)  # Purple
			"boss":
				bg_color = Color(0.9, 0.2, 0.2, 1)  # Deep red
			"shop":
				bg_color = Color(0.9, 0.8, 0.3, 1)  # Gold
			"fireevent":
				bg_color = Color(1.0, 0.4, 0.1, 1)  # Orange
			"waterevent":
				bg_color = Color(0.2, 0.5, 0.9, 1)  # Blue
			"windevent":
				bg_color = Color(0.8, 0.95, 0.9, 1)  # Light cyan
			"earthevent":
				bg_color = Color(0.5, 0.4, 0.2, 1)  # Brown
			"rest":
				bg_color = Color(0.3, 0.7, 0.4, 1)  # Green
			"explore":
				bg_color = Color(0.5, 0.5, 0.6, 1)  # Gray-blue
			"hub":
				bg_color = Color(0.4, 0.2, 0.6, 1)  # Purple
			_:
				bg_color = Color(0.3, 0.3, 0.3, 1)  # Default gray


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
			"explore":
				description = "Explore, see what you find."
				
	#generate_random_rewards()

	#self.pressed.connect(_on_pressed)
	match encounter_type:
		"shop":
			texture_normal = preload("res://World/MAP/Shop.png")
		"unknown":
			texture_normal = preload("res://World/MAP/Mystery.png")
		"fight":
			texture_normal = preload("res://World/MAP/Fight_Encounter_Node.png")
			texture_hover = preload("res://World/MAP/Fight_Encounter_Node_Hover.png")
		"elite":
			# Elite nodes use fight texture but will have different color/glow
			texture_normal = preload("res://World/MAP/Fight_Encounter_Node.png")
			texture_hover = preload("res://World/MAP/Fight_Encounter_Node_Hover.png")
			modulate = Color(1.3, 0.8, 1.5, 1)  # Purple-ish glow for elites
		"boss":
			# Boss nodes use fight texture but with dramatic color
			texture_normal = preload("res://World/MAP/Fight_Encounter_Node.png")
			texture_hover = preload("res://World/MAP/Fight_Encounter_Node_Hover.png")
			modulate = Color(1.5, 0.5, 0.5, 1)  # Red glow for boss
			scale = Vector2(1.2, 1.2)  # Slightly larger
		"fireevent":
			texture_normal = preload("res://World/MAP/Fire_Node.png")
		"hub":
			texture_normal = preload("res://World/MAP/portal_hub.png")
			
func generate_random_rewards():
	# Do NOT overwrite manual rewards
	if rewards.size() > 0:
		return

	var pool := CardCollection.get_all_cards()

	if pool.is_empty():
		return

	var reward_count := 1  # default

	match encounter_type:
		"fight":
			reward_count = randi_range(1, 2)
		"elite":
			reward_count = randi_range(2, 3)
		"boss":
			reward_count = randi_range(3, 4)
		"explore":
			reward_count = randi_range(1, 2)
		"fireevent", "waterevent", "windevent", "earthevent":
			reward_count = randi_range(1, 2)
		_:
			return  # Others get no automatic rewards

	# Build reward list based on rarity weight
	var weighted_pool: Array[CardData] = []

	for card in pool:
		if card == null:
			continue

		var weight := 1

		# Weight based on rarity
		match String(card.rarity).to_lower():
			"common": weight = 20
			"uncommon": weight = 12
			"rare": weight = 6
			"epic": weight = 3
			"legendary": weight = 1
			"mythic": weight = 1

		for i in weight:
			weighted_pool.append(card)

	for i in reward_count:
		rewards.append(weighted_pool.pick_random())

func _on_pressed():
	if is_reachable:
		emit_signal("clicked", self)
		
func get_line_anchor() -> Vector2:
	return global_position + size * 0.5

func is_connected_to(node: MapNode) -> bool:
	return connected_nodes.has(get_path_to(node))
