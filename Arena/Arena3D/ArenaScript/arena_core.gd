# =====================================================================
# 📘 FUNCTION INDEX — ArenaCore.gd
# =====================================================================

# 🧩 CARD LOADING & FUSION CONFIG
# ---------------------------------------------------------------------
# get_card(path)                           → Lazy-loads card resources & caches them
# _trigger_fusion_abilities(fused, srcs)   → Runs “on_fusion” triggers for component cards
# _check_fusion_pair(a, b)                 → Returns result CardData if valid fusion exists
# _play_fusion_effect(result_card)         → Plays fusion animation, camera shake, and logs fusion

# 🔧 DECK & LEADER MANAGEMENT
# ---------------------------------------------------------------------
# _build_decks()                           → Builds player/enemy decks, tutorial override included
# _spawn_leaders()                         → Spawns player/enemy leaders & initiates cutscene
# _play_leader_spawn_sound(leader)         → Plays 3D sound when leader enters battlefield
# _place_leader(unit, pos)                 → Places leader unit + model on board safely

# ❤️ LEADER / HP HANDLING
# ---------------------------------------------------------------------
# damage_leader(target, amount)            → Applies damage to leader & triggers defeat check
# on_leader_damaged(owner, new_hp)         → Emits hp_changed for UI
# on_leader_defeated(owner)                → Handles win/lose sequence and emits battle_finished

# 🌍 BIOME / TERRAIN SYSTEM
# ---------------------------------------------------------------------
# _apply_terrain_bonus(unit, terrain)      → Recalculates ATK/DEF based on terrain type
# get_terrain_multiplier(unit, terrain)    → Returns numeric multiplier for terrain
# get_terrain_for_unit(unit)               → Looks up terrain type of unit’s current tile

# 🌿 UNIT STATE / STATS
# ---------------------------------------------------------------------
# regen_units_for_owner(owner, amount)     → Regenerates DEF for all units of given owner
# refresh_tile_art_safe(pos)               → Updates tile art, safely hiding facedown enemies

# 💧 ESSENCE / ECONOMY
# ---------------------------------------------------------------------
# _gain_essence(owner, amount)             → Increases essence & refreshes UI hand display
# emit_signal("essence_changed")           → Notifies OrbGrid & UI about updated essence

# 🃏 HAND / SUMMON SYSTEM
# ---------------------------------------------------------------------
# _draw_starting_hand(n)                   → Draws initial hand & animates card draws
# _draw_card()                             → Pops card from deck → hand
# _draw_up_to_hand_limit()                 → Fills player hand up to max hand size
# on_hand_card_clicked(card)               → Handles fusion selection or summon readiness
# try_place_dragged_card(tile)             → Handles both fusion and normal card placement
# _try_place_regular_card(tile)            → Executes summon popup → confirm callback
# confirm_summon_in_mode(mode)             → Finalizes card/fusion summon & deducts essence
# cancel_summon_popup()                    → Cancels active summon and resets hand/phase
# clear_card_placement_mode()              → Resets selection/drag and UI hand state
# set_player_deck(arr)                     → Replace player deck from external source

# 🧬 FUSION & ABILITY EXECUTION
# ---------------------------------------------------------------------
# _trigger_fusion_abilities(...)           → Executes any “on_fusion” card scripts
# _execute_card_ability(unit, ability)     → Runs a single ability’s execute() safely

# 🔊 SOUND & FX HELPERS
# ---------------------------------------------------------------------
# _play_card_flip_sound()                  → Plays card flip SFX
# _play_card_place_sound(card, facedown)   → Plays card placement sound based on context
# _play_heal_sound()                       → Plays heal SFX in 3D space
# _float_text(world_pos, text, color)      → Displays floating combat text
# shake(intensity, duration)               → Shakes camera (defined for ArenaCamera)
# stop_fusion_pending_hum()                → Stops looping hum when fusion overlay ends

# 🎯 TURN FLOW MANAGEMENT
# ---------------------------------------------------------------------
# _on_end_turn_button_pressed()            → Handles player end-turn input
# _start_player_turn()                     → Handles player turn setup & regen
# _start_enemy_turn()                      → Runs AI logic & enemy regen, then returns control
# _reset_action_flags()                    → Clears unit action states
# mark_unit_acted(u)                       → Marks a unit as acted & sets exhaustion visuals
# can_unit_act(u)                          → Checks if unit can act this turn

# ⚙️ LIFECYCLE / INIT
# ---------------------------------------------------------------------
# _ready()                                 → Initializes systems, connects signals, pre-fade setup
# _deferred_startup()                      → Builds decks, spawns leaders, fades in, starts battle
# enable_tutorial_mode()                   → Activates tutorial settings
# _on_battle_concluded(result)             → Called after victory/defeat, returns to map/hub

# 🔄 PHASE / LOGGING / SIGNALS
# ---------------------------------------------------------------------
# _set_phase(p)                            → Updates internal phase and emits signal
# _update_phase_ui()                       → Updates phase label on UI
# log_message(message, color)              → Sends colored text to UI log
# _log(message, color)                     → Emits log_line signal + prints to console

# 🧭 INPUT HANDLER (DELEGATION HUB)
# ---------------------------------------------------------------------
# _unhandled_input(event)                  → Main dispatcher for mouse, keyboard, fusion cancel, etc.
#   ↳ Left click: summons, moves, or fuses cards
#   ↳ Right click: cancels current action
#   ↳ Shift / Mouse Motion: camera freelook toggle

# 🪄 GENERAL HELPERS (EXPOSED TO OTHER SYSTEMS)
# ---------------------------------------------------------------------
# get_leader_pos(owner)                    → Returns current leader tile for owner
# clear_card_placement_mode()              → Cancels current card drag or summon popup
# get_terrain_for_unit(unit)               → Retrieves current terrain name
# stop_fusion_pending_hum()                → Force stop lingering fusion SFX
# =====================================================================







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
	"TUTORIAL_GOBLIN":      "res://Cards/Monster Cards/Tutorial_Goblin.tres",
