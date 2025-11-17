extends Control
class_name BattleUI

@onready var attacker_art: TextureRect = $HBoxContainer/PlayerPanel/PlayerArt
@onready var defender_art: TextureRect = $HBoxContainer/EnemyPanel/EnemyArt
@onready var attacker_name: Label = $HBoxContainer/PlayerPanel/PlayerName
@onready var defender_name: Label = $HBoxContainer/EnemyPanel/EnemyName
@onready var attacker_atk: Label = $HBoxContainer/PlayerPanel/PlayerArt/ATKContainer/ATKSTAT
@onready var attacker_def: Label = $HBoxContainer/PlayerPanel/PlayerArt/DEFContainer/DEFSTAT
@onready var defender_atk: Label = $HBoxContainer/EnemyPanel/EnemyArt/ATKContainer/ATKSTAT
@onready var defender_def: Label = $HBoxContainer/EnemyPanel/EnemyArt/DEFContainer/DEFSTAT
@onready var player_dmg: Label = $HBoxContainer/PlayerPanel/PlayerArt/PlayerDamageLabel
@onready var enemy_dmg: Label = $HBoxContainer/EnemyPanel/EnemyArt/EnemyDamageLabel
@onready var hand: GridContainer = $"../BottomContainer/Hand"

# --- Default fallback Audio ---
@export var default_attack_sound: AudioStream = preload("res://Audio/Sound FX/Attack.mp3")
@export var death_sound: AudioStream = preload("res://Audio/Sound FX/CardDeath.mp3")
@export var counter_sound: AudioStream = preload("res://Audio/Sound FX/Attack.mp3")

# --- Public interface ----------------------------------------------------------
func show_battle(att: UnitData, defn: UnitData) -> void:
	visible = true
	modulate.a = 1.0

	attacker_art.texture = att.card.art
	defender_art.texture = defn.card.art
	attacker_name.text = att.card.name
	defender_name.text = defn.card.name
	refresh_stats(att, defn)

	player_dmg.visible = false
	enemy_dmg.visible = false


func play_attack_phase(att: UnitData, defn: UnitData, damage_to_def: int, hit_number: int = 0, total_hits: int = 1) -> void:
	refresh_stats(att, defn)
	show_battle(att, defn)

	# 🎵 Use card-specific attack sound if available
	var sound_to_play: AudioStream = null
	if att.card and "attack_sound" in att.card and att.card.attack_sound:
		sound_to_play = att.card.attack_sound
	else:
		sound_to_play = default_attack_sound

	_play_sound(sound_to_play)

	await _animate_hit("attacker", "defender", damage_to_def, hit_number, total_hits)

	refresh_stats(att, defn)
	await get_tree().process_frame

	# 💀 If defender died, play death sound
	if defn.current_def <= 0:
		if defn.card and "death_sound" in defn.card and defn.card.death_sound:
			_play_sound(defn.card.death_sound)
		else:
			_play_sound(death_sound)
		return

	if damage_to_def > 0:
		await _flash_stat(defender_def, Color(1, 0.4, 0.4))


func play_counter_phase(defn: UnitData, att: UnitData, damage_to_att: int) -> void:
	# 🎵 Counter attacker uses its own sound too (defender attacks back)
	var counter_sound_to_play: AudioStream = null
	if defn.card and "attack_sound" in defn.card and defn.card.attack_sound:
		counter_sound_to_play = defn.card.attack_sound
	else:
		counter_sound_to_play = counter_sound

	if damage_to_att > 0:
		_play_sound(counter_sound_to_play)

	await _animate_hit("defender", "attacker", damage_to_att)

	refresh_stats(att, defn)
	await get_tree().process_frame

	# 💀 If attacker died, play death sound
	if att.current_def <= 0:
		if att.card and "death_sound" in att.card and att.card.death_sound:
			_play_sound(att.card.death_sound)
		else:
			_play_sound(death_sound)
		return

	if damage_to_att > 0:
		await _flash_stat(attacker_def, Color(0.4, 0.8, 1.0))


func fade_out_battle() -> void:
	if not visible:
		return
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	visible = false


