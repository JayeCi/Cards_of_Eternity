extends Node

# ==========================================================
# 🧠 Persistent Tutorial State
# ==========================================================
enum Stage {
	NOT_STARTED,
	HUB_INTRO,
	ARENA_SUMMON_TUTORIAL,
	ARENA_MOVEMENT_TUTORIAL,
	ARENA_TERRAIN_TUTORIAL,
	ARENA_COMBAT_TUTORIAL,
	ARENA_FUSION_TUTORIAL, # ✅ NEW
	COMPLETED
}

var stage: int = Stage.NOT_STARTED
var has_seen_attack_popup: bool = false
var has_moved_a_unit: bool = false
var has_seen_combat: bool = false
var has_learned_terrain: bool = false
var has_learned_fusion: bool = false # ✅ NEW

# Called from HUB
func start_hub_intro(guide: Node) -> void:
	if stage != Stage.NOT_STARTED:
		return

	stage = Stage.HUB_INTRO
	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "The Cards of Eternity are awakening..."),
		DialogueManager._dl("Guide", "Let us begin your training."),
	])

# Called when arena intro is done
func start_arena_summon_tutorial() -> void:
	if stage >= Stage.ARENA_SUMMON_TUTORIAL:
		return

	stage = Stage.ARENA_SUMMON_TUTORIAL
	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Welcome to your first battle!"),
		DialogueManager._dl("Guide", "Try summoning a monster in Attack Mode."),
		DialogueManager._dl("Guide", "Click a hand card, then choose a tile."),
	])

# Called when popup appears
func on_popup_shown_attack_mode(core) -> void:
	if has_seen_attack_popup:
		return
		# Restore cursor + normal UI input
	InputState.set_mode(InputState.Mode.UI)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)



	has_seen_attack_popup = true
	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Attack Mode places your card face-up and activates any On Summon ability."),
		DialogueManager._dl("Guide", "Once summoned, you can move it."),
	])

	DialogueManager.finished.connect(func(_id):
		core.ui_sys.call_deferred("_enable_summon_buttons")
	, Object.CONNECT_ONE_SHOT)

# Called after first manual move
func on_unit_moved():
	if stage < Stage.ARENA_MOVEMENT_TUTORIAL:
		stage = Stage.ARENA_MOVEMENT_TUTORIAL
		DialogueManager.start_convo([
			DialogueManager._dl("Guide", "Good! Movement lets you challenge enemies."),
		])

# Called on first combat resolution
func on_combat_triggered(attacker, defender):
	if has_seen_combat:
		return
	has_seen_combat = true
	stage = Stage.ARENA_COMBAT_TUTORIAL

	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Combat happens when you step onto an enemy."),
		DialogueManager._dl("Guide", "Attackers strike first, then defenders counter!"),
	])

# Called when unit stands on terrain
func on_standing_on_terrain(tile_type: String):
	if has_learned_terrain:
		return
	has_learned_terrain = true
	stage = Stage.ARENA_TERRAIN_TUTORIAL

	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Different terrain affects your stats."),
		DialogueManager._dl("Guide", "Matching your element grants bonuses, some tiles grant negative effects so be careful."),
	])

# ==========================================================
# 🧬 NEW — Fusion Tutorial
# ==========================================================
func on_attempt_fusion():
	if has_learned_fusion:
		return

	has_learned_fusion = true
	stage = Stage.ARENA_FUSION_TUTORIAL

	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Ah, fusion! A powerful technique."),
		DialogueManager._dl("Guide", "If you have 2 cards you want to fuse together, select both and then place them on the board."),
		DialogueManager._dl("Guide", "They will attempt to merge, and if successful, the fused card appears!"),
		DialogueManager._dl("Guide", "If the fusion fails, the second card will be played and the first is destroyed... so choose carefully."),
		DialogueManager._dl("Guide", "Experiment! Different combinations may yield powerful new monsters."),
	])

# Called on win
func on_battle_victory():
	stage = Stage.COMPLETED
	DialogueManager.start_convo([
		DialogueManager._dl("Guide", "Excellent! You’re ready for the realms."),
	])

# Helper
func tutorial_finished() -> bool:
	return stage == Stage.COMPLETED
