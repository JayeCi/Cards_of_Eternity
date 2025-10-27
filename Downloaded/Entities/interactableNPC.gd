extends Node3D
class_name InteractableNPC

# ======================================================================
# 🧍‍♂️ INTERACTABLE NPC
# Handles player interaction, multi-page dialogue, conditional branching,
# and event triggers such as enabling Areas or giving card rewards.
# ======================================================================

# -------------------------------------------------
# 🔹 Signals
# -------------------------------------------------
signal dialogue_started(npc: InteractableNPC)
signal dialogue_finished(npc: InteractableNPC)
signal reward_granted(cards: Array) # Array[CardData]

# -------------------------------------------------
# 🔹 Exports (Tunable per NPC)
# -------------------------------------------------
@export var npc_name := "Cashier"
@export var interact_action := &"interact"
@export var portraits: DialoguePortraits
@export var loop_last_page := true

# Reference to the card pickup area (Area3D node with signal `card_picked_up`)
@export var cards_on_counter: Area3D

# Dialogue and logic control
@export var dialogue_script: DialogueScript
@export var current_page_index := 0  # Which dialogue page we’re currently on
@export var rewards_by_page: Dictionary = {}  # Optional rewards keyed by page index

# Node references
@export var reward_receiver_path: NodePath
@export var prompt_path: NodePath
@export var player_group := "player"

# -------------------------------------------------
# 🔹 Internal References
# -------------------------------------------------
@onready var _area: Area3D = $InteractArea
@onready var _prompt: Node = get_node_or_null(prompt_path)
@onready var _receiver: Node = get_node_or_null(reward_receiver_path)

var _player: Node3D
var _busy := false

# -------------------------------------------------
# 🔹 State Flags
# -------------------------------------------------
var has_seen_page_1 := false
var has_seen_page_2 := false
var cards_picked_up := false

# ======================================================================
# 🏁 READY
# ======================================================================
func _ready() -> void:
	# --- Setup player detection triggers ---
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

	# --- Connect to the cards_on_counter signal if present ---
	if cards_on_counter and cards_on_counter.has_signal("card_picked_up"):
		cards_on_counter.card_picked_up.connect(_on_card_picked_up)
		print("[NPC] Connected to card_picked_up signal from:", cards_on_counter.name)
	else:
		push_warning("[NPC] ⚠️ CardsOnCounter missing or not set up properly!")

	# --- Hide prompt initially ---
	if _prompt:
		_prompt.visible = false

	print("[NPC] Ready:", npc_name, "| Starting page index:", current_page_index)


# ======================================================================
# 🕹️ PLAYER INTERACTION
# ======================================================================
func _process(_dt: float) -> void:
	# Only allow conversation start when not busy
	if _player and not _busy and Input.is_action_just_pressed(interact_action):
		_start_conversation()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group(player_group):
		_player = body
		print("[NPC] Player entered interaction range:", _player)
		if _prompt:
			_prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if body == _player:
		print("[NPC] Player left interaction range.")
		_player = null
		if _prompt:
			_prompt.visible = false


func on_interact(by: Node = null) -> void:
	# Manual trigger (for scripted events)
	if by and by.is_in_group(player_group):
		_player = by
	if not _busy:
		print("[NPC] Interaction triggered manually.")
		_start_conversation()


# ======================================================================
# 💬 DIALOGUE FLOW
# ======================================================================
func _start_conversation() -> void:
	if _busy or dialogue_script == null:
		return

	var page := dialogue_script.get_page(current_page_index)
	if not page:
		push_error("[NPC] DialogueScript missing page index %s" % current_page_index)
		return

	_busy = true
	if _prompt:
		_prompt.visible = false

	_start_page(page)


