extends Node3D

@export var x: int
@export var y: int
@export var terrain_type: String = "Stone"

var occupant = null
var highlighted = false

@onready var highlight_mesh = $Highlight
@onready var card_sprite = $CardMesh
@onready var mesh = $TileMesh
@onready var label: Label3D = $Badge
@onready var card_mesh: MeshInstance3D = $CardMesh

func _ready():
	set_meta("tile_marker", true)

	if mesh:
		mesh.mesh = mesh.mesh.duplicate()
		var base_mat = mesh.mesh.surface_get_material(0)
		if base_mat:
			var mat_copy = base_mat.duplicate()
			mesh.set_surface_override_material(0, mat_copy)

	# Hide card mesh by default
	if card_mesh:
		card_mesh.visible = false

func set_highlight(state: bool, symbol: String = ""):
	highlighted = state
	if label:
		label.text = symbol
		label.visible = state and symbol != ""
	
	if highlight_mesh:
		highlight_mesh.visible = state

func set_art(tex: Texture2D):
	if tex == null:
		push_warning("⚠️ set_art called with null texture on tile (%d, %d)" % [x, y])
		return

	# Ensure each tile has its own material instance
	var mat = card_mesh.get_surface_override_material(0)
	if not mat:
		var base_mat = card_mesh.mesh.surface_get_material(0)
		if base_mat:
			mat = base_mat.duplicate()
			card_mesh.set_surface_override_material(0, mat)
		else:
			mat = StandardMaterial3D.new()
			card_mesh.set_surface_override_material(0, mat)

	# ✅ Actually apply the texture to the material
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.albedo_color = Color(1, 1, 1, 1)

	# ✅ Make sure the mesh is visible and slightly raised
	card_mesh.visible = true
	card_mesh.position.y = 0.05

	print("✅ Tile", x, y, "texture set to", tex)

func set_badge_text(text: String):
	label.text = text

func clear():
	occupant = null
	if card_mesh:
		var mat = card_mesh.get_surface_override_material(0)
		if mat:
			mat.albedo_texture = null
		card_mesh.visible = false

	label.text = ""
	set_highlight(false)

func flash():
	if not has_node("HighlightMesh"):
		return

	var mesh = $HighlightMesh
	var tw = create_tween()
	mesh.visible = true
	mesh.modulate = Color(1, 0.5, 0.5, 0.8)  # reddish flash
	tw.tween_property(mesh, "modulate:a", 0.0, 0.3)
	await tw.finished
	mesh.visible = false
	
func set_exhausted(state: bool):
	if card_mesh:
		var mat = card_mesh.get_surface_override_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			card_mesh.set_surface_override_material(0, mat)

		if state:
			mat.albedo_color = Color(0.4, 0.4, 0.4, 0.7)  # darker and semi-transparent
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		else:
			mat.albedo_color = Color(1, 1, 1, 1)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

func _apply_terrain_visual() -> void:
	if not mesh:
		return

	var mat = mesh.get_surface_override_material(0)
	if not mat:
		var base = mesh.mesh.surface_get_material(0)
		mat = base.duplicate() if base else StandardMaterial3D.new()
		mesh.set_surface_override_material(0, mat)

	match terrain_type:
		"Stone":
			mat.albedo_color = Color(0.5, 0.5, 0.5)
		"Grass":
			mat.albedo_color = Color(0.3, 0.8, 0.3)
		"Lava":
			mat.albedo_color = Color(1.0, 0.3, 0.1)
		"Water":
			mat.albedo_color = Color(0.2, 0.4, 1.0)
		"Forest":
			mat.albedo_color = Color(0.1, 0.5, 0.2)
		"Ice":
			mat.albedo_color = Color(0.6, 0.8, 1.0)
