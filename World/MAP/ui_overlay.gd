extends Control

@onready var card_collection_gui: Control = $"../Card_Collection_GUI"
@onready var taskbar: Control = $Taskbar
@onready var deck_count: Label = $Taskbar/Panel/VBoxContainer2/TextureRect/DeckCount

func _ready():
	CardCollection.card_count_changed.connect(_update_deck_count)
	_update_deck_count()
	
func show_encounter_info(node: MapNode):
	$InfoPanel.visible = true
	$InfoPanel/Panel/VBoxContainer/EnemyName.text = node.enemy_name
	$InfoPanel/Panel/VBoxContainer/Difficulty.text = str("Difficulty: " , node.difficulty)

	if node.is_completed:
		$InfoPanel/Panel/VBoxContainer/Completion.text = "(Completed)"
	else:
		$InfoPanel/Panel/VBoxContainer/Completion.text = "(Not Completed)"
		
	# populate other things (reward preview, art, etc.)

func _update_deck_count():
	deck_count.text = str(CardCollection.count())


func _on_start_button_pressed() -> void:
	GameSession.switch_to_arena()
	
func show_rewards():
	return


func _on_collection_button_pressed() -> void:
	card_collection_gui.visible = true
	taskbar.visible = false
