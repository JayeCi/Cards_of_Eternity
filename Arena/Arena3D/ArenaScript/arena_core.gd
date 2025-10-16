# File: arena_core.gd
extends Node3D
class_name ArenaCore

# -----------------------------
# PUBLIC SIGNALS
# -----------------------------
signal battle_finished(result: String)
signal essence_changed(player_essence: int, enemy_essence: int)
signal hp_changed(owner: int, hp: int)
signal phase_changed(new_phase: int)
signal log_line(text: String, color: Color)
signal focus_camera(world_pos: Vector3, zoom_mult: float, duration: float)
signal fade_ui(to_alpha: float, dur: float)

# -----------------------------
# CONSTANTS / ENUMS
# -----------------------------
const CARD_MODEL_SCALE := Vector3(0.75, 0.75, 0.75)
const BOARD_W := 7
const BOARD_H := 7
const PLAYER := 0
const ENEMY := 1
const MAX_HAND_SIZE := 5
const MAX_ENEMY_HAND_SIZE := 5
const BASE_MOVE_RANGE := 1
const CARD_BACK := preload("res://Images/CardBack1.png")
const CARD_MOVE_SOUND := preload("res://Audio/Sound FX/CardMove.mp3")
const TERRAIN_BONUS := {
	"Grass": {"Fire": 0.9, "Water": 1.1, "Earth": 1.1, "Wind": 1.0},
	"Forest": {"Fire": 0.8, "Earth": 1.2, "Water": 1.0, "Wind": 1.0},
	"Lava": {"Fire": 1.2, "Water": 0.7, "Earth": 1.0, "Wind": 1.0},
	"Water": {"Water": 1.2, "Fire": 0.7, "Earth": 1.0, "Wind": 1.0},
	"Stone": {"Earth": 1.1, "Wind": 0.9, "Fire": 1.0, "Water": 1.0},
	"Ice": {"Water": 1.1, "Wind": 0.9, "Fire": 0.8, "Earth": 1.0},
	"Meadow": {"Wind": 1.1, "Earth": 0.9, "Fire": 1.0, "Water": 1.0},
}

enum Phase { SUMMON_OR_MOVE, SELECT_SUMMON_TILE, SELECT_MOVE_TARGET, ENEMY_TURN }

# -----------------------------
# EXPORTED CAMERA TUNABLES
# -----------------------------
@export var camera_move_speed: float = 5.0
@export var camera_zoom_speed: float = 10.0
@export var min_zoom: float = 3.0
@export var max_zoom: float = 20.0

# -----------------------------
# NODES
# -----------------------------
@onready var board: Board3D = $Board3D

@onready var ui_root: Control = $UISystem
@onready var camera: Camera3D = $CameraSystem


# Subsystems:
@onready var camera_sys: Node = $CameraSystem
@onready var ui_sys: Node = $UISystem
@onready var battle_sys: Node = $BattleSystem
@onready var ai_sys: Node = $AISystem
@onready var cutscene_sys: Node = $CutsceneSystem

# UI children we still reference directly (for convenience)
@onready var card_draw: AudioStreamPlayer = $UISystem/SFX/CardDraw
@onready var card_details_ui: Control = $UISystem/ArenaCardDetails


# -----------------------------
# GAME DATA
# -----------------------------
var phase: int = Phase.SUMMON_OR_MOVE
var summon_mode := UnitData.Mode.ATTACK

# Decks & hands
var player_deck: Array = []
var player_hand: Array = []
var enemy_deck: Array = []
var enemy_hand: Array = []

# Essence
var player_essence: int = 1
var enemy_essence: int = 1
var essence_gain_per_turn: int = 1

# Leaders / Units
var player_leader: UnitData
var enemy_leader: UnitData

var units := {}  # Dictionary<Vector2i, UnitData>

