extends Node3D
signal finished(result: String)

@onready var a = $SpriteA
@onready var b = $SpriteB
@onready var flash = $Flash  # optional white Sprite3D or ColorRect

func play_battle(att_card: CardData, def_card: CardData, outcome: String) -> void:
	# --- setup sprites ---
	a.texture = att_card.art
	b.texture = def_card.art
	a.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	a.no_depth_test = true
	b.no_depth_test = true

	# ✅ smaller scale & better spacing
	a.position = Vector3(-2.0, 1.5, -1.5)
	b.position = Vector3( 2.0, 1.5, -1.5)
	a.scale = Vector3.ONE * 0.3
	b.scale = Vector3.ONE * 0.3
	a.visible = true
	b.visible = true
	a.modulate = Color(1, 1, 1, 1)
	b.modulate = Color(1, 1, 1, 1)

	# --- 1. slide-in tween ---
	var tw = create_tween()
	var ta = tw.tween_property(a, "position", Vector3(-0.5, 1.0, 0), 0.4)
	ta.set_trans(Tween.TRANS_SINE)
	ta.set_ease(Tween.EASE_OUT)
	
	var tb = tw.parallel().tween_property(b, "position", Vector3(0.5, 1.0, 0), 0.4)
	tb.set_trans(Tween.TRANS_SINE)
	tb.set_ease(Tween.EASE_OUT)

	await tw.finished
	await get_tree().create_timer(0.05).timeout

	# --- 2. clash impact ---
	var impact = create_tween()
	var ta2 = impact.tween_property(a, "position", Vector3(-0.8, 1.0, 0), 0.08)
	var tb2 = impact.parallel().tween_property(b, "position", Vector3(0.8, 1.0, 0), 0.08)
	await impact.finished

	# --- 3. quick flash ---
	if flash:
		flash.visible = true
		flash.modulate = Color(1, 1, 1, 0)
		var ft = create_tween()
		ft.tween_property(flash, "modulate:a", 1.0, 0.05)
		ft.tween_property(flash, "modulate:a", 0.0, 0.2)
		await ft.finished
		flash.visible = false

	# --- 4. fade out losing card ---
	var fade = create_tween()
	match outcome:
		"attacker_wins":
			fade.tween_property(b, "modulate:a", 0.0, 0.4)
		"defender_wins":
			fade.tween_property(a, "modulate:a", 0.0, 0.4)
		_:
			fade.tween_property(a, "modulate:a", 0.6, 0.4)
			fade.parallel().tween_property(b, "modulate:a", 0.6, 0.4)
	await fade.finished

	await get_tree().create_timer(0.3).timeout
	emit_signal("finished", outcome)