#"":                  "res://Cards/Monster Cards/.tres",
}

var fusion_selection: Array = []   # up to 2 CardData objects
var fusion_pairs := {
	# Example mapping
	["GOBLIN", "IMP"]: "JESTER_OF_FLAMES",
	["FYSH", "LYZARD"]: "NAGA",
	["FOREST_FAE", "LAVA_HARE"]: "FLAME_FAE",
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
#const FUSION_PENDING_SOUND := preload("res://Audio/Sound FX/Fusion Pending.mp3")
#const FUSE_SOUND := preload("res://Audio/Sound FX/Fuse.mp3")

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
@export var is_tutorial_match: bool = false

# -----------------------------
# NODES
# -----------------------------
@onready var board: Board3D = $BoardGenerator

@onready var ui_root: Control = $UISystem
@onready var camera: Camera3D = $CameraSystem


# Subsystems:
@onready var camera_sys: Node = $CameraSystem
@onready var ui_sys: Node = $UISystem
@onready var battle_sys: Node = $BattleSystem
@onready var ai_sys: Node = $AISystem
@onready var cutscene_sys: Node = $CutsceneSystem
@onready var move_sys: ArenaMove = $MoveSystem

# UI children we still reference directly (for convenience)
@onready var card_draw: AudioStreamPlayer = $UISystem/SFX/CardDraw
@onready var card_details_ui: Control = $UISystem/ArenaCardDetails


# -----------------------------
# GAME DATA
# -----------------------------
var phase: int = Phase.SUMMON_OR_MOVE
var summon_mode := UnitData.Mode.ATTACK
var _is_transitioning := false

# Decks & hands
var player_deck: Array = []
var player_hand: Array = []
var enemy_deck: Array = []
var enemy_hand: Array = []

# Essence
var player_essence: int = 1
var enemy_essence: int = 1
var essence_gain_per_turn: int = 1
var _is_fusion_pending_active: bool = false
var _fusion_was_valid: bool = false

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

var data = GameSession.encounter_data

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
	board.Biome.TUNDRA,
	#board.Biome.DEFAULT
]


# -----------------------------
# LIFECYCLE
# -----------------------------
func _ready():
	GameSession.arena_instance = self
	await get_tree().process_frame
	# After other connects:
	connect("battle_finished", Callable(self, "_on_battle_concluded"))

	# 🕶 Immediately cover screen with black before anything loads
	if ui_sys.has_node("FadeRect"):
		var fade_rect: ColorRect = ui_sys.get_node("FadeRect")
		fade_rect.modulate.a = 1.0  # fully black
		fade_rect.visible = true

	call_deferred("_deferred_startup")


	# minimal registry of cards (your collection)


	# ✅ Connect essence UI
	var orb_grid := ui_sys.get_node_or_null("OrbGrid")
	if orb_grid and orb_grid.has_method("set_essence"):
		connect("essence_changed", Callable(orb_grid, "set_essence"))
	else:
		push_warning("⚠️ OrbGrid not found or missing set_essence() in UISystem")
		
	if data:
		print("🎭 Fighting:", data.enemy_name)
		print("🧠 AI Style:", data.ai_style)
		print("🔥 Difficulty:", data.difficulty)

		# Build enemy deck based on payload
		enemy_deck.clear()
		for card_data in data.enemy_deck:
			if card_data:
				enemy_deck.append(card_data.duplicate())

func _deferred_startup():
	randomize()
	#board.biome = all_biomes[randi() % all_biomes.size()]
	board.biome = board.Biome.TUNDRA
	# Generate the map for that biome
	board._generate_grid()

	# Optional: friendly text for logging
	var biome_names = {
		board.Biome.OCEAN: "🌊 Ocean",
		board.Biome.VOLCANO: "🌋 Volcano",
		board.Biome.FOREST: "🌲 Forest",
		board.Biome.MEADOW: "🌾 Meadow",
		board.Biome.MOUNTAIN: "⛰️ Mountain",
		board.Biome.TUNDRA: "❄️ Tundra",
		#board.Biome.DEFAULT: " DEFAULT "
	}
	_log("🌍 Battlefield biome: " + biome_names.get(board.biome, str(board.biome)))

	# Build decks, spawn leaders, play intro
	_build_decks()
	_spawn_leaders()

	ui_sys.call("init_ui", self)              # hand, labels, hover/ghost setup
	camera_sys.call("init_camera", self)      # places camera top-down
	battle_sys.call("init_battle", self)      # links helpers/consts
	ai_sys.call("init_ai", self)
	if GameSession.has_method("setup_arena"):
		GameSession.setup_arena(self)



	cutscene_sys.call("init_cutscene", self)
#
#
#
	# 🟡 Hide End Turn button before intro cutscene
	var end_turn_btn := ui_sys.get_node_or_null("EndTurnButton")
	if end_turn_btn:
		end_turn_btn.visible = false

	# 🎥 Play intro cutscene
	cutscene_sys._intro()

		# 🎥 Start fade-in BEFORE intro begins
	if ui_sys.has_node("FadeRect"):
		var fade_rect: ColorRect = ui_sys.get_node("FadeRect")
		var fade_tween := create_tween()
		fade_tween.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
		await fade_tween.finished
		fade_rect.visible = false
	
	# 🕒 Wait until cutscene ends and fade finishes before showing button
	await get_tree().create_timer(4.0).timeout  # matches your intro + fade length

	if end_turn_btn:
		end_turn_btn.visible = true

	
	await get_tree().create_timer(4.0).timeout
	
	emit_signal("essence_changed", player_essence, enemy_essence)
	ui_sys.call("refresh_hand", player_hand, player_essence)
	_draw_starting_hand(5)
	# --- Fade in the scene ---
	if ui_sys.has_node("FadeRect"):
		var fade_rect: ColorRect = ui_sys.get_node("FadeRect")
		var tween := create_tween()
		tween.tween_property(fade_rect, "modulate:a", 0.0, 1.5)
		await tween.finished
		fade_rect.visible = false


	if is_tutorial_match:
		TutorialManager.start_arena_summon_tutorial()

	_set_phase(Phase.SUMMON_OR_MOVE)
	_update_phase_ui()
	