# Input / selection
var selected_card: CardData = null
var selected_pos := Vector2i(-1,-1)
var dragging_card: CardData = null
var hovered_tile: Node3D = null

# Turn bookkeeping
var acted_this_turn := {} # {UnitData: true}

# Camera lock used by focus tweens/cutscenes
var _is_camera_locked := false
var is_cutscene_active: bool = false

# -----------------------------
# CARDS (preloads you used)
# -----------------------------
const DIRT = preload("res://Cards/Monster Cards/Dirt.tres")
const GOBLIN = preload("res://Cards/Monster Cards/Goblin.tres")
const IMP = preload("res://Cards/Monster Cards/Imp.tres")
const FYSH = preload("res://Cards/Monster Cards/Fish.tres")
const NAGA = preload("res://Cards/Monster Cards/Naga.tres")
const COLD_SLOTH = preload("res://Cards/Monster Cards/Cold_Sloth.tres")
const LAVA_HARE = preload("res://Cards/Monster Cards/Lava_Hare.tres")
const FOREST_FAE = preload("res://Cards/Monster Cards/Forest_Fae.tres")

const FIREBALL = preload("res://Cards/Spell Cards/Fireball.tres")
# -----------------------------
# LIFECYCLE
# -----------------------------
func _ready() -> void:
	# let UI initialize its references
	await get_tree().process_frame

	# minimal registry of cards (your collection)
	CardCollection.add_card(FIREBALL)
	CardCollection.add_card(GOBLIN)
	CardCollection.add_card(DIRT)
	CardCollection.add_card(IMP)
	CardCollection.add_card(FYSH)
	CardCollection.add_card(NAGA)
	CardCollection.add_card(FOREST_FAE)
	CardCollection.add_card(COLD_SLOTH)
	CardCollection.add_card(LAVA_HARE)

	# Pick a random biome
	var all_biomes = [
		board.Biome.OCEAN,
		board.Biome.VOLCANO,
		board.Biome.FOREST,
		board.Biome.MEADOW,
		board.Biome.MOUNTAIN,
		board.Biome.TUNDRA
	]

	# Use randf_range or randi for variety
	randomize()
	board.biome = all_biomes[randi() % all_biomes.size()]
	
	# Generate the map for that biome
	board._generate_grid()

	# Optional: friendly text for logging
	var biome_names = {
		board.Biome.OCEAN: "🌊 Ocean",
		board.Biome.VOLCANO: "🌋 Volcano",
		board.Biome.FOREST: "🌲 Forest",
		board.Biome.MEADOW: "🌾 Meadow",
		board.Biome.MOUNTAIN: "⛰️ Mountain",
		board.Biome.TUNDRA: "❄️ Tundra"
	}
	_log("🌍 Battlefield biome: " + biome_names.get(board.biome, str(board.biome)))

	# Build decks, spawn leaders, play intro
	_build_decks()

	_spawn_leaders()

	ui_sys.call("init_ui", self)              # hand, labels, hover/ghost setup
	camera_sys.call("init_camera", self)      # places camera top-down
	battle_sys.call("init_battle", self)      # links helpers/consts
	ai_sys.call("init_ai", self)
	cutscene_sys.call("init_cutscene", self)

	await cutscene_sys._intro()     # cinematic leader reveal
	
	emit_signal("essence_changed", player_essence, enemy_essence)
	ui_sys.call("refresh_hand", player_hand, player_essence)

	_draw_starting_hand(5)
	_set_phase(Phase.SUMMON_OR_MOVE)
	_update_phase_ui()
		
	if ui_sys.has_node("OrbGrid"):
		var essence_display = ui_sys.get_node("OrbGrid")
		connect("essence_changed", Callable(essence_display, "set_essence"))
		
