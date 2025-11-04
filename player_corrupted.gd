extends CharacterBody3D

const SPEED = 5.0
const SPRINT_MULTIPLIER = 1.7  
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.003
# --- Sprinting ---
var is_sprinting := false
var sprint_speed := SPEED * SPRINT_MULTIPLIER

signal starter_deck_chosen(element_type)

# --- FOOTSTEPS ---
const STEP_DISTANCE := 2.0            # meters per step
const STEP_MIN_GAP := 0.15            # seconds, avoids machine-gun on stalls
const VOLUME_DB_RANGE := Vector2(-23.0, -21.0)
const PITCH_RANGE := Vector2(0.92, 1.08)


var _footstep_streams: Array[AudioStream] = [
	preload("res://Audio/footstep1.mp3"),
	preload("res://Audio/footstep2.mp3"),
	preload("res://Audio/footstep3.mp3"),
]
var _rng := RandomNumberGenerator.new()
var _step_dist_accum := 0.0
var _time_since_step := 0.0
var hovered_deck: Node3D = null

@onready var crosshair: Label = $Crosshair/Label


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
@onready var ray_cast_3d: RayCast3D = $Head/RayCast3D
@onready var step_player: AudioStreamPlayer3D = $StepPlayer

var rotation_x = 0.0
var mouse_locked = true
var current_interactable: Node3D = null
var deck_claimed := {
	"Fire": false,
	"Water": false,
	"Earth": false,
	"Wind": false,
}


func _ready() -> void:
	
	if Engine.has_singleton("DialogueManager"):
		DialogueManager._ui = $DialogueUI
		print("[World] Registered DialogueUI manually")
		
	#CardCollection.add_card(get_card(CARD_PATHS.GOBLIN))
	#CardCollection.add_card(get_card(CARD_PATHS.DIRT))
	#CardCollection.add_card(get_card(CARD_PATHS.COLD_SLOTH))
	#CardCollection.add_card(get_card(CARD_PATHS.FYSH))
	#CardCollection.add_card(get_card(CARD_PATHS.FOREST_FAE))
	#CardCollection.add_card(get_card(CARD_PATHS.IMP))
	#CardCollection.add_card(get_card(CARD_PATHS.LAVA_HARE))
	#CardCollection.add_card(get_card(CARD_PATHS.NAGA))
	#CardCollection.add_card(get_card(CARD_PATHS.FIREBALL))
	#CardCollection.add_card(get_card(CARD_PATHS.LYZARD))
	#CardCollection.add_card(get_card(CARD_PATHS.ERUPTION))
	#CardCollection.add_card(get_card(CARD_PATHS.DRAKE_OF_EMERALD))
	#CardCollection.add_card(get_card(CARD_PATHS.FLAME_FAE))
	#CardCollection.add_card(get_card(CARD_PATHS.AXO_THE_KNIGHT))
	#CardCollection.add_card(get_card(CARD_PATHS.FINN))
	#CardCollection.add_card(get_card(CARD_PATHS.FALCREEP))
	#CardCollection.add_card(get_card(CARD_PATHS.SNAPTRAP))
	#CardCollection.add_card(get_card(CARD_PATHS.MOLTEN_PIG))
	#CardCollection.add_card(get_card(CARD_PATHS.NINJOAD))
	#CardCollection.add_card(get_card(CARD_PATHS.BOOGLES))
	#CardCollection.add_card(get_card(CARD_PATHS.FUNGOO))
	#CardCollection.add_card(get_card(CARD_PATHS.ORB_OF_DARKNESS))
	#CardCollection.add_card(get_card(CARD_PATHS.SHADOW_CANDLES))
	#CardCollection.add_card(get_card(CARD_PATHS.JESTER_OF_FLAMES))
	#CardCollection.add_card(get_card(CARD_PATHS.VOIDLING_ERO))
	#CardCollection.add_card(get_card(CARD_PATHS.MUSHMONK))
	#CardCollection.add_card(get_card(CARD_PATHS.ZEI_PANDA))
	#CardCollection.add_card(get_card(CARD_PATHS.YORG_ARCHER))
	#CardCollection.add_card(get_card(CARD_PATHS.STONE_FAE))
	#CardCollection.add_card(get_card(CARD_PATHS.CONFLAGURATION_BLADE))
	#CardCollection.add_card(get_card(CARD_PATHS.TIDAL_WAVE))
	#CardCollection.add_card(get_card(CARD_PATHS.AQUA_WHIP))

	_rng.randomize()
	# Ensure step player exists (optional safety)
	if step_player == null:
		step_player = AudioStreamPlayer3D.new()
		step_player.name = "StepPlayer"
		add_child(step_player)
		step_player.unit_size = 1.0
		step_player.attenuation_filter_cutoff_hz = 5000.0
		
	InputState.register_player(self)
	starter_deck_chosen.connect(_on_deck_chosen)

func get_card(path: String) -> CardData:
	var card := load(path)
	if card == null:
		push_error("❌ Failed to load card at: " + path)
	return card

func _input(event):
	if event.is_action_pressed("interact") and current_interactable:
		if current_interactable is ElementDeck:
			_handle_element_deck(current_interactable.element_type)
	# Sprint toggle
	if event.is_action_pressed("sprint"):
		is_sprinting = true
	elif event.is_action_released("sprint"):
		is_sprinting = false

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

