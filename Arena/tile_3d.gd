extends Node3D
class_name Tile

@export var x: int
@export var y: int
@export var terrain_type: String = "Stone"



var occupant = null
var highlighted = false
var hover_highlight = false 
var summon_highlight := false  
var core: ArenaCore


@onready var card_mesh: MeshInstance3D = $CardMesh
@onready var mesh: MeshInstance3D = $TileMesh
@onready var label: Label3D = $Badge
@onready var hover_area: Area3D = $HoveredArea
@onready var leader_badge: MeshInstance3D = $LeaderBadge
@onready var default_tile: Node3D = $TileMesh/DefaultTile
@onready var move_highlight: MeshInstance3D = $MoveHighlight
@onready var card_border: Sprite3D = $CardMesh/Sprite3D

#TILEMESHES
@onready var water_mesh: MeshInstance3D = $TileMesh/WaterMesh
@onready var stone_mesh: MeshInstance3D = $TileMesh/StoneMesh
@onready var ice_mesh: MeshInstance3D = $TileMesh/IceMesh
@onready var lava_mesh: MeshInstance3D = $TileMesh/LavaMesh
@onready var grass_mesh: MeshInstance3D = $TileMesh/GrassMesh
@onready var forest_mesh: MeshInstance3D = $TileMesh/ForestMesh
@onready var default_mesh: MeshInstance3D = $TileMesh/DefaultMesh
@onready var animation_player: AnimationPlayer = $AnimationPlayer

signal hovered(tile)
signal unhovered(tile)

func _ready():
	make_unique_highlight()

	if card_mesh:
		card_mesh.visible = false  # invisible until art is set
	#await get_tree().create_timer(1.0).timeout
	#print("TEST SHAKE START")
	#var tween := create_tween()
	#tween.tween_property(self, "position:y", position.y + 0.5, 0.2)
	#tween.tween_property(self, "position:y", position.y, 0.2)

	set_meta("tile_marker", true)
	_apply_terrain_visual()
	
	if hover_area:
		hover_area.mouse_entered.connect(_on_mouse_entered)
		hover_area.mouse_exited.connect(_on_mouse_exited) 
	# --- Ensure unique mesh and material per tile ---
	if mesh and mesh.mesh:
		mesh.mesh = mesh.mesh.duplicate()  # duplicate the mesh resource
		var base_mat := mesh.mesh.surface_get_material(0)
		if base_mat:
			var unique_mat = base_mat.duplicate()
			mesh.set_surface_override_material(0, unique_mat)

	# initialize color
	_apply_terrain_visual()



# --- CORE FUNCTION ---
func set_art(tex: Texture2D, flipped: bool = false) -> void:
	if occupant and occupant.has_method("get"):
		flipped = occupant.owner == 1 if not flipped else flipped

	if not card_mesh:
		return

	if tex == null:
		card_mesh.visible = false
		return

	var mat := card_mesh.get_surface_override_material(0)
	if not mat:
		var base_mat := card_mesh.mesh.surface_get_material(0)
		mat = base_mat.duplicate() if base_mat else StandardMaterial3D.new()
		card_mesh.set_surface_override_material(0, mat)

	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.uv1_scale.y = -1 if flipped else 1

	# --- prevent early reveal for leaders ---
	if occupant and occupant.is_leader:
		card_mesh.visible = false
		if card_border:
			card_border.visible = false
	else:
		card_mesh.visible = true
		card_mesh.position.y = 0.05



# --- OTHER VISUAL HELPERS ---
func set_highlight(state: bool, symbol: String = "") -> void:
	highlighted = state
	if label:
		label.text = symbol
		label.visible = state and symbol != ""
	#if highlight_mesh:
		#highlight_mesh.visible = state
		#
func set_move_highlight_tint(color: Color) -> void:
	play_move_highlight_intro(color)

func make_unique_highlight():
	var h: MeshInstance3D = $MoveHighlight
	if h == null:
		return

	# Try surface override first
	var mat := h.get_surface_override_material(0)

	if mat == null:
		# If surface override is empty, duplicate the base surface material
		var base_mat := h.mesh.surface_get_material(0)
		if base_mat:
			mat = base_mat.duplicate(true)
			h.set_surface_override_material(0, mat)
	else:
		# Already has override → duplicate it so each tile is unique
		mat = mat.duplicate(true)
		h.set_surface_override_material(0, mat)

func set_badge_text(text: String) -> void:
	if label:
		label.text = text
		label.visible = text != ""

func set_default_visual():
	# Hide any biome props or special FX
	if has_node("Visuals"):
		for child in $Visuals.get_children():
			child.visible = false

	# Hide buff overlays
	if has_node("BuffIcon"):
		$BuffIcon.visible = false

	# Reset material to plain
	if has_node("MeshInstance3D"):
		var mesh = $MeshInstance3D
		if mesh.material_override:
			var mat = mesh.material_override.duplicate()
			mat.albedo_color = Color(0.8, 0.8, 0.8)
			mesh.material_override = mat

