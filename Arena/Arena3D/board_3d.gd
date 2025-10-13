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

# ✅ NEW HELPER — safely fetch a tile occupied by a given UnitData
func get_tile_position_for_unit(unit: UnitData) -> Node3D:
	for pos in tiles.keys():
		var tile = tiles[pos]
		if tile and tile.occupant == unit:
			return tile
	return null
	
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
			
			var terrain_options = ["Stone", "Grass" , "Lava", "Water", "Forest", "Ice"]
			tile.terrain_type = terrain_options[randi() % terrain_options.size()]
			
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
	
func set_board_layout(layout_name: String) -> void:
	var layout: Array = []

	match layout_name:
		"stone_arena":
			# All Stone
			layout.resize(height)
			for y in range(height):
				layout[y] = []
				for x in range(width):
					layout[y].append("Stone")

		"lava_valley":
			# Outer ring Lava, middle Stone
			layout.resize(height)
			for y in range(height):
				layout[y] = []
				for x in range(width):
					var is_edge = x == 0 or y == 0 or x == width - 1 or y == height - 1
					layout[y].append("Lava" if is_edge else "Stone")

		"forest_meadow":
			# Diagonal forest paths
			layout.resize(height)
			for y in range(height):
				layout[y] = []
				for x in range(width):
					layout[y].append("Forest" if (x + y) % 2 == 0 else "Grass")

		_:
			push_warning("Unknown board layout: %s" % layout_name)
			return

	# Apply layout to tiles
	for y in range(height):
		for x in range(width):
			var tile: Node3D = get_tile(x, y)
			if tile and y < layout.size() and x < layout[y].size():
				tile.terrain_type = layout[y][x]
				tile._apply_terrain_visual()