func _handle_element_deck(element_type: String):
	var starter: Array = []

	match element_type:
		"Fire":
			starter = [
				get_card(CARD_PATHS.LAVA_HARE),
				get_card(CARD_PATHS.FLAME_FAE),
				get_card(CARD_PATHS.FIREBALL),
				get_card(CARD_PATHS.JESTER_OF_FLAMES),
				get_card(CARD_PATHS.ERUPTION),
			]

		"Water":
			starter = [
				get_card(CARD_PATHS.FYSH),
				get_card(CARD_PATHS.LYZARD),
				get_card(CARD_PATHS.TIDAL_WAVE),
				get_card(CARD_PATHS.AQUA_WHIP),
				get_card(CARD_PATHS.MUSHMONK),
			]

		"Earth":
			starter = [
				get_card(CARD_PATHS.DIRT),
				get_card(CARD_PATHS.COLD_SLOTH),
				get_card(CARD_PATHS.STONE_FAE),
				get_card(CARD_PATHS.SNAPTRAP),
				get_card(CARD_PATHS.DRAKE_OF_EMERALD),
			]

		"Wind":
			starter = [
				get_card(CARD_PATHS.ZEI_PANDA),
				get_card(CARD_PATHS.FALCREEP),
				get_card(CARD_PATHS.YORG_ARCHER),
				# add real wind cards later
			]

	# already claimed?
	if deck_claimed[element_type]:
		show_pickup_popup("You've already claimed this starter deck.")
		return

	deck_claimed[element_type] = true

	# Add them to the player's collection
	for c in starter:
		CardCollection.add_card(c)

	show_pickup_popup(element_type + " Starter Deck Obtained!")
	# After showing popup and adding cards
	current_interactable.queue_free()
	current_interactable = null
	hovered_deck = null
	emit_signal("starter_deck_chosen", element_type)


var _saved_yaw := 0.0
var _saved_pitch := 0.0

func save_camera_rotation():
	_saved_yaw = rotation.y
	_saved_pitch = head.rotation.x

func restore_camera_rotation(duration: float = 1.3):
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "rotation:y", _saved_yaw, duration)
	tween.parallel().tween_property(head, "rotation:x", _saved_pitch, duration)
	return tween


func look_toward_point(point: Vector3, duration: float = 1.3) -> Tween:
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	# --- YAW (body) ---
	var flat = point - global_position
	flat.y = 0.0
	if flat.length() > 0.001:
		var yaw = atan2(flat.x, flat.z)
		tween.tween_property(self, "rotation:y", yaw, duration)

	# --- PITCH (camera) ---
	var dir = (point - cam.global_position).normalized()
	var pitch = asin(dir.y)
	pitch = clamp(pitch, deg_to_rad(-60), deg_to_rad(60))
	tween.parallel().tween_property(head, "rotation:x", -pitch, duration)

	return tween

func show_pickup_popup(text: String):
	# You can replace this later with real UI
	print(text)

func _unhandled_input(event: InputEvent) -> void:
	if collection_ui.visible:
		return
	if InputState.mode != InputState.Mode.FREE:
		return



	if event is InputEventMouseMotion and mouse_locked:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		rotation_x = clamp(rotation_x, deg_to_rad(-89), deg_to_rad(89))
		head.rotation.x = rotation_x


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
	
	var current_speed = SPEED
	if is_sprinting:
		current_speed = sprint_speed

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

		# --- HOVER HIGHLIGHT USING RAYCAST3D ---
	ray_cast_3d.force_raycast_update()

	if not ray_cast_3d.is_colliding():
		if hovered_deck:
			hovered_deck.hide_label()
			hovered_deck = null
		current_interactable = null      # ✅ reset
		_crosshair_hover_off()
		return


	var hit = ray_cast_3d.get_collider()
	var root = hit

	# climb upward until we find something interactable
	while root and not root.is_in_group("interactable"):
		root = root.get_parent()

	# if nothing found
	if not root:
		if hovered_deck:
			hovered_deck.hide_label()
			hovered_deck = null
		return

	# FOUND interactable!
	if hovered_deck != root:
		if hovered_deck:
			hovered_deck.hide_label()

		root.show_label()
		hovered_deck = root
		current_interactable = root     # ✅ NOW HERE
		_crosshair_hover_on()

func face_target(target: Node3D):
	var p := target.global_position
	p.y = global_position.y # keep head level
	look_at(p, Vector3.UP)
	rotation_x = 0.0
	head.rotation.x = 0.0


func _crosshair_hover_on():
	crosshair.modulate = Color(1, 1, 1, 1) # white / full alpha

func _crosshair_hover_off():
	crosshair.modulate = Color("363636b3") # dim

func _on_deck_chosen(chosen_type: String):
	# get all elemental deck nodes
	var all_decks = get_tree().get_nodes_in_group("element_deck")
	for deck in all_decks:
		if deck.element_type != chosen_type:
			deck.queue_free()


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
		InputState.set_mode(InputState.Mode.FREE)
		taskbar.visible = true
	else:
		collection_ui.show()
		InputState.set_mode(InputState.Mode.UI)
		taskbar.visible = false


# Player.gd (add this helper anywhere in the script)
func _dl(speaker: String, text: String, expr := "neutral") -> DialogueLine:
	var l := DialogueLine.new()
	l.speaker = speaker
	l.text = text
	l.expression = expr
	return l

func _on_tutorial_portal_entered(body):
	if body != self:
		return
	
	# 🚫 Already completed tutorial?
	if Globals.tutorial_completed:
		return

	# 🚫 Not the stage where tutorial battle should start?
	if Globals.tutorial_stage < 2:
		DialogueManager.start_convo([
			_dl("Guide", "You're not ready. You need to add your cards to your deck."),
		])
		InputState.set_mode(InputState.Mode.CUTSCENE)
		return

	# ✅ Correct stage, so launch battle
	var guide = get_tree().get_first_node_in_group("guide")
	if guide:
		guide.start_tutorial_battle_dialogue(self)
