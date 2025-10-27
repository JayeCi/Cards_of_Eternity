extends Node3D
class_name InteractableNPC

signal dialogue_started(npc: InteractableNPC)
signal dialogue_finished(npc: InteractableNPC)
signal reward_granted(cards: Array)  # Array[CardData]

@export var npc_name := "Cashier"
@export var interact_action := &"interact"
@export var portraits: DialoguePortraits
@export var loop_last_page := true
@onready var cards_on_counter: Node3D = get_node_or_null("/root/Gas_Station_Store/CardsOnCounter")


var has_seen_page_1 := false
var has_seen_page_2 := false
var cards_picked_up := false

@export var dialogue_script: DialogueScript
@export var current_page_index := 0


# Rewards per page index (0-based) -> Array[CardData]
@export var rewards_by_page: Dictionary = {}

@export var reward_receiver_path: NodePath
@export var prompt_path: NodePath
@export var player_group := "player"

@onready var _area: Area3D = $InteractArea
@onready var _prompt: Node = get_node_or_null(prompt_path)
@onready var _receiver: Node = get_node_or_null(reward_receiver_path)

var _player: Node3D
var _busy := false

func _ready() -> void:
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	var counter := cards_on_counter
	if counter and counter.has_signal("card_picked_up"):
		counter.card_picked_up.connect(_on_card_picked_up)
		
	if _prompt: _prompt.visible = false


func _process(_dt: float) -> void:
	if _player and not _busy and Input.is_action_just_pressed(interact_action):
		_start_conversation()

func _on_body_entered(body: Node) -> void:
	if body is Node3D and body.is_in_group(player_group):
		_player = body
		print("Player found: ", _player)
		if _prompt: _prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body == _player:
		_player = null
		if _prompt: _prompt.visible = false
		
func _on_card_picked_up(cards: Array) -> void:
	print("[NPC] Card pickup signal received by:", self.get_path())
	print("[NPC] current_page_index before:", current_page_index)
	current_page_index = 2
	print("[NPC] current_page_index after:", current_page_index)

	print("[NPC] Cards picked up! Page 3 now available.")
	cards_picked_up = true

	_busy = false
	if _prompt:
		_prompt.visible = true

func on_interact(by: Node = null) -> void:
	if by and by is Node3D and by.is_in_group("player"):
		_player = by
	if not _busy:
		print("starting convo")
		_start_conversation()
		
func next_page():
	if dialogue_script and current_page_index < dialogue_script.pages.size() - 1:
		current_page_index += 1
		
func _start_page(page: DialoguePage) -> void:
	if not page:
		return

	# Apply page defaults (speaker/portrait) to its lines
	for line in page.lines:
		if line.text == "": continue
		if page.speaker == "": line.speaker = page.speaker
		if line.portrait_key == "": line.portrait_key = page.portrait_key

	if portraits and DialogueManager._ui and "portraits" in DialogueManager._ui:
		DialogueManager._ui.portraits = portraits

	DialogueManager.started.connect(_on_dialogue_started, CONNECT_ONE_SHOT)
	DialogueManager.finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	DialogueManager.advanced.connect(_on_dialogue_advanced, CONNECT_ONE_SHOT)

	DialogueManager.start_convo(page.lines, npc_name, page)

func _start_conversation() -> void:
	if _busy or dialogue_script == null:
		return

	var page := dialogue_script.get_page(current_page_index)
	if not page:
		push_error("DialogueScript missing page index %s" % current_page_index)
		return

	_busy = true
	if _prompt:
		_prompt.visible = false

	_start_page(page)

func _on_dialogue_started(convo_id) -> void:
	emit_signal("dialogue_started", self)

func _on_dialogue_advanced(index: int) -> void:
	# ✅ Don't do anything if dialogue has already been closed
	if not DialogueManager._is_running:
		return

	_grant_rewards_for_page(index)

	## 🟩 Optional looping feature only if dialogue fully finished last line
	#if loop_last_page and index == lines.size() - 1 and DialogueManager._is_running == false:
		#_end_convo()
		#_start_conversation()

func _on_dialogue_finished(convo_id) -> void:
	emit_signal("dialogue_finished", self)

	# --- Page 1 complete ---
	if current_page_index == 0:
		has_seen_page_1 = true
		current_page_index = 1
		print("[NPC] Page 1 finished. Next time, Page 2 will play.")
		_busy = false                # ✅ allow player to talk again
		if _prompt:
			_prompt.visible = true   # show “Press E” again
		_end_convo()
		return

	# --- Page 2 complete ---
	if current_page_index == 1:
		has_seen_page_2 = true
		print("[NPC] ✅ Page 2 finished — enabling CardsOnCounter Area3D...")

		var counter := cards_on_counter
		if counter:
			var area: Area3D = counter.get_node_or_null("Area3D")
			if area:
				area.monitoring = true
				area.monitorable = true
				area.set_deferred("visible", true)
				print("[NPC] 🟩 Counter area enabled!")
			else:
				push_warning("[NPC] ❌ CardsOnCounter has no Area3D node.")

		if counter and counter.has_signal("card_picked_up"):
			print("[NPC] Found counter with signal:", counter.name)
			counter.card_picked_up.connect(func(cards): print("[NPC] got pickup signal"), CONNECT_ONE_SHOT)
			await counter.card_picked_up
			cards_picked_up = true
			current_page_index = 2
			print("[NPC] Cards picked up! Page 3 now available.")

		_busy = false                # ✅ unlock talking again
		if _prompt:
			_prompt.visible = true
		_end_convo()
		return

	# --- Page 3 or later ---
	if current_page_index >= 2:
		print("[NPC] All dialogue pages completed.")
		_busy = false
		if _prompt:
			_prompt.visible = true
		_end_convo()


func _end_convo() -> void:
	if _player and _prompt:
		_prompt.visible = true
	# ⚠️ don't set _busy here; let callers control it


func _get_dialogue_manager() -> Node:
	return DialogueManager

func _grant_rewards_for_page(idx: int) -> void:
	if not rewards_by_page.has(idx): return
	var cards: Array = rewards_by_page[idx]
	if cards.is_empty(): return
	emit_signal("reward_granted", cards.duplicate())
	if _receiver:
		for c in cards:
			if _receiver.has_method("add_card"):
				_receiver.call_deferred("add_card", c)
