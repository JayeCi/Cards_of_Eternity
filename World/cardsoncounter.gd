extends Area3D
signal card_picked_up(cards: Array[CardData])

@export var interact_action := &"interact"
@export var prompt_path: NodePath
@onready var pickup_sfx: AudioStreamPlayer3D = $"../PickupSound"
@export var card_mesh: NodePath
@export var cards_to_give: Array[CardData] = []  # 🆕 multiple cards
@onready var card_pickup_manager: Control = $"../../../Card_Description_Popup/CardPickupManager"

@onready var _prompt: Node = get_node_or_null(prompt_path)
@onready var _card: Node3D = get_node_or_null(card_mesh)
@onready var _player: Node3D = null
@onready var _audio := AudioStreamPlayer3D.new()

var _picked_up := false

func _ready() -> void:
	if _prompt:
		_prompt.visible = false
	add_child(_audio)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player and not _picked_up and Input.is_action_just_pressed(interact_action):
		_pickup_cards()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body
		if _prompt:
			_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		if _prompt:
			_prompt.visible = false

func _pickup_cards() -> void:
	if _picked_up:
		return
	_picked_up = true

	if _prompt:
		_prompt.visible = false

	# 🔹 Show pickup popups
	var manager = card_pickup_manager
	if manager and manager.has_method("show_card"):
		manager.show_card(cards_to_give)

	print("[CardsOnCounter] Player picked up cards!")

	# 🔹 Add all cards to the collection
	for card in cards_to_give:
		if card:
			CardCollection.add_card(card)

	# 🔹 Notify listeners (like NPCs waiting for pickup)
	emit_signal("card_picked_up", cards_to_give.duplicate())
	print("[CardsOnCounter] Signal emitted for pickup!")


	# 🔹 Optional sound
	if pickup_sfx:
		pickup_sfx.play()

	# 🔹 Optional fade-out
	if _card:
		var tween := create_tween()
		tween.tween_property(_card, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished

	queue_free()