func _apply_terrain_bonus(unit: UnitData, terrain: String) -> void:
	if not unit or not unit.card:
		return
	var element = unit.card.element
	if not TERRAIN_BONUS.has(terrain):
		return
	if not TERRAIN_BONUS[terrain].has(element):
		return

	var mult = TERRAIN_BONUS[terrain][element]
	if mult == 1.0:
		return

	var old_atk = unit.current_atk
	var old_def = unit.current_def
	unit.current_atk = int(unit.current_atk * mult)
	unit.current_def = int(unit.current_def * mult)

	var is_buff = mult > 1.0
	var color := Color(0.6, 1, 0.6) if is_buff else Color(1, 0.5, 0.5)

	_log("🌿 %s is affected by terrain (%s): ATK %d→%d DEF %d→%d" %
		[unit.card.name, terrain, old_atk, unit.current_atk, old_def, unit.current_def],
		color)

	# 🔔 Flash stat change if the card details are currently visible
	if card_details_ui and card_details_ui.visible:
		card_details_ui.call("flash_stat_change", is_buff)

	# ✅ Flash using UI system reference
	if ui_sys and ui_sys.has_node("ArenaCardDetails"):
		var details_ui = ui_sys.get_node("ArenaCardDetails")
		if details_ui.visible:
			details_ui.flash_stat_change(is_buff)
			
func _build_decks() -> void:
	# PLAYER
	player_deck.clear()
	var all_ids = CardCollection.get_all_cards()
	for id in all_ids:
		var count = CardCollection.get_card_count(id)
		var card_data = CardCollection.get_card_data(id)
		for i in range(count):            # ✅ fix loop
			player_deck.append(card_data.duplicate())
	player_deck.shuffle()

	# ENEMY (fallback)
	enemy_deck.clear()
	for id in ["IMP", "GOBLIN", "LAVA HARE", "FOREST FAE", "COLD SLOTH"]:
		if ResourceLoader.exists("res://Cards/Monster Cards/%s.tres" % id):
			var card = ResourceLoader.load("res://Cards/Monster Cards/%s.tres" % id)
			for i in range(10):           # ✅ fix loop
				enemy_deck.append(card.duplicate())
	enemy_deck.shuffle()

	_log("✅ Decks built: Player=%d, Enemy=%d" % [player_deck.size(), enemy_deck.size()])

func _spawn_leaders() -> void:
	player_leader = UnitData.new().init_from_card(LAVA_HARE, PLAYER)
	player_leader.is_leader = true
	player_leader.hp = 10

	enemy_leader = UnitData.new().init_from_card(DIRT, ENEMY)
	enemy_leader.is_leader = true
	enemy_leader.hp = 10

	_place_leader(player_leader, Vector2i(BOARD_W/2, 0))
	_place_leader(enemy_leader, Vector2i(BOARD_W/2, BOARD_H-1))

	# Hide both leaders visually until cutscene intro plays
	for leader in [player_leader, enemy_leader]:
		var tile = board.get_tile_position_for_unit(leader)
		if not tile:
			for pos in units.keys():
				if units[pos] == leader:
					tile = board.get_tile(pos.x, pos.y)
					break
		if tile and tile.has_node("CardMesh"):
			tile.get_node("CardMesh").visible = false
			
			
			# Hide 3D models until cutscene intro
	for leader in [player_leader, enemy_leader]:
		if leader.has_meta("leader_model"):
			leader.get_meta("leader_model").visible = false
		if leader.has_meta("leader_ring"):
			leader.get_meta("leader_ring").visible = false

