# File: res://UI/orb_grid.gd
extends Control

@export var orb_scene: PackedScene = preload("res://AnimatedOrb.tscn") # or whatever orb icon scene you use
var current_essence := 0

func _ready():
	clear_orbs()

func set_essence(amount: int) -> void:
	if amount == current_essence:
		return
	current_essence = amount
	_refresh_grid()

func _refresh_grid() -> void:
	clear_orbs()
	for i in range(current_essence):
		var orb = orb_scene.instantiate()
		add_child(orb)
		# Optional pop-in animation
		orb.scale = Vector2(0, 0)
		var t = create_tween()
		t.tween_property(orb, "scale", Vector2(1, 1), 0.2).set_delay(i * 0.05)

func clear_orbs() -> void:
	for child in get_children():
		child.queue_free()
