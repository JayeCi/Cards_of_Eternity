extends Control

@onready var card_collection_gui: Control = $"../Card_Collection_GUI"
@onready var taskbar: Control = $Taskbar
@onready var deck_count: Label = $Taskbar/Panel/VBoxContainer2/TextureRect/DeckCount
@onready var description: Label = $InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/ScrollContainer/Description
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var info_panel: Control = $InfoPanel
@onready var reward_animation_player: AnimationPlayer = $Reward/AnimationPlayer

var _info_panel_open := false

func _ready():
	CardCollection.card_count_changed.connect(_update_deck_count)
	_update_deck_count()

func show_encounter_info(node: MapNode, animate: bool = true) -> void:
	info_panel.visible = true

	$InfoPanel/MainPanel/VBoxContainer/EnemyName.text = node.enemy_name
	$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Difficulty.text = str("Difficulty: ", node.difficulty)

	if node.is_completed:
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Completion.text = "(Completed)"
	else:
		$InfoPanel/MainPanel/VBoxContainer/DescriptionPanel/VBoxContainer/Completion.text = "(Not Completed)"

	description.text = node.description if node.description != "" else "No description available."

	if animate and not _info_panel_open:
		animation_player.play("Slide_In")

	_info_panel_open = true


func hide_info_panel(animate: bool = true) -> void:
	if animate:
		animation_player.play("Slide_Out")
	else:
		info_panel.visible = false
	_info_panel_open = false


func is_info_panel_open() -> bool:
	return _info_panel_open


func _on_slide_button_pressed() -> void:
	if _info_panel_open:
		hide_info_panel(true)
	else:
		# reopen (no node context here, just slide in UI; actual content set from MapCore)
		info_panel.visible = true
		animation_player.play("Slide_In")
		_info_panel_open = true


func _on_AnimationPlayer_animation_finished(anim_name: String) -> void:
	if anim_name == "Slide_In":
		_info_panel_open = true
		info_panel.visible = true
	elif anim_name == "Slide_Out":
		_info_panel_open = false
		# keep visible true if you’re just sliding offscreen,
		# or set false if you actually hide it:
		# info_panel.visible = false
		
func show_rewards(rewards: Array[CardData]) -> void:
	var card_grid: GridContainer = $Reward/CardGrid
	
	# ✅ Clear old cards
	for child in card_grid.get_children():
		child.queue_free()

	# ✅ Populate with new rewards
	for card_data in rewards:
		var card_ui = preload("res://UI/CardUI.tscn").instantiate()
		card_grid.add_child(card_ui)
			
		card_ui.card_data = card_data
		card_ui.refresh()


	# ✅ Play animation (Fade_In → wait 5s → Fade_Out)
	reward_animation_player.play("Fade_In")

	# Wait until fade-in finishes
	await reward_animation_player.animation_finished

	# Wait 5 seconds while cards are visible
	await get_tree().create_timer(5.0).timeout

	reward_animation_player.play("Fade_Out")

	# Optionally clear them after fade-out
	await reward_animation_player.animation_finished
	for child in card_grid.get_children():
		child.queue_free()

	
func _update_deck_count():
	deck_count.text = str(CardCollection.count())


func _on_collection_button_pressed() -> void:
	visible = false
	taskbar.visible = false
	card_collection_gui.visible = true

	if Globals.tutorial_stage == 0:
		Globals.tutorial_stage = 1


func _on_start_button_pressed() -> void:
	GameSession.switch_to_arena()