func enable_tutorial_mode():
	is_tutorial_match = true
	if battle_sys:
		battle_sys.is_tutorial_match = true
		
func _on_battle_concluded(result: String) -> void:
	#await get_tree().create_timer(2.0).timeout
	if DialogueManager and DialogueManager.has_method("force_close"):
		DialogueManager.force_close()

	GameSession.last_battle_result = result
	GameSession.switch_to_earth_map()

func set_player_deck(arr: Array) -> void:
	player_deck = arr.duplicate()
	
func refresh_tile_art_safe(pos: Vector2i):
	if not units.has(pos): return
	var u: UnitData = units[pos]
	var t = board.get_tile(pos.x, pos.y)
	if not t: return

	# 👇 Prevent accidental reveal
	var is_enemy := u.owner == ENEMY
	var is_facedown = u.is_facedown or (u.has_meta("is_facedown") and u.get_meta("is_facedown"))
	if is_enemy and is_facedown:
		t.set_art(CARD_BACK)
		return

	t.set_art(u.card.art, u.owner == ENEMY)

		
func _apply_terrain_bonus(unit: UnitData, terrain: String) -> void:
	if not unit or not unit.card:
		return
	if unit.is_leader:
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

	var old_mult = unit.get_meta("last_terrain_mult") if unit.has_meta("last_terrain_mult") else 1.0
	var new_mult = TERRAIN_BONUS[terrain][element]
	if abs(new_mult - old_mult) < 0.001:
		return

	var old_max_def = base_def * old_mult
	var ratio = clamp(unit.current_def / old_max_def, 0.0, 1.0)

	unit.current_atk = int(round(base_atk * new_mult))
	unit.current_def = int(round(base_def * new_mult * ratio))
	unit.set_meta("last_terrain_mult", new_mult)

	var diff_percent = ((new_mult / old_mult) - 1.0) * 100.0
	var is_buff = diff_percent > 0.0
	var color := Color(0.6, 1.0, 0.6) if is_buff else Color(1.0, 0.5, 0.5)

	# 🚫 Skip revealing facedown enemies
	var is_enemy := unit.owner == ENEMY
	var is_facedown = unit.is_facedown or (unit.has_meta("is_facedown") and unit.get_meta("is_facedown"))
	if is_enemy and is_facedown and not unit.is_leader:
		return

	if unit.card.card_type == CardData.CardType.SPELL or unit.card.card_type == CardData.CardType.EVENT:
		return

	var sign := "+" if is_buff else ""
	_log("🌿 %s adapts to %s terrain (%s%.1f%% %s)" % [
		unit.card.name, terrain, sign, abs(diff_percent), "buff" if is_buff else "debuff"
	], color)

	var pos = board.get_unit_position(unit)
	if pos != Vector2i(-1, -1):
		refresh_tile_art_safe(pos)

	var tile := board.get_tile_position_for_unit(unit)
	if tile and tile.has_method("update_stat_labels"):
		tile.update_stat_labels(unit.current_atk, unit.current_def)
		_float_text(tile.global_position + Vector3(0, 1.2, 0), "%s%.1f%% %s" % [sign, abs(diff_percent), ("buff" if is_buff else "debuff")], color)

	# ✅ Enforce correct visuals *after* all logic
	battle_sys._enforce_visual_face_state()

func _float_text(world_pos: Vector3, text: String, color: Color = Color.WHITE) -> void:
	if ui_sys and ui_sys.has_method("_float_text"):
		ui_sys._float_text(world_pos, text, color)
		
		
# ==========================================================
# 🧬 Fusion Ability Trigger System
# ==========================================================
func _trigger_fusion_abilities(fused_card: CardData, source_cards: Array[CardData]) -> void:
	if not fused_card:
		return

	for c in source_cards:
		if c == null:
			continue
		if not ("script" in c) or c.script == null:
			continue
		if not (c.script is Script):
			continue

		var script_ref: Script = c.script
		var temp_inst = null

		# Instantiate the ability script
		if script_ref:
			temp_inst = script_ref.new()

		# Only execute if the script defines "trigger" and "execute"
		if temp_inst and temp_inst.has_method("execute"):
			var trigger_val := ""
			if temp_inst.has_variable("trigger"):
				trigger_val = str(temp_inst.trigger).to_lower()

			if trigger_val == "on_fusion":
				temp_inst.execute(self, fused_card)

# In ArenaCamera.gd
func shake(intensity: float = 0.1, duration: float = 0.2) -> void:
	var original_pos := position
	var tween := create_tween()
	for i in range(5):
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.5, intensity * 0.5),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(self, "position", original_pos + offset, duration / 10.0)
		tween.tween_property(self, "position", original_pos, duration / 10.0)

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
	# 🔹 PLAYER DECK BUILD
	player_deck.clear()

	# 1️⃣ Pull from DeckManager if present
	if DeckManager and DeckManager.has_method("get_deck_carddatas"):
		var dm_cards := DeckManager.get_deck_carddatas()
		if dm_cards.size() > 0:
			for cd in dm_cards:
				if cd:
					player_deck.append(cd.duplicate())

	# 2️⃣ Fallback — use CardCollection if still empty
	if player_deck.is_empty():
		var all_cards = CardCollection.get_all_cards()
		for card_data in all_cards:
			if card_data:
				player_deck.append(card_data.duplicate())

	# ✅ Shuffle last
	player_deck.shuffle()
	# 👇 RIGHT HERE after enemy_deck.clear()
	if is_tutorial_match:
		enemy_deck.append(load("res://Cards/Monster Cards/Tutorial_Goblin.tres").duplicate())
		# Add 5–10 copies so the AI always draws something
		for i in range(8):
			enemy_deck.append(load("res://Cards/Monster Cards/Tutorial_Goblin.tres").duplicate())
		enemy_deck.shuffle()
		_log("🎓 Tutorial enemy deck built: %d Tutorial Goblins" % enemy_deck.size())
		return
		
	# 🔹 ENEMY: Auto-build from folders (as you already do)
	
	# ✅ If enemy deck is already populated from MapNode, STOP
	if enemy_deck.size() > 0 and not is_tutorial_match:
		enemy_deck.shuffle()
		return
	enemy_deck.clear()
	var enemy_folders = [
		"res://Cards/Monster Cards",
		"res://Cards/Spell Cards"
	]
	for folder_path in enemy_folders:
		var dir := DirAccess.open(folder_path)
		if not dir:
			push_warning("⚠️ Missing folder: %s" % folder_path)
			continue
		for file_name in dir.get_files():
			if file_name.ends_with(".tres"):
				var path := "%s/%s" % [folder_path, file_name]
				var card := ResourceLoader.load(path)
				if card:
					var copies := 5
					for i in range(copies):
						enemy_deck.append(card.duplicate())

	player_deck.shuffle()
	enemy_deck.shuffle()

	_log("✅ Decks built: Player=%d, Enemy=%d" % [player_deck.size(), enemy_deck.size()])