func _place_leader(unit: UnitData, pos: Vector2i) -> void:
	units[pos] = unit
	var tile = board.get_tile(pos.x, pos.y)
	if not tile:
		push_error("⚠️ Could not find tile for leader placement at %s" % str(pos))
		return

	tile.set_occupant(unit)
	tile.set_art(unit.card.art)
	tile.set_badge_text("L")

	# ✅ Spawn leader's 3D model if available
	if unit.card and unit.card.model_scene:
		var model_instance = unit.card.model_scene.instantiate()
		model_instance.name = "CardModel"
		model_instance.position = Vector3(0, 0.1, 0)
		model_instance.scale = CARD_MODEL_SCALE

		# 🔹 Flip enemy model to face the player
		if unit.owner == self.ENEMY:
			model_instance.rotate_y(deg_to_rad(180))

		# Add to tile
		tile.add_child(model_instance)
		model_instance.scale = CARD_MODEL_SCALE
		print("Leader model scale after spawn:", model_instance.scale)


		# Start hidden until cutscene intro
		model_instance.visible = false

		# Store references for cutscene reveal
		unit.set_meta("leader_model", model_instance)
		
func damage_leader(target: int, amount: int) -> void:
	var leader: UnitData = player_leader if target == PLAYER else enemy_leader
	if leader == null:
		push_warning("No leader found for target %d" % target)
		return

	leader.hp = max(leader.hp - amount, 0)
	emit_signal("hp_changed", leader.owner, leader.hp)

	var who = "Your" if target == PLAYER else "Enemy"
	_log("%s Leader takes %d damage!" % [who, amount], Color(1, 0.5, 0.5))

	if ui_sys and ui_sys.has_method("update_leader_hp"):
		ui_sys.update_leader_hp(player_leader.hp, enemy_leader.hp)

func get_terrain_multiplier(unit: UnitData, terrain: String) -> float:
	if not unit or not unit.card:
		return 1.0
	if not TERRAIN_BONUS.has(terrain):
		return 1.0
	var element = unit.card.element
	if not TERRAIN_BONUS[terrain].has(element):
		return 1.0
	return TERRAIN_BONUS[terrain][element]
	
func clear_card_placement_mode() -> void:
	dragging_card = null
	selected_card = null
	selected_pos = Vector2i(-1, -1)
	battle_sys.call("clear_highlights")
	_set_phase(Phase.SUMMON_OR_MOVE)
	_update_phase_ui()
	ui_sys.call("fade_hand_in")
	ui_sys.call("hide_hover")

# -----------------------------
# DRAW / HAND / ESSENCE
# -----------------------------
func _draw_starting_hand(n: int) -> void:
	for i in range(n):                     # ✅ fix loop
		var card_ui: Control = _draw_card()
		if not card_ui:
			return
		await ui_sys.call("_animate_card_draw", card_ui)
		await get_tree().create_timer(0.15).timeout

func _draw_card() -> Control:
	if player_deck.is_empty(): return null
	var card: CardData = player_deck.pop_back()
	player_hand.append(card)
	ui_sys.call("refresh_hand", player_hand, player_essence)
	card_draw.play()
	return ui_sys.call("get_last_hand_card_ui")

func on_hand_card_clicked(card: CardData) -> void:
	# called from UISystem
	selected_card = card
	dragging_card = card
	_set_phase(Phase.SELECT_SUMMON_TILE)
	battle_sys.call("show_valid_summon_tiles")
	ui_sys.call("on_drag_start", card)

func try_place_dragged_card(hover_tile: Node3D) -> void:
	if not dragging_card or not selected_card:
		_log("⚠️ Tried to place a card, but none is selected.")
		ui_sys.call("cancel_drag")
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()
		return

	if not hover_tile or hover_tile.occupant != null:
		ui_sys.call("cancel_drag")
		battle_sys.call("clear_summon_highlights") # 🧹 clear when not placing
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()
		return


	var leader_pos: Vector2i = battle_sys.call("get_leader_pos", PLAYER)
	var tile_pos := Vector2i(hover_tile.x, hover_tile.y)

	var cost := 1
	if selected_card and "cost" in selected_card:
		cost = int(selected_card.cost)

	if player_essence < cost:
		_log("❌ Not enough Essence to summon %s (cost %d, have %d)" % [selected_card.name, cost, player_essence], Color(1,0.5,0.3))
		ui_sys.call("cancel_drag"); _set_phase(Phase.SUMMON_OR_MOVE); _update_phase_ui()
		return

	if tile_pos.distance_to(leader_pos) > 1:
		_log("⚠️ You can only summon next to your Leader!", Color(1,0.5,0.2))
		ui_sys.call("cancel_drag"); _set_phase(Phase.SUMMON_OR_MOVE); _update_phase_ui()
		return

	selected_pos = tile_pos
	ui_sys.call("open_summon_popup")  # shows ATTACK/DEFENSE/FACEDOWN options

