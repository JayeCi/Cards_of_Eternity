extends Node3D
class_name Board3D

@export var tile_scene: PackedScene
@export var width: int = 7
@export var height: int = 7
@export var spacing: float = 1.1
@onready var card_ui: ArenaCardDetails = get_node("../UISystem/ArenaCardDetails")
@onready var terrain_ui: Control = get_node("../UISystem/ArenaTerrainDetails")
@onready var core: ArenaCore = $".."

# -------------------------------------------------------------
# BIOMES
# -------------------------------------------------------------
enum Biome {
	OCEAN, VOLCANO, FOREST, MEADOW, MOUNTAIN, TUNDRA
}

@export var biome: Biome = Biome.MEADOW

var tiles: Dictionary = {}

# -------------------------------------------------------------
# READY
# -------------------------------------------------------------
func _ready() -> void:
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

# -------------------------------------------------------------
# TILE HOVER
# -------------------------------------------------------------
func _on_tile_hovered(tile: Node3D) -> void:
	if core and core.is_cutscene_active:
		return

	if tile.occupant:
		if card_ui: card_ui.show_unit(tile.occupant)
		if terrain_ui: terrain_ui.visible = false
	else:
		if terrain_ui: terrain_ui.show_terrain(tile.terrain_type)
		if card_ui: card_ui.hide_card()

func _on_tile_hover_exited(tile: Node3D) -> void:
	if core and core.is_cutscene_active:
		return
	if card_ui: card_ui.hide_card()
	if terrain_ui: terrain_ui.hide_terrain()

# -------------------------------------------------------------
# GRID GENERATION
# -------------------------------------------------------------
func _generate_grid() -> void:
	if not tile_scene:
		push_error("Board3D: tile_scene not assigned!")
		return

	var half_w := (width - 1) * 0.5
	var half_h := (height - 1) * 0.5
	tiles.clear()

	print("Generating %s board: %dx%d" % [str(biome), width, height])

	var base_terrain := "Grass"
	var terrain_weights := {}

	match biome:
		Biome.OCEAN:
			base_terrain = "Water"
			terrain_weights = {
				"Water": 0.7,
				"Stone": 0.1,
				"Grass": 0.2
			}
		Biome.VOLCANO:
			base_terrain = "Lava"
			terrain_weights = {
				"Lava": 0.7,
				"Stone": 0.3
			}
		Biome.FOREST:
			base_terrain = "Forest"
			terrain_weights = {
				"Forest": 0.6,
				"Grass": 0.3,
				"Stone": 0.1
			}
		Biome.MEADOW:
			base_terrain = "Grass"
			terrain_weights = {
				"Grass": 0.7,
				"Stone": 0.2,
				"Forest": 0.1
			}
		Biome.MOUNTAIN:
			base_terrain = "Stone"
			terrain_weights = {
				"Stone": 0.6,
				"Grass": 0.3,
				"Forest": 0.1
			}
		Biome.TUNDRA:
			base_terrain = "Ice"
			terrain_weights = {
				"Ice": 0.6,
				"Stone": 0.2,
				"Water": 0.2
			}

	# --- STEP 1: Create a base map ---
	var map := []
	for y in range(height):
		map.append([])
		for x in range(width):
			map[y].append(base_terrain)

	# --- STEP 2: Generate clusters / blobs ---
	var cluster_count = int(width * height * 0.2)
	for i in range(cluster_count):
		var cluster_terrain = _pick_weighted(terrain_weights)
		if cluster_terrain == base_terrain:
			continue
		_seed_cluster(map, cluster_terrain, base_terrain)

	# --- STEP 3: Instantiate tiles ---
	for y in range(height):
		for x in range(width):
			var tile := tile_scene.instantiate()
			tile.x = x
			tile.y = y
			tile.terrain_type = map[y][x]

			if tile.has_method("_apply_terrain_visual"):
				tile._apply_terrain_visual()

			var pos_x := (x - half_w) * spacing
			var pos_z := -(y - half_h) * spacing
			tile.position = Vector3(pos_x, 0, pos_z)
			tile._apply_terrain_visual()
			add_child(tile)
			tiles[Vector2i(x, y)] = tile

	position = Vector3.ZERO
	print("Generated %d tiles." % tiles.size())
	
func get_tile_position_for_unit(unit: UnitData) -> Node3D:
	for pos in tiles.keys():
		var tile = tiles[pos]
		if tile and tile.occupant == unit:
			return tile
	return null
# -------------------------------------------------------------
# HELPERS
# -------------------------------------------------------------
func _pick_weighted(weights: Dictionary) -> String:
	var total = 0.0
	for v in weights.values():
		total += v
	var r = randf() * total
	var acc = 0.0
	for key in weights.keys():
		acc += weights[key]
		if r <= acc:
			return key
	return weights.keys()[0]

func _seed_cluster(map: Array, terrain: String, base_terrain: String) -> void:
	var h = map.size()
	var w = map[0].size()
	var cx = randi() % w
	var cy = randi() % h
	var size = randi_range(3, 6)

	for i in range(size):
		var px = clamp(cx + randi_range(-2, 2), 0, w - 1)
		var py = clamp(cy + randi_range(-2, 2), 0, h - 1)
		map[py][px] = terrain

func get_tile(x: int, y: int) -> Node3D:
	return tiles.get(Vector2i(x, y))
