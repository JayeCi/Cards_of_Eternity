extends Area3D

@export var pickup_distance: float = 2.0
@export var pickup_key: String = "interact"
@export var popup_manager_path: NodePath = NodePath("/root/Main/CanvasLayer/CardPickupManager")

signal card_picked(card: CardData)

var player_in_range := false
var player: Node3D = null
var card_data: CardData = null

func _ready() -> void:
	# Connect area signals

	# Randomize card after signals (important order)
	_randomize_card()

	# Ensure collision layer works
	monitoring = true
	monitorable = true

	# Create label dynamically if not in scene
	if not has_node("Label3D"):
		var label = Label3D.new()
		label.name = "Label3D"
		label.text = "Press [E] to pick up"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visible = false
		add_child(label)
	else:
		$Label3D.visible = false  # hide by default

func _physics_process(delta: float) -> void:
	if player_in_range and player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= pickup_distance and Input.is_action_just_pressed(pickup_key):
			_pickup()

func _pickup() -> void:
	if card_data == null:
		push_warning("Pickup has no card data!")
		return

	print("Picked up:", card_data.name)
	CardCollection.add_card(card_data)
	emit_signal("card_picked", card_data)

	# 🟢 Show popup using manager
	var manager: Node = get_node_or_null(popup_manager_path)
	if manager and manager.has_method("show_card"):
		manager.show_card(card_data)

	queue_free()


func _on_body_entered(body):
	if body.is_in_group("player"):
		print("Player entered pickup area:", body.name)
		player_in_range = true
		player = body
		if has_node("Label3D"):
			$Label3D.visible = true

func _on_body_exited(body):
	if body == player:
		print("Player exited pickup area:", body.name)
		player_in_range = false
		player = null
		if has_node("Label3D"):
			$Label3D.visible = false

# --- Random Card Selection ---
func _randomize_card() -> void:
	var dir = DirAccess.open("res://cards")
	if dir == null:
		push_warning("Could not open res://cards directory")
		return

	var card_files: Array = []
	dir.list_dir_begin()
	var file = dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			card_files.append(file)
		file = dir.get_next()
	dir.list_dir_end()

	if card_files.size() == 0:
		push_warning("No card files found in res://cards/")
		return

	var random_file = card_files[randi() % card_files.size()]
	card_data = ResourceLoader.load("res://cards/" + random_file)
	print("Spawned CardPickup with random card:", card_data.name)