# 🎯 Show overflow damage to leader
func show_overflow_damage(damage: int, target_side: String) -> void:
	# Determine which card art to overlay
	var target_art: TextureRect
	if target_side == "defender":
		target_art = defender_art
	else:
		target_art = attacker_art

	# Create overflow label dynamically
	var overflow_label := Label.new()
	overflow_label.text = "⚡ OVERFLOW\n-%d" % damage
	overflow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overflow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Style the label
	overflow_label.add_theme_font_size_override("font_size", 42)
	overflow_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	overflow_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	overflow_label.add_theme_constant_override("outline_size", 8)

	# Position it over the card art
	overflow_label.anchor_left = 0.0
	overflow_label.anchor_top = 0.0
	overflow_label.anchor_right = 1.0
	overflow_label.anchor_bottom = 1.0
	overflow_label.modulate.a = 0.0

	target_art.add_child(overflow_label)

	# Animate the overflow label
	var tw = create_tween()
	tw.tween_property(overflow_label, "modulate:a", 1.0, 0.2)
	tw.tween_property(overflow_label, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)  # Stay visible longer
	tw.tween_property(overflow_label, "modulate:a", 0.0, 0.3)
	tw.tween_property(overflow_label, "scale", Vector2(1.5, 1.5), 0.3)
	await tw.finished

	overflow_label.queue_free()


# --- Helpers -------------------------------------------------------------------
func refresh_stats(att: UnitData, defn: UnitData) -> void:
	if not att or not defn:
		return
	attacker_atk.text = "%d" % att.current_atk
	attacker_def.text = "%d" % att.current_def
	defender_atk.text = "%d" % defn.current_atk
	defender_def.text = "%d" % defn.current_def


func _animate_hit(from_side: String, to_side: String, damage: int, hit_number: int = 0, total_hits: int = 1) -> void:
	var attacker_node: TextureRect
	var defender_node: TextureRect
	var dmg_label: Label

	if from_side == "attacker":
		attacker_node = attacker_art
		defender_node = defender_art
		dmg_label = enemy_dmg
	else:
		attacker_node = defender_art
		defender_node = attacker_art
		dmg_label = player_dmg

	# Show damage with hit number for multi-hit attacks
	if total_hits > 1 and hit_number > 0:
		dmg_label.text = "-%d (Hit %d)" % [damage, hit_number]
	else:
		dmg_label.text = "-%d" % damage
	dmg_label.visible = true
	dmg_label.modulate.a = 1.0

	# ⚔️ Smooth attack lunge forward
	var offset = Vector2(50, 0) if from_side == "attacker" else Vector2(-50, 0)
	var original_pos = attacker_node.position

	var tw = create_tween()
	tw.tween_property(attacker_node, "position", original_pos + offset, 0.15)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

	await _flash_hit(defender_node, Color(1, 0.3, 0.3))
	await get_tree().create_timer(0.1).timeout

	# ⚔️ Smooth return to original position
	var tw2 = create_tween()
	tw2.tween_property(attacker_node, "position", original_pos, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw2.parallel().tween_property(dmg_label, "modulate:a", 0.0, 0.3)
	await tw2.finished
	dmg_label.visible = false


func _flash_hit(art: TextureRect, flash_color: Color) -> void:
	var orig = art.modulate
	var tw = create_tween()
	tw.tween_property(art, "modulate", flash_color.lightened(0.8), 0.1)
	tw.tween_property(art, "modulate", orig, 0.2)
	await tw.finished


func _flash_stat(label: Label, flash_color: Color) -> void:
	var orig_col = label.modulate
	var tw = create_tween()
	tw.tween_property(label, "modulate", flash_color.lightened(0.6), 0.1)
	tw.tween_property(label, "scale", Vector2(1.3, 1.3), 0.1)
	tw.tween_property(label, "modulate", orig_col, 0.25)
	tw.tween_property(label, "scale", Vector2.ONE, 0.25)
	await tw.finished


# --- Sound helper ---------------------------------------------------------------
func _play_sound(sound: AudioStream) -> void:
	if not sound:
		return
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = sound
	p.volume_db = -8.0
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()
	p.connect("finished", Callable(p, "queue_free"))