func _start_page(page: DialoguePage) -> void:
	if not page:
		return

	# --- Apply default speaker/portrait values ---
	for line in page.lines:
		if line.text == "":
			continue
		if page.speaker == "":
			line.speaker = page.speaker
		if line.portrait_key == "":
			line.portrait_key = page.portrait_key

	# --- Set portraits for this NPC ---
	if portraits and DialogueManager._ui and "portraits" in DialogueManager._ui:
		DialogueManager._ui.portraits = portraits

	# --- Connect to DialogueManager events (one-time per conversation) ---
	DialogueManager.started.connect(_on_dialogue_started, CONNECT_ONE_SHOT)
	DialogueManager.finished.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)
	DialogueManager.advanced.connect(_on_dialogue_advanced, CONNECT_ONE_SHOT)

	# --- Begin dialogue ---
	DialogueManager.start_convo(page.lines, npc_name, page)


# ======================================================================
# 📜 DIALOGUE CALLBACKS
# ======================================================================
func _on_dialogue_started(convo_id) -> void:
	print("[NPC] Dialogue started:", npc_name)
	emit_signal("dialogue_started", self)


func _on_dialogue_advanced(index: int) -> void:
	if not DialogueManager._is_running:
		return
	_grant_rewards_for_page(index)


func _on_dialogue_finished(convo_id) -> void:
	print("[NPC] Dialogue finished for:", npc_name)
	emit_signal("dialogue_finished", self)

	match current_page_index:

		# ---------------------------------------------------------
		# 🟦 PAGE 1 COMPLETE
		# ---------------------------------------------------------
		0:
			has_seen_page_1 = true

			# Branch: If player already picked up cards, skip to Page 3
			if cards_picked_up:
				current_page_index = 3
				print("[NPC] Player already has cards — skipping to Page 3 next time.")
			else:
				current_page_index = 1
				print("[NPC] Player has NOT picked up cards — Page 2 will play next.")

			_end_and_reset()
			return

		# ---------------------------------------------------------
		# 🟩 PAGE 2 COMPLETE — Enable counter for card pickup
		# ---------------------------------------------------------
		1:
			has_seen_page_2 = true
			print("[NPC] Page 2 complete — enabling CardsOnCounter for pickup...")

			var counter := cards_on_counter
			if counter:
				await get_tree().process_frame
				counter.set_deferred("monitoring", true)
				counter.set_deferred("monitorable", true)
				counter.set_deferred("visible", true)
				print("[NPC] 🟩 Counter Area3D activated.")

				if not counter.is_connected("card_picked_up", Callable(self, "_on_card_picked_up")):
					counter.card_picked_up.connect(_on_card_picked_up)
					print("[NPC] Connected card_picked_up signal from:", counter.name)

			# Next page logic: if pickup happens later, _on_card_picked_up() will jump to page 3
			current_page_index = 2
			_end_and_reset()
			return

		# ---------------------------------------------------------
		# 🟧 PAGE 3 OR LATER — Post-pickup dialogue
		# ---------------------------------------------------------
		_:
			print("[NPC] All dialogue pages completed or in post-pickup state.")
			_end_and_reset()
			return


# ======================================================================
# 🎁 CARD PICKUP CALLBACK
# ======================================================================
func _on_card_picked_up(cards: Array) -> void:
	cards_picked_up = true
	current_page_index = 3  # Advance NPC dialogue to next logical page
	print("[NPC] Cards picked up — next time Page 3 will play.")

	_busy = false
	if _prompt:
		_prompt.visible = true


# ======================================================================
# 🧩 UTILITY FUNCTIONS
# ======================================================================
func _end_and_reset() -> void:
	_busy = false
	if _prompt:
		_prompt.visible = true
	_end_convo()


func _end_convo() -> void:
	if _player and _prompt:
		_prompt.visible = true
	# ⚠️ Do not reset _busy here, caller manages it


func _get_dialogue_manager() -> Node:
	return DialogueManager


func _grant_rewards_for_page(idx: int) -> void:
	if not rewards_by_page.has(idx):
		return
	var cards: Array = rewards_by_page[idx]
	if cards.is_empty():
		return

	emit_signal("reward_granted", cards.duplicate())

	if _receiver:
		for c in cards:
			if _receiver.has_method("add_card"):
				_receiver.call_deferred("add_card", c)
