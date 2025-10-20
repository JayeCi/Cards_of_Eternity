extends Node3D
class_name ArenaCore

# ==========================================================
# 🧩 FAST LAZY CARD LOADER
# ==========================================================
var _card_cache: Dictionary = {}

func get_card(path: String) -> Resource:
	if not _card_cache.has(path):
		_card_cache[path] = load(path)
	return _card_cache[path]


# ==========================================================
# 🔧 EXAMPLE USAGE:
#   instead of:   GOBLIN
#   use:          get_card(CARD_PATHS.GOBLIN)
# ==========================================================
const CARD_PATHS := {
	"DIRT":        "res://Cards/Monster Cards/Dirt.tres",
	"GOBLIN":      "res://Cards/Monster Cards/Goblin.tres",
	"IMP":         "res://Cards/Monster Cards/Imp.tres",
	"FYSH":        "res://Cards/Monster Cards/Fish.tres",
	"NAGA":        "res://Cards/Monster Cards/Naga.tres",
	"COLD_SLOTH":  "res://Cards/Monster Cards/Cold_Sloth.tres",
	"LAVA_HARE":   "res://Cards/Monster Cards/Lava_Hare.tres",
	"FOREST_FAE":  "res://Cards/Monster Cards/Forest_Fae.tres",
	"FIREBALL":    "res://Cards/Spell Cards/Fireball.tres",
	"LYZARD":      "res://Cards/Monster Cards/Lyzard.tres",
	"ERUPTION":    "res://Cards/Spell Cards/Eruption.tres",
}

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
signal unit_stats_changed(unit: UnitData)

# -----------------------------
# CONSTANTS / ENUMS
# -----------------------------
const HEAL_SOUND := preload("res://Audio/Sound FX/heal.mp3")
const LEADER_IN_SOUND := preload("res://Audio/Sound FX/leaderslide.mp3")
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
var _cache := {}
# Turn bookkeeping
var acted_this_turn := {} # {UnitData: true}

# Camera lock used by focus tweens/cutscenes
var _is_camera_locked := false
var is_cutscene_active: bool = false
	# Pick a random biome
var all_biomes = [
	board.Biome.OCEAN,
	board.Biome.VOLCANO,
	board.Biome.FOREST,
	board.Biome.MEADOW,
	board.Biome.MOUNTAIN,
	board.Biome.TUNDRA
]


# -----------------------------
# LIFECYCLE
# -----------------------------
func _ready() -> void:
	# let UI initialize its references
	await get_tree().process_frame
	call_deferred("_deferred_startup")
	# minimal registry of cards (your collection)

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
	
	if ui_sys.has_node("OrbGrid"):
		var essence_display = ui_sys.get_node("OrbGrid")
		connect("essence_changed", Callable(essence_display, "set_essence"))
		
func _deferred_startup():
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
	
func refresh_tile_art_safe(pos: Vector2i):
	if not units.has(pos): return
	var u: UnitData = units[pos]
	var t = board.get_tile(pos.x, pos.y)
	if not t: return
	if u.is_facedown:
		t.set_art(CARD_BACK)
	else:
		t.set_art(u.card.art, u.owner == ENEMY)

		