func _spawn_leaders() -> void:
	
	# ✅ Step 0: Hide all existing leader visuals before spawning (prevent flicker/disappear)
	for leader in [player_leader, enemy_leader]:
		if leader and leader.has_meta("leader_model"):
			var mdl = leader.get_meta("leader_model")
			if mdl: mdl.visible = false

	# ✅ Use chosen leader if any
	if Globals.selected_leader:
		player_leader = UnitData.new().init_from_card(Globals.selected_leader, PLAYER)
	else:
		player_leader = UnitData.new().init_from_card(get_card(CARD_PATHS.GOBLIN), PLAYER)

	player_leader.is_leader = true

		
	enemy_leader = UnitData.new().init_from_card(get_card(CARD_PATHS.BOOGLES), ENEMY)
	enemy_leader.is_leader = true


		# =========================
	# Tutorial HP overrides
	# =========================
	if is_tutorial_match:
		player_leader.hp = 50
		enemy_leader.hp = 20
	else:
		player_leader.hp = 20
		enemy_leader.hp = 20



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
	#_log("%s Leader takes %d damage!" % [who, amount], Color(1, 0.5, 0.5))

	if ui_sys and ui_sys.has_method("update_leader_hp"):
		ui_sys.update_leader_hp(player_leader.hp, enemy_leader.hp)
	if leader.hp <= 0:
		on_leader_defeated(target)
		return

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
		#await get_tree().create_timer(0.15).timeout

func _draw_card() -> Control:
	if player_deck.is_empty(): return null
	var card: CardData = player_deck.pop_back()
	player_hand.append(card)
	ui_sys.call("refresh_hand", player_hand, player_essence)
	card_draw.play()
	return ui_sys.call("get_last_hand_card_ui")

func on_hand_card_clicked(card: CardData) -> void:
	if dragging_card:
		return

	# Toggle selection
	if fusion_selection.has(card):
		fusion_selection.erase(card)
		_log("❎ Deselected %s" % card.name)
		# 🔹 Clear highlights when deselecting all
		if fusion_selection.is_empty() and battle_sys and battle_sys.has_method("clear_summon_highlights"):
			battle_sys.call("clear_summon_highlights")
	else:
		fusion_selection.append(card)
		_log("✅ Selected %s (%d/2)" % [card.name, fusion_selection.size()])

	# --- Handle selection states ---
	if fusion_selection.size() == 1:
		selected_card = card
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()
		_log("💡 Select another card to attempt fusion, or click a tile to summon %s." % card.name, Color(0.9, 0.9, 0.6))

		# ✅ Highlight all valid summon tiles
		if battle_sys and battle_sys.has_method("show_valid_summon_tiles"):
			battle_sys.call("show_valid_summon_tiles")

	elif fusion_selection.size() == 2:
		if is_tutorial_match:
			TutorialManager.on_attempt_fusion()

		selected_card = fusion_selection[1]
		dragging_card = selected_card
		if ui_sys and ui_sys.has_method("fade_hand_out"):
			ui_sys.fade_hand_out()
		if ui_sys and ui_sys.has_method("on_drag_start"):
			ui_sys.on_drag_start(selected_card)
		_set_phase(Phase.SELECT_SUMMON_TILE)
		_update_phase_ui()
		_log("🧬 Fusion pair ready — select a tile to place the fusion.", Color(1.0, 0.9, 0.4))
		# 🧩 Show visual pending fusion overlay
		var result := _check_fusion_pair(fusion_selection[0], fusion_selection[1])
		if ui_sys and ui_sys.has_method("show_fusion_pending"):
			ui_sys.show_fusion_pending(fusion_selection, result)

		# ✅ Highlight again for fusion placement
		if battle_sys and battle_sys.has_method("show_valid_summon_tiles"):
			battle_sys.call("show_valid_summon_tiles")


func _play_card_flip_sound() -> void:
	var sound := preload("res://Audio/Sound FX/Card Flip.mp3")
	if not sound:
		return

	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = sound
	p.volume_db = -6.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
	p.connect("finished", Callable(p, "queue_free"))



