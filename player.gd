extends CharacterBody3D

const SPEED = 10.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003

# --- FOOTSTEPS ---
const STEP_DISTANCE := 2.0            # meters per step
const STEP_MIN_GAP := 0.15            # seconds, avoids machine-gun on stalls
const VOLUME_DB_RANGE := Vector2(-23.0, -21.0)
const PITCH_RANGE := Vector2(0.92, 1.08)

@onready var step_player: AudioStreamPlayer3D = $StepPlayer
var _footstep_streams: Array[AudioStream] = [
	preload("res://Audio/footstep1.mp3"),
	preload("res://Audio/footstep2.mp3"),
	preload("res://Audio/footstep3.mp3"),
]
var _rng := RandomNumberGenerator.new()
var _step_dist_accum := 0.0
var _time_since_step := 0.0

# ------------------
const CARD_PATHS := {
	"DIRT":               "res://Cards/Monster Cards/Dirt.tres",
	"GOBLIN":             "res://Cards/Monster Cards/Goblin.tres",
	"IMP":                "res://Cards/Monster Cards/Imp.tres",
	"FYSH":               "res://Cards/Monster Cards/Fysh.tres",
	"NAGA":               "res://Cards/Monster Cards/Naga of the Pyre.tres",
	"COLD_SLOTH":         "res://Cards/Monster Cards/Cold_Sloth.tres",
	"LAVA_HARE":          "res://Cards/Monster Cards/Lava_Hare.tres",
	"FOREST_FAE":         "res://Cards/Monster Cards/Forest_Fae.tres",
	"FIREBALL":           "res://Cards/Spell Cards/Fireball.tres",
	"LYZARD":             "res://Cards/Monster Cards/Aqua Lyzard.tres",
	"ERUPTION":           "res://Cards/Spell Cards/Eruption.tres",
	"DRAKE_OF_EMERALD":   "res://Cards/Monster Cards/Drake of Emerald.tres",
	"FLAME_FAE":          "res://Cards/Monster Cards/Flame_Fae.tres",
	"AXO_THE_KNIGHT":     "res://Cards/Monster Cards/Axo The Knight.tres",
	"STONE_FAE":          "res://Cards/Monster Cards/Stone_Fae.tres",
	"FINN":                 "res://Cards/Monster Cards/Finn.tres",
	"FALCREEP":             "res://Cards/Monster Cards/Falcreep.tres",
	"SNAPTRAP":             "res://Cards/Monster Cards/Snaptrap.tres",
	"MOLTEN_PIG":           "res://Cards/Monster Cards/Molten_Pig.tres",
	"NINJOAD":              "res://Cards/Monster Cards/Ninjoad.tres",
	"BOOGLES":              "res://Cards/Monster Cards/Boogles.tres",
	"FUNGOO":               "res://Cards/Monster Cards/Fungoo.tres",
	"ORB_OF_DARKNESS":      "res://Cards/Spell Cards/Orb_Of_Darkness.tres",
	"SHADOW_CANDLES":       "res://Cards/Spell Cards/Shadow_Candles.tres",
	"JESTER_OF_FLAMES":     "res://Cards/Monster Cards/Jester_of_Flames.tres",
	"VOIDLING_ERO":         "res://Cards/Monster Cards/Voidling_Ero.tres",
	"MUSHMONK":             "res://Cards/Monster Cards/Mushmonk.tres",
	"ZEI_PANDA":            "res://Cards/Monster Cards/Zei_Panda.tres",
	"YORG_ARCHER":          "res://Cards/Monster Cards/Yorg_Archer.tres",
	"CONFLAGURATION_BLADE": "res://Cards/Spell Cards/Conflaguration_Blade.tres",
	"TIDAL_WAVE":           "res://Cards/Spell Cards/Tidal_Wave.tres",
	"AQUA_WHIP":            "res://Cards/Spell Cards/Aqua_whip.tres",
	#"":                  "res://Cards/Monster Cards/.tres",
}

@onready var cam: Camera3D = $Head/Camera3D
@onready var head = $Head
@onready var collection_ui: Control = $"../Card_Collection_GUI"
@onready var taskbar: Control = $"../Taskbar"

var rotation_x = 0.0
var mouse_locked = true