func _apply_terrain_bonus(unit: UnitData, terrain: String) -> void:
	if not unit or not unit.card:
		return
	if not TERRAIN_BONUS.has(terrain):
		return
	var element := unit.card.element
	if not TERRAIN_BONUS[terrain].has(element):
		return

	# 🧩 Cache base stats once
	if not unit.has_meta("base_atk"):
		unit.set_meta("base_atk", unit.card.atk)
	if not unit.has_meta("base_def"):
		unit.set_meta("base_def", unit.card.def)

	var base_atk: float = float(unit.get_meta("base_atk"))
	var base_def: float = float(unit.get_meta("base_def"))

	# --- Retrieve old multiplier if known ---
	var old_mult := 1.0
	if unit.has_meta("last_terrain_mult"):
		old_mult = float(unit.get_meta("last_terrain_mult"))

	var new_mult = TERRAIN_BONUS[terrain][element]
	if abs(new_mult - old_mult) < 0.001:
		return  # no effective change

	# --- Preserve % HP ratio ---
	var old_max_def := base_def * old_mult
	var ratio := 1.0
	if old_max_def > 0:
		ratio = clamp(unit.current_def / old_max_def, 0.0, 1.0)

	# --- Apply new stats ---
	unit.current_atk = int(round(base_atk * new_mult))
	unit.current_def = int(round(base_def * new_mult * ratio))
	unit.set_meta("last_terrain_mult", new_mult)

	# --- Determine buff/debuff ---
	var diff_percent = ((new_mult / old_mult) - 1.0) * 100.0
	var is_buff = diff_percent > 0.0
	var color := Color(0.6, 1.0, 0.6) if is_buff else Color(1.0, 0.5, 0.5)
	var sign := "+" if is_buff else ""

	# --- Log improvement with percentage ---
	_log("🌿 %s adapts to %s terrain: ATK %.1f→%d | DEF %.1f→%d (%.0f%% preserved, %s%.1f%% %s)" %
		[unit.card.name, terrain,
		base_atk * old_mult, unit.current_atk,
		base_def * old_mult, unit.current_def,
		ratio * 100.0,
		sign, abs(diff_percent), ("buff" if is_buff else "debuff")],
		color)

	# --- Safe refresh of visuals ---
	var pos = board.get_unit_position(unit)
	if pos != Vector2i(-1, -1):
		refresh_tile_art_safe(pos)
	var tile := board.get_tile_position_for_unit(unit)
	if tile and tile.has_method("update_stat_labels"):
		tile.update_stat_labels(unit.current_atk, unit.current_def)
		var pos3d = tile.global_position + Vector3(0, 1.2, 0)
		_float_text(pos3d, "%s%.1f%% %s" % [sign, abs(diff_percent), ("buff" if is_buff else "debuff")], color)