func refresh_card_art() -> void:
	# 🧩 Ensures card art stays visible after terrain or mesh refresh
	if occupant and occupant.card and card_mesh:
		var mat := card_mesh.get_surface_override_material(0)
		if not mat:
			var base := card_mesh.mesh.surface_get_material(0)
			mat = base.duplicate() if base else StandardMaterial3D.new()
			card_mesh.set_surface_override_material(0, mat)

		# 👇 Check if card is facedown - NEVER show face-up art unless properly flipped
		var is_facedown = occupant.is_facedown or (occupant.has_meta("is_facedown") and occupant.get_meta("is_facedown"))
		if is_facedown and core:
			mat.albedo_texture = core.CARD_BACK
		else:
			mat.albedo_texture = occupant.card.art

		mat.albedo_color = Color(1, 1, 1, 1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		card_mesh.visible = true

func clear() -> void:
	# --- fully reset the art mesh ---
	if card_mesh:
		card_mesh.visible = false              # hide the old card
		card_mesh.scale = Vector3.ONE
		var mat := card_mesh.get_surface_override_material(0)
		if not mat and card_mesh.mesh:
			var base := card_mesh.mesh.surface_get_material(0)
			mat = base.duplicate() if base else StandardMaterial3D.new()
			card_mesh.set_surface_override_material(0, mat)
		if mat:
			mat.albedo_texture = null           # ✅ remove leftover card art
			mat.albedo_color = Color(1, 1, 1, 1)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	# --- clear tile data ---
	set_badge_text("")
	set_highlight(false)
	occupant = null

	if leader_badge:
		leader_badge.visible = false

	if move_highlight:
		move_highlight.visible = false

	# --- restore terrain visuals ---
	_apply_terrain_visual()
	
func set_occupant_no_summon(unit: UnitData):
	occupant = unit
	refresh_card_art()   # just updates art, no summon logic
	_update_card_border_color(unit.card.element)
	_update_leader_badge()

func set_occupant(unit: UnitData) -> void:
	occupant = unit

	# Update art if card exists
	if unit and unit.card:
		set_art(unit.card.art, unit.owner == 1)
		_update_card_border_color(unit.card.element)
	else:
		card_mesh.visible = false
		if card_border:
			card_border.visible = false

	# Show/hide the leader badge
	_update_leader_badge()


func _update_card_border_color(element: String = "") -> void:
	if not card_border:
		return

	if not occupant:
		card_border.visible = false
		return

	# 🔹 Determine color by ownership
	var color: Color
	if occupant.owner == core.PLAYER:
		color = Color(0.2, 0.4, 1.0)   # Player Blue
	else:
		color = Color(1.0, 0.2, 0.2)   # Enemy Red

	card_border.visible = true
	card_border.modulate = color

	## Optional: Gentle pulse for subtle animation
	#var tw := create_tween()
	#tw.tween_property(card_border, "modulate:a", 0.8, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tw.tween_property(card_border, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tw.set_loops()

func _pulse_border(border: MeshInstance3D):
	if not border: return
	var tw = create_tween()
	tw.tween_property(border, "scale", border.scale * 1.05, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(border, "scale", border.scale, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.set_loops(0)  # loop forever

func _update_leader_badge() -> void:
	if not leader_badge:
		return

	if occupant and occupant.is_leader:
		leader_badge.visible = true
	else:
		leader_badge.visible = false


func set_exhausted(state: bool) -> void:
	if not card_mesh:
		return
	var mat := card_mesh.get_surface_override_material(0)
	if not mat:
		mat = StandardMaterial3D.new()
		card_mesh.set_surface_override_material(0, mat)

	if state:
		mat.albedo_color = Color(0.4, 0.4, 0.4, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.albedo_color = Color(1, 1, 1, 1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED


# --- TERRAIN COLOR SYSTEM ---
func set_terrain_type(new_type: String) -> void:
	terrain_type = new_type
	if card_mesh and card_mesh.visible and occupant:
		var mat := card_mesh.get_surface_override_material(0)
		if mat:
			# 👇 Check if card is facedown - NEVER show face-up art unless properly flipped
			var is_facedown = occupant.is_facedown or (occupant.has_meta("is_facedown") and occupant.get_meta("is_facedown"))
			if is_facedown and core:
				mat.albedo_texture = core.CARD_BACK
			else:
				mat.albedo_texture = occupant.card.art

	_apply_terrain_visual()

func update_terrain_visual(terrain_type: String) -> void:
	# Find the mesh or Sprite3D that displays the tile
	var mesh: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
	var sprite: Sprite3D = $Sprite3D if has_node("Sprite3D") else null

	# Define textures (you can adjust these paths)
	var textures := {
		"Grass": preload("res://UI/Terrains/grass.png"),
		"Lava": preload("res://UI/Terrains/Lava.png"),
		"Forest": preload("res://Downloaded/Decor/Foliage/forest_0.jpg"),
		"Water": preload("res://UI/Terrains/Water.png"),
		"Ice": preload("res://UI/Terrains/Ice.png"),
		"Stone": preload("res://UI/Terrains/stone.png"),
		"Default": preload("res://UI/Terrains/default_texture.jpg"),
		#"Shadow": preload("res://ui/Terrain/Shadow.png"),
	}

	if sprite:
		if textures.has(terrain_type):
			sprite.texture = textures[terrain_type]
	elif mesh and mesh.get_active_material(0):
		var mat := mesh.get_active_material(0)
		if mat and mat is StandardMaterial3D:
			if textures.has(terrain_type):
				mat.albedo_texture = textures[terrain_type]

	# Optional: subtle flash when it changes
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(0.8, 1.0, 0.8), 0.15)
	tw.tween_property(self, "modulate", Color(1, 1, 1), 0.15)

func _apply_terrain_visual(new_terrain_type: String = "") -> void:
	# ✅ Allow external override
	if new_terrain_type != "":
		terrain_type = new_terrain_type

	# ✅ Hide all terrain meshes first
	for mesh_variant in [
		water_mesh, stone_mesh, ice_mesh, lava_mesh, grass_mesh, forest_mesh, default_mesh
	]:
		if mesh_variant:
			mesh_variant.visible = false

	# ✅ Selectively show correct mesh and apply materials
	match terrain_type:
		"Default":
			if default_mesh:
				default_mesh.visible = true


		"Stone":
			if stone_mesh:
				stone_mesh.visible = true

		"Grass":
			if grass_mesh:
				grass_mesh.visible = true

		"Forest":
			if forest_mesh:
				forest_mesh.visible = true

		"Lava":
			if lava_mesh:
				lava_mesh.visible = true

		"Ice":
			if ice_mesh:
				ice_mesh.visible = true
				if ice_mesh.material_override:
					var mat = ice_mesh.material_override
					mat.albedo_color = Color(0.8, 0.9, 1.0)
					mat.roughness = 0.1
					mat.metallic = 0.3

		"Water":
			if water_mesh:
				water_mesh.visible = true
				if water_mesh.material_override:
					var mat = water_mesh.material_override
					mat.albedo_color = Color(0.2, 0.4, 0.9)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = 0.85

	# ✅ Refresh card art if this tile has an occupant
	if occupant and occupant.card:
		refresh_card_art()

func pulse_move_highlight() -> void:
	if not move_highlight or not move_highlight.visible:
		return

	var mat := move_highlight.get_surface_override_material(0)
	if not mat:
		var base := move_highlight.mesh.surface_get_material(0)
		mat = base.duplicate() if base else StandardMaterial3D.new()
		move_highlight.set_surface_override_material(0, mat)

	# Ensure transparency is enabledw
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.8
	if occupant and occupant.owner != core.PLAYER:
		mat.emission = Color(1, 0, 0)
		mat.emission_energy_multiplier = 3.0
	else:
		var tw = create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.4, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(mat, "albedo_color:a", 0.8, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.set_loops(0)
	

func set_core(core_ref: ArenaCore) -> void:
	core = core_ref
func play_move_highlight_intro(color: Color) -> void:
	if not move_highlight:
		return

	# Ensure material exists
	var mat := move_highlight.get_surface_override_material(0)
	if not mat:
		var base := move_highlight.mesh.surface_get_material(0)
		mat = base.duplicate() if base else StandardMaterial3D.new()
		move_highlight.set_surface_override_material(0, mat)

	# Set initial invisible state
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.albedo_color.a = 0.0  # fully hidden

	move_highlight.scale = Vector3(0.6, 0.6, 0.6)
	move_highlight.visible = true

	var tw := create_tween()

	# Pop & fade-in
	tw.tween_property(mat, "albedo_color:a", 0.8, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(move_highlight, "scale", Vector3(1.15, 1.15, 1.15), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Settle back down
	tw.tween_property(move_highlight, "scale", Vector3(1, 1, 1), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# 🆕 HOVER BEHAVIOR ---
func _on_mouse_entered() -> void:
	hover_highlight = true
	#_update_highlight_visibility()
	emit_signal("hovered", self)
	
func _on_mouse_exited() -> void:
	hover_highlight = false

	## 🧠 Only hide hover highlights if NOT system-marked
	#if not highlighted and not summon_highlight and highlight_mesh:
		#highlight_mesh.visible = false

	emit_signal("unhovered", self)