func try_place_dragged_card(hover_tile: Node3D) -> void:
	if hover_tile == null:
		return
			
	# 🟥 Prevent summoning on non-highlight tiles
	if not hover_tile or not hover_tile.summon_highlight:
		_log("🚫 You can only summon on a highlighted tile!", Color(1, 0.5, 0.5))

		# Hide summon highlights immediately
		if battle_sys and battle_sys.has_method("clear_summon_highlights"):
			battle_sys.call("clear_summon_highlights")

		# Fully reset card placement state
		ui_sys.call("cancel_drag")
		fusion_selection.clear()
		selected_card = null
		dragging_card = null
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()

		# Fade hand back in to visually confirm cancel
		if ui_sys and ui_sys.has_method("fade_hand_in"):
			ui_sys.call("fade_hand_in")

		return

	print("🧩 DEBUG fusion_selection size:", fusion_selection.size())

	if fusion_selection.size() == 2:
		var a = fusion_selection[0]
		var b = fusion_selection[1]
		var result := _check_fusion_pair(a, b)

		if not result:
			# 🧩 INVALID FUSION
			_fusion_was_valid = false
			_log("⚠️ No valid fusion found — %s will be consumed and %s will be summoned instead." %
				[a.name, b.name], Color(0.843, 0.0, 0.0, 1.0))
			if is_tutorial_match:
				DialogueManager.start_convo([
					DialogueManager._dl("Guide", "That combination didn’t create anything new."),
					DialogueManager._dl("Guide", "Many combinations will fail — experiment!"),
				])

			player_hand = player_hand.filter(func(c): return c != a)
			ui_sys.refresh_hand(player_hand, player_essence)

			selected_card = b
			selected_pos = Vector2i(hover_tile.x, hover_tile.y)
			_set_phase(Phase.SELECT_SUMMON_TILE)
			_update_phase_ui()
			ui_sys.show_popup(b)
			return
		else:
			# ✅ VALID FUSION
			_fusion_was_valid = true
			var cost := int(result.cost) if "cost" in result else 1
			if player_essence < cost:
				_log("❌ Not enough Essence to fuse %s (Cost %d, you have %d)." %
					[result.name, cost, player_essence])
				if is_tutorial_match:
					DialogueManager.start_convo([
						DialogueManager._dl("Guide", "Notice your Essence above your hand."),
						DialogueManager._dl("Guide", "Summoning costs essence. End your turn to gain more."),
					])

				ui_sys.cancel_drag()
				fusion_selection.clear()
				return

			selected_pos = Vector2i(hover_tile.x, hover_tile.y)
			selected_card = result
			_set_phase(Phase.SELECT_SUMMON_TILE)
			_update_phase_ui()
			_log("🧬 Fusion pair ready — select summon mode.")
			ui_sys.show_popup(result)
			return


		## Store intent for when the popup button is pressed
		#selected_pos = Vector2i(hover_tile.x, hover_tile.y)
		selected_card = result
		_set_phase(Phase.SELECT_SUMMON_TILE)
		_update_phase_ui()

		_log("🧬 Fusion pair ready — select summon mode.")
		ui_sys.show_popup(result)  # user will press Attack/Defense/FaceDown
		return


	# --- 🟢 Handle normal summon (single card)
	if fusion_selection.size() == 1:
		selected_card = fusion_selection[0]
		selected_pos = Vector2i(hover_tile.x, hover_tile.y)

		var card_cost := int(selected_card.cost) if "cost" in selected_card else 1
		if player_essence < card_cost:
			_log("❌ Not enough Essence to summon %s (Cost %d, you have %d)." %
				[selected_card.name, card_cost, player_essence], Color(1, 0.5, 0.3))
			return

		_log("🎴 Summon ready — select summon mode.")
		_set_phase(Phase.SELECT_SUMMON_TILE)
		_update_phase_ui()
		ui_sys.show_popup(selected_card)
		return


	# --- 🟡 Nothing selected
	_log("⚠️ Clicked tile but no card selected.", Color(1, 0.8, 0.3))

func _try_place_regular_card(hover_tile: Node3D) -> void:
	if selected_card == null:
		return

	var cost := int(selected_card.cost) if "cost" in selected_card else 1
	var live_essence := player_essence  # 🔹 always use live value

	if live_essence < cost:
		_log("❌ Not enough Essence to summon %s (Cost %d, you have %d)" %
			[selected_card.name, cost, live_essence], Color(1, 0.5, 0.3))
		ui_sys.call("cancel_drag")
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()
		return

	ui_sys.show_popup(selected_card, func(mode):
		var fresh_essence := player_essence  # read again when button clicked
		var live_cost := int(selected_card.cost) if "cost" in selected_card else 1
		if fresh_essence < live_cost:
			_log("❌ Not enough Essence at confirm (Cost %d, you have %d)" %
				[live_cost, fresh_essence], Color(1, 0.5, 0.3))
			return

		player_essence = clamp(player_essence - live_cost, 0, 8)
		emit_signal("essence_changed", player_essence, enemy_essence)
		ui_sys.call("refresh_hand", player_hand, player_essence)
		player_hand.erase(selected_card)
		battle_sys.call("place_unit", selected_card, selected_pos, PLAYER, mode, true)
		_log("🎴 %s summoned in %s Mode!" % [selected_card.name, str(mode)], Color(0.7, 1.0, 0.7))
		_set_phase(Phase.SUMMON_OR_MOVE)
		_update_phase_ui()
	)

func _check_fusion_pair(a: CardData, b: CardData) -> CardData:
	# --- 1️⃣ Explicit static fusion pairs ---
	var key := [a.name, b.name]
	var key_rev := [b.name, a.name]
	for k in fusion_pairs.keys():
		if k == key or k == key_rev:
			var result_name = fusion_pairs[k]
			if CARD_PATHS.has(result_name):
				return get_card(CARD_PATHS[result_name])

	# --- 2️⃣ Dynamic Conflaguration Blade fusion ---
	var a_name := str(a.name).to_lower().replace(" ", "_")
	var b_name := str(b.name).to_lower().replace(" ", "_")
	var a_elem := str(a.element if a.element != null else "").to_lower()
	var b_elem := str(b.element if b.element != null else "").to_lower()

	print("🔥 FUSION DEBUG:", a.name, "(", a_elem, ")", b.name, "(", b_elem, ")")

	var is_blade_a := a_name.find("conflaguration_blade") != -1
	var is_blade_b := b_name.find("conflaguration_blade") != -1
	var is_fire_a := a_elem == "fire"
	var is_fire_b := b_elem == "fire"

	if (is_blade_a and is_fire_b):
		var fused := b.duplicate()
		fused.atk += 8
		fused.description += "\n🔥 Empowered by the Conflaguration Blade (+8 ATK)."
		return fused
	elif (is_blade_b and is_fire_a):
		var fused := a.duplicate()
		fused.atk += 8
		fused.description += "\n🔥 Empowered by the Conflaguration Blade (+8 ATK)."
		return fused

	print("❌ Fusion failed: no valid Conflaguration Blade + Fire-type combo found.")
	return null