func _float_text(world_pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	if ui_sys and ui_sys.has_method("_float_text"):
		ui_sys._float_text(world_pos, text, color)

# Regenerate DEF for all units belonging to a specific owner,
# capped by terrain-adjusted maximum DEF.
func regen_units_for_owner(owner: int, amount: int = 2) -> void:
	for pos in units.keys():
		var u: UnitData = units[pos]
		if u == null:
			continue
		if u.is_leader or u.owner != owner:
			continue
		if u.is_facedown:
			continue 

		var tile := board.get_tile(pos.x, pos.y)
		if tile == null:
			continue

		var mult := get_terrain_multiplier(u, tile.terrain_type)
		var base_def: float = float(u.get_meta("base_def")) if u.has_meta("base_def") else float(u.card.def)
		var max_def_for_tile := int(round(base_def * mult))

		var old_def := u.current_def
		u.current_def = min(u.current_def + amount, max_def_for_tile)

		if u.current_def != old_def:
			var color := Color(0.6, 1.0, 0.6) if owner == PLAYER else Color(1.0, 0.6, 0.6)
			_log("🛠 %s regenerates %d DEF (%d → %d)" % [u.card.name, amount, old_def, u.current_def], color)

		if tile.has_method("update_stat_labels"):
			tile.update_stat_labels(u.current_atk, u.current_def)

	if card_details_ui and card_details_ui.visible and card_details_ui.has_method("refresh_if_showing"):
		card_details_ui.call("refresh_if_showing", card_details_ui.current_unit)

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
	
	# ✅ Step 0: Hide all existing leader visuals before spawning (prevent flicker/disappear)
	for leader in [player_leader, enemy_leader]:
		if leader and leader.has_meta("leader_model"):
			var mdl = leader.get_meta("leader_model")
			if mdl: mdl.visible = false

	# ✅ Step 1: Initialize both leaders' data
	player_leader = UnitData.new().init_from_card(get_card(CARD_PATHS.LAVA_HARE), PLAYER)
	player_leader.is_leader = true
	player_leader.hp = 100

	enemy_leader = UnitData.new().init_from_card(get_card(CARD_PATHS.DIRT), ENEMY)
	enemy_leader.is_leader = true
	enemy_leader.hp = 100

	# ✅ Step 2: Place enemy leader first
	_place_leader(enemy_leader, Vector2i(BOARD_W / 2, BOARD_H - 1))
	_play_leader_spawn_sound(enemy_leader)
	_log("👿 Enemy Leader enters the battlefield...", Color(1, 0.4, 0.4))

	# Wait while camera shows enemy intro
	await get_tree().create_timer(3.5).timeout

	# ✅ Step 3: Place player leader second
	_place_leader(player_leader, Vector2i(BOARD_W / 2, 0))
	_play_leader_spawn_sound(player_leader)



func _play_leader_spawn_sound(leader: UnitData) -> void:
	if not leader:
		return
	var tile = board.get_tile_position_for_unit(leader)
	if not tile:
		return
	var pos = tile.global_position if tile else Vector3.ZERO

	var p := AudioStreamPlayer3D.new()
	add_child(p)
	p.stream = LEADER_IN_SOUND
	p.global_position = pos
	p.volume_db = -12.0
	p.pitch_scale = randf_range(0.97, 1.03)
	p.unit_size = 6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.play()
	p.connect("finished", Callable(p, "queue_free"))

func _place_leader(unit: UnitData, pos: Vector2i) -> void:
	# ✅ Safety: clear any prior occupant from this tile first
	if units.has(pos):
		var prev = units[pos]
		if prev and prev != unit:
			var prev_tile = board.get_tile(pos.x, pos.y)
			if prev_tile:
				prev_tile.set_occupant(null)
				prev_tile.set_art(null)
		units.erase(pos)

	# ✅ Set new occupant
	units[pos] = unit
	var tile = board.get_tile(pos.x, pos.y)
	if not tile:
		push_error("⚠️ Could not find tile for leader placement at %s" % str(pos))
		return

	tile.set_occupant(unit)
	tile.set_art(unit.card.art)
	tile.set_badge_text("L")

	# ✅ Spawn leader's 3D model if available
	if unit.card and unit.card.model_path != "":
		var model_scene: PackedScene = load(unit.card.model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "CardModel"
			model_instance.position = Vector3(0, 0.1, 0)
			model_instance.scale = CARD_MODEL_SCALE

			if unit.owner == ENEMY:
				model_instance.rotate_y(deg_to_rad(180))

			tile.add_child(model_instance)
			unit.set_meta("leader_model", model_instance)
			model_instance.visible = false
		else:
			push_warning("⚠️ Could not load model scene at path: %s" % unit.card.model_path)

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


	# ✅ Clean up placement session
	player_hand.erase(selected_card)
	ui_sys.call("refresh_hand", player_hand, player_essence)
	battle_sys.call("clear_highlights")

	# ✅ Lock only if NOT placed facedown (facedown stays toggleable on click)
	var placed_tile := board.get_tile(selected_pos.x, selected_pos.y)
	if placed_tile and placed_tile.occupant and placed_tile.occupant.owner == PLAYER:
		var unit = placed_tile.occupant
		var placed_face_down := (summon_mode == UnitData.Mode.FACEDOWN)
		unit.set_meta("flipped_permanent", not placed_face_down)


	# ✅ Fully exit placement mode
	selected_card = null
	selected_pos = Vector2i(-1, -1)
	dragging_card = null
	ui_sys.call("cancel_drag")
	ui_sys.call("fade_hand_in")
	battle_sys.call("_reset_hover_state")
	_set_phase(Phase.SUMMON_OR_MOVE)
	_update_phase_ui()

	_log("🎴 Card placed successfully", Color(0.7, 1.0, 0.7))


# -----------------------------
# TURN FLOW
# -----------------------------
func _on_end_turn_button_pressed() -> void:
	if phase != Phase.SUMMON_OR_MOVE:
		return
	_log("📜 Player ends their turn.")
	ui_sys.call("fade_hand_out")
	battle_sys.call("_reset_hover_state")

	# Hand off to enemy (enemy regen + AI handled there)
	await _start_enemy_turn()

func _start_player_turn() -> void:
	battle_sys.call("_reset_hover_state")

	print("🕐 _start_player_turn() called at:", Time.get_ticks_msec())

	_reset_action_flags()
	ui_sys.call("show_battle_message", "Your Turn!", 1.5)
	_draw_up_to_hand_limit()
	_set_phase(Phase.SUMMON_OR_MOVE)
	player_essence += essence_gain_per_turn
	emit_signal("essence_changed", player_essence, enemy_essence)

	# 💚 Sound + regen for player side
	_play_heal_sound()
	_log("💚 Player's army restores 2 DEF.", Color(0.7, 1.0, 0.7))
	regen_units_for_owner(PLAYER, 2)

	battle_sys.apply_all_passives()
	ui_sys.call("fade_hand_in")

	dragging_card = null
	selected_card = null
	selected_pos = Vector2i(-1, -1)

	print("Player essence now:", player_essence)
	battle_sys.core = self
	ui_sys.call("refresh_hand", player_hand, player_essence)
	for pos in units.keys():
		var u: UnitData = units[pos]
		if u and u.is_facedown:
			var tile = board.get_tile(pos.x, pos.y)
			if tile:
				tile.set_art(CARD_BACK)

	for pos in units.keys():
		var u: UnitData = units[pos]
		if u and u.is_facedown:
			refresh_tile_art_safe(pos)

	get_viewport().gui_release_focus()

func _start_enemy_turn() -> void:
	battle_sys.call("_reset_hover_state")

	_reset_action_flags()
	ui_sys.call("show_battle_message", "Enemy Turn!", 1.5)
	_set_phase(Phase.ENEMY_TURN)
	enemy_essence += essence_gain_per_turn
	emit_signal("essence_changed", player_essence, enemy_essence)

	# ❤️ Sound + regen for enemy side
	_play_heal_sound()
	_log("❤️ Enemy's army restores 2 DEF.", Color(1.0, 0.6, 0.6))
	regen_units_for_owner(ENEMY, 2)

	battle_sys.apply_all_passives()

	await get_tree().create_timer(0.5).timeout
	await ai_sys.call("run_enemy_turn")

	_log("🔁 Enemy turn finished.")
	for pos in units.keys():
		var u: UnitData = units[pos]
		if u and u.is_facedown:
			var tile = board.get_tile(pos.x, pos.y)
			if tile:
				tile.set_art(CARD_BACK)

	_start_player_turn()

func _draw_up_to_hand_limit() -> void:
	while player_hand.size() < MAX_HAND_SIZE and not player_deck.is_empty():
		var ui_card = _draw_card()
		if not ui_card: break
		await ui_sys.call("_animate_card_draw", ui_card)
		await get_tree().create_timer(0.15).timeout

func _reset_action_flags() -> void:
	acted_this_turn.clear()
	battle_sys.call("clear_exhausted_tiles")
	
func _play_card_place_sound() -> void:
	var sound := preload("res://Audio/Sound FX/Cardfacedown.mp3")  # 🔊 pick your desired sound
	if not sound:
		return
	var p := AudioStreamPlayer3D.new()
	add_child(p)
	p.stream = sound
	p.volume_db = -10.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.unit_size = 5.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.play()
	p.connect("finished", Callable(p, "queue_free"))

func _play_heal_sound() -> void:
	if not HEAL_SOUND:
		return
	var p := AudioStreamPlayer3D.new()
	add_child(p)
	p.stream = HEAL_SOUND
	p.volume_db = -10.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.unit_size = 5.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.play()
	p.connect("finished", Callable(p, "queue_free"))

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
			if selected_pos != Vector2i(-1, -1):
				var t = battle_sys.board.get_tile(selected_pos.x, selected_pos.y)
				if t and t.occupant:
					t.occupant.set_meta("allow_face_toggle_session", false)

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