func _ready() -> void:
	if Engine.has_singleton("DialogueManager"):
		DialogueManager._ui = $DialogueUI
		print("[World] Registered DialogueUI manually")
		
	CardCollection.add_card(get_card(CARD_PATHS.GOBLIN))
	CardCollection.add_card(get_card(CARD_PATHS.DIRT))
	CardCollection.add_card(get_card(CARD_PATHS.COLD_SLOTH))
	CardCollection.add_card(get_card(CARD_PATHS.FYSH))
	CardCollection.add_card(get_card(CARD_PATHS.FOREST_FAE))
	CardCollection.add_card(get_card(CARD_PATHS.IMP))
	CardCollection.add_card(get_card(CARD_PATHS.LAVA_HARE))
	CardCollection.add_card(get_card(CARD_PATHS.NAGA))
	CardCollection.add_card(get_card(CARD_PATHS.FIREBALL))
	CardCollection.add_card(get_card(CARD_PATHS.LYZARD))
	CardCollection.add_card(get_card(CARD_PATHS.ERUPTION))
	CardCollection.add_card(get_card(CARD_PATHS.DRAKE_OF_EMERALD))
	CardCollection.add_card(get_card(CARD_PATHS.FLAME_FAE))
	CardCollection.add_card(get_card(CARD_PATHS.AXO_THE_KNIGHT))
	CardCollection.add_card(get_card(CARD_PATHS.FINN))
	CardCollection.add_card(get_card(CARD_PATHS.FALCREEP))
	CardCollection.add_card(get_card(CARD_PATHS.SNAPTRAP))
	CardCollection.add_card(get_card(CARD_PATHS.MOLTEN_PIG))
	CardCollection.add_card(get_card(CARD_PATHS.NINJOAD))
	CardCollection.add_card(get_card(CARD_PATHS.BOOGLES))
	CardCollection.add_card(get_card(CARD_PATHS.FUNGOO))
	CardCollection.add_card(get_card(CARD_PATHS.ORB_OF_DARKNESS))
	CardCollection.add_card(get_card(CARD_PATHS.SHADOW_CANDLES))
	CardCollection.add_card(get_card(CARD_PATHS.JESTER_OF_FLAMES))
	CardCollection.add_card(get_card(CARD_PATHS.VOIDLING_ERO))
	CardCollection.add_card(get_card(CARD_PATHS.MUSHMONK))
	CardCollection.add_card(get_card(CARD_PATHS.ZEI_PANDA))
	CardCollection.add_card(get_card(CARD_PATHS.YORG_ARCHER))
	CardCollection.add_card(get_card(CARD_PATHS.STONE_FAE))
	CardCollection.add_card(get_card(CARD_PATHS.CONFLAGURATION_BLADE))
	CardCollection.add_card(get_card(CARD_PATHS.TIDAL_WAVE))
	CardCollection.add_card(get_card(CARD_PATHS.AQUA_WHIP))

	_rng.randomize()
	# Ensure step player exists (optional safety)
	if step_player == null:
		step_player = AudioStreamPlayer3D.new()
		step_player.name = "StepPlayer"
		add_child(step_player)
		step_player.unit_size = 1.0
		step_player.attenuation_filter_cutoff_hz = 5000.0
		
	var mgr := get_tree().get_first_node_in_group("dialogue_manager")
	if mgr:
		# Use the finished signal from DialogueManager, not custom ones
		mgr.started.connect(_on_dialogue_started)
		mgr.finished.connect(_on_dialogue_finished)
		
	_lock_mouse()
	#_start_intro_dialogue()
	
func _on_dialogue_started(_id = null):
	# DialogueManager already disables movement
	_unlock_mouse()

func _on_dialogue_finished(_id = null):
	# DialogueManager already re-enables movement
	_lock_mouse()
	
func get_card(path: String) -> CardData:
	var card := load(path)
	if card == null:
		push_error("❌ Failed to load card at: " + path)
	return card

func _input(event):
	if event.is_action_pressed("interact"):
		var mgr = get_tree().get_first_node_in_group("dialogue_manager")
		if mgr and mgr._is_running:
			if mgr._ui and mgr._ui.visible:
				mgr._ui.on_player_pressed_continue()
			return


		# Only check NPCs if not already talking
		var space_state = get_world_3d().direct_space_state
		var from = cam.global_position
		var to = from + -cam.global_transform.basis.z * 3.0
		var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		if result and result.collider.is_in_group("npcs"):
			result.collider.on_interact()

	if Input.is_action_just_pressed("open_collection"):
		_toggle_collection()

func _unhandled_input(event: InputEvent) -> void:
	if collection_ui.visible:
		return

	if event is InputEventMouseMotion and mouse_locked:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		rotation_x = clamp(rotation_x, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = rotation_x

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if mouse_locked:
			_unlock_mouse()
		else:
			_lock_mouse()

func _physics_process(delta: float) -> void:
	if collection_ui.visible:
		return

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_downward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# --- FOOTSTEPS UPDATE ---
	_time_since_step += delta
	if is_on_floor():
		var horiz_speed := Vector2(velocity.x, velocity.z).length()
		var moved := horiz_speed * delta
		_step_dist_accum += moved

		# First step plays quickly after movement starts
		var threshold := STEP_DISTANCE
		if _time_since_step < STEP_MIN_GAP:
			threshold = STEP_DISTANCE + 999.0  # force wait

		if horiz_speed > 0.1 and _step_dist_accum >= threshold and _time_since_step >= STEP_MIN_GAP:
			_play_footstep()
			_step_dist_accum = 0.0
	else:
		_step_dist_accum = 0.0  # reset in air

func _play_footstep() -> void:
	_time_since_step = 0.0
	if _footstep_streams.is_empty():
		return
	step_player.stream = _footstep_streams[_rng.randi_range(0, _footstep_streams.size() - 1)]
	step_player.pitch_scale = _rng.randf_range(PITCH_RANGE.x, PITCH_RANGE.y)
	#step_player.volume_db = _rng.randf_range(VOLUME_DB_RANGE.x, VOLUME_DB_RANGE.y)
	step_player.play()
# ---------------------------------------

func _toggle_collection():

	if collection_ui.visible:
		collection_ui.hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_locked = true
		if not taskbar.visible:
			taskbar.visible = true
	else:
		collection_ui.show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_locked = false
		if taskbar.visible:
			taskbar.visible = false
func _lock_mouse():
	mouse_locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unlock_mouse():
	mouse_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
# Player.gd (add this helper anywhere in the script)
func _dl(speaker: String, text: String, expr := "neutral") -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker = speaker
	l.text = text
	l.expression = expr
	return l

#func _start_intro_dialogue():
	#var lines: Array[DialogueLine] = [
		#_dl("Player", "What the..."),
		#_dl("Player", "The air here feels heavy — and my head! Ugh..."),
		#_dl("Player", "I need to find out where I am...")
	#]
	#DialogueManager.start_dialogue(lines)  # ✅ now Array[DialogueLine]