func _play_fusion_effect(result_card: CardData) -> void:
	var fusion_scene := preload("res://Cards/Abilities/fusion_effect.tscn")
	var effect: CanvasLayer = fusion_scene.instantiate()
	add_child(effect)

	var art_a: Texture2D = fusion_selection[0].art
	var art_b: Texture2D = fusion_selection[1].art
	var fusion_name := result_card.name
	

	effect.start(art_a, art_b, fusion_name)
	# 🔇 Stop the Fusion Pending hum once fusion animation starts
	stop_fusion_pending_hum()


	# Optional: camera shake + UI log
	if camera_sys and camera_sys.has_method("shake"):
		camera_sys.shake(0.25, 0.4)

	ui_sys.call("show_battle_message", "🧬 Fusion Created: %s!" % result_card.name, 2.0)

	# ⏳ Wait for the animation duration (matches FusionEffect2D duration)
	await get_tree().create_timer(1.5).timeout

	# Remove the effect layer when done
	effect.queue_free()

func confirm_summon_in_mode(mode: int) -> void:
	if selected_card == null:
		_log("⚠️ No card selected for summon.")
		return
	if selected_pos == Vector2i(-1, -1):
		_log("⚠️ No target tile selected for summon.")
		return

	var mode_name := ""
	match mode:
		UnitData.Mode.ATTACK:
			mode_name = "Attack Mode"
		UnitData.Mode.DEFENSE:
			mode_name = "Defense Mode"
		UnitData.Mode.FACEDOWN:
			mode_name = "Face-Down"
	if is_tutorial_match and not TutorialManager.has_seen_attack_popup and mode == UnitData.Mode.ATTACK:
		TutorialManager.on_popup_shown_attack_mode(self)
	if is_tutorial_match and mode == UnitData.Mode.FACEDOWN and not TutorialManager.has_seen_combat:
		DialogueManager.start_convo([
			DialogueManager._dl("Guide", "Face-Down summons hide your stats, but disable abilities."),
			DialogueManager._dl("Guide", "Useful for baiting opponents or blocking movement."),
			DialogueManager._dl("Guide", "Click a facedown card to move it, hit R while selected to flip it face up!"),
		])

	# --- 🧬 Handle Fusion Result (pre-set by try_place_dragged_card)
	if fusion_selection.size() == 2:
		var a = fusion_selection[0]
		var b = fusion_selection[1]
		var fused := selected_card
		var cost := int(fused.cost) if "cost" in fused else 1

		player_essence -= cost
		emit_signal("essence_changed", player_essence, enemy_essence)

		player_hand = player_hand.filter(func(c): return c != a and c != b)
		ui_sys.refresh_hand(player_hand, player_essence)

		# 🌀 Play fusion animation and wait for it to finish before placing
		await _play_fusion_effect(fused)
		if ui_sys and ui_sys.has_method("hide_fusion_pending"):
			await ui_sys.hide_fusion_pending()

		# ✅ Now safely place the fused card
		move_sys.place_unit(fused, selected_pos, PLAYER, mode, true)


		if _fusion_was_valid:
			_log("🧬 %s + %s fused into %s (%s)!" %
				[a.name, b.name, fused.name, mode_name], Color(1.0, 0.8, 0.4))
		if is_tutorial_match and not TutorialManager.has_learned_fusion:
			DialogueManager.start_convo([
				DialogueManager._dl("Guide", "Excellent!"),
				DialogueManager._dl("Guide", "Fusion can create stronger monsters than summoning alone."),
			])

		else:
			_log("🎴 %s summoned in %s!" % [fused.name, mode_name], Color(0.7, 1.0, 0.7))


	else:
		# --- 🟢 Handle Normal Summon
		var cost := int(selected_card.cost) if "cost" in selected_card else 1
		player_essence -= cost
		emit_signal("essence_changed", player_essence, enemy_essence)

		player_hand.erase(selected_card)
		ui_sys.refresh_hand(player_hand, player_essence)

		move_sys.place_unit(selected_card, selected_pos, PLAYER, mode, true)
		_log("🎴 %s summoned in %s!" % [selected_card.name, mode_name], Color(0.7, 1.0, 0.7))

	# --- ✅ Cleanup (common for both)
	if battle_sys and battle_sys.has_method("clear_summon_highlights"):
		battle_sys.call("clear_summon_highlights")

	if ui_sys:
		ui_sys.call_deferred("fade_hand_in")
		ui_sys.call_deferred("cancel_drag")  # 🧩 FIX: properly reset hover/drag state
		
	_fusion_was_valid = false
	fusion_selection.clear()
	if ui_sys and ui_sys.has_method("hide_fusion_pending"):
		ui_sys.hide_fusion_pending()

	selected_card = null
	dragging_card = null
	_set_phase(Phase.SUMMON_OR_MOVE)
	_update_phase_ui()

	# 🧩 Force hover system reset to fix broken tile hover
	if battle_sys and battle_sys.has_method("_reset_hover_state"):
		battle_sys.call("_reset_hover_state")

# -----------------------------
# TURN FLOW
# -----------------------------
func _on_end_turn_button_pressed() -> void:
	if phase != Phase.SUMMON_OR_MOVE:
		return
	_log("📜 Player ends their turn.")
	ui_sys.call("fade_hand_out")
	battle_sys.call("_reset_hover_state")
	
	if is_tutorial_match and player_hand.size() > 0 and units.size() <= 2: # only leaders on board
		DialogueManager.start_convo([
			DialogueManager._dl("Guide", "Try placing a monster first!"),
			DialogueManager._dl("Guide", "Ending turns without acting puts you at a disadvantage."),
		])

	# Hand off to enemy (enemy regen + AI handled there)
	await _start_enemy_turn()

