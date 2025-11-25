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
# -------------------------------------------------------------
# BIOMES
# -------------------------------------------------------------
enum Biome {
	#DEFAULT,
	OCEAN,
	VOLCANO,
	FOREST,
	MEADOW,
	MOUNTAIN,
	TUNDRA
}

@export var biome: Biome = Biome.TUNDRA

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
	
func get_tile_from_collider(node: Node) -> Node3D:
	while node and not node.has_meta("tile_marker"):
		node = node.get_parent()
	if node and node.has_meta("tile_marker"):
		return node as Node3D
	return null

func get_unit_position(unit: UnitData) -> Vector2i:
	for pos in tiles.keys():
		var tile = tiles[pos]
		if tile and tile.occupant == unit:
			return pos
	return Vector2i(-1, -1)

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
		#Biome.DEFAULT:
			#base_terrain = "Default"
			#terrain_weights = {"Default": 1.0}
		Biome.OCEAN:
			base_terrain = "Water"
			terrain_weights = {"Water": 0.7, "Stone": 0.2, "Grass": 0.1}
		Biome.VOLCANO:
			base_terrain = "Lava"
			terrain_weights = {"Lava": 0.8, "Stone": 0.2}
		Biome.FOREST:
			base_terrain = "Forest"
			terrain_weights = {"Forest": 0.7, "Grass": 0.2, "Stone": 0.1}
		Biome.MEADOW:
			base_terrain = "Grass"
			terrain_weights = {"Grass": 0.7, "Stone": 0.2, "Forest": 0.1}
		Biome.MOUNTAIN:
			base_terrain = "Stone"
			terrain_weights = {"Stone": 0.7, "Grass": 0.2, "Forest": 0.1}
		Biome.TUNDRA:
			base_terrain = "Ice"
			terrain_weights = {"Ice": 0.6, "Stone": 0.2, "Water": 0.2}

	# --- STEP 1: Create layered or patterned map ---
	var map := []
	for y in range(height):
		map.append([])
		for x in range(width):
			var t := base_terrain

			# Create gradient or pattern bands by row
			var row_ratio := float(y) / float(height - 1)
			match biome:
				Biome.OCEAN:
					if row_ratio < 0.4:
						t = "Water"
					elif row_ratio < 0.7:
						t = "Grass"
					else:
						t = "Stone"

				Biome.VOLCANO:
					if row_ratio < 0.3:
						t = "Lava"
					elif row_ratio < 0.6:
						t = "Stone"
					else:
						t = "Lava"

				Biome.FOREST:
					if row_ratio < 0.4:
						t = "Forest"
					elif row_ratio < 0.7:
						t = "Grass"
					else:
						t = "Stone"

				Biome.MOUNTAIN:
					if row_ratio < 0.3:
						t = "Stone"
					elif row_ratio < 0.6:
						t = "Grass"
					else:
						t = "Forest"

				Biome.TUNDRA:
					if row_ratio < 0.3:
						t = "Ice"
					elif row_ratio < 0.6:
						t = "Stone"
					else:
						t = "Water"

				Biome.MEADOW:
					if row_ratio < 0.5:
						t = "Grass"
					else:
						t = "Forest"

			map[y].append(t)

	# --- STEP 2: Add small variation for natural feel ---
	for y in range(height):
		for x in range(width):
			if randf() < 0.12:
				map[y][x] = _pick_weighted(terrain_weights)