func confirm_summon_in_mode(mode: int) -> void:
	# Defensive guard — make sure a card and position exist
	if selected_card == null or selected_pos == Vector2i(-1, -1):
		_log("⚠️ No card or tile selected to summon.", Color(1, 0.8, 0.3))
		ui_sys.call("cancel_drag")
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()
		return

	summon_mode = mode

	var cost := int(selected_card.cost) if "cost" in selected_card else 1
	if player_essence < cost:
		_log("❌ Not enough Essence to summon %s (Cost %d, you have %d)" %
			[selected_card.name, cost, player_essence], Color(1, 0.5, 0.3))
		ui_sys.call("cancel_drag")
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()
		return

	# Deduct cost and place card
	player_essence -= cost
	emit_signal("essence_changed", player_essence, enemy_essence)
	
	player_hand.erase(selected_card)
	battle_sys.call("place_unit", selected_card, selected_pos, PLAYER, summon_mode, true)


	# Clean up
	ui_sys.call("cancel_drag")  # ✅ hides ghost + shows hand again
	player_hand.erase(selected_card)
	selected_card = null
	selected_pos = Vector2i(-1, -1)
	ui_sys.call("refresh_hand", player_hand, player_essence)
	battle_sys.call("clear_highlights")
	_set_phase(Phase.SUMMON_OR_MOVE)
	_update_phase_ui()
	
# -----------------------------
# TURN FLOW
# -----------------------------
func _on_end_turn_button_pressed() -> void:
	if phase != Phase.SUMMON_OR_MOVE: return
	_log("📜 Player ends their turn.")
	_set_phase(Phase.ENEMY_TURN)
	ui_sys.call("fade_hand_out")

	await ai_sys.call("run_enemy_turn")
	_log("🔁 Enemy turn finished.")
	_start_player_turn()

func _start_player_turn() -> void:
	print("🕐 _start_player_turn() called at:", Time.get_ticks_msec())

	_reset_action_flags()
	ui_sys.call("show_battle_message", "Your Turn!", 1.5)
	_draw_up_to_hand_limit()
	_set_phase(Phase.SUMMON_OR_MOVE)
	player_essence += essence_gain_per_turn
	emit_signal("essence_changed", player_essence, enemy_essence)
	battle_sys.apply_all_passives()
	ui_sys.call("fade_hand_in")

	# ✅ clear any leftover card drag state
	dragging_card = null
	selected_card = null
	selected_pos = Vector2i(-1, -1)

	print("Player essence now:", player_essence)
	battle_sys.core = self
	ui_sys.call("refresh_hand", player_hand, player_essence)
	get_viewport().gui_release_focus()


func _draw_up_to_hand_limit() -> void:
	while player_hand.size() < MAX_HAND_SIZE and not player_deck.is_empty():
		var ui_card = _draw_card()
		if not ui_card: break
		await ui_sys.call("_animate_card_draw", ui_card)
		await get_tree().create_timer(0.15).timeout

func _reset_action_flags() -> void:
	acted_this_turn.clear()
	battle_sys.call("clear_exhausted_tiles")

# -----------------------------
# PHASE / LOG / HP
# -----------------------------
func _set_phase(p: int) -> void:
	phase = p
	emit_signal("phase_changed", phase)

func _update_phase_ui() -> void:
	ui_sys.call("update_phase_label", phase)