func _start_player_turn() -> void:
	await get_tree().process_frame  # ensures last turn cleanup fully done

	_gain_essence(PLAYER, essence_gain_per_turn)
	print("✅ AFTER GAIN essence:", player_essence)

	if camera_sys and camera_sys.has_method("focus_on_leader"):
		camera_sys.call_deferred("focus_on_leader", PLAYER)

	battle_sys.call("_reset_hover_state")
	_reset_action_flags()
	_draw_up_to_hand_limit()

	_set_phase(Phase.SUMMON_OR_MOVE)
	ui_sys.call("show_battle_message", "Your Turn!", 1.5)

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

	battle_sys._enforce_visual_face_state()
	get_viewport().gui_release_focus()

func _start_enemy_turn() -> void:
	battle_sys.call("_reset_hover_state")

	_reset_action_flags()
	_set_phase(Phase.ENEMY_TURN)
	if camera_sys and camera_sys.has_method("focus_on_leader"):
		camera_sys.call_deferred("focus_on_leader", ENEMY)

	ui_sys.call("show_battle_message", "Enemy Turn!", 1.5)
	if is_tutorial_match and TutorialManager.once("enemy_turn_explained"):
		DialogueManager.start_convo([
			DialogueManager._dl("Guide", "It's the enemy's turn now."),
			DialogueManager._dl("Guide", "They move and attack just like you."),
		])



	_gain_essence(ENEMY, essence_gain_per_turn)
	emit_signal("essence_changed", player_essence, enemy_essence)

	# ❤️ Sound + regen for enemy side
	_play_heal_sound()
	_log("❤️ Enemy's army restores 2 DEF.", Color(1.0, 0.6, 0.6))
	regen_units_for_owner(ENEMY, 2)

	battle_sys.apply_all_passives()

	await get_tree().create_timer(0.5).timeout
	await ai_sys.call("run_enemy_turn")

	for pos in units.keys():
		var u: UnitData = units[pos]
		if u and u.is_facedown:
			var tile = board.get_tile(pos.x, pos.y)
			if tile:
				tile.set_art(CARD_BACK)
	battle_sys._enforce_visual_face_state()

	# ✅ Wait a frame to ensure UI and data are synced
	await get_tree().process_frame

	# ✅ Explicitly re-sync player essence before next turn starts
	emit_signal("essence_changed", player_essence, enemy_essence)
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
	
func cancel_summon_popup() -> void:
	if ui_sys and ui_sys.has_method("hide_popup"):
		ui_sys.hide_popup()
	if battle_sys and battle_sys.has_method("clear_summon_highlights"):
		battle_sys.call("clear_summon_highlights")
	if ui_sys and ui_sys.has_method("fade_hand_in"):
		ui_sys.fade_hand_in()

	fusion_selection.clear()
	selected_card = null
	dragging_card = null
	selected_pos = Vector2i(-1, -1)

	_log("❎ Summon canceled.", Color(0.8, 0.8, 0.8))
	_set_phase(Phase.SUMMON_OR_MOVE)
	_update_phase_ui()

func _play_card_place_sound(card_data: CardData = null, is_facedown: bool = false) -> void:
	var sound: AudioStream = null

	# 🔹 1️⃣ Choose correct sound
	if is_facedown:
		# Default facedown sound
		sound = preload("res://Audio/Sound FX/Cardfacedown.mp3")
	elif card_data:
		# Try meta key or property directly
		if card_data.has_meta("place_sound"):
			var meta_val = card_data.get_meta("place_sound")
			if meta_val is String:
				sound = load(meta_val)
			elif meta_val is AudioStream:
				sound = meta_val
		elif "place_sound" in card_data:
			var prop_val = card_data.place_sound
			if prop_val is String:
				sound = load(prop_val)
			elif prop_val is AudioStream:
				sound = prop_val
	else:
		# Fallback generic sound
		sound = preload("res://Audio/Sound FX/Cardfacedown.mp3")

	# 🔹 2️⃣ Play globally (UI-style)
	if sound:
		var p := AudioStreamPlayer.new()
		add_child(p)
		p.stream = sound
		p.volume_db = -5.0
		p.pitch_scale = randf_range(0.95, 1.05)
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
	
func _gain_essence(owner: int, amount: int = 1) -> void:
	if owner == PLAYER:
		player_essence = clamp(player_essence + amount, 0, 8)
	else:
		enemy_essence = clamp(enemy_essence + amount, 0, 8)

	print("💧 Essence updated: Player =", player_essence, "Enemy =", enemy_essence)
	emit_signal("essence_changed", player_essence, enemy_essence)

		# 🩵 Force UI + hand sync every time essence changes
	if owner == PLAYER and ui_sys and ui_sys.has_method("refresh_hand"):
		ui_sys.call("refresh_hand", player_hand, player_essence, true)


func on_leader_damaged(owner: int, new_hp: int) -> void:
	emit_signal("hp_changed", owner, new_hp)

func on_leader_defeated(owner: int) -> void:
	if owner == PLAYER:
		_log("💀 Your Leader has fallen!", Color(1,0.3,0.3))
		ui_sys.call("show_battle_message", "Your Leader has fallen! You lose!", 2.5)
		await get_tree().create_timer(2.5).timeout
		emit_signal("battle_finished", "player_lost")
	else:
		_log("🏆 Enemy Leader defeated! You win!", Color(0.3,1,0.3))
		ui_sys.call("show_battle_message", "Enemy Leader defeated! You win!", 2.5)
		await get_tree().create_timer(2.5).timeout
		emit_signal("battle_finished", "player_won")