#
			## ✅ Normalize Default to base_terrain (so it behaves consistently)
			#if map[y][x] == "Default":
				#map[y][x] = base_terrain

	# --- STEP 2.5: Add HOLE terrain (guaranteed 1, max 3 on 7x7 board) ---
	var max_holes := 3
	var hole_count := 0
	var total_tiles := width * height
	var target_holes := randi_range(1, max_holes)  # Always want 1-3 holes

	# ✅ GUARANTEED: Place at least 1 hole
	while hole_count < target_holes:
		var hx := randi_range(1, width - 2)  # Avoid edges
		var hy := randi_range(1, height - 2)  # Avoid edges

		# Don't overwrite if already a hole
		if map[hy][hx] != "Hole":
			map[hy][hx] = "Hole"
			hole_count += 1
			print("⚫ Placed HOLE at (%d, %d)" % [hx, hy])

		# Safety: prevent infinite loop if board is too small
		if hole_count >= max_holes or hole_count >= (width - 2) * (height - 2):
			break

	print("⚫ Total holes placed: %d" % hole_count)

	# --- STEP 3: Instantiate tiles ---
	for y in range(height):
		for x in range(width):
			var tile := tile_scene.instantiate()
			tile.set_core(core)
			tile.x = x
			tile.y = y
			tile.terrain_type = map[y][x]

			if tile.has_method("_apply_terrain_visual"):
				tile._apply_terrain_visual()

			#if tile.terrain_type == base_terrain and tile.has_method("set_default_visual"):
				#tile.set_default_visual()

			# ✅ Mark as tile so we can detect from any child collider
			tile.set_meta("tile_marker", true)

			# ✅ Connect hover signals for UI info display
			if tile.has_signal("hovered"):
				tile.hovered.connect(_on_tile_hovered)
			if tile.has_signal("unhovered"):
				tile.unhovered.connect(_on_tile_hover_exited)

			var pos_x := (x - half_w) * spacing
			var pos_z := -(y - half_h) * spacing
			tile.position = Vector3(pos_x, 0, pos_z)
			add_child(tile)
			tiles[Vector2i(x, y)] = tile


	position = Vector3.ZERO
	print("Generated %d patterned tiles." % tiles.size())

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

func is_in_bounds(pos: Vector2i) -> bool:
	if not core:
		return false
	return pos.x >= 0 and pos.y >= 0 and pos.x < core.BOARD_W and pos.y < core.BOARD_H

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

func are_move_highlights_visible(selected_pos: Vector2i) -> bool:
	# ✅ If the player has a valid selected tile, that counts as "active selection"
	if selected_pos != Vector2i(-1, -1):
		var sel_tile = get_tile(selected_pos.x, selected_pos.y)
		if sel_tile and sel_tile.occupant and sel_tile.occupant.owner == core.PLAYER:
			return true

	# ✅ Otherwise, check if any MoveHighlight visuals are showing
	for child in get_children():
		if child.has_node("MoveHighlight"):
			var mh = child.get_node("MoveHighlight")
			if mh.visible:
				return true
	return false

# -------------------------------------------------------------
# ✨ TILE FLASH / HIGHLIGHT EFFECT
# -------------------------------------------------------------
func flash_tiles(positions: Array, color: Color = Color(1.0, 0.8, 0.3), duration: float = 0.25) -> void:
	if positions.is_empty():
		return

	for pos in positions:
		if not tiles.has(pos):
			continue
		var tile = tiles[pos]
		if not tile:
			continue

		var mesh: MeshInstance3D = tile.get_node_or_null("MeshInstance3D")
		if not mesh:
			for child in tile.get_children():
				if child is MeshInstance3D:
					mesh = child
					break
		if not mesh:
			continue

		var mat := mesh.get_active_material(0)
		if not mat:
			continue

		mat = mat.duplicate()
		mesh.set_surface_override_material(0, mat)

		# --- Handle StandardMaterial3D ---
		if mat is StandardMaterial3D:
			mat.emission_enabled = true
			mat.emission = color

			var tween := create_tween()
			tween.tween_method(
				func(v):
					mat.emission = color * v
			, 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

			tween.tween_callback(func():
				mat.emission_enabled = false
			)

		# --- Handle ShaderMaterial (if tile uses a custom shader) ---
		elif mat is ShaderMaterial:
			if mat.shader.has_param("emission"):
				mat.set_shader_parameter("emission", color)
			elif mat.shader.has_param("flash_strength"):
				mat.set_shader_parameter("flash_strength", 1.0)

			var tween := create_tween()
			tween.tween_method(
				func(v):
					if mat.shader.has_param("emission"):
						mat.set_shader_parameter("emission", color * v)
					elif mat.shader.has_param("flash_strength"):
						mat.set_shader_parameter("flash_strength", v)
			, 1.0, 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

			tween.tween_callback(func():
				if mat.shader.has_param("emission"):
					mat.set_shader_parameter("emission", Color(0,0,0))
				elif mat.shader.has_param("flash_strength"):
					mat.set_shader_parameter("flash_strength", 0.0)
)