#func _log(text: String, color: Color = Color.WHITE) -> void:
	#emit_signal("log_line", text, color)

func on_leader_damaged(owner: int, new_hp: int) -> void:
	emit_signal("hp_changed", owner, new_hp)

func on_leader_defeated(owner: int) -> void:
	if owner == PLAYER:
		_log("💀 Your Leader has fallen!", Color(1,0.3,0.3))
		ui_sys.call("show_battle_message", "Your Leader has fallen! You lose!", 3.0)
		emit_signal("battle_finished", "player_lost")
	else:
		_log("🏆 Enemy Leader defeated! You win!", Color(0.3,1,0.3))
		ui_sys.call("show_battle_message", "Enemy Leader defeated! You win!", 3.0)
		emit_signal("battle_finished", "player_won")

# -----------------------------
# INPUT HUB (delegates to systems)
# -----------------------------
func _unhandled_input(event: InputEvent) -> void:
	
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if dragging_card:
				try_place_dragged_card(hovered_tile)
			else:
				battle_sys.call("on_board_click", event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected_card = null
			ui_sys.hide_hover()
			selected_pos = Vector2i(-1,-1)
			dragging_card = null
			battle_sys.call("clear_highlights")
			_set_phase(Phase.SUMMON_OR_MOVE)
			_update_phase_ui()
			ui_sys.call("cancel_drag")  # 🧹 FIX — reset ArenaUI drag state & hide details

	if event is InputEventKey and event.keycode == KEY_SHIFT:
		camera_sys.call_deferred("toggle_freelook", event.pressed)

	if camera_sys and camera_sys.has_method("forward_mouse_motion"):
		if camera_sys.get("is_freelook") and event is InputEventMouseMotion:
			camera_sys.call("forward_mouse_motion", event.relative)

# -----------------------------
# HELPERS exposed for systems
# -----------------------------
func get_leader_pos(owner: int) -> Vector2i:
	return battle_sys.call("get_leader_pos", owner)

func can_unit_act(u: UnitData) -> bool:
	return not acted_this_turn.has(u)

func mark_unit_acted(u: UnitData) -> void:
	acted_this_turn[u] = true
	battle_sys.call("set_exhausted_for_unit", u, true)

# -----------------------------
# CARD ABILITY EXECUTION HELPER
# -----------------------------
func _execute_card_ability(unit: UnitData, ability: CardAbility) -> void:
	if ability == null:
		_log("⚠️ Tried to execute null ability on %s" % unit.card.name)
		return

	if not ability.has_method("execute"):
		_log("⚠️ Ability %s has no execute() method!" % ability.display_name)
		return

	# Try to safely run the ability's effect
	_log("✨ Activating ability: %s (Trigger: %s)" % [ability.display_name, ability.trigger], Color(0.7, 1.0, 0.9))
	ability.execute(self, unit)

# -----------------------------
# LOGGING SYSTEM
# -----------------------------
func log_message(message: String, color: Color = Color.WHITE) -> void:
	# If your UI system has a log or console text area, send it there
	if has_node("UISystem/LogPanel/LogLabel"):
		var label: Label = get_node("UISystem/LogPanel/LogLabel")
		label.text += "[color=#%s]%s[/color]\n" % [color.to_html(false), message]
	elif has_node("UISystem/LogBox"):
		# Alternate location
		var log_box: RichTextLabel = get_node("UISystem/LogBox")
		log_box.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), message])
	else:
		# Fallback to console
		print(message)

# Optional alias to match older scripts
func _log(message: String, color: Color = Color.WHITE) -> void:
	# Always print to console for debugging
	print(message)
	# Send to ArenaUI via signal
	emit_signal("log_line", message, color)

func get_terrain_for_unit(unit: UnitData) -> String:
	for pos in board.tiles.keys():
		var tile = board.tiles[pos]
		if tile and tile.occupant == unit:
			return tile.terrain_type
	return ""