# -----------------------------
# INPUT HUB (delegates to systems)
# -----------------------------
func _unhandled_input(event: InputEvent) -> void:
	if InputState.mode == InputState.Mode.DIALOGUE:
		return
	# ==========================================================
	# 🧬 FUSION PENDING INPUT HANDLING
	# ==========================================================
	if _is_fusion_pending_active:
		if event is InputEventMouseButton and event.pressed:

			# ✅ RIGHT-CLICK → cancel fusion
			if event.button_index == MOUSE_BUTTON_RIGHT:
				if ui_sys and ui_sys.has_method("hide_fusion_pending"):
					ui_sys.hide_fusion_pending()
				if has_method("stop_fusion_pending_hum"):
					stop_fusion_pending_hum()

				_is_fusion_pending_active = false
				fusion_selection.clear()
				selected_card = null
				dragging_card = null
				selected_pos = Vector2i(-1, -1)

				# 🧹 Full visual + UI reset
				if ui_sys:
					# Reset hover/selection tweens
					if "_selected_card_ui_map" in ui_sys:
						ui_sys._selected_card_ui_map.clear()
					if "_hover_card_tween_map" in ui_sys:
						for tw in ui_sys._hover_card_tween_map.values():
							if tw and tw.is_running():
								tw.kill()
						ui_sys._hover_card_tween_map.clear()

					# Reset card visuals
					if ui_sys.has_node("BottomContainer/Hand"):
						var hand: GridContainer = ui_sys.get_node("BottomContainer/Hand")
						for card_ui in hand.get_children():
							if card_ui is Control:
								card_ui.position.y = 0
								card_ui.scale = Vector2.ONE

					# ✅ Instantly refresh the hand (fixes visual drift)
					if ui_sys.has_method("refresh_hand"):
						ui_sys.refresh_hand(player_hand, player_essence, true)

				_log("❎ Fusion canceled.", Color(0.8, 0.8, 0.8))

				if ui_sys and ui_sys.has_method("fade_hand_in"):
					ui_sys.fade_hand_in()

				_set_phase(Phase.SUMMON_OR_MOVE)
				_update_phase_ui()
				return


	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("left clicking")
			if hovered_tile:
				# 🧬 If two cards are selected, always do fusion
				if fusion_selection.size() == 2:
					try_place_dragged_card(hovered_tile)
					return

				# 🎴 If one card is selected (normal summon)
				elif fusion_selection.size() == 1:
					
					selected_card = fusion_selection[0]
					dragging_card = selected_card

					if ui_sys and ui_sys.has_method("fade_hand_out"):
						ui_sys.fade_hand_out()
					if ui_sys and ui_sys.has_method("on_drag_start"):
						ui_sys.on_drag_start(selected_card)

					try_place_dragged_card(hovered_tile)
					return

			# Otherwise, forward click to board
			if move_sys and move_sys.has_method("on_board_click"):
				move_sys.call("on_board_click", event.position)
				return


		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 🧹 Cancel current selection or drag
			if selected_card or not fusion_selection.is_empty():
				var deselected_names := []
				for c in fusion_selection:
					deselected_names.append(c.name)
				if selected_card and not deselected_names.has(selected_card.name):
					deselected_names.append(selected_card.name)
				if ui_sys and "_selected_card_ui_map" in ui_sys:
					ui_sys._selected_card_ui_map.clear()

				_log("❎ Deselected %s" % ", ".join(deselected_names), Color(0.8, 0.8, 0.8))
				# 🧩 If a summon popup is active — close it instead of just deselecting
				if ui_sys and ui_sys.has_method("is_popup_open") and ui_sys.is_popup_open():
					cancel_summon_popup()
					get_viewport().set_input_as_handled()
					return

			if ui_sys and ui_sys.has_node("BottomContainer/Hand"):
				var hand: GridContainer = ui_sys.get_node("BottomContainer/Hand")
				for card_ui in hand.get_children():
					if card_ui is Control:
						# Reset hover/selection tweens ONLY
						card_ui.position.y = 0
						# ✅ Restore essence-based tint instead of forcing white
						if card_ui.has_method("get_card_data") and card_ui.has_method("set_playable"):
							var c = card_ui.get_card_data()
							if c:
								var cost := 1
								if c.has_meta("cost"): cost = int(c.get_meta("cost"))
								elif c.has_method("get_cost"): cost = c.get_cost()
								elif "cost" in c: cost = int(c.cost)
								card_ui.set_playable(cost <= player_essence)

			# Reset hover / highlights / selections
			if ui_sys and ui_sys.has_method("hide_fusion_pending"):
				ui_sys.hide_fusion_pending()
			if battle_sys and battle_sys.has_method("clear_highlights"):
				battle_sys.call("clear_highlights")

			selected_card = null
			fusion_selection.clear()
						# 🧩 Also reset all UI-side card selections and tweens
			if ui_sys:
				if "_selected_card_ui_map" in ui_sys:
					ui_sys._selected_card_ui_map.clear()
				if "_hover_card_tween_map" in ui_sys:
					for tw in ui_sys._hover_card_tween_map.values():
						if tw and tw.is_running():
							tw.kill()
					ui_sys._hover_card_tween_map.clear()

				# Reset card positions visually
				if ui_sys.has_node("BottomContainer/Hand"):
					var hand: GridContainer = ui_sys.get_node("BottomContainer/Hand")
					for card_ui in hand.get_children():
						if card_ui is Control:
							card_ui.position.y = 0
							card_ui.scale = Vector2.ONE

			dragging_card = null
			selected_pos = Vector2i(-1, -1)

			if ui_sys:
				if ui_sys.has_method("hide_hover"):
					ui_sys.call("hide_hover")
				if ui_sys.has_method("fade_hand_in"):
					ui_sys.call("fade_hand_in")
				if ui_sys.has_method("cancel_drag"):
					ui_sys.call("cancel_drag")

			_set_phase(Phase.SUMMON_OR_MOVE)
			_update_phase_ui()


	# ✅ Handle keyboard / mouse motion separately
	elif event is InputEventKey and event.keycode == KEY_SHIFT:
		camera_sys.call_deferred("toggle_freelook", event.pressed)
	elif event is InputEventMouseMotion:
		if camera_sys and camera_sys.has_method("forward_mouse_motion"):
			if camera_sys.get("is_freelook"):
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

func stop_fusion_pending_hum():
	if has_node("FusionPendingHum"):
		var hum := get_node("FusionPendingHum")
		if hum and hum.playing:
			hum.stop()
		hum.queue_free()
