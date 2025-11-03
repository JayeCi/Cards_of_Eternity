extends Node

@onready var player = get_tree().get_first_node_in_group("player")
@onready var guide = $"../HUB_Guide_Walking"
@onready var table_target = $"../Table" # Node3D near the decks

var state = "intro"

func _ready():
	await get_tree().process_frame
	while guide.agent.get_navigation_map() == null:
		await get_tree().process_frame

	# ✅ Wait one more frame so guide/global transforms update
	await get_tree().process_frame

	player.face_target(guide)

	InputState.set_mode(InputState.Mode.CUTSCENE)
	guide.approach_player(player)

	player.starter_deck_chosen.connect(_on_player_chose_deck)
	
	
func _on_player_chose_deck(element_type: String):
	guide.on_player_chosen_deck(element_type)

func _on_guide_reached_player():
	# first dialogue happens inside the guide script
	# nothing needed here unless you want camera effects
	print("Guide reached player.")


func _on_guide_reached_table():
	print("Guide reached table.")
	# enable interaction with decks
	InputState.set_mode(InputState.Mode.FREE)

	# optionally highlight decks
