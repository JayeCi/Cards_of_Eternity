extends Control

@onready var anim: AnimationPlayer = get_node_or_null("ColorRect/AnimationPlayer")

func fade_out() -> void:
	if anim:
		anim.play("fade_out")
		await anim.animation_finished

func fade_in() -> void:
	if anim:
		anim.play("fade_in")
		await anim.animation_finished
