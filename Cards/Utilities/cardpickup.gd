extends Area3D

@export var pickup_distance: float = 2.0
@export var pickup_key: String = "interact"
@export var popup_manager_path: NodePath = NodePath("../CanvasLayer/CardPickupManager")
@onready var pickup_sound: AudioStreamPlayer3D = $PickupSound
@onready var new_pickup_sound: AudioStreamPlayer3D = $NewPickupSound
@onready var mesh: MeshInstance3D = $MeshInstance3D


signal card_picked(card: CardData)

var player_in_range := false
var player: Node3D = null
var card_data: CardData = null

# 🔹 Animation settings
@export var spin_speed: float = 90.0  # degrees per second
@export var float_amplitude: float = 0.05
@export var float_speed: float = 2.0

var _base_y: float = 0.0
var _float_phase: float = 0.0

func _ready() -> void:
	_randomize_card()
	monitoring = true
	monitorable = true

	# Create or hide label
	if not has_node("Label3D"):
		var label = Label3D.new()
		label.name = "Label3D"
		label.text = "Press [E] to pick up"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.visible = false
		add_child(label)
	else:
		$Label3D.visible = false

	_base_y = position.y

func _physics_process(delta: float) -> void:
	# 🌀 Always spin & float
	_spin_and_float(delta)

	# Check for player interaction
	if player_in_range and player:
		var dist = global_position.distance_to(player.global_position)
		if dist <= pickup_distance and Input.is_action_just_pressed("interact"):
			_pickup()

# --- Animation helpers ---
func _spin_and_float(delta: float) -> void:
	# Continuous rotation around Y-axis
	rotate_y(deg_to_rad(spin_speed * delta))

	# Gentle floating up/down motion
	_float_phase += delta * float_speed
	position.y = _base_y + sin(_float_phase) * float_amplitude

func _pickup() -> void:
	if card_data == null:
		push_warning("Pickup has no card data!")
		return

	print("Picked up:", card_data.name)
	mesh.visible = false
	# 🔸 Use resource_path for lookup — that’s what CardCollection uses as its key
	var key := card_data.resource_path
	var is_new := not CardCollection.has_card(key)

	# 🔸 Add to collection first (so count is updated)
	CardCollection.add_card(card_data)
	emit_signal("card_picked", card_data)

	# 🔸 Show popup
	var manager: Node = get_node_or_null(popup_manager_path)
	if manager and manager.has_method("show_card"):
		manager.show_card(card_data)

	# 🔸 Play correct sound
	if is_new:
		new_pickup_sound.play()
		await new_pickup_sound.finished
	else:
		pickup_sound.play()
		await pickup_sound.finished

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
	var dir = DirAccess.open("res://Cards/Monster Cards")
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

	if card_files.is_empty():
		push_warning("No card files found in res://cards/")
		return

	var random_file = card_files[randi() % card_files.size()]
	card_data = ResourceLoader.load("res://Cards/Monster Cards/" + random_file)
	print("Spawned CardPickup with random card:", card_data.name)
