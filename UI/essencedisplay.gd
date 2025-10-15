extends Control

@onready var grid: GridContainer = $"."
@export var orb_scene: PackedScene
var current_essence := 0

func set_essence(amount: int) -> void:
	# Only rebuild if value changed
	if amount == current_essence:
		return
	current_essence = amount

	# Clear old orbs
	for c in grid.get_children():
		c.queue_free()

	# Add new orbs
	for i in range(amount):
		var orb := orb_scene.instantiate()
		grid.add_child(orb)
		
		# If orb_scene is a Control wrapper with AnimatedSprite2D inside:
		if orb.has_node("Orb"):
			var sprite: AnimatedSprite2D = orb.get_node("Orb")
			sprite.play("rotate")
		elif orb is AnimatedSprite2D:
			# If orb_scene is directly an AnimatedSprite2D
			orb.play("rotate")
