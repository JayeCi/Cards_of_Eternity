extends Control
class_name BattleUI

@onready var attacker_art: TextureRect = $HBoxContainer/AttackerPanel/AttackerArt
@onready var defender_art: TextureRect = $HBoxContainer/DefenderPanel/DefenderArt
@onready var attacker_name: Label = $HBoxContainer/AttackerPanel/AttackerName
@onready var defender_name: Label = $HBoxContainer/DefenderPanel/DefenderName
@onready var attacker_atk: Label = $HBoxContainer/AttackerPanel/AttackerATK
@onready var defender_def: Label = $HBoxContainer/DefenderPanel/DefenderDEF
@onready var dmg_label: Label = $DamageLabel

func play_battle(att: UnitData, defn: UnitData, damage: int, defender_died: bool) -> void:
	visible = true
	modulate.a = 0.0
	dmg_label.visible = false
	dmg_label.modulate = Color(1, 0.2, 0.2, 1)
	dmg_label.scale = Vector2.ONE
	dmg_label.z_index = 50

	# Assign visuals
	attacker_art.texture = att.card.art
	defender_art.texture = defn.card.art
	attacker_name.text = att.card.name
	defender_name.text = defn.card.name
	attacker_atk.text = "ATK: %d" % att.current_atk
	defender_def.text = "DEF: %d" % defn.current_def

	# 1) Fade-in
	var fade_in = create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	await get_tree().create_timer(0.3).timeout

	# 2) Attacker lunge
	_play_card_sound(att.card.attack_sound)  # 🔊 <-- PLAY ATTACKER’S ATTACK SOUND
	var atk_tween = create_tween()
	atk_tween.tween_property(attacker_art, "position:x", attacker_art.position.x + 70, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	atk_tween.tween_property(attacker_art, "position:x", attacker_art.position.x, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await atk_tween.finished
	await get_tree().create_timer(0.15).timeout

	# 3) Defender takes damage
	if damage > 0:
		_play_card_sound(defn.card.defense_sound)  # 🔊 <-- PLAY DEFENDER’S DEFENSE SOUND
		await _show_damage_popup(dmg_label, damage, Color(1, 0.3, 0.3), defender_art)
	await get_tree().create_timer(0.2).timeout

	# 4) Defender reaction / counterattack
	if defender_died:
		var fade_tw = create_tween()
		fade_tw.tween_property(defender_art, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await fade_tw.finished
	else:
		# Defender counterattack animation
		var counter_tw = create_tween()
		counter_tw.tween_property(defender_art, "position:x", defender_art.position.x - 50, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		counter_tw.tween_property(defender_art, "position:x", defender_art.position.x, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_play_card_sound(defn.card.attack_sound)  # 🔊 <-- PLAY COUNTERATTACK SOUND
		await counter_tw.finished

		# Counter damage popup
		var counter_dmg := 0
		if defn.mode == UnitData.Mode.ATTACK:
			counter_dmg = max(defn.current_atk, 0)
		elif defn.mode == UnitData.Mode.DEFENSE:
			counter_dmg = int(max(defn.current_atk, 0) * 0.5)

		if counter_dmg > 0:
			await _show_damage_popup(dmg_label, counter_dmg, Color(0.4, 0.8, 1.0), attacker_art)
			await get_tree().create_timer(0.2).timeout

	await get_tree().create_timer(0.2).timeout

	# 5) Fade-out
	var fade_out = create_tween()
	fade_out.tween_property(self, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	visible = false
	
func _play_card_sound(sound: AudioStream):
	if not sound:
		return
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = sound
	player.volume_db = -8.0
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()
	player.connect("finished", Callable(player, "queue_free"))

# Shows a floating damage number above a given art control
func _show_damage_popup(label: Label, amount: int, color: Color, anchor_art: Control) -> void:
	label.visible = true
	label.text = "-%d" % amount
	label.modulate = color
	label.scale = Vector2.ONE * 0.9
	label.modulate.a = 1.0

	# Center above the card art
	var art_rect := anchor_art.get_global_rect()
	var center := art_rect.position + art_rect.size * 0.5
	label.global_position = center - label.size * 0.5 + Vector2(0, -20)

	var tw := create_tween()
	tw.tween_property(label, "global_position:y", label.global_position.y - 60, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	await tw.finished
	label.visible = false
