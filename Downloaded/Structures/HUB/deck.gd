# Deck.gd
extends Node3D
class_name ElementDeck

@export_enum("Fire", "Water", "Earth", "Wind") var element_type: String = "Fire"

signal interacted(element_type)

@export var label: Label3D
@onready var sparks: GPUParticles3D = $BODY/Sparks
@onready var sfx: AudioStreamPlayer3D = $SFX



func show_label():
	print("SHOW LABEL!")
	label.visible = true
	label.modulate = Color(1,1,1,1)
	sparks.emitting = true
	sfx.play()
	#label.modulate.a = 0.0
	var t = get_tree().create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.15)


func hide_label():
	if not label:
		return

	var t = get_tree().create_tween()
	sparks.emitting = false
	sfx.stop()
	t.tween_property(label, "modulate:a", 0.0, 0.15)
	t.finished.connect(func():
		label.visible = false)
