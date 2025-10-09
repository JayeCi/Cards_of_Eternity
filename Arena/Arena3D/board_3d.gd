extends Node3D

@export var tile_scene: PackedScene
@export var width: int = 7
@export var height: int = 7
@export var spacing: float = 1.1

var tiles: Dictionary = {}

func _ready() -> void:
	# Clear any existing tiles before generating
	for child in get_children():
		child.queue_free()

	_generate_grid()

func _generate_grid() -> void:
	if not tile_scene:
		push_error("Board3D: tile_scene not assigned!")
		return

	var half_w := (width - 1) * 0.5
	var half_h := (height - 1) * 0.5

	print("Generating board:", width, "x", height)

	for y in range(height):
		for x in range(width):
			var tile := tile_scene.instantiate()
			tile.x = x
			tile.y = y

			# Position tiles evenly around (0,0)
			var pos_x := (x - half_w) * spacing
			var pos_z := -(y - half_h) * spacing
			tile.position = Vector3(pos_x, 0, pos_z)

			add_child(tile)
			tiles[Vector2i(x, y)] = tile

	# Optional: Adjust pivot to grid center
	position = Vector3.ZERO
	print("Generated ", tiles.size(), " tiles total.")

func get_tile(x: int, y: int) -> Node3D:
	return tiles.get(Vector2i(x, y))
